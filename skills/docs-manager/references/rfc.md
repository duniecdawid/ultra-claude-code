# Reference: RFC (Request for Comments)

## Purpose

An RFC captures a non-trivial technical decision — the problem, the options considered, the trade-offs, and the final decision. It serves as a permanent decision record so future developers understand *why* things are the way they are.

## When to Write One

Not every decision needs an RFC. Write one when:
- Multiple valid approaches exist with significant trade-offs
- The decision affects multiple components or teams
- The choice is hard to reverse
- Someone is likely to ask "why did we do it this way?" in 6 months

## How to Write One

The alternatives table is the heart of the document. List real pros and cons — not strawman arguments that make your preferred option look good. If you can't articulate genuine advantages of the alternatives, you haven't thought hard enough.

The Outcome section (empty until the decision is made — see template) is what future readers look at first.

**Common pitfalls:**
- Writing the RFC after the decision is already made (it becomes a justification document, not a decision record)
- Missing the "Why Not" column — this is the most valuable part for future readers

## Template

```markdown
# RFC: {Title}

> Created: {date}
> Status: Open | Accepted | Rejected | Superseded
> Author: {author}
> Reviewers: {reviewers}

## Problem Statement

What is the problem or decision that needs to be made? Why is it non-trivial?

## Proposed Solution

Describe the proposed approach in detail.

### Design

### Implementation Approach

## Alternatives Considered

| Alternative | Pros | Cons | Why Not |
|------------|------|------|---------|
| | | | |

## Trade-offs

What are the key trade-offs of the proposed solution?

## Open Questions

- [ ]

## Outcome

> Filled in after the decision is made.

**Decision:**

**Rationale:**

**Follow-up actions:**
- [ ]
```

## Cross-References

- Links TO: architecture docs affected by the decision
- Links FROM: planning framework Stage 3 (`references/planning-framework/stage-3.md`) — created during discussion when an architectural fork appears
