# Planning Framework — Stage 2: Research

Base Stage 2 rules. Modes extend these in their own `references/stage-2.md` (e.g., debug-mode adds a hypothesis gate; doc-code-verification-mode adds a verification matrix).

**Purpose:** Gather codebase and documentation context. Results stay in conversation context only — no files written.

## Base Research Skills

These are always available and run when applicable.

- **`code-surveyor`** — structural survey of relevant code packages
- **`doc-surveyor`** — structural survey of relevant documentation sections
- **`/uc:research`** — cache-first external library, API, pattern, or market research. Writes committed research files under `documentation/technology/research/` (libraries + patterns) or `documentation/product/research/` (market). Cache hits return instantly; misses spawn the `researcher` subagent.

Spawn all applicable research skills in parallel. At minimum, always launch `code-surveyor` + `doc-surveyor` together — even for seemingly simple issues, because doc-surveyor frequently reveals context that changes your understanding of "simple." Invoke `/uc:research` whenever external libraries or unfamiliar patterns are involved. If you genuinely believe only one surveyor applies (e.g., pure documentation change with zero code impact), state which one you are skipping and why in your stage transition message.

## Tech Stack Sweep — MANDATORY

Beyond researching *new* or unfamiliar things, sweep `/uc:research` over **every core technology the draft plan will touch**, even libraries the project already uses. This is a hard rule, not a heuristic — planners used to skip "established" libraries on the assumption that executors already knew them, and the knowledge base stayed permanently empty. The sweep makes the knowledge base bootstrap itself.

**Strict derivation rule (mechanical, hard to skip):**

1. From the code-surveyor's output and your draft task breakdown, enumerate the files this plan will create or modify. For tasks that extend existing components, include the files being extended.
2. For each file, read the imports/requires/use declarations and list every **external** package (anything not a relative import or a stdlib/builtin module).
3. Deduplicate the list.
4. For each library in the deduplicated list, run:
   ```
   /uc:research {library} --fill-only
   ```
   The `--fill-only` flag keeps research summaries out of your planner context — the skill classifies, canonicalizes, checks the cache, and spawns the researcher on miss, but returns only `{target_path, status}` per call. Bulk sweeps of 10 libraries cost ~10 small tool calls instead of 10 large summary absorptions.
5. When you need to actually read a research file during Stage 3 discussion or Stage 4 writing, read the file at `target_path` directly. The file is already on disk.

**What the sweep produces:**

- Every library in the plan's surface area has a fresh research file under `documentation/technology/research/libraries/` (or in the harness scope for Claude/Anthropic topics).
- The `/uc:research` skill's canonicalization rules ensure different phrasings (`zod`, `zod v4`, `zod schemas`) all route to the same file — no duplicates.
- Stage 4 populates `task.md` Research pointers directly from the files on disk; no additional research fires at that point.
- Lead's pre-spawn coverage check at execution time becomes a rarely-firing safety net.

**Why strict:** "core technology the plan touches" is a judgment call that lets planners skip things. "Every external package imported in any file on the plan's Files list" is mechanical and unambiguous. Use the mechanical rule.

**Subsystem expansion (optional, judgment call):** if the plan touches messaging/auth/db/cache layers in a way that depends on the subsystem's semantics even though no file directly imports it, add those libraries to the sweep too. This is a nice-to-have, not a rule — add them if you notice, skip them if you don't.

**Research-to-task mapping:** track which library supports which draft task as you sweep. Stage 4 Step 5b turns this mapping into the `**Research:**` section of each `task.md`. A library that applies to multiple tasks becomes a pointer in each of those tasks' task.md files (same path, possibly different one-line gloss per task).

## Rules

- No files written to disk by this stage directly. (`/uc:research` itself writes durable files under `documentation/technology/research/` — that's the skill's own persistence, not a stage write.)
- Research results remain in conversation context.
- Modes extend by: adding scoping context to surveyors, adding extra agents (e.g., Explore, System Tester, Checker), adding extra research phases. The mode-specific extensions live in the active mode's `references/stage-2.md`.

## Track research-to-task mapping

As you run `/uc:research` for external libraries, frameworks, APIs, and patterns, **note which draft task each research artifact supports**. You're still shaping tasks during Stage 2/3, but by the time you reach Stage 4 you'll have a list like:

```
task-1 (Add JWT auth middleware):
  - documentation/technology/research/libraries/jsonwebtoken.md — need v9 algorithms param
  - documentation/technology/research/libraries/express.md — async error handling

task-2 (User sessions):
  - documentation/technology/research/libraries/jsonwebtoken.md — shared with task-1, different gloss
  - documentation/technology/research/libraries/redis.md — session store TTL semantics
```

Stage 4 Step 5b turns this mapping into the `**Research:**` section of each task's `task.md` file. A research file that applies to multiple tasks becomes a pointer in each of those tasks' task.md files (same path, possibly different one-line gloss per task — duplicating a path is not duplicating content).

Don't just collect research for "the plan" as a whole — keep the per-task attribution in your head or in a scratch note as you go, so Stage 4 doesn't lose it.

## Stage Transition

Before transitioning, verify: (a) you spawned at least code-surveyor + doc-surveyor (or stated why one was skipped), and (b) you synthesized their results into findings you can discuss. The active mode may add additional verification gates (e.g., debug-mode requires the hypothesis list to have been presented and investigated).

When the verification gates pass, announce:

> **▶ PROCEED TO STAGE 3: DISCUSS**

The active mode's `references/stage-2.md` will instruct you to read its `references/stage-3.md` next.
