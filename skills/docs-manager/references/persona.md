# Reference: Persona

## Purpose

A persona document captures who uses the product — their role, goals, frustrations, and behavior patterns. It grounds product decisions in real user context rather than assumptions.

## Perspective

**User-centered.** Write as a profile of a real type of person, grounded in evidence.

- DO include: demographics, goals, pain points, behaviors, evidence sources
- DO NOT include: product features (→ product description), technical details (→ architecture), market trends (→ research)

## How to Write One

The summary passes the skim test: a reader knows within 2–3 sentences whether this persona is relevant to their work.

- Confidence is honest: 20 user interviews = high; synthesized from competitor reviews and assumptions = low. Low-confidence personas are still useful, but decisions based on them need validation.
- Goals and pain points are specific and prioritized: "wants to save time" is too vague; "needs to process 50+ orders per hour without switching between 3 tools" is actionable.
- Behaviors describe what they actually do, not what they should do — spreadsheets-as-database is a behavior worth capturing.

**Common pitfalls:**
- Inventing personas without evidence — if you can't cite a source, mark it as low-confidence
- Making personas too generic ("busy professional who values efficiency" describes everyone)
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
