---
description: Cache-first research skill — looks up existing research in documentation/technology/research/ (product/domain libraries and patterns) or .claude/ultra/research/ (Claude Code / Agent SDK / Anthropic API harness knowledge) and spawns the Researcher agent only on cache miss or stale entry. Covers library/API documentation, architectural patterns research, and market/competitor analysis via a single auto-classified interface. Use when adding a new library, debugging an external dependency, investigating patterns or best practices, running competitor analysis, asking how Claude Code / Claude Agent SDK / Anthropic API features work, or any "how does X work / what changed in X / best practice for X" question. Triggers on "research library", "look up docs", "how does X work", "why is X failing", "best practice for X", "competitors for X", "alternatives to X", "landscape of X", "what changed in X".
user-invocable: true
argument-hint: "topic to research [--mode=library|patterns|market]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
---

# Research

Cache-first external research. The skill checks the relevant index for a fresh entry; on hit, it returns an excerpt directly. On miss or stale, it spawns the `researcher` agent as a stateless subagent via the Task tool, waits for the result, and returns it. Research findings are durable documentation, not invisible cache.

## Invariant — MANDATORY

**Every invocation of `/uc:research` produces exactly one of two outcomes:**

1. **Cache hit** — an existing research file covers the topic, and you return its relevant section(s) to the caller (see Step 5).
2. **Agent spawn** — the `researcher` subagent is spawned via the Task tool, it does the research, and you return its result to the caller (see Step 6).

**There is no third outcome.** You never return "I couldn't find anything," "the cache had something but not quite right," "the topic was ambiguous so I stopped," or any other shrug. If you are about to reply to the caller without having done (1) or (2), **STOP and spawn the agent.** The spawn is the default fallback for every uncertain case — not a conditional branch you can skip.

The only allowed clarification interrupt is the AskUserQuestion in Step 2 when the topic is genuinely ambiguous between modes. Once the user answers (or you auto-classify), you MUST reach outcome (1) or (2) before ending the turn.

There are **two cache scopes** with separate indexes:

- **Product/domain research** — `documentation/technology/research/index.json` for libraries the product depends on (`zod`, `nats`, `prisma`…), and `documentation/product/research/` for market analysis.
- **Claude harness research** — `.claude/ultra/research/index.json` for Claude Code / Claude Agent SDK / Anthropic API knowledge. This is meta-research about the *tooling we build with*, not the product itself, so it lives alongside other harness state in `.claude/ultra/` (next to `version.json`, `app-context.md`, etc.).

## Why This Skill

Three research pathways (library docs, patterns, market) share one cache policy and one agent. Cache hits are free (no spawn, just a file read). Cache misses spawn an isolated subagent so the caller's context stays clean. Everything the researcher writes is first-class durable documentation, committed alongside whatever depends on it.

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

From `mode`, topic, and Claude-detection (Step 2), derive:

- **Subject slug** — kebab-case, ≤4 tokens. For library mode, strip the library/API name (e.g., "zod object schema validation" → `zod`). For patterns mode, use the core pattern phrase (e.g., "rate limiting strategies" → `rate-limiting`). For market mode, use the domain phrase (e.g., "AI coding assistant landscape" → `ai-coding-assistants`). For Claude topics, slug the specific surface (e.g., "claude code hooks" → `claude-code`, "claude agent sdk subagents" → `claude-agent-sdk`, "anthropic prompt caching" → `anthropic-api`).
- **Target path:**
  - **Claude / Anthropic topics** (any topic that matched the Claude triggers in Step 2) → `.claude/ultra/research/{subject}.md` — flat layout, harness scope
  - `library` (non-Claude) → `documentation/technology/research/libraries/{subject}.md`
  - `patterns` → `documentation/technology/research/patterns/{subject}.md`
  - `market` → `documentation/product/research/{subject}.md`
- **Index path** (used in Step 4):
  - Claude / Anthropic topics → `.claude/ultra/research/index.json`
  - everything else → `documentation/technology/research/index.json`

### Step 4: Check the Index

Pick the index path per Step 3 (`.claude/ultra/research/index.json` for Claude topics, `documentation/technology/research/index.json` otherwise). If it doesn't exist, skip to Step 6 (cache miss, bootstrap path).

Run this jq query to find a matching fresh entry (substitute `$INDEX_PATH` for the chosen index):

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
 | .[0]' "$INDEX_PATH"
```

Where `$TOPIC_KEYWORDS` is the most significant word in the topic (strip filler like "how to", "best practices for", etc.) and `$MODE` is the classified mode (`library`, `pattern`, or `market`).

**Entries with `expires: null` are always fresh** (frozen research — never auto-expires). Entries with an ISO date are fresh when `expires > today`.

### Step 5: Cache Hit Decision

Evaluate the jq result. **A cache hit requires ALL of these to be true:**

1. The jq query returned a non-null entry (not `null`, not an empty array).
2. The entry's `topics[]` array contains at least one element that matches the user's topic keywords (substring, case-insensitive), OR the entry's `subject` contains the topic keywords. If the match was only via the `summary` field, that's a weak signal — treat as cache miss and fall through to Step 6.
3. The entry's `expires` is `null` OR strictly greater than today.

**If all three are true → cache hit:**

1. Read the target file referenced by the entry's key.
2. Find the H2 section whose title contains the user's topic keywords. If no H2 section matches on title, **that is a cache miss** — the index claimed coverage the file doesn't actually deliver. Fall through to Step 6.
3. Return a structured response:
   - One-sentence header identifying the source file and its `fetched_at` / `expires`
   - The relevant H2 section content
   - A pointer: "Full file: `{target_path}`"

**If any of the three is false → fall through to Step 6.** Do NOT narrate "the cache had something close but not quite right" to the user — go spawn the agent. The agent is the authoritative path for anything the cache doesn't fully cover.

### Step 6: Cache Miss — Spawn Researcher (MANDATORY ON ANY NON-HIT)

**You reach this step whenever Step 5 did not produce a cache hit.** That includes: index file missing, jq returned null, entry found but topics don't match, entry found but expired, entry found but the target H2 section is missing, topic ambiguity that the classifier resolved via AskUserQuestion, or any other case where Step 5 did not return content to the caller. **There is no "skip the spawn" branch.** If you're here, you spawn.

1. **Check bootstrap:** if neither the target directory tree nor the index file exists, that's fine — the researcher agent handles bootstrap on its own (creates `documentation/technology/research/` for product topics, or `.claude/ultra/research/` for Claude topics).
2. **Read existing file content** (if the target file already exists but is stale): `cat "$TARGET_PATH"` into a string so you can pass it to the agent. If the file doesn't exist, pass an empty string.
3. **Spawn the researcher agent** via the Task tool, passing the chosen `target_path` and `index_path` (per Step 3):

   ```
   Task(
     subagent_type="researcher",
     description="Research {topic}",
     prompt="""
     mode: {mode}
     topic: {topic}
     subject: {subject-slug}
     target_path: {target_path}
     index_path: {index_path}
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

### Claude harness research

**User:** `/uc:research claude code hooks`

1. Classify → `library` (Claude Code primitive `hooks` matched), subject `claude-code`
2. Target path → `.claude/ultra/research/claude-code.md` (Claude topic — harness scope)
3. Index path → `.claude/ultra/research/index.json` — doesn't exist yet
4. Spawn researcher in library mode; agent bootstraps `.claude/ultra/research/` on first call, queries Ref.tools AND fetches `docs.claude.com` URLs in parallel per the library-mode "Claude / Anthropic Topics" guidance, writes `claude-code.md` with H2 sections per primitive (Hooks, Slash Commands, MCP, etc.), sets `expires: fetched_at + 10 days`

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

- **Every invocation ends in a research result.** Cache hit or agent spawn — no third option. This is the Invariant above, repeated because it is the single most important rule in this skill. If you find yourself about to return without a result, you have a bug in your flow — spawn the agent.
- **Cache first, always.** Check the index before spawning. The skill's main value is the cheap cache hit path.
- **Cache miss is the default fallback, not a separate condition.** Any uncertainty, any weak match, any missing section, any classification ambiguity that didn't resolve to a clear hit → spawn. The agent is cheap compared to returning no result.
- **One file per library, one file per pattern topic.** Don't create `zod-schemas.md` + `zod-parsing.md` — they go in `zod.md` as H2 sections. The researcher agent handles the merge.
- **Respect `expires: null`.** Frozen entries are deliberate; don't overwrite them unless the user explicitly asks for a refresh.
- **Trust the agent's output.** This skill is a cache layer, not a reviewer. If the agent returns something weird, the fix is in the agent or its mode reference, not in this skill.
- **Classify conservatively.** When ambiguous, ask via AskUserQuestion — don't silently pick a mode. After the user answers, resume the flow and reach a cache hit or spawn; never stop mid-skill.
