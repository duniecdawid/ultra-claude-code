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

## Conversational Planning

Planning is a **dialogue with the user**, not a one-shot generation. Every planning mode that loads Plan Enhancer must build a real conversation — asking, listening, challenging, and iterating.

### Core rules

1. **Never fabricate user responses.** Every question that needs user input MUST go through AskUserQuestion. Never write questions as text output and answer them yourself. Never assume the user's preferences or decisions — wait for their actual response.

2. **Always ask scope questions.** Even when the request seems clear, there are always decisions the user should make — edge cases, in/out of scope boundaries, phasing, trade-offs. Use AskUserQuestion for these. Don't skip this because you think the answer is obvious.

3. **React to user answers substantively.** When the user responds:
   - If you **agree** — say why briefly and build on their answer
   - If you **disagree** — say so directly, explain your concern, and suggest an alternative. You are a senior technical leader, not a yes-machine. Push back on approaches you think are risky, over-scoped, or under-scoped
   - If the answer is **incomplete or unclear** — ask a follow-up via AskUserQuestion. Don't fill in the gaps yourself
   - If the answer **changes your understanding** — say what changed and how it affects the plan

4. **Suggest improvements proactively.** If you see opportunities the user hasn't considered — simpler approaches, potential pitfalls, phasing strategies, things that should be out of scope — raise them. Use AskUserQuestion to get the user's take.

5. **Challenge weak decisions.** If the user makes a choice that you think is suboptimal, say so respectfully but clearly: "I'd push back on X because Y. Have you considered Z?" Then let them decide — respect the final call, but make sure they heard the concern.

### Approval gate rules

- Only an explicit "Approve" selection counts as plan approval. Do NOT infer approval from empty, blank, ambiguous, or non-committal responses.
- If the user selects "Other" with empty or unclear text, re-ask the question. Say: "I need an explicit approval, rejection, or feedback before proceeding."
- Never skip or auto-approve the approval step. The plan is not approved until the user explicitly says so.

## Research Dispatch Strategy

Planning modes need codebase context before building a plan. This section defines a two-phase research approach that all planning modes follow by default. Individual modes may override specific phases — overrides are documented in the table below.

### Phase A — Structural Survey

Spawn **Code Surveyor** + **Doc Surveyor** in parallel (both Sonnet, `uc:Code Surveyor` and `uc:Doc Surveyor` agent types):

- **Code Surveyor**: Scoped to the code packages most relevant to the feature or bug. The planning mode determines the scope based on its Phase 1 analysis (e.g., Feature Mode uses scope challenge output; Debug Mode uses symptom-related code paths).
- **Doc Surveyor**: Scoped to the documentation directories most relevant to the work — typically `documentation/technology/architecture/` and `documentation/product/requirements/`, plus any directories identified in Phase 1.

While surveyors work, the Lead does its own **direct reading** of key files (architecture docs, requirements, plans, app-context). The planning mode specifies which files to read directly.

Surveyors return structured overviews (file lists, components, data structures, patterns, cross-references). This gives the Lead a structural map of the relevant codebase and documentation without the cost of a full Researcher agent.

### Phase B — Targeted Deep Research (Conditional)

Only spawn a **Researcher** (`uc:Researcher` agent type, Sonnet) when Phase A reveals gaps that require deep analysis. Specific triggers:

- **External integrations**: Surveyors found references to external services, APIs, or dependencies that need investigation beyond structural overview
- **Complex cross-component interactions**: Structural map shows the work touches 3+ components with non-obvious interaction patterns
- **Undocumented patterns**: Code Surveyor found patterns or conventions with no corresponding documentation from Doc Surveyor
- **Doc-code conflicts**: Doc Surveyor and Code Surveyor returned contradictory information about the same component

If none of these triggers fire, proceed to the next phase with surveyor output + direct reading only. Do not spawn a Researcher "just in case."

When Phase B is triggered, scope the Researcher tightly to the identified gaps — not a broad re-survey of what the surveyors already covered. Reference specific findings from Phase A in the Researcher prompt.

### Mode Override Table

| Mode | Phase A | Phase B | Notes |
|------|---------|---------|-------|
| **Feature Mode** | Default (Code + Doc Surveyor) | Conditional — triggered by external deps, plan conflicts, external system context | Standard two-phase |
| **Debug Mode** | Default, scoped to symptom-related code paths | **Override**: Per-hypothesis Researchers replace generic Phase B. Each hypothesis gets its own narrowly-scoped Researcher. System Tester also spawned (unique to Debug Mode). | Phase B override for targeted investigation |
| **Doc-Code Verification** | Already uses surveyors natively | Uses Checkers instead of Researcher | Pre-existing, no change needed |
| **Init Project** | Already uses surveyors natively | N/A | Pre-existing, no change needed |
| **Re-planning** | May skip Phase A if prior survey data is still valid | Default | Avoid redundant re-survey |

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

**Trivial work** (single-line changes, config/env vars, renames, typo fixes) is always absorbed into the nearest Full or Standard task — never classified as a standalone task.

## Task Granularity Rules

### Sizing Philosophy

Tasks are **vertical feature slices**, not horizontal technical layers. Each task should deliver a recognizable piece of functionality end-to-end.

- **Wrong:** Split by layer — one task for DB schema, another for the API endpoint, another for the frontend component
- **Right:** Split by functionality — "media upload flow" covers schema + endpoint + UI for that feature
- **Heuristic:** "Would a developer do this in one focused sitting?" If yes, it's one task.

### Task Count Guidance

Target task counts by plan complexity:

| Complexity | Task Count | Example |
|-----------|-----------|---------|
| Simple | 1–3 | Add a settings page, fix a workflow bug |
| Medium | 4–6 | User auth system, payment integration |
| Complex | 6–10 | Multi-tenant support, real-time collaboration |

**Default to the low end.** Start with the minimum number of tasks and only add more when a task is clearly too large for a single agent. Most plans should have 1-3 tasks. A 1-task plan for a focused change is ideal, not a sign of under-planning. Never pad task count with config, setup, or doc tasks — these are absorbed, not standalone.

Over 10 tasks is a red flag — the plan is likely sliced too thin or the scope is too large for a single plan.

### Dependency-Aware Merging

**Core rule:** If Task A must complete before Task B can start, and A exists only to set something up for B, **merge A into B**.

**Decision test:** "Does keeping A separate enable real parallelism?" If B is the only task that depends on A, the answer is no — merge them.

**Common merge targets:**
- Schema migration + endpoint that uses it → one task
- Type definitions + component that consumes them → one task
- Env config + feature that reads it → one task

**Exception — keep separate when A enables fan-out:** If A unblocks multiple independent tasks (B, C, D can all start after A), keeping A separate is justified because it enables real parallelism.

### Trivial Task Absorption

**Standalone Trivial tasks are not allowed.** Every Trivial-classified item must be absorbed into the nearest Standard or Full task as a step in its description. This is a hard constraint, not guidance.

**Rules:**

1. **Documentation updates are NOT tasks.** They belong in the plan's "Documentation Changes" section. Never create a task whose primary purpose is updating docs.
2. **Config/env changes are NOT tasks.** Adding env vars, feature flags, or deployment config is setup work — include it as a step in the task that needs the config.
3. **Renames, copy changes, and one-liners are NOT tasks.** Absorb them into the task that motivates the change.

**The only exception:** A Trivial item that enables fan-out to 3+ independent tasks may remain standalone (same exception as dependency-aware merging).

**Absorption target selection:** Attach the Trivial work to the task that most directly depends on it. If multiple tasks depend on it and it doesn't enable fan-out, attach it to the first task in execution order.

### Size Examples

- **Too large**: "Implement the authentication system" — this is a plan, not a task
- **Too small**: "Add JWT_SECRET to env config" — this is setup that belongs inside a real task, not a standalone task
- **Right size**: "Build login flow with JWT middleware, token validation, refresh logic, and auth endpoint" — clear scope, vertical slice, completable by one agent, testable independently

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
- A vertical slice delivering recognizable progress, not a horizontal layer

## Plan Format

Use the loaded plan template (`templates/plan.md`) as the base structure. The plan README.md must include:

1. **Objective** — What this plan accomplishes
2. **Context** — Links to architecture docs, requirements, RFCs
3. **Scope** — In scope / out of scope boundaries
4. **Success Criteria** — Checkboxes for plan-level acceptance
5. **Task List** — Every task with classification, description, files, success criteria, dependencies
6. **Documentation Changes** — Structured changelog of docs updated during planning, plus any remaining doc updates for execution
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
6. **Validate — HARD GATE (do not skip):**
   a. Scan the task list for any task classified as Trivial. If found, STOP and absorb it into the nearest Full/Standard task before proceeding.
   b. Scan for any task whose sole purpose is documentation, config/env changes, or renames. If found, STOP and absorb it.
   c. Apply dependency-aware merging: for each A→B chain where A is pure setup, merge into B.
   d. Count remaining tasks. If count exceeds the low end of the complexity range, justify each task — if you can't articulate why it needs its own pipeline, merge it.
   e. Every remaining task must be Full or Standard.
7. **Write plan to `documentation/plans/{name}/README.md`** via the Write tool — this is the canonical copy that `/uc:plan-execution` reads from. The plan is on disk before the user reviews it.
8. **Present a concise summary in chat** — NOT the full plan. Include: plan name, objective, task count with Full/Standard breakdown only (never report Trivial counts — Trivial tasks should not exist), and the file path. The user can read the full plan from the file.
9. **Ask for approval via AskUserQuestion** — Options: "Approve" / "Reject with feedback" / "Partially reject (specify changes)"

**Approval gate rules — strictly enforce:**
- Only an explicit "Approve" selection counts as approval. Do NOT infer approval from empty, blank, ambiguous, or non-committal responses.
- If the user selects "Other" with empty or unclear text, re-ask the question. Say: "I need an explicit approval, rejection, or feedback before proceeding."
- Never skip or auto-approve this step. The plan is not approved until the user explicitly says so.

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

**Merge analysis:** An initial draft might produce: Task A "Update env config with JWT_SECRET" → Task 1 depends on it, Task B "Add login endpoint" → depends on Task 1. Applying dependency-aware merging: env config is pure setup with no fan-out benefit — absorb it into Task 1. Login and registration are the same auth surface — combine into one vertical slice. Result: 3 tasks → 2 tasks.

**Plan Enhancer produces:**

```
documentation/plans/user-auth/
├── README.md
├── shared/
└── tasks/
```

**README.md includes tasks like:**

```markdown
### Task 1: Build JWT auth middleware with token validation
- **Classification:** Full
- **Description:** Add JWT_SECRET and TOKEN_EXPIRY to environment config. Create Express middleware that validates JWT tokens from HTTP-only cookies, extracts user claims, and attaches to request context. Includes token refresh logic.
- **Files:** .env.example (modify), src/config.ts (modify), src/middleware/auth.ts (create), src/types/auth.ts (create), src/app.ts (modify)
- **Success criteria:** Env vars documented and loaded; middleware validates tokens, rejects expired tokens, refreshes near-expiry tokens, attaches user to req.user
- **Dependencies:** None

### Task 2: Build login and registration endpoints
- **Classification:** Standard
- **Description:** Create POST /api/auth/login, POST /api/auth/register, and POST /api/auth/logout endpoints. Login validates credentials and returns JWT in HTTP-only cookie. Register creates user with hashed password. Logout clears the token cookie.
- **Files:** src/routes/auth.ts (create), src/services/auth.ts (create), src/models/user.ts (create)
- **Success criteria:** Login returns 200 with token cookie on valid creds, 401 on invalid; register creates user and returns 201; logout clears cookie and returns 200
- **Dependencies:** Task 1
```

> **Why 2 tasks, not 3+:** Env config was pure setup for Task 1 with no independent value — merged in. Login, registration, and logout are the same auth surface area — one vertical slice, not three horizontal endpoints.

> **Note on doc updates:** If this plan required updating API documentation, that would go in the Documentation Changes table above — not as a separate Task 3. Documentation updates are never standalone tasks.
