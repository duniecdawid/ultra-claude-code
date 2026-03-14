---
description: Standardizes plan output for all planning modes. Writes plan directly to documentation/plans/{name}/README.md with embedded task list. Auto-loaded by planning mode skills via context field.
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

You provide plan structuring instructions that are loaded into context by planning mode skills (Feature Mode, Debug Mode, etc.). You govern how the plan is structured, task granularity, where the plan is written, and how it is presented for approval.

## Responsibility Split

| Responsibility | Owner |
|---------------|-------|
| Driving the planning process | Planning mode skill |
| Gathering context (research, architecture) | Planning mode skill |
| Deciding plan scope and content | Planning mode skill + user |
| **Plan format and template** | **Plan Enhancer** |
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

Surveyors return structured overviews (file lists, components, data structures, patterns, cross-references). This gives the Lead a structural map of the relevant codebase and documentation without the cost of spawning additional agents.

### Phase B — Targeted Deep Research (Conditional)

Two tools are available for filling gaps identified by surveyors:

1. **Codebase gaps** — Spawn an **Explore agent** (`Explore` subagent type) when Phase A reveals gaps requiring deep codebase analysis:
   - **Complex cross-component interactions**: Structural map shows the work touches 3+ components with non-obvious interaction patterns
   - **Undocumented patterns**: Code Surveyor found patterns or conventions with no corresponding documentation from Doc Surveyor
   - **Doc-code conflicts**: Doc Surveyor and Code Surveyor returned contradictory information about the same component

2. **External library gaps** — Use `/uc:tech-research` (Ref.tools) or the shared Tech Knowledge agent when Phase A reveals:
   - **External integrations**: Surveyors found references to external services, APIs, or dependencies that need documentation beyond structural overview

If none of these triggers fire, proceed to the next phase with surveyor output + direct reading only. Do not spawn an Explore agent "just in case."

When Phase B is triggered, scope the Explore agent tightly to the identified gaps — not a broad re-survey of what the surveyors already covered. Reference specific findings from Phase A in the Explore agent prompt.

### Mode Override Table

| Mode | Phase A | Phase B | Notes |
|------|---------|---------|-------|
| **Feature Mode** | Default (Code + Doc Surveyor) | Conditional — Explore agents for codebase gaps, /tech-research for external library gaps | Standard two-phase |
| **Debug Mode** | Default, scoped to symptom-related code paths | **Override**: Per-hypothesis Explore agents replace generic Phase B. Each hypothesis gets its own narrowly-scoped Explore agent. System Tester also spawned (unique to Debug Mode). | Phase B override for targeted investigation |
| **Doc-Code Verification** | Already uses surveyors natively | Uses Checkers instead of Explore agents | Pre-existing, no change needed |
| **Init Project** | Already uses surveyors natively | N/A | Pre-existing, no change needed |
| **Re-planning** | May skip Phase A if prior survey data is still valid | Default | Avoid redundant re-survey |

## What You Do

1. **Standardize format** — All plans use the loaded plan template with embedded task list. The template includes an `Execute: /uc:plan-execution {NNN}` header so the user knows how to run it by number.
2. **Ensure granularity** — Tasks must be right-sized for agentic execution. Err heavily toward fewer, larger tasks.
3. **Write plan to disk** — Scaffold the plan directory and write `documentation/plans/{NNN}-{name}/README.md` before presenting for approval

## Plan Directory Structure

When a plan is created, scaffold this structure:

```
documentation/plans/{NNN}-{plan-name}/
├── README.md          # The plan document (task list embedded)
├── shared/            # Lead-level shared notes (created empty, used during execution)
└── tasks/             # Per-task pipeline artifacts (created empty, used during execution)
```

Create the directories immediately. The `shared/` and `tasks/` directories start empty — they are populated during execution.

## Plan Naming

Derive the plan name and number:

1. **Semantic name** — from the user's feature description or `$ARGUMENTS`:
   - Lowercase, hyphenated: "Add user authentication" -> `user-auth`
   - Short but descriptive: 2-4 words max
   - No special characters

2. **Sequential number** — scan `documentation/plans/` for directories matching `[0-9][0-9][0-9]-*`:
   - Extract the highest number, increment by 1, zero-pad to 3 digits
   - If no numbered plans exist, start at `001`
   - Example: existing `001-user-auth`, `002-api-keys` → next is `003`

3. **Final folder name**: `{NNN}-{semantic-name}` (e.g., `001-user-auth`)

## Task Pipeline

Every task gets the full pipeline team: **Executor + Reviewer + Tester** (+ shared Tech Knowledge agent for external library documentation). There is no classification step — all tasks receive the same treatment. The executor explores the codebase directly and queries the knowledge agent for external library docs.

**Trivial work** (single-line changes, config/env vars, renames, typo fixes) is always absorbed into the nearest task — never a standalone task.

## Task Granularity Rules

### Sizing Philosophy

Tasks deliver **end-to-end testable user value**, not technical artifacts. The core heuristic: **"Can the tester verify this task by putting themselves in the user's shoes and testing the full flow from input to output?"** If yes — right-sized. If the tester can only verify a technical artifact (a migration exists, a repository method works, a type is defined) — too small.

Each task should cut across the full stack (DB → backend → frontend/API) so that when it's done, a tester can simulate real user behavior and confirm the feature works end-to-end. Err on the side of **too few, too large** tasks rather than too many small ones.

- **Wrong:** Split by layer — one task for DB schema, another for the entity/repo, another for the service, another for the controller, another for tests. These produce tasks a tester can only verify by checking technical artifacts ("the column exists", "the method is defined"), not user behavior.
- **Wrong:** Split by technical concern — "Add migration", "Update repository", "Add service method", "Clean up controller", "Add test coverage". A tester cannot verify any of these from the user's perspective — they're steps within a single task.
- **Right:** Split by user-facing functionality — "Implement admin overload with schema migration, entity updates, service logic, and API endpoints" delivers a complete flow a tester can verify: "as a user, when I create an admin overload, the system stores it and returns it via the API."
- **Heuristic:** "Can a tester verify this by simulating user behavior — making requests, checking responses, observing system behavior?" If the tester can only check technical artifacts (schema exists, function defined, type exported), the task is too small.
- **Anti-pattern detector:** If your tasks form a sequential chain where each depends on the previous one, they are almost certainly too granular — and none of them are independently testable from a user's perspective. A chain of 3+ sequential tasks should usually be merged into 1-2 tasks.

### Task Count Guidance

Target task counts by plan complexity:

| Complexity | Task Count | Example |
|-----------|-----------|---------|
| Simple | 1 | Add a settings page, fix a workflow bug, add a new API endpoint with tests |
| Medium | 2–3 | User auth system, payment integration |
| Complex | 3–5 | Multi-tenant support, real-time collaboration |

**Default to 1 task.** A single-task plan is the ideal outcome for most work. Only split into multiple tasks when the work genuinely has independent, parallelizable pieces or is too large for one agent to hold in context. Sequential dependency chains are a strong signal that tasks should be merged.

Over 5 tasks is a red flag — the plan is almost certainly sliced too thin. Over 3 tasks should be rare and justified.

### Dependency-Aware Merging

**Core rule:** If tasks form a sequential dependency chain, **merge them into one task**. Sequential tasks that each depend on the previous one gain nothing from being separate — they can't run in parallel and they add overhead.

**Decision test:** "Can these tasks run in parallel?" If no, merge them. Period.

**Common merge targets:**
- Schema migration + entity + repository + service + controller → one task (this is a single feature, not five tasks)
- Type definitions + component that consumes them → one task
- Env config + feature that reads it → one task
- Any A→B→C chain → one task

**Exception — keep separate only when tasks enable real parallelism:** If A unblocks multiple independent tasks (B, C, D can all start after A), keeping A separate is justified. But B, C, D themselves must each be substantial.

### Trivial Task Absorption

**Standalone Trivial tasks are not allowed.** Every Trivial item must be absorbed into the nearest task as a step in its description. This is a hard constraint, not guidance.

**Rules:**

1. **Documentation updates are NOT tasks.** They belong in the plan's "Documentation Changes" section. Never create a task whose primary purpose is updating docs.
2. **Config/env changes are NOT tasks.** Adding env vars, feature flags, or deployment config is setup work — include it as a step in the task that needs the config.
3. **Renames, copy changes, and one-liners are NOT tasks.** Absorb them into the task that motivates the change.

**The only exception:** A Trivial item that enables fan-out to 3+ independent tasks may remain standalone (same exception as dependency-aware merging).

**Absorption target selection:** Attach the Trivial work to the task that most directly depends on it. If multiple tasks depend on it and it doesn't enable fan-out, attach it to the first task in execution order.

### Size Examples

- **Too large**: "Implement the entire multi-tenant architecture with data isolation, tenant management, billing integration, and admin dashboard" — this is a plan, not a task
- **Too small**: "Add JWT_SECRET to env config" — a tester can only verify the env var exists, not any user behavior
- **Too small**: "Add schema migration for scope column" — a tester can only verify the column exists, not that scoping works end-to-end
- **Too small**: "Update repository to support nullable partner" — a tester can only verify a method signature, not a user-facing flow
- **Too small**: "Clean up controller to remove sentinel UUID" — a tester can only verify code structure, not user behavior
- **Right size**: "Build login flow with JWT middleware, token validation, refresh logic, and auth endpoint" — tester can verify: "as a user, when I submit credentials, I get a token; when I use the token, I access protected resources; when the token expires, I'm rejected"
- **Right size**: "Add partner scoping — migration adds scope column, repository supports filtering by scope, service enforces scope on all queries, API endpoints accept scope parameter, returns scoped results" — tester can verify: "as a user, when I request partners with scope X, I only see partners in that scope"
- **Right size**: "Add admin overload support — schema migration, entity/repository changes, service logic, API endpoints, and controller updates" — tester can verify: "as a user, when I create an admin overload via the API, the system stores it and returns it correctly"

### Granularity Checks

Each task MUST have:
- A clear description of what to build/change
- Expected files to create or modify
- Patterns (architecture/standards files the executor must follow — populated by Standards Review)
- Success criteria (how to verify it's done)
- Dependencies on other tasks (if any)

Each task SHOULD be:
- Completable by a single Executor agent in one pass
- End-to-end testable from a user or system perspective — a tester can verify it by simulating user behavior, not just checking technical artifacts
- Non-overlapping with other tasks (no two tasks modifying the same file for the same reason)
- A cross-functional slice (DB → backend → API/UI) delivering end-to-end user value, not a horizontal layer

## Plan Format

Use the loaded plan template (`templates/plan.md`) as the base structure. The plan README.md must include:

1. **Objective** — What this plan accomplishes
2. **Context** — Links to architecture docs, requirements, RFCs
3. **Tech Stack** — External libraries, frameworks, and services the plan depends on (the shared Tech Knowledge agent loads documentation for these at execution startup)
4. **Scope** — In scope / out of scope boundaries
4. **Success Criteria** — Checkboxes for plan-level acceptance
5. **Task List** — Every task with description, files, success criteria, dependencies
6. **Documentation Changes** — Structured changelog of docs updated during planning, plus any remaining doc updates for execution
7. **Risk Assessment** — Risks with likelihood, impact, mitigation

## Plan Creation Process

1. **Derive plan name and number** from the feature description or `$ARGUMENTS`. Scan `documentation/plans/` for the next sequential number (see Plan Naming above).
2. **Check for existing plan** — if `documentation/plans/*-{name}/` exists (suffix match), read it for revision context
3. **Scaffold plan directory**:
   ```bash
   mkdir -p documentation/plans/{NNN}-{name}/shared documentation/plans/{NNN}-{name}/tasks
   ```
4. **Build the plan** — the planning mode provides the content; you ensure format compliance. Use the loaded plan template including the `Execute: /uc:plan-execution {NNN}` header.
5. **Validate task sizes** — apply granularity rules to every task in the list
6. **Validate — HARD GATE (do not skip):**
   a. Scan for any task whose sole purpose is documentation, config/env changes, renames, or other trivial work. If found, STOP and absorb it into the nearest task.
   b. Scan for sequential dependency chains (A→B→C where each depends on the previous). If found, STOP and merge the chain into one task. Sequential chains gain nothing from being separate.
   c. Count remaining tasks. If count exceeds the low end of the complexity range, justify each task — if you can't articulate why it MUST be separate (i.e., it enables real parallelism), merge it.
   d. For each task, verify the tester can verify it end-to-end from the user's perspective. If a task can only be verified by checking technical artifacts (schema exists, function defined, type exported), it's too small — merge it into the task it supports.
6.5. **Standards Review** — For each task, identify which architecture and standards files apply:
   a. Scan `documentation/technology/architecture/` and `documentation/technology/standards/` for pattern files. Gracefully handle missing or empty directories (skip if not found).
   b. For each task: examine its description, files, and success criteria to determine which specific architecture/standards files are relevant.
   c. Populate the task's `**Patterns:**` field with file paths and optional section hints, e.g.:
      `documentation/technology/standards/error-handling.md` (API Error Responses section), `documentation/technology/architecture/auth.md`
      If no patterns apply: `None identified`
   d. If a task requires a pattern that isn't documented, draft the missing doc and flag it with ⚠️ in the summary.
   e. Present a Standards Review summary in chat before approval:
      ```
      Standards Review:
      - Task 1 → error-handling.md, auth.md
      - Task 2 → api-conventions.md, database.md
      - ⚠️ Drafted: documentation/technology/standards/api-conventions.md (new — review before approving)
      ```
7. **Write plan to `documentation/plans/{NNN}-{name}/README.md`** via the Write tool — this is the canonical copy that `/uc:plan-execution` reads from. The plan is on disk before the user reviews it.
8. **Present a concise summary in chat** — NOT the full plan. Include: plan number, plan name, objective, task count, and the file path. The user can read the full plan from the file.
9. **Ask for approval via AskUserQuestion** — Options: "Approve" / "Reject with feedback" / "Partially reject (specify changes)"

**Approval gate rules — strictly enforce:**
- Only an explicit "Approve" selection counts as approval. Do NOT infer approval from empty, blank, ambiguous, or non-committal responses.
- If the user selects "Other" with empty or unclear text, re-ask the question. Say: "I need an explicit approval, rejection, or feedback before proceeding."
- Never skip or auto-approve this step. The plan is not approved until the user explicitly says so.

### Post-Approval — HARD STOP (mandatory — all planning modes follow this)

**CRITICAL: The planning conversation ENDS after these 3 steps. There is no step 4.**

When the user explicitly approves the plan:

1. **Commit plan files** — Stage all plan files (README.md, directories) and commit:
   ```
   git add documentation/plans/{NNN}-{name}/ && git commit -m "plan: {NNN}-{name}"
   ```
2. **Print execution command** — Display this exact message and nothing else after it:
   ```
   Plan committed. To execute, run:
   /clear /uc:plan-execution {NNN}
   ```
   Clearing context before execution gives executor agents maximum working memory. Plans are on disk — nothing is lost.
3. **STOP IMMEDIATELY** — Your job is done. Do NOT:
   - Start executing the plan
   - Spawn any agents or teams
   - Invoke `/uc:plan-execution` or any other skill
   - Write any more code or make any more changes
   - Continue the conversation with implementation work

   The user will start a fresh context and run the execution command themselves. This separation is intentional — execution needs a clean context window, not one filled with planning artifacts.

### Plan Revision (if rejected)

If the user rejects or partially rejects the plan:

1. Read their feedback
2. Edit the existing `documentation/plans/{NNN}-{name}/README.md` using the Edit tool to incorporate changes
3. Re-present the concise summary with changes highlighted
4. Re-ask for approval via AskUserQuestion

Repeat until approved or the user abandons the plan.

## Existing Plan Handling

If a plan directory matching `*-{name}` already exists (revision or re-planning):
- Read the existing `README.md` to understand current state
- Check for checkpoint files — if they exist, this plan has been partially executed
- Warn the user if modifying a plan that has execution history
- Preserve `shared/` and `tasks/` contents — they contain teammate work

## Constraints

- Do NOT execute the plan — that is `/uc:plan-execution`'s job. After approval, commit and print the execution command, then STOP.
- Do NOT create tasks without success criteria
- ALWAYS write the plan to `documentation/plans/{NNN}-{name}/README.md` BEFORE presenting for approval — this ensures the plan is on disk and cannot be lost
- ALWAYS include the `Execute: /uc:plan-execution {NNN}` header in the plan document
- ALWAYS follow the Post-Approval steps after the user approves — commit, print command, stop. No exceptions.

## Example

**Input from Feature Mode:** "Add user authentication with JWT"

**Merge analysis:** An initial draft might produce: Task A "Update env config with JWT_SECRET", Task B "Build JWT middleware", Task C "Add login endpoint", Task D "Add registration endpoint", Task E "Add tests". Applying the sequential chain rule: these all form a dependency chain (A→B→C→D→E) and cannot run in parallel. Auth middleware and auth endpoints are the same feature surface. Result: 5 tasks → 1 task.

**Plan Enhancer produces:**

```
documentation/plans/001-user-auth/
├── README.md
├── shared/
└── tasks/
```

**README.md includes tasks like:**

```markdown
### Task 1: Build JWT authentication system
- **Description:** Add JWT_SECRET and TOKEN_EXPIRY to environment config. Create Express middleware that validates JWT tokens from HTTP-only cookies, extracts user claims, and attaches to request context. Includes token refresh logic. Create POST /api/auth/login, POST /api/auth/register, and POST /api/auth/logout endpoints. Login validates credentials and returns JWT in HTTP-only cookie. Register creates user with hashed password. Logout clears the token cookie.
- **Files:** .env.example (modify), src/config.ts (modify), src/middleware/auth.ts (create), src/types/auth.ts (create), src/app.ts (modify), src/routes/auth.ts (create), src/services/auth.ts (create), src/models/user.ts (create)
- **Patterns:** `documentation/technology/architecture/auth.md`, `documentation/technology/standards/error-handling.md` (API Error Responses section), `documentation/technology/standards/middleware.md`
- **Success criteria:** Env vars documented and loaded; middleware validates tokens, rejects expired tokens, refreshes near-expiry tokens, attaches user to req.user; login returns 200 with token cookie on valid creds, 401 on invalid; register creates user and returns 201; logout clears cookie and returns 200
- **Dependencies:** None
```

> **Why 1 task, not 5:** Env config, middleware, login, registration, and logout form a sequential dependency chain — they cannot run in parallel and they all serve the same feature. One task, one end-to-end testable unit, one pipeline team.

> **Note on doc updates:** If this plan required updating API documentation, that would go in the Documentation Changes table above — not as a separate task. Documentation updates are never standalone tasks.
