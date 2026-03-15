# Stage 2: Research

**Purpose:** Gather codebase and documentation context. Results stay in conversation context only.

## Base Research Skills

These are always available and run when applicable.

- **`code-surveyor`** — structural survey of relevant code packages
- **`doc-surveyor`** — structural survey of relevant documentation sections
- **`tech-research`** — external library/framework documentation via Ref.tools

Spawn all applicable research skills in parallel unless the issue is simple enough that only one is needed. For most work, launch `code-surveyor` + `doc-surveyor` together, and add `tech-research` when external libraries are involved.

## Rules

- No files written to disk
- Research results remain in conversation context
- Modes **extend** by: adding scoping context to surveyors, adding extra agents (e.g., Explore, System Tester, Checker), adding extra research phases
- The active mode's SKILL.md defines what extensions it adds on top of these base rules

## Stage Transition

The mode signals completion with:

> **▶ PROCEED TO STAGE 3: DISCUSS**
