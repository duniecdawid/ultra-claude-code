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

### Validating the trigger harness before trusting its numbers

The trigger eval reports a *rate*, so a broken run looks like a finding rather than a failure. Three things to know before quoting a score:

- [MEASURED 2026-07-25] The eval defaults (`--num-workers 10 --timeout 30`) are too aggressive for Opus-class models — nested sessions don't reach their first tool call inside 30s, and a timeout is recorded as "did not trigger", which is indistinguishable from a routing miss. Override to `--num-workers 1` (2 at most) and `--timeout 240`+. Measured on a 20-query set: 10 workers/30–60s scored 12/12 should-trigger queries as failures; the same queries and same description run serially triggered correctly.
- **Signature of a broken run:** *every* should-trigger query fails while *every* should-not-trigger query passes. Negatives pass for free when nothing triggers at all, so that shape is an artifact — never a description finding. Corollary: a suspiciously round score near "all negatives correct" deserves a serial spot-check of two or three positives before you act on it.
- **Detection is first-tool-call sensitive.** The harness gives up if the model's opening tool call isn't `Skill`/`Read`, so run it from a directory with nothing to explore — a scratch dir, not a populated repo, and not a home directory. An agent that starts by looking around scores zero regardless of how good the description is.
- **Clean up after every run.** Each query writes a real command file into `<project-root>/.claude/commands/`, removed in a `finally` block that a killed or timed-out process skips. Survivors advertise themselves as genuine skills in every later session in that directory: `grep -rl "^This skill handles" .claude/commands/` and delete the hits.

## Skill bodies — behavior testing

For body/reference restructuring, use skill-creator's eval loop by invocation: realistic eval prompts with objectively-verifiable assertions, a with-skill/without-skill control, grader + benchmark aggregation (pass_rate, tokens, time as mean ± stddev). Run the same evals before and after; gate on pass_rate not dropping; treat token/time deltas as the win metric. Keep artifacts in the `<skill-name>-workspace/` sibling directory (skill-creator's convention) so iterations stay comparable.

## Agents — no official harness; freeze-and-grade

1. **Before:** freeze 3–5 representative task prompts covering the agent's core duties, plus a short grading rubric (3–6 objective criteria: did it produce X, did it stay read-only, did it flag Y).
2. Run each prompt against the pre-refactor agent; save outputs.
3. Refactor; re-run the identical prompts, same model and settings.
4. Grade both sides with an **independent Opus pass** that sees the rubric but not which output is before/after (label-blind). Gate: no criterion regresses.
5. Keep prompts + rubric next to the agent definition so the next refactor reuses them.

## Compression propositions (caveman-compress output) — minimum bar

Full evals are overkill for a single description trim. Minimum accepted evidence:
- Trigger-set re-run (identical frozen set), AND
- Key-term diff clean or every dropped term explicitly risk-flagged and accepted by the parent.

## Record-keeping

Every accepted refactor records one line where the artifact lives (changelog, PR body, or workspace note): baseline metric → post metric, date, test-set identity. Unrecorded baselines rot; the frozen set is the asset.
