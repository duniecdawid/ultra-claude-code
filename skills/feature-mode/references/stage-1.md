# Feature Mode — Stage 1: Understand

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-1.md`

The instructions below extend the base rules with feature-mode-specific behavior.
**Precedence:** the base rules run first; the extensions below extend or specialize them. If a mode extension contradicts a base rule, the extension wins (modes are specializations of the base). If the conflict is unclear, stop and ask the user.

## Existing Plan Handling Extension

`framework.md` already covers the base existing-plan handling — read its instructions and apply them first when you detect a plan directory matching `*-{ARGUMENTS}*` or where `{ARGUMENTS}` is a plan number (e.g., "001", "1").

If detection finds an existing plan whose README has **`Status: Stub` AND `Source: Roadmap`**, this is a stub plan from `/uc:roadmap`. The scope boundary is already defined by the roadmap. Apply these stub-specific rules:

1. Load the stub's Objective, Context, Scope, and Success Criteria into your working context.
2. Your job shifts from "discover scope" to "verify and refine scope." Present the stub's scope to the user: "This plan was scaffolded by /uc:roadmap with the following scope: [summary]. Let me verify this is still correct and dig into implementation details."
3. You still ask at least 3 questions (per the base rule), but focus on **implementation approach, edge cases within the defined scope, and technical decisions** — not on what to build.
4. The stub's **Out of Scope** section is a hard boundary — do not expand scope beyond it without explicit user approval.
5. Read `documentation/plans/ROADMAP.md` if it exists, so you understand where this plan sits in the overall sequence and what prior plans provide.

If the matched plan exists but is NOT a stub (Status is Draft / Approved / In Progress), follow the base existing-plan handling from `framework.md` only — no stub-specific rules apply.

## Mode Extensions

Before any research or planning, challenge the feature request as a Head of Technology would:

1. **Parse the request** — What is being asked? What is the expected user-facing outcome?
2. **Challenge scope** — Is this one feature or multiple? Is it too vague? What's the minimum viable scope?
3. **Ask "why?"** — What problem does this solve? Who benefits?
4. **Identify assumptions** — What does the request assume about current architecture?
5. **Predict implementation challenges** — Based on your experience, what are the likely hard parts? What will look simple but isn't? Where will the real complexity hide? Share these predictions with the user.
6. **Surface edge cases and failure modes** — What happens when things go wrong? What are the boundary conditions? What user behaviors could break this?
7. **Propose hypotheses** — Offer your initial hypotheses about the right approach, potential pitfalls, and things that need deciding. Frame these as "I suspect X because Y — does that match your understanding?" Don't just ask questions — bring your own perspective for the user to react to.
8. **Flag dependencies and risks** — What could this break? What does it depend on? Are there ordering constraints or things that need to exist first?

Present your analysis alongside scope questions via AskUserQuestion. Don't just ask "what do you want?" — bring your own informed perspective. The goal is a dialogue where you contribute expertise, not just collect requirements.

**Cut-scope ideas:** When ideas come up during scope discussion that are explicitly cut from scope, mention them to the user — they decide whether to add them to the backlog. Saving to backlog NEVER happens without explicit user consent.

## Stage Transition

When you have satisfied the base Stage 1 rules (3+ answered questions, scope boundary articulated, assumptions verified, affected parties named), announce:

> **▶ PROCEED TO STAGE 2: RESEARCH**

Then read:
`${CLAUDE_PLUGIN_ROOT}/skills/feature-mode/references/stage-2.md`
