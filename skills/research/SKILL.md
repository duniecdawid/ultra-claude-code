---
description: Cache-first research skill — looks up existing research in documentation/technology/research/ and spawns the Researcher agent only on cache miss or stale entry. Covers library/API documentation, architectural patterns research, and market/competitor analysis via a single auto-classified interface. Use when adding a new library, debugging an external dependency, investigating patterns or best practices, running competitor analysis, or any "how does X work / what changed in X / best practice for X" question. Triggers on "research library", "look up docs", "how does X work", "why is X failing", "best practice for X", "competitors for X", "alternatives to X", "landscape of X", "what changed in X".
user-invocable: true
argument-hint: "topic to research [--mode=library|patterns|market]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
---

# Research

Cache-first external research. The skill checks `documentation/technology/research/index.json` for a fresh entry; on hit, it returns an excerpt directly. On miss or stale, it spawns the `researcher` agent as a stateless subagent via the Task tool, waits for the result, and returns it. Research findings are durable project documentation, not invisible cache.

## Why This Skill

Three research pathways (library docs, patterns, market) share one knowledge base and one cache policy. Cache hits are free (no spawn, just a file read). Cache misses spawn an isolated subagent so the caller's context stays clean. Everything the researcher writes is first-class documentation under `documentation/technology/research/` (or `documentation/product/research/` for market mode), committed alongside the code that depends on it.

## Process

### Step 1: Parse Arguments

From `$ARGUMENTS`:

- Extract the topic text (everything that isn't a flag)
- Extract an explicit `--mode=library|patterns|market` if present
- If no `--mode`, classify automatically (Step 2)

### Step 2: Auto-Classify Mode

If the user supplied `--mode`, use it and skip classification. Otherwise apply these heuristics to the topic text:

**`library`** — topic names a specific package, framework, SDK, runtime, database, API, or protocol. Examples:

- `zod`, `nats jetstream consumer config`, `prisma findUnique`, `Node.js 22`, `redis pub/sub`, `postgres listen/notify`
- Single-identifier topics or `{identifier} {feature}` patterns
- **Claude / Anthropic topics always classify as `library`**, even when phrased as how-to. Triggers: `claude code`, `claude agent sdk`, `anthropic api`, `anthropic sdk`, or any Claude Code primitive (`hooks`, `slash commands`, `mcp servers`, `sub-agents`, `output styles`, `plugins`, `claude code settings`, `tool use`, `prompt caching`). The `library-mode.md` reference has a dedicated "Claude / Anthropic Topics" section instructing the researcher to query Ref.tools **and** fetch the curated `docs.claude.com` URLs in parallel.

**`patterns`** — topic is phrased as a strategy, approach, or practice. Examples:

- `rate limiting strategies`, `how to handle auth refresh`, `best practices for webhook retry`, `dependency injection for tests`, `idempotent job handlers`
- Contains words like *strategies, patterns, best practices, how to, approach, handle*

**`market`** — topic is about competitors, alternatives, landscape, or trends. Examples:

- `competitors in project management SaaS`, `alternatives to Stripe`, `current state of vector databases`, `AI coding assistant landscape`, `market trends for authentication services`
- Contains words like *competitors, alternatives, landscape, market, trends, compare X and Y*

**Ambiguous case** — when the topic fits two modes or neither (e.g., bare `GraphQL` could be library or patterns), ask the user via AskUserQuestion which mode applies. Do not silently default; ambiguity is rare enough that asking is the right move.

### Step 3: Compute Target Path & Subject Slug

From `mode` and topic, derive:

- **Subject slug** — kebab-case, ≤4 tokens. For library mode, strip the library/API name (e.g., "zod object schema validation" → `zod`). For patterns mode, use the core pattern phrase (e.g., "rate limiting strategies" → `rate-limiting`). For market mode, use the domain phrase (e.g., "AI coding assistant landscape" → `ai-coding-assistants`).
- **Target path:**
  - `library` → `documentation/technology/research/libraries/{subject}.md`
  - `patterns` → `documentation/technology/research/patterns/{subject}.md`
  - `market` → `documentation/product/research/{subject}.md`

### Step 4: Check the Index

The index lives at `documentation/technology/research/index.json`. If it doesn't exist, skip to Step 6 (cache miss, bootstrap path).

Run this jq query to find a matching fresh entry:

```bash
TODAY=$(date -I)
jq --arg q "$TOPIC_KEYWORDS" \
   --arg type "$MODE" \
   --arg today "$TODAY" \
'.entries
 | to_entries
 | map(select(
     .value.type == $type
     and (.value.expires == null or .value.expires > $today)
     and (
       (.value.subject | ascii_downcase | contains($q | ascii_downcase))
       or ([.value.topics[], .value.summary] | join(" ") | ascii_downcase | contains($q | ascii_downcase))
     )
   ))
 | sort_by(.value.fetched_at)
 | reverse
 | .[0]' documentation/technology/research/index.json
```

Where `$TOPIC_KEYWORDS` is the most significant word in the topic (strip filler like "how to", "best practices for", etc.) and `$MODE` is the classified mode (`library`, `pattern`, or `market`).

**Entries with `expires: null` are always fresh** (frozen research — never auto-expires). Entries with an ISO date are fresh when `expires > today`.

### Step 5: Cache Hit

If the jq query returned an entry:

1. Read the target file referenced by the entry's key.
2. Find the H2 section most relevant to the user's topic (fuzzy title match, or the first section if the topic is broad).
3. Return a structured response:
   - One-sentence header identifying the source file and its `fetched_at` / `expires`
   - The relevant H2 section content
   - A pointer: "Full file: `{target_path}`"

No agent spawn. Done.

### Step 6: Cache Miss — Spawn Researcher

If the index query returned `null`, or the index file doesn't exist:

1. **Check bootstrap:** if `documentation/technology/research/` doesn't exist, that's fine — the researcher agent handles bootstrap on its own.
2. **Read existing file content** (if the target file already exists but is stale): `cat "$TARGET_PATH"` into a string so you can pass it to the agent. If the file doesn't exist, pass an empty string.
3. **Spawn the researcher agent** via the Task tool:

   ```
   Task(
     subagent_type="researcher",
     description="Research {topic}",
     prompt="""
     mode: {mode}
     topic: {topic}
     subject: {subject-slug}
     target_path: {target_path}
     index_path: documentation/technology/research/index.json
     staleness_reason: {reason}
     existing_file_content: |
       {existing content or empty}
     """
   )
   ```

   The agent reads its own root file + one mode-specific reference from `skills/research/references/{mode}-mode.md`, does the research, writes the target file, updates the index, and returns a one-paragraph summary.

4. **Relay the agent's return** to the caller. Also include the target file path so the caller can read it directly if needed.

## Output Format

**Cache hit:**

```
📄 Research: {topic}

From: {target_path}
Last verified: {fetched_at}. Expires: {expires or "never (frozen)"}.

## {H2 section title}

{section content}

Sources:
{source URLs from frontmatter}
```

**Cache miss (after agent return):**

```
🔬 Researched: {topic}

Written to: {target_path}
Fetched: {today}. Expires: {agent-chosen expires}.

{Agent's one-paragraph summary}

Sources:
{source URLs}
```

## Examples

### New library lookup (cache miss)

**User:** `/uc:research zod schema validation`

1. Classify → `library`, subject `zod`, target `documentation/technology/research/libraries/zod.md`
2. Check index → no entry
3. Spawn researcher agent with the above fields, empty existing content
4. Agent writes `zod.md` with sections for schema validation and associated topics, updates index, returns summary
5. Skill returns the summary to the user

### Second lookup on same library (cache hit)

**User:** `/uc:research zod error maps`

1. Classify → `library`, subject `zod`
2. Check index → entry exists, `expires: 2026-04-23`, `topics` includes "error maps"
3. Cache hit. Read `libraries/zod.md`, return the `## Error Maps` section.

### Pattern research

**User:** `/uc:research rate limiting strategies`

1. Classify → `patterns`, subject `rate-limiting`, target `documentation/technology/research/patterns/rate-limiting.md`
2. Index lookup → no entry
3. Spawn researcher in patterns mode
4. Agent writes the file with synthesized content, sets `expires: fetched_at + 90 days`

### Market research (replaces Discovery Mode's market-analyzer subagent)

**User:** `/uc:research competitors in project management SaaS`

1. Classify → `market`, subject `project-management-saas`, target `documentation/product/research/project-management-saas.md`
2. Index lookup → no entry
3. Spawn researcher in market mode
4. Agent writes the file following the existing product research format, sets `expires: fetched_at + 30 days`

### Historical research (frozen)

**User:** `/uc:research history of microservices before 2018`

1. Classify → `patterns`, subject `history-of-microservices-pre-2018`
2. Index lookup → no entry
3. Spawn researcher in patterns mode
4. Agent detects "before 2018" / "history of" signals, sets `expires: null`
5. Any future `/uc:research history of microservices before 2018` call returns the cached entry forever (or until a human deletes it)

## Error Handling

**Ref.tools unavailable:** The researcher agent falls back to WebSearch/WebFetch automatically — the skill doesn't need to handle this.

**Index corruption:** If jq errors on malformed index.json, treat as cache miss and spawn the agent. The agent rebuilds the entry atomically, which self-heals.

**Target file exists but frontmatter is missing or malformed:** Pass the existing content to the agent verbatim; the agent decides whether to preserve, rewrite, or fail. Most often the agent rewrites the file fresh.

**Classification disagreement:** If the user supplied `--mode=X` but the topic obviously doesn't match (e.g., `--mode=market zod`), trust the user and proceed. The researcher will write to the mode-appropriate directory.

## Guidelines

- **Cache first, always.** Never spawn the agent without checking the index. The skill's main value is the cheap cache hit path.
- **One file per library, one file per pattern topic.** Don't create `zod-schemas.md` + `zod-parsing.md` — they go in `zod.md` as H2 sections. The researcher agent handles the merge.
- **Respect `expires: null`.** Frozen entries are deliberate; don't overwrite them unless the user explicitly asks for a refresh.
- **Trust the agent's output.** This skill is a cache layer, not a reviewer. If the agent returns something weird, the fix is in the agent or its mode reference, not in this skill.
- **Classify conservatively.** When ambiguous, ask — don't silently pick a mode and potentially scatter research across the wrong directory.
