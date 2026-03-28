# Stage 2: Research

**Purpose:** Gather codebase and documentation context. Results stay in conversation context only.

## Base Research Skills

These are always available and run when applicable.

- **`code-surveyor`** — structural survey of relevant code packages
- **`doc-surveyor`** — structural survey of relevant documentation sections
- **`tech-research`** — external library/framework documentation via Ref.tools

Spawn all applicable research skills in parallel. At minimum, always launch `code-surveyor` + `doc-surveyor` together — even for seemingly simple issues, because doc-surveyor frequently reveals context that changes your understanding of "simple." Add `tech-research` when external libraries are involved. If you genuinely believe only one surveyor applies (e.g., pure documentation change with zero code impact), state which one you are skipping and why in your stage transition message.

## Rules

- No files written to disk
- Research results remain in conversation context
- Modes **extend** by: adding scoping context to surveyors, adding extra agents (e.g., Explore, System Tester, Checker), adding extra research phases
- The active mode's SKILL.md defines what extensions it adds on top of these base rules

## Stage Transition

Before transitioning, verify: (a) you spawned at least code-surveyor + doc-surveyor (or stated why one was skipped), and (b) you synthesized their results into findings you can discuss. If using debug-mode, also verify your hypothesis list was presented to the user and investigated.

The mode signals completion with:

> **▶ PROCEED TO STAGE 3: DISCUSS**
