# Reference: Requirements

## Purpose

A requirements document defines what problems to solve and what success looks like. It captures the goals, acceptance criteria, and priorities — the "what" and "why" without the "how."

## Perspective

**Goal-oriented.** Write from the perspective of what needs to be achieved, not how to build it.

- DO include: functional requirements, non-functional requirements, acceptance criteria, priorities, dependencies
- DO NOT include: implementation details (→ architecture), user experience flows (→ product description), market data (→ research)

## How to Write One

Start with the problem statement — who has this problem and why does it matter? Then list requirements with clear IDs (FR-001 for functional, NFR-001 for non-functional) so they can be referenced from plans and tasks.

Every requirement needs a priority. Use Must/Should/Could — "Must" means the feature doesn't ship without it, "Should" means it's expected but deferrable, "Could" means it's a nice-to-have. Be honest about priorities; if everything is "Must," nothing is prioritized.

Acceptance criteria are the most important part. Each one should be testable — "Given X, when Y, then Z." If you can't write a test for it, the requirement isn't specific enough.

**Common pitfalls:**
- Requirements that describe solutions instead of problems ("use Redis for caching" is architecture, not a requirement)
- Missing acceptance criteria — a requirement without criteria is a wish
- Not separating functional from non-functional — performance, security, and reliability requirements are easy to forget
- Duplicating product description content instead of linking to it

## Template

```markdown
# Requirements: {Feature/Area}

> Created: {date}
> Status: Draft | Approved | Implemented

## Functional Requirements

| ID | Requirement | Priority | Status |
|----|------------|----------|--------|
| FR-001 | | Must | Pending |
| FR-002 | | Should | Pending |

## Non-Functional Requirements

| ID | Requirement | Category | Target |
|----|------------|----------|--------|
| NFR-001 | | Performance | |
| NFR-002 | | Security | |

## Acceptance Criteria

- [ ]

## Dependencies

| Dependency | Type | Impact |
|-----------|------|--------|
| | | |

## Notes

```

## Cross-References

- Links TO: product description (what's being required), research (evidence for priorities), personas (who needs this)
- Links FROM: architecture (what it must achieve), plans (what's being built)
