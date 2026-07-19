---
description: Cache-first research skill — looks up existing research in documentation/technology/research/ (product/domain libraries and patterns) or .claude/ultra/research/ (Claude Code / Agent SDK / Anthropic API harness knowledge) and spawns the Researcher agent only on cache miss or stale entry — in the background by default so the conversation continues while research runs (--sync to block). Covers library/API documentation, architectural patterns research, and market/competitor analysis via a single auto-classified interface. Use when adding a new library, debugging an external dependency, investigating patterns or best practices, running competitor analysis, asking how Claude Code / Claude Agent SDK / Anthropic API features work, or any "how does X work / what changed in X / best practice for X" question. Triggers on "research library", "look up docs", "how does X work", "why is X failing", "best practice for X", "competitors for X", "alternatives to X", "landscape of X", "what changed in X".
user-invocable: true
argument-hint: "topic to research [--mode=library|patterns|market]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
  - ToolSearch
  - mcp__Ref__ref_search_documentation
  - mcp__Ref__ref_read_url
---

# Research

Cache-first external research. The skill checks the relevant index for a fresh entry; on hit, it returns an excerpt directly. On miss or stale, it spawns the `researcher` agent as a stateless **background** subagent via the `Agent` tool (one-shot fan-out, `run_in_background: true` — the conversation continues while it works, and the findings are relayed when its completion notification arrives). Pass `--sync` to block until the result instead. Research findings are durable documentation, not invisible cache.

## Invariant — MANDATORY

**Every invocation of `/uc:research` produces exactly one of three outcomes:**

1. **Cache hit** — an existing research file covers the topic, and you return its relevant section(s) to the caller (see Step 5).
2. **Dispatched (default)** — the `researcher` subagent is spawned in the background via the `Agent` tool (`run_in_background: true`), and you immediately return a dispatch notice (see Step 6). **The dispatch is not the end of the obligation:** when the researcher's completion notification arrives, you MUST relay its result (summary + target path) into the conversation — a dispatch that never resolves to a relay is the same as a shrug.
3. **Sync result** (`--sync`, or background-spawn fallback) — the researcher is spawned with `run_in_background: false`, you wait, and you return its result in the same turn.

**There is no fourth outcome.** You never return "I couldn't find anything," "the cache had something but not quite right," "the topic was ambiguous so I stopped," or any other shrug. If you are about to reply to the caller without having done (1), (2), or (3), **STOP and spawn the agent.** The spawn is the default fallback for every uncertain case — not a conditional branch you can skip.

**Never read or relay `target_path` while a dispatch is pending** — the file may be absent or half-written until the completion notification arrives.

**Background-spawn fallback:** if the background spawn returns an error (in-process teammates cannot spawn background subagents), fall back to outcome (3) silently — spawn sync and wait. Never fail the invocation because backgrounding is unavailable.

The only allowed clarification interrupt is the AskUserQuestion in Step 2 when the topic is genuinely ambiguous between modes. Once the user answers (or you auto-classify), you MUST reach outcome (1), (2), or (3) before ending the turn.

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
- Extract the `--fill-only` flag if present
- Extract the `--sync` flag if present (block on the researcher instead of dispatching it in the background — use when the answer gates the caller's very next step and there is nothing useful to do meanwhile)
- If no `--mode`, classify automatically (Step 2)

**`--fill-only` mode** is for callers that want to ensure research exists without absorbing its content into their own context. It's designed for bulk sweeps from planning modes (see Stage 2 Tech Stack sweep). Semantics:

- Full flow runs (classify → canonicalize → cache check → spawn on miss) exactly as in the default path. The researcher agent still writes the file if spawned. The index still updates.
- The only difference is the caller's return payload: instead of returning the H2 section content (cache hit) or the agent's summary paragraph (cache miss), return a compact envelope: `{target_path, mode, subject, status: "hit" | "pending" | "spawned" | "refreshed" | "failed", expires}`. With the background default, a cache miss returns `status: "pending"` immediately; the researcher's completion notification upgrades it to `"spawned"`/`"refreshed"` (or `"failed"`).
- Bulk sweeps benefit doubly: each miss dispatches its researcher in parallel (fan-out) instead of serializing sync spawns. The sweeping caller MUST collect every completion notification before reading any `target_path` — a `"pending"` entry's file may not exist yet.
- This saves the caller ~2–5K tokens per sweep entry when it just needs "is this research on disk now?" rather than "what does it say?"
- If the caller later needs the content, it reads the returned `target_path` directly (only after the entry's researcher has completed).

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

### Step 3: Canonicalize Subject Slug & Compute Target Path

**Duplicate prevention is load-bearing.** Different callers will phrase the same topic differently — `zod`, `zod v4`, `zod schemas`, `zod object validation`, `zod error maps` must ALL route to `libraries/zod.md`, not create five separate files. The canonicalization rules below make that automatic.

#### 3a. Raw slug derivation

Start with a loose slug from the topic:

- Lowercase the topic text
- Hyphenate spaces
- Strip punctuation except hyphens
- Collapse multiple hyphens into one

Example: "NATS JetStream consumer config" → raw slug `nats-jetstream-consumer-config`.

#### 3b. Canonicalization (reduce to the shortest stable form)

Apply these rules in order to reduce the raw slug to a canonical form:

1. **Strip version markers anywhere in the slug:** drop tokens matching `v\d+(\.\d+)?` (e.g., `v4`, `v9.1`), `\d+\.\d+(\.\d+)?` (e.g., `4.5`, `2.10.1`), and bare `\d+` when it appears AFTER an identifier token (e.g., `node-22` → `node`, but `16-bit` stays `16-bit`). Examples: `zod-v4` → `zod`, `react-16-class-components` → `react-class-components`.
2. **For library mode**, strip these topic-noise words from the slug: `api`, `sdk`, `client`, `server`, `schema`, `schemas`, `schema-validation`, `validation`, `config`, `configuration`, `consumer`, `producer`, `middleware`, `hook`, `hooks`, `plugin`, `plugins`, `module`, `modules`, `library`, `lib`, `docs`, `documentation`, `best`, `practices`, `breaking`, `changes`, `deprecation`, `notes`, `guide`, `tutorial`, `intro`, `overview`, `getting-started`. Also strip method-level qualifiers that aren't package names: `find-unique`, `find-first`, `insert`, `update`, `delete`, `query`, `pub-sub`, `listen-notify`, `stream`, `streams`, `jetstream`. Example: `nats-jetstream-consumer-config` → `nats`, `prisma-find-unique` → `prisma`, `zod-object-schema-validation` → `zod-object` → `zod`.
3. **For patterns mode**, strip filler words: `strategies`, `strategy`, `pattern`, `patterns`, `approach`, `approaches`, `how-to`, `best`, `practices`, `for`, `with`, `the`, `a`, `an`. Example: `rate-limiting-strategies-for-apis` → `rate-limiting`.
4. **For market mode**, strip filler: `competitors`, `alternatives`, `current`, `state`, `landscape`, `market`, `trends`, `in`, `for`, `of`, `the`. Example: `current-state-of-vector-databases` → `vector-databases`.
5. **Collapse** any resulting double-hyphens and trim leading/trailing hyphens.
6. **Minimum length check:** if canonicalization would leave an empty slug, fall back to the raw slug's first token. (Defensive.)

The result is the **canonical subject slug**. For library mode it should be just the package/protocol name (`zod`, `nats`, `prisma`, `redis`, `postgres`, `react`, `express`). For patterns mode it's the core pattern identifier. For market mode it's the domain.

#### 3c. Pre-flight broader match (duplicate prevention)

Before assuming a new file needs to be created, check the index for an existing entry that this canonical slug should merge into. The rule:

- An existing entry matches if (a) its `type` equals the current mode AND (b) its `subject` exactly equals the canonical slug OR is a prefix of the canonical slug OR the canonical slug is a prefix of it.
- "Prefix" is whole-token: `nats` is a prefix of `nats-jetstream` only if split on hyphens; `na` is NOT a prefix of `nats`.

Run this jq query against the chosen index path (per 3d below — do it before Step 4's freshness check):

```bash
jq --arg c "$CANONICAL_SLUG" \
   --arg type "$MODE" \
'.entries
 | to_entries
 | map(select(.value.type == $type))
 | map(select(
     .value.subject == $c
     or ((.value.subject + "-") | startswith($c + "-"))
     or (($c + "-") | startswith(.value.subject + "-"))
   ))
 | sort_by(.value.subject | length)
 | .[0]' "$INDEX_PATH"
```

The `sort_by(subject | length)` prefers the shortest matching subject — so when both `zod` and `zod-schemas` exist (they shouldn't, but defensively), `zod` wins as the canonical home.

**If the pre-flight finds a match:** use that entry's key (path) as `target_path` and its `subject` as the effective subject for this invocation. Go straight to Step 4 (freshness check on the matched entry). If the matched entry is fresh, it's a cache hit; if stale, the researcher spawns to refresh the existing file. **Either way, no new file is created.**

**If no pre-flight match:** compute `target_path` from the canonical subject slug and proceed to Step 4 with the canonical slug as the query target.

#### 3d. Target path & index path from canonical slug

- **Target path** (used only when no pre-flight match exists):
  - **Claude / Anthropic topics** (any topic that matched the Claude triggers in Step 2) → `.claude/ultra/research/{canonical-subject}.md` — flat layout, harness scope
  - `library` (non-Claude) → `documentation/technology/research/libraries/{canonical-subject}.md`
  - `patterns` → `documentation/technology/research/patterns/{canonical-subject}.md`
  - `market` → `documentation/product/research/{canonical-subject}.md`
- **Index path:**
  - Claude / Anthropic topics → `.claude/ultra/research/index.json`
  - everything else → `documentation/technology/research/index.json`

### Step 4: Freshness Check on Matched Entry

At this point Step 3c has either:
- **Found a pre-flight match** — the target entry is chosen; you just verify freshness here.
- **Found no match** — check the index normally using the canonical slug as the query term.

Pick the index path per Step 3d. If it doesn't exist, skip to Step 6 (cache miss, bootstrap path).

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

1. **If `--fill-only`:** return the compact envelope `{target_path, mode, subject, status: "hit", expires}` and stop. Do NOT read the file body.
2. **Otherwise (default mode):** read the target file referenced by the entry's key. Find the H2 section whose title contains the user's topic keywords. If no H2 section matches on title, **that is a cache miss** — the index claimed coverage the file doesn't actually deliver. Fall through to Step 6.
3. Return a structured response:
   - One-sentence header identifying the source file and its `fetched_at` / `expires`
   - The relevant H2 section content
   - A pointer: "Full file: `{target_path}`"

**If any of the three is false → fall through to Step 6.** Do NOT narrate "the cache had something close but not quite right" to the user — go spawn the agent. The agent is the authoritative path for anything the cache doesn't fully cover.

### Step 6: Cache Miss — Spawn Researcher (MANDATORY ON ANY NON-HIT)

**You reach this step whenever Step 5 did not produce a cache hit.** That includes: index file missing, jq returned null, entry found but topics don't match, entry found but expired, entry found but the target H2 section is missing, topic ambiguity that the classifier resolved via AskUserQuestion, or any other case where Step 5 did not return content to the caller. **There is no "skip the spawn" branch.** If you're here, you spawn.

1. **Check bootstrap:** if neither the target directory tree nor the index file exists, that's fine — the researcher agent handles bootstrap on its own (creates `documentation/technology/research/` for product topics, or `.claude/ultra/research/` for Claude topics).
2. **Read existing file content** (if the target file already exists but is stale): `cat "$TARGET_PATH"` into a string so you can pass it to the agent. If the file doesn't exist, pass an empty string.
3. **Pre-fetch Ref.tools URLs** (library and patterns modes only; skip for market mode). MCP tools are only available in the main conversation context, not in subagent contexts, so the skill must do the Ref.tools search here and pass the results to the agent:

   a. Load Ref.tools via ToolSearch: `select:mcp__Ref__ref_search_documentation,mcp__Ref__ref_read_url`
   b. Call `mcp__Ref__ref_search_documentation` with the topic (e.g., `"zod object schema validation typescript"`)
   c. Extract the result URLs into a list. If Ref.tools is unavailable or returns no results, pass an empty list — the agent falls back to WebSearch/WebFetch.

4. **Spawn the researcher agent** via the `Agent` tool — one-shot **background by default**: no `name`, explicit `run_in_background: true` (Mode F per `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`), so the conversation continues while research runs. With `--sync`, use `run_in_background: false` and wait. If the background spawn errors (teammate contexts can't background subagents), retry sync. Pass the chosen `target_path`, `index_path` (per Step 3), and the pre-fetched Ref.tools URLs:

   ```
   Agent(
     subagent_type="researcher",
     run_in_background=true,   # false only with --sync, or as fallback when backgrounding errors
     description="Research {topic}",
     prompt="""
     mode: {mode}
     topic: {topic}
     subject: {subject-slug}
     target_path: {target_path}
     index_path: {index_path}
     staleness_reason: {reason}
     ref_urls:
       - {url1 from Ref.tools search}
       - {url2 from Ref.tools search}
     existing_file_content: |
       {existing content or empty}
     """
   )
   ```

   The agent reads its own root file + one mode-specific reference from `skills/research/references/{mode}-mode.md`, fetches the `ref_urls` via WebFetch as its primary source, supplements with WebSearch, writes the target file, updates the index, and returns a one-paragraph summary.

5. **Return to the caller — two-phase in the background default:**
   - **At dispatch** (background spawn succeeded): immediately return the dispatch notice (see Output Format) — topic, `target_path`, and "research running in background; findings will be relayed when it completes." In `--fill-only` mode, return the compact envelope with `status: "pending"`. Then continue with whatever the conversation was doing. **Do not read `target_path` or claim any findings while the dispatch is pending.**
   - **At the completion notification**: relay the researcher's result — the summary paragraph plus the target file path (`status` upgrades to `"spawned"` new file / `"refreshed"` stale entry updated / `"failed"` with the reason). This relay is mandatory (Invariant outcome 2); fold it into the current conversation turn naturally.
   - **Sync path** (`--sync` or fallback): both phases collapse into one — wait for the agent and return its result directly. Do NOT include the agent's summary paragraph in fill-only mode — the caller will read `target_path` directly if it needs content.

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

**Cache miss — at dispatch (background default):**

```
🔬 Research dispatched: {topic}

Target: {target_path}
Running in the background — findings will be relayed here when it completes. We can continue in the meantime.
```

**Cache miss — at completion (relay on notification, or immediately with `--sync`):**

```
🔬 Researched: {topic}

Written to: {target_path}
Fetched: {today}. Expires: {agent-chosen expires}.

{Agent's one-paragraph summary}

Sources:
{source URLs}
```

**`--fill-only` mode** (cache hit or miss — same compact envelope):

```
{
  "target_path": "documentation/technology/research/libraries/zod.md",
  "mode": "library",
  "subject": "zod",
  "status": "hit" | "pending" | "spawned" | "refreshed" | "failed",
  "expires": "2026-04-24" | null,
  "error": "..."        // only on status=failed
}
```

Callers that invoked `--fill-only` use the `status` field to decide whether the research is available: `"hit"`, `"spawned"`, and `"refreshed"` mean the file is on disk now; `"pending"` means a background researcher is still writing it — the caller must wait for that researcher's completion notification before reading `target_path`. A `failed` status should never happen silently — the skill still returns the envelope so callers can log/report the gap.

## Examples

### New library lookup (cache miss)

**User:** `/uc:research zod schema validation`

1. Classify → `library`, subject `zod`, target `documentation/technology/research/libraries/zod.md`
2. Check index → no entry
3. Spawn researcher agent in the background with the above fields, empty existing content; immediately return the dispatch notice — the conversation continues
4. Agent writes `zod.md` with sections for schema validation and associated topics, updates index, returns summary
5. On the completion notification, skill relays the summary into the conversation

### Blocking lookup (`--sync`)

**User (or a calling skill whose next step needs the answer):** `/uc:research zod schema validation --sync`

Same flow, but step 3 spawns with `run_in_background: false` and steps 3–5 collapse into one turn: wait, then return the summary directly.

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

- **Every invocation ends in a research result.** Cache hit, background dispatch (which MUST later resolve to a relay of the findings), or sync result — no fourth option. This is the Invariant above, repeated because it is the single most important rule in this skill. If you find yourself about to return without a result or a pending dispatch, you have a bug in your flow — spawn the agent.
- **Cache first, always.** Check the index before spawning. The skill's main value is the cheap cache hit path.
- **Cache miss is the default fallback, not a separate condition.** Any uncertainty, any weak match, any missing section, any classification ambiguity that didn't resolve to a clear hit → spawn. The agent is cheap compared to returning no result.
- **One file per library, one file per pattern topic.** Don't create `zod-schemas.md` + `zod-parsing.md` — they go in `zod.md` as H2 sections. The researcher agent handles the merge.
- **Respect `expires: null`.** Frozen entries are deliberate; don't overwrite them unless the user explicitly asks for a refresh.
- **Trust the agent's output.** This skill is a cache layer, not a reviewer. If the agent returns something weird, the fix is in the agent or its mode reference, not in this skill.
- **Classify conservatively.** When ambiguous, ask via AskUserQuestion — don't silently pick a mode. After the user answers, resume the flow and reach a cache hit or spawn; never stop mid-skill.
