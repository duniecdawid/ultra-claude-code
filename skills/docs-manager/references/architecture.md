# Reference: Architecture

## Purpose

An architecture document explains how the platform is built — components, data flow, technology choices, and interfaces. It's the document an engineer reads to understand the system's structure before making changes.

## Perspective

**Builder-facing.** Write for someone who needs to understand the system well enough to modify it safely.

- DO include: components, responsibilities, data flow, tech stack, interfaces, dependencies
- DO NOT include: user experience or workflows (→ product description), market context (→ research), success metrics (→ requirements)

## How to Write One

Start with an overview of what this subsystem does and where it sits in the larger system. Then describe its components — what each one does, where it lives in the codebase, and how they interact.

Data flow is often the most valuable part. Trace how data enters the system, gets transformed, and exits. Diagrams help but aren't required — a clear written description is better than a vague diagram.

Technology choices should include rationale. "We use PostgreSQL" is less useful than "We use PostgreSQL because we need transactional consistency across X and Y."

**Common pitfalls:**
- Describing what the system *should* do instead of what it *does* — architecture docs drift fast, keep them grounded in current reality
- Mixing in product behavior that belongs in the product description
- Listing technologies without explaining why they were chosen
- Forgetting to document interfaces between components — these are where bugs live

## Template

```markdown
# Architecture: {Title}

> Created: {date}
> Status: Draft | Active | Superseded

## Overview

Brief description of this architectural component or subsystem.

## Context

What problem does this architecture solve? What constraints exist?

## Components

| Component | Responsibility | Location |
|-----------|---------------|----------|
| | | |

## Data Flow

How data moves through this subsystem.

## Technology Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| | | |

## Interfaces

### External APIs

### Internal APIs

## Security Considerations

## Performance Considerations

## Dependencies

| Dependency | Type | Notes |
|-----------|------|-------|
| | | |

## Open Questions

- [ ]
```

## Cross-References

- Links TO: product description (what it enables), requirements (what it must achieve), standards (how to build it)
- Links FROM: product description (how it's built), testing (system being tested)
