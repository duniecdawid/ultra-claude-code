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

Present the item to the user via AskUserQuestion. Use the **4-option variant** when a plan is being designed or executed, and the **3-option variant** when there is no plan context.

### 4-option variant (plan context exists)

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

### 3-option variant (no plan context)

Omit "Include in plan" when:
- The skill has no concept of a plan (e.g., discovery-mode)
- Plan execution is complete (post-completion triage in plan-execution)

```
AskUserQuestion({
  questions: [{
    question: "{Describe the item concisely — what it is and why it surfaced.}",
    header: "Triage",
    multiSelect: false,
    options: [
      { label: "Do immediately", description: "Handle this right now, inline with current work." },
      { label: "Add to backlog", description: "Save to project backlog for later prioritization." },
      { label: "Ignore", description: "Not worth tracking. Discard." }
    ]
  }]
})
```

## Batching

If multiple triage-worthy items surface at the same point (e.g., a list of follow-up items at plan completion, missing features in doc-code verification), present them as a single AskUserQuestion call with one question per item (up to 4 questions per call — the tool's limit). If there are more than 4, make multiple calls.

If more than 5 items surface simultaneously, list them all first in your output, then ask: "I found N items that may be worth triaging. Want me to walk through them, or should I list them and you tell me which to add to backlog?" This avoids prompt fatigue.

## Deferred Triage

Some skills run long processes where interrupting with triage prompts would break flow. In these cases:

1. **Collect** items in a summary section during the process (e.g., "Follow-up Items" in plan-execution's completion summary)
2. **Triage** all collected items in batch after the process completes

Plan-execution uses this pattern: follow-up items are collected throughout execution and triaged after shutdown (step 5.5).

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
