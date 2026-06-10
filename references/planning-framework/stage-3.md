# Planning Framework — Stage 3: Discuss

Mandatory for ALL planning modes — no exceptions.

**Purpose:** Synthesize all findings from Stages 1-2, present a summary with your own perspective, and brainstorm the approach with the user. This is a mandatory conversation gate before the plan is written.

## On Entry — Update the Stage Field

Before presenting any synthesis, as the first procedural action on entering this stage, update the skeleton's plan-level `stage` to reflect that discussion is now active:

- Set `plan.json` `"stage"` → `"discuss"` (the skeleton was scaffolded at the end of Stage 1 with `stage: research`). This is the Stage 2→3 transition update.

This and the Abandon cancel below are the only writes permitted in Stage 3 — discussion content stays in conversation context (see `framework.md` Constraints).

## Rules

- No files written, except the on-entry `stage` update above and the Exit Gate "Abandon" cancel below.
- You MUST present your own perspective — not just ask questions.
- Goal is convergence toward an approach.
- Exit ONLY via the explicit AskUserQuestion exit gate (see below).

## Discussion Principles

Adapted from the Critical Brainstorm skill and tuned for planning context:

- **Research first, opine second.** Your perspective must be grounded in Stage 2 findings, not assumptions. When you make a claim, reference what you found.
- **Hold your ground on genuine concerns.** When you identify a real risk, don't fold because the user pushes back. Explain *why* you're worried. Cite evidence from the research. If they convince you with new information, acknowledge it honestly — but don't cave to pressure alone.
- **Name uncomfortable things.** If the approach is over-engineered, say so. If the scope is unrealistic, say so. If a popular tool is wrong for this case, say so. The user's blind spots are what you're here to find.
- **Think in time horizons.** A solution that works today might create pain in 3 months. Map out how the decision ages.
- **Every response must advance the discussion.** Raise a new concern, deepen an existing one, propose an alternative, or ask a pointed question. Never just summarize or agree. If you have nothing new to add, it's time to exit.
- **Present your own perspective — don't just ask questions.** The user wants a dialogue with a senior technical partner, not an interviewer collecting requirements.
- **Goal is convergence toward an approach.** This is not open-ended brainstorming. Each exchange should narrow the space of possibilities. When you and the user agree on the shape of the solution, prompt the exit gate.

## RFC for Architectural Challenges

When the discussion reveals an architectural challenge — multiple valid approaches, significant trade-offs, affects multiple components, or the user is uncertain about direction — create an RFC before proceeding to the plan.

1. Create RFC at `documentation/technology/rfcs/{NNN}-{topic}.md` — look up the RFC reference in docs-manager's Document Type References table and read it before writing.
2. Fill in: Problem Statement, Proposed Solution, Alternatives Considered, Trade-offs.
3. Present the alternatives to the user with your recommendation and reasoning.
4. Record the user's decision and rationale in the RFC Outcome section.
5. Update architecture documentation in `documentation/technology/architecture/` to reflect the decision.

The RFC stays on disk as a decision record. The plan then references it rather than re-explaining the architectural choice.

## Exit Gate

When the discussion reaches convergence, offer the user a choice via AskUserQuestion:

- **"Proceed to plan"** — moves to Stage 4: Write
- **"Keep discussing"** — continues Stage 3
- **"Abandon"** — cancels the planning session (see below), then exits the planning mode entirely

### Abandon → Cancel

When the user selects "Abandon", do NOT delete the skeleton. Cancel it so it stays visible as a tombstone and its number stays reserved:

1. Update `plan.json`: set `"status"` → `"cancelled"`. Leave `"stage"` as-is (it records how far planning got).
2. Update the README `Status:` line → `Cancelled`.
3. Retain the directory and the plan number — never remove them. A later re-run of any planning mode against this name resurrects the same number in place (see `framework.md` Existing Plan Handling).
4. Exit the planning mode.

## Stage Transition

> **▶ PROCEED TO STAGE 4: WRITE**

The active mode's `references/stage-3.md` will instruct you to read its `references/stage-4.md` next.
