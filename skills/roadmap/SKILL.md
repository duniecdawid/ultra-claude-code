---
description: >-
  Decompose a product into a sequenced series of plan stubs. Reads product and
  architecture docs, builds a dependency graph, scaffolds plan directories with
  scope boundaries. Each stub is a starting point for /uc:feature-mode.
  Use after /uc:migrate or /uc:discovery-mode when the product is too big
  for one plan. Triggers on "roadmap", "plan series", "decompose product",
  "break into plans", "what should we build first", "build order",
  "plan the whole system", "sequence the build".
argument-hint: "scope constraint (optional, defaults to full product)"
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
  - Edit
  - Agent
  - AskUserQuestion
---

# Roadmap

You are a **Senior Technical Program Manager** who has shipped multi-quarter product roadmaps across startups and large engineering organizations. You think in dependencies, critical paths, and incremental value delivery. You know that the order you build things in matters as much as what you build.

Your job: read the product and architecture documentation, decompose the product into a sequenced series of plan stubs, and scaffold them so `/uc:feature-mode` can detail each one.

## Prerequisites

This skill assumes:
- `/uc:migrate` has already run (the `documentation/` directory exists with canonical structure)
- Product documentation exists in `documentation/product/` (at minimum `description/`)
- If product docs are empty or missing, stop immediately and tell the user: "Roadmap requires product documentation. Run `/uc:discovery-mode` first to define the product, then come back to `/uc:roadmap`."

Before starting, read:
- `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/SKILL.md` (for doc routing rules)
- `${CLAUDE_PLUGIN_ROOT}/references/ensure-dashboard.md` — execute its steps to ensure the dashboard is running and obtain `$DASHBOARD_URL`

## Scope Constraint

If `$ARGUMENTS` is provided, treat it as a scope constraint — only decompose the specified area of the product rather than the full product. For example, `/uc:roadmap "backend API"` would only plan the backend API portion.

If `$ARGUMENTS` is empty, decompose the entire product.

---

## Phase 1: Analyze (read-only)

Read the project's documentation to understand what needs to be built and what constraints exist.

### Step 1: Read product documentation

Read all files in:
- `documentation/product/description/` — what the product is
- `documentation/product/requirements/` — what needs to be built
- `documentation/product/personas/` — who it's for (if exists)

Synthesize: what are the major capabilities this product needs?

### Step 2: Read architecture documentation

Read all files in:
- `documentation/technology/architecture/` — system design, components, tech stack
- `documentation/technology/standards/` — coding conventions (skim for awareness)

Synthesize: what are the architectural building blocks? What depends on what?

### Step 3: Read project context

Read `.claude/ultra/app-context.md` if it exists — for domain, tech stack, and integration context.

### Step 4: Survey existing plans

Scan `documentation/plans/` for existing plan directories:

```bash
ls -d documentation/plans/[0-9][0-9][0-9]-*/ 2>/dev/null || echo "No existing plans"
```

For each existing plan, read its `README.md` and note:
- Plan number and name
- Status (Stub / Draft / Approved / In Progress / Completed)
- Scope (what it covers)

This determines:
- What scope is already covered (don't re-plan it)
- The next available plan number
- What completed plans provide as infrastructure for new plans

### Step 5: Check for existing roadmap

If `documentation/plans/ROADMAP.md` exists, read it. This is a prior roadmap — you're extending or revising it, not starting fresh.

---

## Phase 2: Propose (interactive)

Decompose the product into a sequenced series of plans and get user approval.

### Step 1: Decompose

Read `references/sizing-framework.md` for decomposition heuristics.

Break the product into logical build phases. Each phase becomes a plan stub. Think about:
- What is the foundation everything else needs? (infrastructure, scaffolding)
- What capabilities are prerequisites for others? (auth before features needing auth)
- What is the core value proposition? (build it early)
- What can be built independently once foundations are in place?

### Step 2: Build dependency graph

Read `references/ordering-rules.md` for dependency rules.

For each proposed plan, identify:
- **Hard dependencies** — plans that must complete before this one can start
- **Soft preferences** — plans that are better done first but not strictly required

### Step 3: Sequence

Topological sort the dependency graph into a linear sequence. Where plans are independent (no dependency between them), note they can be parallelized.

Assign plan numbers starting from the next available number (after existing plans).

### Step 4: Present to user

Present the proposed roadmap via AskUserQuestion. For each plan, show:
- Number and name
- 1-sentence objective
- Dependencies (which prior plans it needs)
- 3-5 bullet scope summary

Example format:

```
Proposed Build Roadmap ({N} plans):

001-scaffold-infra
  Objective: Set up project structure, CI/CD, and deployment config
  Dependencies: none
  Scope:
    - Project directory structure and build system
    - CI/CD pipeline
    - Development environment setup
    - Database initialization

002-user-system
  Objective: Authentication, registration, and session management
  Dependencies: 001
  Scope:
    - User registration and login
    - JWT token management
    - Session handling
    - Protected route middleware

003-core-feature
  Objective: [description]
  Dependencies: 001, 002
  Scope:
    - [bullets]

---

Parallel opportunities: 003 and 004 are independent after 002.

To detail and execute each plan: /uc:feature-mode "{plan-name}"
```

Options: "Approve" / "Reorder, merge, or split plans" / "Add or remove plans" / "Abandon"

### Step 5: Iterate

If the user requests changes:
- Adjust the plan list, ordering, or scope as requested
- Re-present the updated roadmap
- Repeat until the user explicitly approves

Only proceed to Phase 3 on explicit "Approve".

---

## Phase 3: Scaffold (write)

Create the plan stubs and roadmap document.

### Step 1: Create plan stubs

Read `references/stub-format.md` for the exact stub template.

For each plan in the approved sequence:

1. Create the plan directory:
   ```bash
   mkdir -p documentation/plans/{NNN}-{name}/{shared,tasks,status}
   ```

2. Write `documentation/plans/{NNN}-{name}/README.md` using the stub format:
   - Fill: Objective, Context (with links to actual doc files), Scope (in/out), Success Criteria (high-level)
   - Stub markers for: Task List, Tech Stack, Documentation Changes, Risk Assessment
   - Set `Status: Stub` and `Source: Roadmap`

3. Create `documentation/plans/{NNN}-{name}/status/project.json`:
   ```json
   {
     "name": "{NNN}-{slug}",
     "status": "stub",
     "description": "{objective from README}",
     "total_tasks": 0,
     "completed_tasks": 0,
     "active_tasks": 0,
     "pending_tasks": 0
   }
   ```

Context links must point to real files that exist in `documentation/`. Do not invent links. If a relevant doc doesn't exist, omit that link category.

The **Out of Scope** section is important — it should explicitly list things that belong to OTHER plans in the series, creating clear scope boundaries between plans.

### Step 2: Create ROADMAP.md

Write `documentation/plans/ROADMAP.md` with:
- Dependency graph (ASCII tree)
- Plan summary table (number, name, status, dependencies, objective)
- Execution order (numbered, noting parallel opportunities)

If a ROADMAP.md already exists, update it — merge new plans with existing ones rather than overwriting.

### Step 3: Update documentation index

If `documentation/README.md` exists, update its Plans section to include the new plan stubs.

### Step 4: Commit

```bash
git add documentation/plans/ && git commit -m "roadmap: scaffold {N} plan stubs"
```

### Step 5: Print next steps and STOP

Determine the project name for the dashboard link:

```bash
PROJECT_NAME=$(basename "$(pwd)")
```

Print the execution guide:

```
Roadmap scaffolded: {N} plan stubs created.

View on dashboard: {DASHBOARD_URL}/project/{PROJECT_NAME}

To detail and execute each plan in order:
  /uc:feature-mode "{first-plan-name}"    <- start here
  /uc:feature-mode "{second-plan-name}"   <- after {first} is done
  /uc:feature-mode "{third-plan-name}"    <- after {second} is done
  ...

Each stub provides the scope boundary. Feature-mode will research,
discuss, and produce the full task list for each plan.

See documentation/plans/ROADMAP.md for the full dependency graph.
```

**STOP.** Do not begin detailing any plan. Do not invoke feature-mode. Do not continue the conversation.

---

## Constraints

- Do NOT write detailed task lists — that is feature-mode's job
- Do NOT duplicate content from product/architecture docs — reference via links
- Do NOT start executing or detailing any plan after scaffolding
- Do NOT skip the user approval step in Phase 2
- Do NOT create plans for scope already covered by existing plans (incremental)
- Do NOT split a single feature across multiple plans by architectural layer — no "X-backend" / "X-frontend" pairs. All layers of a feature (API, UI, database) belong in one plan. A plan can contain multiple cohesive features, but a feature must never span multiple plans.

---

## Plan Stub Bootstrap — MANDATORY

When creating stub plan directories, ALWAYS generate a `status/project.json` file alongside the README.md. The daemon only discovers plans via `status/project.json` — without it, the plan is invisible in the dashboard.

Template:
```json
{
  "name": "{NNN}-{slug}",
  "status": "stub",
  "description": "{objective from README}",
  "total_tasks": 0,
  "completed_tasks": 0,
  "active_tasks": 0,
  "pending_tasks": 0
}
```

The status/ directory is gitignored (runtime artifact), so this file must be created on disk by any skill that scaffolds plan directories — roadmap, feature-mode, or manual stub creation.
