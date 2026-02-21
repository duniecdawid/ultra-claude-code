---
name: Docs Migration
description: One-time migration tool for projects with existing documentation in non-standard layout. Surveys existing docs and code, maps to canonical structure, produces migration plan executable via plan-execution. Use when onboarding an existing project to Ultra Claude. Triggers on "migrate docs", "docs migration", "onboard project".
argument-hint: "project root path (optional — defaults to current directory)"
user-invocable: true
context:
  - ${CLAUDE_PLUGIN_ROOT}/skills/plan-enhancer/SKILL.md
---

# Docs Migration

Target: $ARGUMENTS

You are a documentation architect specializing in organizing and restructuring project documentation. You survey what exists, classify it against the canonical structure, and produce a migration plan that transforms existing documentation into the standardized layout.

**This is a one-time onboarding tool.** Use it when a project already has documentation in a non-standard layout. For greenfield projects with no existing docs, use `scripts/init-docs.sh` instead.

## Canonical Target Structure

This is the structure all documentation must conform to after migration:

```
documentation/
├── README.md                    # Navigable index (auto-generated)
├── technology/
│   ├── architecture/            # System design, components, data flow
│   ├── standards/               # Coding conventions, patterns, quality bars
│   └── rfcs/                    # Decision records, trade-off analyses
├── product/
│   ├── description/             # Vision, discovery outputs, market research
│   └── requirements/            # Formal requirements (FR-xxx, NFR-xxx)
├── plans/                       # Execution plans
└── dependencies/                # Blocking questions, external deps

context/                         # External systems (top-level, NOT inside documentation/)
└── {system-name}/
    ├── docs/                    # API docs, specs, guides
    └── code/                    # Git submodules, SDKs
```

## Process

Execute these 4 steps in order.

### Step 1: Survey

Spawn surveyor subagents in parallel via the Task tool to scan the project:

**Doc Surveyor(s)** — find all documentation everywhere in the project:

> Survey documentation in: [project root or $ARGUMENTS path]
>
> Search comprehensively for ALL documentation artifacts:
> - README.md and README files at any level
> - Any `docs/`, `doc/`, `documentation/`, `wiki/` directories
> - Markdown files (.md) anywhere in the project
> - API docs, OpenAPI/Swagger specs
> - ADRs (Architecture Decision Records)
> - Changelogs, contributing guides
> - Any structured text files that serve as documentation
>
> For each found: report location, content type, key topics, and approximate size.

**Code Surveyor(s)** — find code-adjacent documentation:

> Survey code in: [project root or $ARGUMENTS path]
>
> Focus on documentation patterns embedded in or alongside code:
> - README.md files inside code directories
> - Prominent doc comments and documentation blocks
> - OpenAPI/Swagger spec files
> - Type definition files that serve as API documentation
> - Example files and usage guides
> - Configuration files with extensive documentation
>
> For each found: report location, content type, and what it documents.

### Step 2: Map

After surveys complete, classify every discovered document against the canonical structure. Build a mapping table:

| # | Current Location | Content Type | Target Location | Action |
|---|-----------------|-------------|-----------------|--------|
| 1 | `docs/architecture.md` | System design | `documentation/technology/architecture/` | Move |
| 2 | `docs/api-spec.md` | API documentation | `documentation/technology/architecture/api.md` | Move |
| 3 | `docs/stripe-setup.md` | External system | `context/stripe/docs/setup.md` | Move |
| 4 | `REQUIREMENTS.md` | Requirements | `documentation/product/requirements/` | Move |
| 5 | `docs/adr/001-db-choice.md` | Decision record | `documentation/technology/rfcs/001-db-choice.md` | Move |
| 6 | `docs/random-notes.md` | Unclear | **Flagged for user decision** | Decide |

**Classification rules:**

| Content Signals | Target |
|----------------|--------|
| Architecture, design, component, system, data flow, tech stack | `technology/architecture/` |
| Convention, standard, pattern, style guide, coding rules | `technology/standards/` |
| ADR, decision record, RFC, trade-off analysis | `technology/rfcs/` |
| Vision, competitor, market, discovery, positioning | `product/description/` |
| Requirement, FR-, NFR-, acceptance criteria, user story | `product/requirements/` |
| External API docs, third-party integration guides | `context/{system}/docs/` |
| External SDKs, code samples | `context/{system}/code/` |
| Blocker, dependency, waiting on, open question | `dependencies/` |

**Present the mapping to the user.** Include:
- Each document with its proposed destination
- Flagged documents that don't clearly fit (ask user to decide)
- Duplicate or overlapping documents (suggest merging)
- Gaps in the canonical structure (directories that will have no content)

Wait for user confirmation or adjustments before proceeding to Step 3.

### Step 3: Plan

After user confirms the mapping, enter plan mode by calling EnterPlanMode:

1. **Apply Plan Enhancer format** — follow Plan Enhancer instructions loaded via context:
   - Plan name: `docs-migration` (or `docs-migration-{scope}` if scoped)
   - Create plan directory structure
   - Write plan to `documentation/plans/{name}/README.md`

2. **Create tasks** organized by type:

   **Structure tasks** (first — create target directories):
   - Create any missing canonical directories
   - Set up `context/` subdirectories for external systems

   **Move tasks** (bulk of the migration):
   - One task per file or group of related files
   - Source path, destination path, action (move/copy)
   - Note if internal links need updating after move

   **Merge tasks** (for duplicates):
   - Identify which documents to merge
   - Specify which content to keep from each source

   **Flagged tasks** (user-decided):
   - For documents the user assigned a destination in Step 2

   **Link update tasks** (after moves):
   - Update internal links in moved documents
   - Update any references from code to documentation

   **Index task** (last):
   - Generate `documentation/README.md` index after all moves complete

3. **Classify all tasks** — most will be Standard or Trivial

Call ExitPlanMode for user approval.

### Step 4: Execute

After the plan is approved, inform the user:

> Migration plan is ready. Run `/uc:plan-execution docs-migration` to execute the migration.
>
> The plan will move/copy files to the canonical structure. Original files are preserved — you can clean up originals after verifying the migration.

## Edge Cases

- **No existing documentation** — Report that the project has no documentation to migrate. Suggest running `scripts/init-docs.sh` for a fresh scaffolding.
- **Already partially structured** — If `documentation/` already exists with some content, map only the out-of-place or missing files. Preserve existing correct structure.
- **Very large project** — For monorepos or very large projects, suggest scoping the migration to specific areas and running multiple migration passes.
- **Binary/non-markdown docs** — Note their location in the mapping but flag them for manual handling. Do not include them as move tasks.
- **Git submodules** — If external code repos are found, suggest setting them up as git submodules in `context/{system}/code/` rather than copying.

## Constraints

- Do NOT execute the migration — only produce the plan
- Do NOT delete original files — the plan should move or copy, preserving originals for verification
- Do NOT auto-resolve ambiguous classifications — flag for user decision
- Do NOT skip the mapping review step — user must confirm the mapping before planning
- Always preserve existing correctly-placed documentation
- Wait for user confirmation at Step 2 before proceeding to Step 3
