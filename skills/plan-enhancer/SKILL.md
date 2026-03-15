---
description: >-
  Defines the 4-stage planning framework (Understand -> Research -> Discuss -> Write) used by all planning modes.
  Standardizes plan output. Writes plan to documentation/plans/{NNN}-{name}/README.md with embedded task list.
  Auto-loaded by planning mode skills via context field.
user-invocable: false
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
context:
  - ${CLAUDE_PLUGIN_ROOT}/templates/plan.md
---

# Plan Enhancer

Plan Enhancer is the starting point and framework for all planning modes. Modes extend it — they cannot bypass or overwrite any rule defined here.

## Constraints

- Do NOT execute the plan — that is `/uc:plan-execution`'s job. After approval, commit and print the execution command, then STOP.
- Do NOT create tasks without success criteria
- Do NOT write any files before Stage 4 — research results and discussion stay in conversation context only
- ALWAYS write the plan to `documentation/plans/{NNN}-{name}/README.md` BEFORE presenting for approval
- ALWAYS include the `Execute: /uc:plan-execution {NNN}` header in the plan document
- ALWAYS follow the Post-Approval steps after the user approves — commit, print command, stop. No exceptions.
- NEVER create plan tasks whose sole purpose is updating documentation — doc updates happen in Stage 4 Steps 2-3

---

## 4-Stage Planning Framework

All planning modes follow these four stages in order. No stage may be skipped. No files are written until Stage 4. Read the reference file for the current stage.

### Stage 1: Understand

Mode-defined. Plan Enhancer does not participate.

→ Read `references/stage-1-understand.md`

### Stage 2: Research

Base research skills (`code-surveyor`, `doc-surveyor`, `tech-research`) always apply. Modes extend but cannot skip or replace them.

→ Read `references/stage-2-research.md`

### Stage 3: Discuss

Mandatory conversation gate. Claude synthesizes findings, presents perspective, brainstorms with user. No files written.

→ Read `references/stage-3-discuss.md`

### Stage 4: Write

All file writing happens here — docs, plan scaffolding, plan README, approval gate, post-approval hard stop.

→ Read `references/stage-4-write.md`

---

## Conversational Planning Rules

These rules apply across all stages — especially Stages 1 and 3. Planning is a **dialogue with the user**, not a one-shot generation.

### Core rules

1. **Never fabricate user responses.** Every question that needs user input MUST go through AskUserQuestion. Never write questions as text output and answer them yourself. Never assume the user's preferences or decisions — wait for their actual response.

2. **Always ask scope questions.** Even when the request seems clear, there are always decisions the user should make — edge cases, in/out of scope boundaries, phasing, trade-offs. Use AskUserQuestion for these. Don't skip this because you think the answer is obvious.

3. **React to user answers substantively.** When the user responds:
   - If you **agree** — say why briefly and build on their answer
   - If you **disagree** — say so directly, explain your concern, and suggest an alternative. You are a senior technical leader, not a yes-machine. Push back on approaches you think are risky, over-scoped, or under-scoped
   - If the answer is **incomplete or unclear** — ask a follow-up via AskUserQuestion. Don't fill in the gaps yourself
   - If the answer **changes your understanding** — say what changed and how it affects the plan

4. **Suggest improvements proactively.** If you see opportunities the user hasn't considered — simpler approaches, potential pitfalls, phasing strategies, things that should be out of scope — raise them. Use AskUserQuestion to get the user's take.

5. **Challenge weak decisions.** If the user makes a choice that you think is suboptimal, say so respectfully but clearly: "I'd push back on X because Y. Have you considered Z?" Then let them decide — respect the final call, but make sure they heard the concern.

## Existing Plan Handling

If a plan directory matching `*-{name}` already exists (revision or re-planning):
- Read the existing `README.md` to understand current state
- Check for checkpoint files — if they exist, this plan has been partially executed
- Warn the user if modifying a plan that has execution history
- Preserve `shared/` and `tasks/` contents — they contain teammate work

### Approval gate rules

- Only an explicit "Approve" selection counts as plan approval. Do NOT infer approval from empty, blank, ambiguous, or non-committal responses.
- If the user selects "Other" with empty or unclear text, re-ask the question. Say: "I need an explicit approval, rejection, or feedback before proceeding."
- Never skip or auto-approve the approval step. The plan is not approved until the user explicitly says so.
