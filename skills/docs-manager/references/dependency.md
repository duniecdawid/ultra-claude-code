# Reference: Dependencies

## Purpose

A dependency document tracks a blocking question or external dependency that prevents work from proceeding. It makes blockers visible, captures the options considered, and records the resolution.

## When to Write One

Write a dependency doc when:
- Work is blocked waiting on an external party or decision
- A question needs to be answered before a plan can proceed
- Multiple teams or stakeholders need to align on something

Don't use this for internal technical decisions — those belong in RFCs. Dependencies are for things outside your control.

## How to Write One

Be specific about what's blocked and what the impact is. Reference specific plans or tasks by name so the reader can trace the dependency chain.

List concrete options — what could you do if this dependency resolved in different ways? This helps the team move faster once the blocker is resolved.

The Resolution section stays empty until resolved. Fill it in with the decision, date, and any follow-up actions.

**Common pitfalls:**
- Vague impact statements ("this blocks progress") — be specific about what plans/tasks are blocked
- Not listing options — even blocked work can be de-risked by preparing for different outcomes
- Forgetting to resolve the document when the blocker clears

## Template

```markdown
# Dependency: {Title}

> Created: {date}
> Status: Open | Resolved | Blocked
> Owner: {who is responsible for resolving}
> Blocking: {what plans or tasks this blocks}

## Description

What is the blocking question or external dependency?

## Impact

What cannot proceed until this is resolved? Reference specific plans or tasks.

## Options

| Option | Pros | Cons |
|--------|------|------|
| | | |

## Resolution

> Filled in when resolved.

**Decision:**

**Date resolved:**

**Follow-up actions:**
- [ ]
```

## Cross-References

- Links TO: plans and tasks that are blocked
- Links FROM: plans that identified the blocker
