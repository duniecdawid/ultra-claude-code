# Reference: Testing

## Purpose

A testing document defines how to verify that a system area works correctly — the strategy, commands, coverage targets, and rules for automated test agents. It's the document someone reads before writing tests or configuring CI for an area.

## Perspective

**Verification-focused.** Write for someone who needs to prove the system works as specified.

- DO include: test strategy, commands, coverage requirements, agent rules, security testing considerations
- DO NOT include: product behavior (→ product description), system design (→ architecture), coding patterns (→ standards)

## How to Write One

Scope to a specific area or strategy, not "all testing" — a testing doc for the auth module beats one for "the whole app."

- Strategy table entries are specific: "integration tests for API endpoints using supertest," not "integration tests."
- Commands are exact and runnable (flags, environment setup) — a testing doc without runnable commands is incomplete.
- Agent rules are read by automated test agents (the task-tester in plan-execution): special setup steps, required fixtures, things to avoid.

**Common pitfalls:**
- Forgetting security testing — it's easy to focus on functional tests and miss security considerations
- Not updating when test infrastructure changes

## Template

```markdown
# Testing: {Area/Strategy}

> Created: {date}
> Status: Draft | Active
> Applies to: {scope}

## Overview

What this testing document covers and its relationship to the system under test.

## Test Strategy

| Test Type | Scope | Tool | Notes |
|-----------|-------|------|-------|
| | | | |

## Commands

\`\`\`bash
# Key test commands for this area
\`\`\`

## Coverage Requirements

| Area | Target | Current |
|------|--------|---------|
| | | |

## Agent Rules

Rules for automated test agents when running tests in this area.

## Security Testing

Security-specific test considerations for this area.

## Related

- Architecture: {link to system being tested}
- Standards: {link to relevant coding standards}
```

## Cross-References

- Links TO: architecture (system being tested), standards (coding patterns to verify)
- Links FROM: plans (test verification steps)
