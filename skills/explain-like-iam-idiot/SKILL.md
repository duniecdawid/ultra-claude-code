---
name: explain-like-iam-idiot
description: >-
  Re-explains the current conversation in plain language — ASCII diagrams, comparison grids,
  named trade-offs — so a non-expert can decide. Use when someone says they don't follow, asks
  for it simply or ELI5, or wants a recap before choosing. Explains what was already discussed;
  critical-brainstorm generates and challenges options.
user-invocable: true
argument-hint: "optional focus (e.g. 'just the deploy part')"
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Explain Like I Am An Idiot

Re-explain this conversation so reader can decide. Input = conversation, narrowed by argument if given. Output = one message here, never file.

"Idiot" mean no jargon, no assumed context. Not mean slow. Simplify words, never facts: trade-off flattened into clean answer fail worse than jargon — reader then decide confident and wrong. Nothing to decide? Aim at reader able to explain it back.

## Toolbox

No fixed shape — nothing required to open or close. Pick only what material need; three device used well beat eight.

| Device | Fits | Trap |
|---|---|---|
| bottom line first | reader must act, not study | commit to position, don't hedge back into fog |
| analogy | unfamiliar mechanism | every analogy leak; name where it breaks or drop it |
| concrete numbers | vague claim ("slow", "costly") | never invent figure to fill slot |
| comparison grid — options × criteria | 2+ options judged on shared criteria | useless when options share no criteria |
| pros/cons list | exactly 2 options, few criteria | collapse at 3+ options or 4+ criteria — use grid |
| weighted grid | 3+ options × 4+ criteria | weights = opinion; show them as such |
| flow diagram, box + arrow | what talk to what, where data move | hide timing entirely |
| sequence, `│` + `→` | order, who wait for whom | noisy past ~5 actors |
| tree, `├── └──` | hierarchy, layout, branching options | imply order that may not exist |
| bar or timeline | magnitude, before/after, duration | need real numbers |
| what breaks if wrong | risk, irreversibility, one-way doors | real failure modes, not ritual caution |
| inline jargon gloss | term that cannot be removed | one gloss, at first use |
| decision block | reader must choose between named options | offer options that exist, not ideal ones |

## Limits

- Diagrams stay ≤72 columns. Wider wrap and die in terminal.
- Comparing options = grid job; box and arrow show movement. Box drawn for choice = picture nobody can read answer off.
- Mark what is assumed or unknown. Confident diagram over missing evidence = main way this fail.
- Every option carry cost, not only benefit — upside alone = pitch, not explanation.
- Cut implementation detail that doesn't change decision, however interesting.
