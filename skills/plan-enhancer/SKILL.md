---
name: Plan Enhancer
description: Standardizes plan output for all planning modes. Redirects plan to documentation/plans/{name}/README.md with embedded task list and task classification. Auto-loaded by planning mode skills via context field.
user-invocable: false
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
context:
  - ${CLAUDE_PLUGIN_ROOT}/templates/plan.md
---

# Plan Enhancer

You provide plan structuring instructions that are loaded into context by planning mode skills (Feature Mode, Debug Mode, etc.). You do NOT trigger plan mode yourself — the planning mode skill is responsible for calling EnterPlanMode and providing the planning context. Your role starts after plan mode is active: you govern where the plan is written, how it's structured, and how tasks are classified.

## Responsibility Split

| Responsibility | Owner |
|---------------|-------|
| Triggering plan mode (EnterPlanMode) | Planning mode skill |
| Gathering context (research, architecture) | Planning mode skill |
| Deciding plan scope and content | Planning mode skill + user |
| **Plan file location** | **Plan Enhancer** |
| **Directory scaffolding** | **Plan Enhancer** |
| **Plan format and template** | **Plan Enhancer** |
| **Task classification** | **Plan Enhancer** |
| **Task granularity enforcement** | **Plan Enhancer** |

## What You Do

1. **Redirect plan location** — Plans go to `documentation/plans/{name}/README.md`, not Claude's default location
2. **Scaffold plan directory** — Create the full plan directory structure including `shared/` and `research/` subdirectories
3. **Standardize format** — All plans use the loaded plan template with embedded task list
4. **Classify tasks** — Each task gets a classification that determines its execution pipeline
5. **Ensure granularity** — Tasks must be right-sized for agentic execution

## Plan Directory Structure

When a plan is created, scaffold this structure:

```
documentation/plans/{plan-name}/
├── README.md          # The plan document (task list embedded)
├── shared/            # Per-role shared memory (created empty, used during execution)
└── research/          # Per-task research files (created empty, used during execution)
```

Create the directories immediately. The `shared/` and `research/` directories start empty — they are populated during execution.

## Plan Naming

Derive the plan name from the user's feature description:
- Lowercase, hyphenated: "Add user authentication" -> `user-auth`
- Short but descriptive: 2-4 words max
- No special characters

If the user provides `$ARGUMENTS`, use it to derive the plan name.

## Task Classification

Classify every task before adding it to the plan. Classification determines which stages of the execution pipeline the task flows through:

| Classification | Criteria | Pipeline Stages |
|----------------|----------|-----------------|
| **Full** | Multi-file changes, architectural impact, complex logic, unclear implementation path | Research -> Implementation -> Review -> Test |
| **Standard** | Single-component, clear requirements, well-understood pattern | Implementation -> Review -> Test |
| **Trivial** | Config change, rename, one-liner, simple flag toggle | Implementation -> Test |

### Classification Guidelines

Mark as **Full** when:
- Task touches 3+ files across different modules
- Task introduces a new architectural pattern
- Task involves integration with external services
- Task has unclear implementation approach requiring research

Mark as **Standard** when:
- Task modifies 1-2 files within a single component
- Requirements are clear and pattern is established
- Similar implementations exist in the codebase

Mark as **Trivial** when:
- Task is a single-line or few-line change
- Task is purely configuration (env vars, feature flags)
- Task is a rename, typo fix, or copy change

## Task Granularity Rules

Tasks must be right-sized for parallel agentic execution:

- **Too large**: "Implement the authentication system" — this is a plan, not a task
- **Too small**: "Add import statement for jwt" — this is a step within a task, not a task itself
- **Right size**: "Add JWT middleware to Express app with token validation and refresh" — clear scope, completable by one agent, testable independently

### Granularity Checks

Each task MUST have:
- A clear description of what to build/change
- Expected files to create or modify
- Success criteria (how to verify it's done)
- Dependencies on other tasks (if any)

Each task SHOULD be:
- Completable by a single Executor agent in one pass
- Independently testable
- Non-overlapping with other tasks (no two tasks modifying the same file for the same reason)

## Plan Format

Use the loaded plan template (`templates/plan.md`) as the base structure. The plan README.md must include:

1. **Objective** — What this plan accomplishes
2. **Context** — Links to architecture docs, requirements, RFCs
3. **Scope** — In scope / out of scope boundaries
4. **Success Criteria** — Checkboxes for plan-level acceptance
5. **Task List** — Every task with classification, description, files, success criteria, dependencies
6. **Architecture Impact** — What architecture docs need updating
7. **Risk Assessment** — Risks with likelihood, impact, mitigation

## Process

Once the planning mode skill has entered plan mode and gathered context, apply these steps:

1. **Derive plan name** from the feature description or `$ARGUMENTS`
2. **Check for existing plan** — if `documentation/plans/{name}/` exists, load it for revision instead of creating new
3. **Create plan directory** — scaffold `shared/` and `research/` subdirectories
4. **Write the plan** to `documentation/plans/{name}/README.md` — NOT Claude's default plan file
5. **Build the plan** — the planning mode provides the content; you ensure format compliance
6. **Classify all tasks** — apply classification rules to every task in the list
7. **Validate granularity** — check each task against granularity rules, split or merge as needed

## Existing Plan Handling

If the plan directory already exists (revision or re-planning):
- Read the existing `README.md` to understand current state
- Check for checkpoint files — if they exist, this plan has been partially executed
- Warn the user if modifying a plan that has execution history
- Preserve `shared/` and `research/` contents — they contain teammate work

## Constraints

- Do NOT modify files outside the plan directory during plan creation
- Do NOT execute the plan — that is `/uc:plan-execution`'s job
- Do NOT skip task classification — every task needs one
- Do NOT create tasks without success criteria
- Do NOT use Claude's default plan file path — always use `documentation/plans/{name}/README.md`

## Example

**Input from Feature Mode:** "Add user authentication with JWT"

**Plan Enhancer produces:**

```
documentation/plans/user-auth/
├── README.md
├── shared/
└── research/
```

**README.md includes tasks like:**

```markdown
### Task 1: Add JWT middleware to Express
- **Classification:** Full
- **Description:** Create Express middleware that validates JWT tokens from HTTP-only cookies, extracts user claims, and attaches to request context
- **Files:** src/middleware/auth.ts (create), src/types/auth.ts (create), src/app.ts (modify)
- **Success criteria:** Middleware validates tokens, rejects expired tokens, attaches user to req.user
- **Dependencies:** None

### Task 2: Add login endpoint
- **Classification:** Standard
- **Description:** Create POST /api/auth/login that validates credentials and returns JWT in HTTP-only cookie
- **Files:** src/routes/auth.ts (create), src/services/auth.ts (create)
- **Success criteria:** Returns 200 with token cookie on valid creds, 401 on invalid
- **Dependencies:** Task 1

### Task 3: Update environment config
- **Classification:** Trivial
- **Description:** Add JWT_SECRET and TOKEN_EXPIRY to environment configuration
- **Files:** .env.example (modify), src/config.ts (modify)
- **Success criteria:** New env vars documented and loaded in config
- **Dependencies:** None
```
