# Reference: Persona

## Purpose

A persona document captures who uses the product — their role, goals, frustrations, and behavior patterns. It grounds product decisions in real user context rather than assumptions.

## Perspective

**User-centered.** Write as a profile of a real type of person, grounded in evidence.

- DO include: demographics, goals, pain points, behaviors, evidence sources
- DO NOT include: product features (→ product description), technical details (→ architecture), market trends (→ research)

## How to Write One

Start with a summary — 2-3 sentences that capture who this person is and their relationship to the product. A reader should be able to skim the summary and know if this persona is relevant to their work.

The confidence level matters. A persona built from 20 user interviews is high-confidence. One synthesized from competitor reviews and assumptions is low-confidence. Be honest — low-confidence personas are still useful, but decisions based on them should be validated.

Goals and pain points should be specific and prioritized. "Wants to save time" is too vague. "Needs to process 50+ orders per hour without switching between 3 different tools" tells you something actionable.

Behaviors should describe what they actually do, not what they should do. If they use spreadsheets as a database, that's a behavior worth capturing — it reveals something about their workflow.

**Common pitfalls:**
- Inventing personas without evidence — if you can't cite a source, mark it as low-confidence
- Making personas too generic ("busy professional who values efficiency" describes everyone)
- Duplicating product description content — the persona says who they are, the product description says what they use
- Forgetting to update personas when new evidence emerges

## Template

```markdown
# Persona: {Name}

> Created: {date}
> Last updated: {date}
> Confidence: High | Medium | Low

## Summary

2-3 sentences: who they are and their relationship to the product.

## Demographics & Context

| Attribute | Value |
|-----------|-------|
| Role | |
| Technical proficiency | Low / Medium / High |
| Usage frequency | Daily / Weekly / Occasional |
| Environment | |

## Goals

1. {primary goal}
2. {secondary goal}

## Pain Points

1. {pain point — severity: Critical / Major / Minor}

## Behaviors & Patterns

- {observed or inferred behavior}

## What Success Looks Like

How this persona knows the product is working for them.

## Evidence Base

- {source and what it provided}

## Related

- Product description: {link to what they use}
- Requirements: {link to what's being built for them}
- Research: {link to market context, if applicable}
```

## Cross-References

- Links TO: product description (what they use), requirements (what's built for them), research (market context)
- Links FROM: requirements (who needs this)
