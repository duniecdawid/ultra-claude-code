# Planning Framework — Stage 2: Research

Base Stage 2 rules. Modes extend these in their own `references/stage-2.md` (e.g., debug-mode adds a hypothesis gate; doc-code-verification-mode adds a verification matrix).

**Purpose:** Gather codebase and documentation context. Results stay in conversation context only — no files written.

## Base Research Skills

These are always available and run when applicable.

- **`code-surveyor`** — structural survey of relevant code packages
- **`doc-surveyor`** — structural survey of relevant documentation sections
- **`/uc:research`** — cache-first external library, API, pattern, or market research. Writes committed research files under `documentation/technology/research/` (libraries + patterns) or `documentation/product/research/` (market). Cache hits return instantly; misses spawn the `researcher` subagent.

Spawn all applicable research skills in parallel — surveyor subagents as one-shot fan-out (no `name`, explicit `run_in_background: true`; Mode F per `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`), and collect every completion notification before synthesizing. At minimum, always launch `code-surveyor` + `doc-surveyor` together — even for seemingly simple issues, because doc-surveyor frequently reveals context that changes your understanding of "simple." Invoke `/uc:research` whenever external libraries or unfamiliar patterns are involved. If you genuinely believe only one surveyor applies (e.g., pure documentation change with zero code impact), state which one you are skipping and why in your stage transition message.

## Tech Stack Sweep — MANDATORY (all modes)

Every planning mode — feature, debug, doc-code-verification, anything else that inherits this framework — must sweep `/uc:research` over **every core technology the in-scope files will touch**, even libraries the project already uses. This is a hard rule, not a heuristic.

**Why:** planners used to skip "established" libraries on the assumption that executors already knew them, and the knowledge base stayed permanently empty — so execution teams still hit cold QUERY round-trips for every library the codebase already uses. The sweep makes the knowledge base bootstrap itself, and over time each project accumulates fresh research files for every library it depends on.

**Strict mechanical derivation (hard to skip):**

1. **Identify the in-scope file set.** Each mode defines this based on its own scoping phase: feature mode uses the draft task breakdown's Files list; debug mode uses the files under investigation for the bug; doc-code-verification mode uses the files being checked against docs. Whatever the active mode flags as in-scope for this planning session is the input to the sweep.
2. **For each in-scope file, read its imports/requires/use declarations** and list every **external** package — anything not a relative import or a stdlib/builtin module. For new files the plan anticipates creating, anticipate which libraries they'll pull in based on existing patterns the code-surveyor surfaced.
3. **Deduplicate** the resulting list across files.
4. **Sweep** — for each library in the deduplicated list, run:
   ```
   /uc:research {library} --fill-only
   ```
   The `--fill-only` flag keeps research summaries out of your planner context — the skill classifies, canonicalizes, checks the cache, and dispatches the researcher on miss (background — misses fan out in parallel instead of serializing), returning only `{target_path, status, expires}` per call. Bulk sweeps of 10 libraries cost ~10 small tool calls instead of 10 large summary absorptions, and the misses research concurrently while you continue Stage 2/3 discussion. The skill's canonicalization rules ensure different phrasings (`zod`, `zod v4`, `zod schemas`) all route to the same file — no duplicates.
5. **Read research files on demand — but never while pending.** When you need actual content during Stage 3 discussion or Stage 4 writing, read the file at the returned `target_path` directly. Entries returned as `status: "pending"` have a background researcher still writing them — collect every pending entry's completion notification before Stage 4 writing begins (or before reading that entry's file, whichever comes first). This is enforced as a hard precondition in Stage 4's Stage Entry Check (`stage-4.md`) — Stage 4 cannot start while any dispatch is pending.

**Why strict:** "core technology the plan touches" is a judgment call that lets planners skip things. "Every external package imported in any in-scope file" is mechanical and unambiguous. Use the mechanical rule.

**Optional subsystem expansion (judgment call):** if the plan depends on the semantics of a subsystem even though no file directly imports its library (e.g., the plan behaves differently under NATS JetStream retention rules but the files only talk to a local abstraction layer), add those libraries to the sweep too. Nice-to-have, not a rule.

**Research-to-task mapping (feature mode only):** track which library supports which draft task as you sweep. Stage 4 Step 5b turns this mapping into the `**Research:**` section of each `task.md`. A library that applies to multiple tasks becomes a pointer in each of those tasks' task.md files (same path, possibly different one-line gloss per task). Debug mode and verification mode don't have multi-task scope so this mapping step is a no-op for them.

**Downstream effect:** Lead's pre-spawn coverage check at execution time becomes a rarely-firing safety net because the knowledge base is already populated. Execution teams get cache hits on every QUERY they'd otherwise have sent cold.

## Rules

- No files written to disk by this stage directly. (`/uc:research` itself writes durable files under `documentation/technology/research/` — that's the skill's own persistence, not a stage write.)
- Research results remain in conversation context.
- Modes extend by: adding scoping context to surveyors, adding extra agents (e.g., Explore, System Tester, Checker — same one-shot fan-out config as the surveyors, per `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`), adding extra research phases. The mode-specific extensions live in the active mode's `references/stage-2.md`.

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
