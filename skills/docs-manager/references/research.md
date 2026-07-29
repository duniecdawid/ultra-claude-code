# Reference: Research

## Purpose

A research document captures external context — market data, competitor analysis, technology landscape findings. It's the evidence base that informs product and technology decisions.

## Perspective

**Market-facing.** Write as a report of what was found externally, not what the product does.

- DO include: competitors, trends, evidence, data, implications for the product
- DO NOT include: product behavior or capabilities (→ product description), technical implementation (→ architecture), success metrics (→ requirements)

## How to Write One

A focused objective produces a useful document: "What's the competitive landscape for auth providers?" beats "research auth."

- Findings lead with evidence, not opinion: "3 of 5 competitors offer SSO as a free tier feature (source: pricing pages, March 2026)" is stronger than "SSO should probably be free."
- Implications, not decisions: "this suggests SSO is table stakes for enterprise customers" belongs here; the actual decision to build SSO goes in requirements.
- Every external claim cites its source — research without sources is opinion.

**Common pitfalls:**
- Mixing research with recommendations about what to build — what to build goes in product descriptions. The exception is when research uncovers external constraints (regulations, compliance, standards) that force specific requirements — those implications belong here and should be linked from requirements.

## Template

```markdown
# Research: {Topic}

> Created: {date}
> Type: Market | Competitor | Technology Landscape
> Status: Draft | Final
> Sources: {count} sources consulted

## Objective

What question this research answers.

## Key Findings

1. {finding with evidence}
2. {finding with evidence}

## Competitor Analysis

<!-- If applicable -->

| Competitor | Approach | Strengths | Weaknesses |
|-----------|----------|-----------|------------|
| | | | |

## Technology Landscape

<!-- If applicable -->

| Option | Maturity | Community | Fit for Our Use Case |
|--------|----------|-----------|---------------------|
| | | | |

## Market Trends

<!-- If applicable -->

## Implications

What these findings mean for product decisions.

## Sources

| Source | Type | Date |
|--------|------|------|
| | | |

## Related

- Product description: {link to what this research informs}
- Requirements: {link to requirements influenced by these findings}
```

## Cross-References

- Links TO: product description (what it informs), requirements (implications for priorities)
- Links FROM: product description (market context), requirements (evidence for priorities)
