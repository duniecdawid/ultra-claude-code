# Planning Framework — Stage 2: Research

Base Stage 2 rules. Modes extend these in their own `references/stage-2.md` (e.g., debug-mode adds a hypothesis gate; doc-code-verification-mode adds a verification matrix).

**Purpose:** Gather codebase and documentation context. Results stay in conversation context only — no files written.

## Base Research Skills

These are always available and run when applicable.

- **`code-surveyor`** — structural survey of relevant code packages
- **`doc-surveyor`** — structural survey of relevant documentation sections
- **`tech-research`** — external library/framework documentation via Ref.tools

Spawn all applicable research skills in parallel. At minimum, always launch `code-surveyor` + `doc-surveyor` together — even for seemingly simple issues, because doc-surveyor frequently reveals context that changes your understanding of "simple." Add `tech-research` when external libraries are involved. If you genuinely believe only one surveyor applies (e.g., pure documentation change with zero code impact), state which one you are skipping and why in your stage transition message.

## Rules

- No files written to disk.
- Research results remain in conversation context.
- Modes extend by: adding scoping context to surveyors, adding extra agents (e.g., Explore, System Tester, Checker), adding extra research phases. The mode-specific extensions live in the active mode's `references/stage-2.md`.

## Stage Transition

Before transitioning, verify: (a) you spawned at least code-surveyor + doc-surveyor (or stated why one was skipped), and (b) you synthesized their results into findings you can discuss. The active mode may add additional verification gates (e.g., debug-mode requires the hypothesis list to have been presented and investigated).

When the verification gates pass, announce:

> **▶ PROCEED TO STAGE 3: DISCUSS**

The active mode's `references/stage-2.md` will instruct you to read its `references/stage-3.md` next.
