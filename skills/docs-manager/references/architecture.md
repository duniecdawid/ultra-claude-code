# Reference: Architecture

## Purpose

An architecture document explains how the platform is built — components, data flow, technology choices, and interfaces. It's the document an engineer reads to understand the system's structure before making changes.

## Perspective

**Builder-facing.** Write for someone who needs to understand the system well enough to modify it safely.

- DO include: components, responsibilities, data flow, tech stack, interfaces, dependencies, state ownership, observability
- DO NOT include: user experience or workflows (→ product description), market context (→ research), success metrics (→ requirements), code conventions or patterns (→ standards), logging formats or error handling patterns (→ standards)

## How to Write One

**Start with the diagram.** Draw the system first — an ASCII diagram showing components, what connects to what, what protocol they use, which direction data flows, and where external dependencies live. The diagram is the anchor of the document. Everything else annotates or extends it.

**Then walk through the primary path.** Pick the most important data path and narrate it step by step. This is the most valuable part — it turns a static picture into a story an engineer can follow. Weave in state ownership, integration contracts, and external dependencies naturally as you encounter them in the narrative. Don't separate them into their own sections. If the system has multiple important paths (e.g., a payment service handling charges, refunds, and disputes), walk through the primary one first, then cover additional paths that reveal different components or behaviors.

**Bold key terms** — technology names, component names, and system elements should be bold in the narrative. This makes the prose scannable: an engineer can skim the bold words to get the topology, then read the full sentences for the story.

Here's what good walkthrough prose looks like:

> A merchant submits a charge via the **REST API**. The **gateway** validates the request and writes an idempotency key to **Redis** to prevent duplicate processing. It then calls **Stripe's** charge API — this is the critical external dependency, and the one most likely to introduce latency. On success, the gateway writes the transaction to the ledger in **PostgreSQL** (source of truth for all financial state) and publishes a `charge.completed` event to **Kafka**. Downstream consumers — billing, analytics, notifications — pick up the event independently.

Notice: no tables, no bullet lists. Components, state ownership (PostgreSQL is source of truth), external dependencies (Stripe), and integration (Kafka events) all appear naturally in the story. Bold terms make it scannable without breaking the narrative flow.

**Technology choices should include rationale.** "We use PostgreSQL" is less useful than "We use PostgreSQL because we need transactional consistency across X and Y." If the technology choices are inherited from a parent service doc, don't repeat them — only document choices specific to this component.

**Only write about risks that are real.** If there are no security concerns worth noting, don't write a security section. If scaling is straightforward, don't manufacture bottleneck analysis. But when something is genuinely risky — a fragile external dependency, a known performance ceiling, a failure mode with wide blast radius, or a process that depends on a human doing the right thing — call it out explicitly. Manual steps are a common hidden risk: if the system relies on someone remembering to rotate a key, approve a queue, or trigger a reconciliation, that's a failure mode worth documenting.

**For service-level docs**, consider also covering runtime behavior (concurrency model, scaling characteristics, resource limits, batch sizes, timeouts) and observability (what signals the system emits and where to find them when something goes wrong). These are less relevant for component-level docs within a service.

**Component docs should not repeat the parent.** When documenting a component that belongs to a larger service, skip everything already covered in the service-level doc — tech stack, observability setup, inherited dependencies. Only add what's specific to this component.

**Common pitfalls:**
- Describing what the system *should* do instead of what it *does* — architecture docs drift fast, keep them grounded in current reality
- Mixing in product behavior that belongs in the product description
- Listing technologies without explaining why they were chosen
- Documenting components in isolation without explaining how data and state flow between them
- Writing sections for completeness when there's nothing meaningful to say

## Template

```markdown
# Architecture: {Title}

> Created: {date}

## Overview

What this subsystem does and where it sits in the larger system.

## Context

What problem does this architecture solve? What constraints exist?

## Architecture

{ASCII diagram showing components, connections, protocols, data direction, external dependencies}

### Walkthrough

Narrative tracing the primary path end-to-end through the system. Covers components, data flow, state ownership, integration points, and external dependencies as they appear in the story.

## Technology Choices

| Technology | Rationale |
|-----------|-----------|
| | |

Only choices specific to this subsystem. Skip anything inherited from a parent service doc.

## Runtime Behavior

<!-- How the service behaves under real conditions: concurrency, scaling, resource limits. Service-level only. -->

## Observability

<!-- What signals to look at when something goes wrong. Service-level only. -->

## Risks & Constraints

<!-- Only what's genuinely relevant. Skip this section if there's nothing to flag. -->

## Open Questions

- [ ]
```

## Cross-References

- Links TO: product description (what it enables), requirements (what it must achieve), standards (how to build it)
- Links FROM: product description (how it's built), testing (system being tested)
