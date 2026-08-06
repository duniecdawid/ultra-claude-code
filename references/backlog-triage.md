# Backlog Triage Protocol

Shared protocol for all skills that surface potentially backlog-worthy items. Read this file just-in-time when follow-up work surfaces, not at skill activation.

## When to Trigger

Trigger triage when you identify something that meets ALL of these criteria:

1. **Actionable** — it's a concrete bug, question, idea, or tech debt item (not a vague observation)
2. **Out of current scope** — it is not part of the work you are currently doing
3. **Worth remembering** — it would be lost if not captured now

Examples that qualify: a related bug found during debugging, a cut-scope idea during feature planning, an open dependency during discovery, a missing feature found during doc-code verification, follow-up work surfaced during plan execution.

Examples that do NOT qualify: general observations, things already tracked elsewhere, items the user explicitly dismissed, in-scope work that you should just do.

## Triage Prompt

Present the item to the user via AskUserQuestion. Use the **plan-context variant** when a plan is being designed or executed, and the **post-execution variant** when there is no plan context.

**Always recommend a disposition**: put the option you would choose first and suffix its label with " (Recommended)". Base the recommendation on the item's severity and cost — e.g. a one-line bug fix leans "Do immediately", a speculative idea leans "Add to backlog".

### Plan-context variant (plan being designed or executed)

```
AskUserQuestion({
  questions: [{
    question: "{Describe the item concisely — what it is and why it surfaced.}",
    header: "Triage",
    multiSelect: false,
    options: [
      { label: "Do immediately", description: "Handle this right now, inline with current work." },
      { label: "Include in plan", description: "Add as a task in the plan being designed or executed." },
      { label: "Add to backlog", description: "Save to project backlog for later prioritization." },
      { label: "Ignore", description: "Not worth tracking. Discard." }
    ]
  }]
})
```

(Already at the 4-option cap — discussion is reachable via the built-in "Other" input. Reorder so the recommended option is first with " (Recommended)".)

### Post-execution variant (no plan context)

Use when:
- The skill has no concept of a plan (e.g., discovery-mode)
- Plan execution is complete (post-completion triage in plan-execution) — "Include in plan" makes no sense there

```
AskUserQuestion({
  questions: [{
    question: "{Describe the item concisely — what it is and why it surfaced.}",
    header: "Triage",
    multiSelect: false,
    options: [
      { label: "Do immediately", description: "Handle this right now, inline with current work." },
      { label: "Add to backlog", description: "Save to project backlog for later prioritization." },
      { label: "Ignore", description: "Not worth tracking. Discard." },
      { label: "Let's talk about it", description: "Discuss this item before deciding." }
    ]
  }]
})
```

(Reorder so the recommended option is first with " (Recommended)" — "Let's talk about it" is never the recommendation.)

## Batching

If multiple triage-worthy items surface at the same point (e.g., a list of follow-up items at plan completion, missing features in doc-code verification), present them as a single AskUserQuestion call with one question per item (up to 10 questions per call). If there are more than 10, make multiple calls.

If more than 10 items surface simultaneously, list them all first in your output, then ask: "I found N items that may be worth triaging. Want me to walk through them, or should I list them and you tell me which to add to backlog?" This avoids prompt fatigue.

## Deferred Triage

Some skills run long processes where interrupting with triage prompts would break flow. In these cases:

1. **Collect** items in a summary section during the process (e.g., "Follow-up Items" in plan-execution's completion summary)
2. **Triage** all collected items in batch after the process completes

Plan-execution uses this pattern: follow-up items are collected throughout execution; at completion, items the plan already resolved are auto-closed (backlog review, step 5.4), and the rest are triaged while the PM writes the operational report (step 5.5).

## Handling Each Choice

### "Do immediately"
Handle the item inline within the current skill session. If the item requires work beyond the skill's scope (e.g., discovery mode cannot write code), say so and suggest the appropriate skill.

### "Include in plan"
Add the item as an additional task or extend an existing task in the active plan. During plan-execution, follow the mid-execution plan change protocol (see "Discovered gaps" in plan-execution SKILL.md).

### "Add to backlog"
Invoke the backlog skill:
```
Skill(skill: 'uc:backlog', args: 'add {category}: {description}')
```
Where `{category}` is one of: `bug`, `question`, `idea`, `debt` — inferred from the item's nature. If ambiguous, default to `idea`.

### "Ignore"
Acknowledge briefly and move on. Do not re-raise the item.

### "Let's talk about it"
Discuss the item with the user — lay out context, tradeoffs, your recommendation's reasoning. When discussion settles on a disposition, act on it (no need to re-ask via AskUserQuestion unless the user asks).
