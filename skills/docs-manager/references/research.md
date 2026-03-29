# Reference: Research

## Purpose

A research document captures external context — market data, competitor analysis, technology landscape findings. It's the evidence base that informs product and technology decisions.

## Perspective

**Market-facing.** Write as a report of what was found externally, not what the product does.

- DO include: competitors, trends, evidence, data, implications for the product
- DO NOT include: product behavior or capabilities (→ product description), technical implementation (→ architecture), success metrics (→ requirements)

## How to Write One

Start with the objective — what question does this research answer? A focused question produces a useful document. "What's the competitive landscape for auth providers?" is better than "research auth."

Key findings should lead with evidence, not opinion. "3 of 5 competitors offer SSO as a free tier feature (source: pricing pages, March 2026)" is stronger than "SSO should probably be free."

The Implications section is where research connects to product decisions — but it states implications, not decisions. "This suggests SSO is table stakes for enterprise customers" belongs here. The actual decision to build SSO goes in requirements.

Every external claim must cite its source. Research without sources is opinion.

**Common pitfalls:**
- Restating product description content — research says what the *market* does, not what *our product* does
- Missing sources — unsourced claims are opinions, not research
- No implications section — raw data without interpretation isn't actionable
- Mixing research with recommendations about what to build — that belongs in requirements

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
