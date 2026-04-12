# Planning Framework

This is a shared reference library, not a skill. Planning modes (feature-mode, debug-mode, doc-code-verification-mode) inherit these rules and extend them per-stage. Modes read this file once at activation, then progressively load `stage-N.md` references — both the base ones in this directory and their own per-mode extensions — only as they enter each stage.

## Constraints

- Do NOT enter Claude Code's built-in PlanMode (EnterPlanMode/ExitPlanMode) — this framework IS the planning system. The built-in PlanMode is a separate mechanism that conflicts with this workflow.
- Do NOT execute the plan — that is `/uc:plan-execution`'s job. After approval, commit and print the execution command, then STOP.
- Do NOT create tasks without success criteria.
- Do NOT write any files before Stage 4 — research results and discussion stay in conversation context only.
- ALWAYS write the plan to `documentation/plans/{NNN}-{name}/README.md` BEFORE presenting it for approval.
- ALWAYS include the `Execute: /uc:plan-execution {NNN}` header in the plan document.
- ALWAYS follow ALL Post-Approval steps after the user approves — update README status, update plan.json, commit, print command, stop. No exceptions.
- NEVER create plan tasks whose sole purpose is updating documentation — doc updates happen in Stage 4 Steps 2-3, before the plan tasks are written.

## Conversational Planning Rules

These rules apply across all stages — especially Stages 1 and 3. Planning is a **dialogue with the user**, not a one-shot generation.

1. **Never fabricate user responses.** Every question that needs user input MUST go through AskUserQuestion. Never write questions as text output and answer them yourself. Never assume the user's preferences or decisions — wait for their actual response.

2. **Always ask scope questions.** Even when the request seems clear, there are decisions the user should make — edge cases, in/out of scope boundaries, phasing, trade-offs. Use AskUserQuestion for these. Don't skip this because the answer feels obvious.

3. **React to user answers substantively.** When the user responds:
   - If you **agree** — say why briefly and build on their answer.
   - If you **disagree** — say so directly, explain your concern, and suggest an alternative. You are a senior technical leader, not a yes-machine. Push back on approaches you think are risky, over-scoped, or under-scoped.
   - If the answer is **incomplete or unclear** — ask a follow-up via AskUserQuestion. Don't fill in the gaps yourself.
   - If the answer **changes your understanding** — say what changed and how it affects the plan.

4. **Suggest improvements proactively.** If you see opportunities the user hasn't considered — simpler approaches, potential pitfalls, phasing strategies, things that should be out of scope — raise them. Use AskUserQuestion to get their take.

5. **Challenge weak decisions.** If the user makes a choice you think is suboptimal, say so respectfully but clearly: "I'd push back on X because Y. Have you considered Z?" Then let them decide — respect the final call, but make sure they heard the concern.

## Existing Plan Handling

If a plan directory matching `*-{name}` already exists (revision or re-planning):

- Read the existing `README.md` to understand current state.
- Check for checkpoint files — if they exist, this plan has been partially executed.
- Warn the user if modifying a plan that has execution history.
- Preserve `shared/` and `tasks/` contents — they contain teammate work.

Modes may extend this behavior in their own `references/stage-1.md` (since detection happens during Stage 1). For example, feature-mode adds stub-plan handling for plans created by `/uc:roadmap`.

## Stage Loading Discipline

Read each stage's reference file only when you are about to enter that stage. Do not preload Stage 2/3/4 references at the start of Stage 1 — they contain rules that only apply at their stage and would pollute your context with constraints you cannot yet act on. Progressive disclosure is the whole point of this structure; honour it.

The 4-stage flow is:

1. **Understand** — gather context from the user via dialogue
2. **Research** — survey code and documentation in parallel
3. **Discuss** — synthesize findings, present perspective, converge on approach
4. **Write** — update docs, build plan, get approval, hard stop

Each stage transitions to the next via an explicit instruction in the stage reference file. Modes layer their own behavior on top through per-stage extensions.
