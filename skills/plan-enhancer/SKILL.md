---
description: Standardizes plan output for all planning modes. Writes plan directly to documentation/plans/{name}/README.md with embedded task list and task classification. Auto-loaded by planning mode skills via context field.
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

You provide plan structuring instructions that are loaded into context by planning mode skills (Feature Mode, Debug Mode, etc.). You govern how the plan is structured, how tasks are classified, where the plan is written, and how it is presented for approval.

## Responsibility Split

| Responsibility | Owner |
|---------------|-------|
| Driving the planning process | Planning mode skill |
| Gathering context (research, architecture) | Planning mode skill |
| Deciding plan scope and content | Planning mode skill + user |
| **Plan format and template** | **Plan Enhancer** |
| **Task classification** | **Plan Enhancer** |
| **Task granularity enforcement** | **Plan Enhancer** |
| **Plan directory scaffolding + file writing** | **Plan Enhancer** |

## What You Do

1. **Standardize format** — All plans use the loaded plan template with embedded task list. The template includes an `Execute: /uc:plan-execution {name}` header so the user knows how to run it.
2. **Classify tasks** — Each task gets a classification that determines its execution pipeline
3. **Ensure granularity** — Tasks must be right-sized for agentic execution
4. **Write plan to disk** — Scaffold the plan directory and write `documentation/plans/{name}/README.md` before presenting for approval

## Plan Directory Structure

When a plan is created, scaffold this structure:

```
documentation/plans/{plan-name}/
├── README.md          # The plan document (task list embedded)
├── shared/            # Lead-level shared notes (created empty, used during execution)
└── tasks/             # Per-task pipeline artifacts (created empty, used during execution)
```

Create the directories immediately. The `shared/` and `tasks/` directories start empty — they are populated during execution.

## Plan Naming

Derive the plan name from the user's feature description:
- Lowercase, hyphenated: "Add user authentication" -> `user-auth`
- Short but descriptive: 2-4 words max
- No special characters

If the user provides `$ARGUMENTS`, use it to derive the plan name.

## Task Classification

Classify every task before adding it to the plan. Classification determines which team members are spawned for the task during execution:

| Classification | Criteria | Pipeline Team |
|----------------|----------|---------------|
| **Full** | Multi-file changes, architectural impact, complex logic, unclear implementation path | Researcher + Executor + Reviewer + Tester |
| **Standard** | Single-component, clear requirements, well-understood pattern | Executor + Reviewer + Tester |
| **Trivial** | Config change, rename, one-liner, simple flag toggle | Executor + Tester |

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

## Plan Creation Process

1. **Derive plan name** from the feature description or `$ARGUMENTS`
2. **Check for existing plan** — if `documentation/plans/{name}/` exists, read it for revision context
3. **Scaffold plan directory**:
   ```bash
   mkdir -p documentation/plans/{name}/shared documentation/plans/{name}/tasks
   ```
4. **Build the plan** — the planning mode provides the content; you ensure format compliance. Use the loaded plan template including the `Execute: /uc:plan-execution {name}` header.
5. **Classify all tasks** — apply classification rules to every task in the list
6. **Validate granularity** — check each task against granularity rules, split or merge as needed
7. **Write plan to `documentation/plans/{name}/README.md`** via the Write tool — this is the canonical copy that `/uc:plan-execution` reads from. The plan is on disk before the user reviews it.
8. **Present a concise summary in chat** — NOT the full plan. Include: plan name, objective, task count with classification breakdown, and the file path. The user can read the full plan from the file.
9. **Ask for approval via AskUserQuestion** — Options: "Approve" / "Reject with feedback" / "Partially reject (specify changes)"

### Plan Revision (if rejected)

If the user rejects or partially rejects the plan:

1. Read their feedback
2. Edit the existing `documentation/plans/{name}/README.md` using the Edit tool to incorporate changes
3. Re-present the concise summary with changes highlighted
4. Re-ask for approval via AskUserQuestion

Repeat until approved or the user abandons the plan.

## Existing Plan Handling

If the plan directory already exists (revision or re-planning):
- Read the existing `README.md` to understand current state
- Check for checkpoint files — if they exist, this plan has been partially executed
- Warn the user if modifying a plan that has execution history
- Preserve `shared/` and `tasks/` contents — they contain teammate work

## Constraints

- Do NOT execute the plan — that is `/uc:plan-execution`'s job
- Do NOT skip task classification — every task needs one
- Do NOT create tasks without success criteria
- ALWAYS write the plan to `documentation/plans/{name}/README.md` BEFORE presenting for approval — this ensures the plan is on disk and cannot be lost
- ALWAYS include the `Execute: /uc:plan-execution {name}` header in the plan document

## Example

**Input from Feature Mode:** "Add user authentication with JWT"

**Plan Enhancer produces:**

```
documentation/plans/user-auth/
├── README.md
├── shared/
└── tasks/
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
