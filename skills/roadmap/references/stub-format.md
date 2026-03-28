# Stub Plan Format

A stub plan uses the standard plan template (`templates/plan.md`) with specific fields filled and others marked as stubs for feature-mode to complete.

## Template

```markdown
# Plan: {Name}

> **Execute:** `/uc:plan-execution {NNN}`
> Created: {date}
> Status: Stub
> Source: Roadmap

## Objective

{1-2 sentences describing what this plan accomplishes. Written by roadmap skill.}

## Context

{Links to documentation files that inform this plan. Only include links to files that actually exist.}

- **Architecture:** [relevant architecture doc](../../technology/architecture/{file}.md)
- **Product:** [relevant product doc](../../product/description/{file}.md)
- **Requirements:** [relevant requirements doc](../../product/requirements/{file}.md)
- **Prior Plans:** [plan this depends on](../{NNN}-{name}/README.md)

## Tech Stack

<!-- STUB: Determined during detailed planning via /uc:feature-mode -->

## Scope

### In Scope

<!-- Each capability spans all layers (API, UI, database). Never split a feature across plans. -->

- {Capability or feature this plan delivers — full-stack, not layer-specific}
- {Another capability}
- {Keep to scope boundaries, not implementation details}

### Out of Scope

- {Thing that belongs to plan NNN-other-plan} (see [{NNN}-{name}](../{NNN}-{name}/README.md))
- {Another exclusion with pointer to which plan owns it}

## Success Criteria

- [ ] {High-level criterion — feature-mode refines these}
- [ ] {Another criterion}

## Task List

<!-- STUB: Tasks are defined during detailed planning. Run: /uc:feature-mode "{plan-name}" -->

## Documentation Changes

<!-- STUB: Populated during detailed planning -->

## Risk Assessment

<!-- STUB: Populated during detailed planning -->
```

## Key rules

- `Status: Stub` and `Source: Roadmap` are mandatory — feature-mode uses these to detect stubs
- Context links must point to real, existing files — do not invent paths
- Out of Scope should cross-reference other plans in the series, creating clear boundaries
- Success Criteria should be high-level and verifiable, not implementation-specific
- Scope items describe capabilities ("User can log in"), not tasks ("Create login endpoint")
- Scope items describe full-stack capabilities, not layer-specific work — a feature must never be split across plans
