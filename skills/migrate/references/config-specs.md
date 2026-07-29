# .claude/ultra/ Config File Specifications

Specifications for each `.claude/ultra/` configuration file derived during Phase 2.

**Note:** Testing configuration is produced as a multi-file directory at `documentation/technology/testing/` by the Explore->Executor pipeline in Phase 3 (Stages B and C), not this group.

## .claude/ultra/version.json

Version marker for migration tracking. Written automatically at the end of every migrate run.

```json
{
  "initialized": "2026.04.03-2",
  "initializedSeq": 67,
  "lastMigrated": "2026.04.03-2",
  "lastMigratedSeq": 67,
  "migratedAt": "2026-04-03T14:22:00.000Z"
}
```

- `initialized` / `initializedSeq` — version when project was first set up (never changes after creation)
- `lastMigrated` / `lastMigratedSeq` — version the project is current to (updated on each migrate)
- `migratedAt` — timestamp of last migration

Do not derive this file — it is written automatically by the migrate skill.

## .claude/ultra/app-context.md

Derived from Code Surveyor findings:
- Project Overview (name, purpose, primary language)
- Domain (what problem does this project solve)
- Key Technologies (frameworks, libraries, build tools)
- External Integrations (APIs, databases, services)

## documentation/technology/testing/ (reference only)

This directory is produced by Phase 3 Stages B+C. Listed here for reference:
- `README.md` — test strategy overview (status, stack, test pyramid)
- `commands.md` — exact test commands by type (unit, integration, e2e)
- `infrastructure.md` — test infra policy (Testcontainers, docker-compose, mocks)
- `security.md` — domain-calibrated security testing categories
- `agent-rules.md` — base rules for all tester agents
- `final-gate.md` — instructions for final-gate tester only

## .claude/ultra/environments.md

Derived from CI config, environment files, docker-compose:
- Development environment setup
- Required environment variables
- External service dependencies

## .claude/ultra/docs-format — obsolete

No longer created. Documentation management is always enabled; the docs-manager skill no longer checks for this file. Delete it if present.

## Plan Presentation

For each file:
- Show proposed content in the plan
- Mark as "create" if file doesn't exist, or "update" if it does (with diff)
- Skip files that already exist with real content (not placeholders) unless user wants to overwrite

## Standards Signals Table

Compile candidate standards from the Code Surveyor's Standards Signals into a table:

| Signal Topic | Proposed Standard File | Evidence | Action |
|---|---|---|---|
| {topic} | `{filename}.md` | High/Med/Low/None | Recommend/Flag |

Evidence strength determines recommendation:
- **High** (5+ files, consistent patterns) -> auto-recommend "Create"
- **Medium** (2-4 files) -> recommend with note about limited evidence
- **Low** (1 file or ambiguous) -> present but don't recommend
- **None but domain-relevant** (e.g., security for payment systems) -> flag for discussion

Present ALL candidates to user via AskUserQuestion with this format:

> **Standards & Testing Config Approval**
>
> Based on code analysis, here are candidate coding standards and the testing config plan. Please approve each:
>
> | # | Standard | Evidence | Recommendation | Your Choice |
> |---|---|---|---|---|
> | 1 | `rest-api.md` | High (12 controllers) | Create | Create / Skip / Create (I'll add context) |
> | 2 | `error-handling.md` | Medium (3 patterns) | Create | Create / Skip / Create (I'll add context) |
> | ... | | | | |
>
> **Testing config** (`documentation/technology/testing/`): Will generate 6 files — test strategy, commands, infrastructure, security ({N} categories based on {domain}), agent rules, and final-gate instructions. Approve? Yes / No / Modify
>
> You may also add unlisted topics (e.g., "Also create a caching standard").

For any topic where user selects "Create (I'll add context)" — follow up with AskUserQuestion to collect their additional context before proceeding to Phase 3.

User must approve before any Explore agents spawn. Only an explicit approval counts — empty, blank, or ambiguous responses must be re-asked.

## Migration Mapping Rules

Use the Docs Manager routing rules for classification when migrating existing docs:
- Architecture, design, component, system, data flow -> `technology/architecture/`
- Convention, standard, pattern, style guide -> `technology/standards/`
- ADR, decision record, RFC, trade-off -> `technology/rfcs/`
- Vision, positioning, product brief -> `product/description/`
- Competitor, market, research, trends -> `product/research/`
- Requirement, FR-, NFR-, acceptance criteria -> `product/requirements/`
- External API docs, integration guides -> `context/{system}/docs/`
- Blocker, dependency, open question, idea, bug -> project backlog via `/uc:backlog add ...`
