# Testing refactors — before/after evidence for skills and agents

Scope: the methodology for proving a skill/agent refactor (especially compression) did not lower effectiveness. Methodology, not a harness — the eval engine is `/skill-creator:skill-creator`, used by invocation.

## The rule

A refactor of harness text is accepted only with before/after evidence on the **same** test set. Brevity that breaks routing or behavior is a regression. No baseline captured before the refactor ⇒ capture it first, on the pre-refactor version, before touching anything.

## Skill descriptions — trigger testing

The failure mode of trimming: a dropped key term stops the skill triggering.

1. **Before:** via `/skill-creator:skill-creator`'s description-optimizer flow, generate ~20 queries — should-trigger and should-NOT-trigger (include near-miss queries that belong to sibling skills). Freeze the set; record baseline accuracy.
2. Refactor the description.
3. **After:** re-run the identical set. Gate: accuracy must not drop; should-NOT-trigger accuracy matters as much (over-triggering wastes invocations and pollutes sibling routing).
4. Cheap supplementary check: diff the discriminating key terms (nouns/verbs) before/after; investigate every disappearance.

## Skill bodies — behavior testing

For body/reference restructuring, use skill-creator's eval loop by invocation: realistic eval prompts with objectively-verifiable assertions, a with-skill/without-skill control, grader + benchmark aggregation (pass_rate, tokens, time as mean ± stddev). Run the same evals before and after; gate on pass_rate not dropping; treat token/time deltas as the win metric. Keep artifacts in the `<skill-name>-workspace/` sibling directory (skill-creator's convention) so iterations stay comparable.

## Agents — no official harness; freeze-and-grade

1. **Before:** freeze 3–5 representative task prompts covering the agent's core duties, plus a short grading rubric (3–6 objective criteria: did it produce X, did it stay read-only, did it flag Y).
2. Run each prompt against the pre-refactor agent; save outputs.
3. Refactor; re-run the identical prompts, same model and settings.
4. Grade both sides with an **independent Opus pass** that sees the rubric but not which output is before/after (label-blind). Gate: no criterion regresses.
5. Keep prompts + rubric next to the agent definition so the next refactor reuses them.

## Compression propositions (caveman-reviewer output) — minimum bar

Full evals are overkill for a single description trim. Minimum accepted evidence:
- Trigger-set re-run (identical frozen set), AND
- Key-term diff clean or every dropped term explicitly risk-flagged and accepted by the parent.

## Record-keeping

Every accepted refactor records one line where the artifact lives (changelog, PR body, or workspace note): baseline metric → post metric, date, test-set identity. Unrecorded baselines rot; the frozen set is the asset.
