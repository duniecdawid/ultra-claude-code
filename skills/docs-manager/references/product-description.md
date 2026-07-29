# Reference: Product Description

## Purpose

A product description explains how the platform works **from the user's perspective**. It's the document someone reads to understand what a feature does, how to use it, and how it behaves.

## Perspective

**User-facing.** Write as if explaining to someone who will use the product, not build it.

- DO include: how it works, how to use it, behavior, edge cases, configuration
- DO NOT include: technical implementation (→ architecture), market data (→ research), success metrics (→ requirements)

## How to Write One

There is no fixed set of sections — the structure follows the natural shape of what you're describing. Good section headers are specific to the feature: "How Matching Works", "Rate Limiting Behavior", "Authentication Flow" — not generic labels like "Details" or "Information."

**Relationship with requirements:** same feature, different angles — see § One Canonical Home in the docs-manager SKILL.md. Example: the description says "users can filter by date range," the requirement says "FR-003: Date range filter must support ranges up to 12 months, response time < 200ms." Never restate acceptance criteria here.

**Common pitfalls:**
- Writing a marketing pitch instead of describing actual behavior
- Being too abstract — describe what the user actually sees and does

## Template

```markdown
# {Product/Feature Name}

> Created: {date}
> Status: Draft | Active | Superseded

## Overview

What this product/feature is, the problem it solves, and why it matters.

<!-- Add ## sections as needed: how it works, how to use it,
     behavior, edge cases, configuration, etc. -->

## Constraints

Known limitations, boundaries, or intentional exclusions.

## Related

- Architecture: {link}
- Requirements: {link}
- Research: {link, if applicable}
```

## Cross-References

- Links TO: architecture (how it's built), requirements (what must be achieved), research (why these capabilities matter)
- Links FROM: personas (what they use), requirements (what's being required), research (what it informs)
