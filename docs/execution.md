# Execution

The execution engine that runs any plan through a dynamically composed agent team. This is the single source of truth for how plans are executed.

For architecture context, see [Architecture](architecture.md). For component reference, see [Components](components.md).

## Overview

**Execute Plan** reads the entire plan directory (`documentation/plans/{name}/`) and runs it through a dynamically composed agent team. On trigger, the Lead reads ALL files in the plan directory — README.md, any existing `research/` files, `shared-context.md` (if resuming), checkpoint files — to build complete context before spawning teammates.

**Prerequisites:**
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` in settings.json
- tmux installed
- Plan exists in `documentation/plans/{name}/README.md`

Agent teams only (per [decision D1](decisions.md) and D13).

## The Coordination Model

Four mechanisms work together:

| Mechanism | Purpose |
|-----------|---------|
| **Role-Separated Task Lists** | Lead creates 4 task groups (research, impl, review, test). Promotes tasks between lists as work completes. Each role only sees their own list. |
| **Shared Memory File** (`plans/{name}/shared-context.md`) | Persistent cross-cutting knowledge: patterns discovered, integration points, gotchas, runtime decisions. Survives session death. |
| **Plan README.md** | Source of truth for what needs to be done, task ordering, success criteria. |
| **Per-Task Research Files** (`plans/{name}/research/task-N.md`) | Deep per-task findings from Researcher. Read by Executor before implementing. |

## Context Bridge — How Teammates Get Context

Teammates do NOT inherit the Lead's conversation history. They start with a blank context window + project CLAUDE.md (auto-inherited). The Lead bridges the gap by including these paths in every teammate's spawn prompt:

| Teammate | Receives in Spawn Prompt |
|----------|-------------------------|
| **All teammates** | Plan README.md path, shared-context.md path, architecture docs path (`documentation/technology/architecture/`) |
| **Researcher** | + research task list claiming instructions |
| **Executor** | + per-task research file path, impl task list claiming instructions, coding standards path (`documentation/technology/standards/`) |
| **Code Reviewer** | + review task list claiming instructions, coding standards path, architecture docs path |
| **Tester** | + success criteria from plan, test task list claiming instructions, SendMessage target (Lead) for failure feedback |

Each teammate is told to re-read `shared-context.md` before starting each new task claim — other teammates may have updated it.

## Dynamic Team Composition

The Lead decides team composition based on plan characteristics:

| Plan Size | Team Composition |
|-----------|-----------------|
| Small (1-5 tasks), research done during planning | 1 Executor + 1 Reviewer + 1 Tester |
| Medium (5-10 tasks), some research needed | 1 Researcher + 1-2 Executors + 1 Reviewer + 1 Tester |
| Large (10+ tasks), multi-subsystem | 1 Researcher + 2-3 Executors + 1 Reviewer + 1 Tester |
| Documentation-only | 1-2 Executors + 1 Reviewer (no tester) |

Max ~5-6 concurrent teammates. Lead always reserves the right to override.

Model selection per role:

| Role | Model | Rationale |
|------|-------|-----------|
| Researcher | sonnet | Needs reasoning for context gathering, not raw power |
| Executor | sonnet | Implementation needs good coding, sonnet sufficient |
| Code Reviewer | sonnet | Pattern matching, quality analysis |
| Tester | sonnet | Per-task test execution + final full test suite gate |

## Role-Separated Task Lists

The Lead manages **four** separate task lists using Claude Code's TaskCreate/TaskList/TaskUpdate:

```
Research Tasks:       [pending] -> [in_progress] -> [completed]
                            | Lead promotes
Implementation Tasks: [pending] -> [in_progress] -> [completed]
                            | Lead promotes
Review Tasks:         [pending] -> [in_progress] -> [completed/failed]
                            | Lead promotes (if passed)
Testing Tasks:        [pending] -> [in_progress] -> [completed/failed]
```

**How it flows:**
- Lead creates all tasks in the research list initially (or impl list if research already exists from planning)
- Researcher self-claims from research list -> completes -> Lead promotes to impl list
- Executor self-claims from impl list -> completes -> Lead promotes to review list
- Code Reviewer self-claims from review list -> passes -> Lead promotes to test list; fails -> Lead re-queues to impl list with feedback
- Tester self-claims from test list -> passes -> done; fails -> Lead re-queues to impl list with feedback

**Why 4 lists instead of task states:** Claude Code's built-in task states are only `pending/in_progress/completed`. Rather than fighting the system with metadata hacks, we use the built-in states cleanly within each role's list. The Lead handles promotion between lists.

## The Execute Plan Team Structure

```
Lead (main session -- user interacts here)
|
+-- Creates 4 role-separated task lists from plan README.md
+-- Creates shared-context.md with initial context
+-- Decides team composition based on plan size/complexity
|
+-- Researcher teammate (0-1)
|   Model: sonnet | Tools: Read, Grep, Glob, WebFetch, mcp__ref
|   - Reads plan README.md + shared-context.md at start
|   - Self-claims from research task list
|   - Writes per-task findings to plans/NAME/research/task-N.md
|   - Writes cross-cutting discoveries to shared-context.md
|   - Goes idle when research list empty -> Lead notified
|
+-- Executor teammate(s) (1-3)
|   Model: sonnet | Tools: Read, Write, Edit, Glob, Grep, Bash
|   - Reads plan README.md + shared-context.md + per-task research file
|   - Self-claims from implementation task list
|   - Implements code conforming to plan + architecture docs
|   - Writes integration notes to shared-context.md (append-only)
|   - Goes idle when impl list empty -> Lead notified
|
+-- Code Reviewer teammate (0-1)
|   Model: sonnet | Tools: Read, Glob, Grep
|   - Reads plan README.md + shared-context.md + coding standards
|   - Self-claims from review task list
|   - Checks: code quality, pattern compliance, duplication, architecture conformance
|   - PASS: marks complete -> Lead promotes to test list
|   - FAIL: marks failed with specific feedback -> Lead re-queues to impl list
|   - Read-only -- cannot modify code
|   - Goes idle when review list empty -> Lead notified
|
+-- Tester teammate (0-1)
    Model: sonnet | Tools: Read, Glob, Grep, Bash
    - Reads plan README.md + shared-context.md + success criteria
    - Self-claims from testing task list
    - Per-task: runs relevant tests, checks success criteria from plan
    - PASS: marks complete | FAIL: SendMessage feedback to Lead -> re-queue
    - Read-only -- cannot modify source code
    - Goes idle when test list empty -> Lead notified
    - FINAL GATE: when all tasks done, Lead asks Tester to run full test suite
      (not per-task -- the entire suite as regression check)
    - Reports final gate results to Lead before team shutdown
```

## Shared Memory Pattern

`plans/{name}/shared-context.md` — the persistent shared memory between all teammates:

**What goes in:**
- Cross-cutting architecture decisions made during execution
- Dependency info between tasks ("Task 3 created UserService -- Task 5 should import from `src/services/user.ts`")
- Gotchas discovered ("The API returns snake_case, not camelCase as docs say")
- Integration points between teammates' work
- Code Review findings that affect multiple tasks (pattern violations)

**What does NOT go in:**
- Per-task research (goes to `plans/{name}/research/task-N.md`)
- Task status (managed by task lists)
- Full code snippets (reference file paths instead)

**Write rules (avoid contention):**
- Each role appends to its own labeled section: `## Researcher Findings`, `## Executor Notes`, `## Review Findings`
- Never edit another role's section — append-only
- Lead writes to `## Lead Decisions`

## Lead Intervention Points

Lead does NOT micromanage. Intervenes only at:

1. **Team creation** — decides roster, writes spawn prompts, creates task lists + shared-context.md
2. **Task promotion** — monitors all 4 lists, promotes completed tasks to the next role's list
3. **Failure handling** — receives failure feedback from Reviewer/Tester, re-queues to impl list with context (max 2 retries per task, then escalates to user)
4. **Checkpoint** — periodic state save (see below)
5. **Completion synthesis** — collects results, produces summary
6. **Team shutdown** — sends shutdown requests, cleans up shared resources

Between these points, teammates self-coordinate via their role-specific task lists.

## Checkpoint Architecture

Progress saved to plan directory at three levels:

| What | Where | When |
|------|-------|------|
| Task list snapshots (all 4 role-lists) | `plans/{name}/checkpoint-{timestamp}.md` | Every N completed tasks (default 3), on TeammateIdle, on user request, on session end |
| Cross-cutting knowledge | `plans/{name}/shared-context.md` | Written continuously by teammates (already on disk) |
| Per-task research | `plans/{name}/research/task-N.md` | Written by Researcher per task (already on disk) |

**Checkpoint file contains:**
- All 4 task list states (research/impl/review/test: pending/in-progress/completed/failed)
- Active teammates and their current assignments
- Decisions made during execution
- Blockers encountered
- Files modified so far

**On resume:** Lead reads plan README.md + latest checkpoint + shared-context.md -> knows exactly what's done vs pending -> rebuilds team -> skips completed work.

## Error Recovery

| Failure Class | Detection | Recovery |
|---------------|-----------|---------|
| **Task failure** (review/test fails) | Reviewer or Tester feedback to Lead | Lead re-queues to impl list with feedback (max 2 retries). After 2 failures: Lead escalates to user with full context. |
| **Teammate crash** (session crash, context overflow) | TeammateIdle fires unexpectedly / Lead notices stalled progress | Lead re-queues their in-progress task to previous state. Spawns replacement teammate with same role prompt + "continue from shared-context.md". |
| **Session death** (everything dies) | User reruns `/uc:execute {plan-name}` | Lead finds latest checkpoint, shows resume prompt. Team rebuilt from scratch, but task states + shared-context.md + research files preserve all progress. |

## Hook Integration

| Hook | Execution Layer Behavior |
|------|------------------------|
| **TeammateIdle** | When a teammate goes idle, checks if their role-list still has claimable tasks. If tasks remain, notifies Lead that teammate stopped prematurely. For Code Reviewer: also checks that all reviewed tasks have written feedback. |
| **TaskCompleted** | Validates task meets success criteria from plan README.md. If criteria unmet, blocks completion and provides feedback. |
| **PreToolUse (Write/Edit)** | Checks if file changes align with architecture docs. Unchanged from planning layer. |
| **Stop** | Triggers checkpoint save if execution is in progress. Writes final checkpoint before session closes. |

## Workflow: Step-by-Step

```
User: /uc:execute user-auth

PHASE 1: SETUP (Lead actions)
  a. Read ENTIRE plan directory:
     - documentation/plans/user-auth/README.md (plan + tasks)
     - documentation/plans/user-auth/research/*.md (existing)
     - documentation/plans/user-auth/shared-context.md (if resuming)
     - documentation/plans/user-auth/checkpoint-*.md (if any)
     Lead now has full picture of plan state.
  b. Check for checkpoint:
     - If checkpoint exists -> show resume prompt
     - If resuming -> skip completed work based on checkpoint
  c. Classify tasks by research status:
     - Tasks with existing research/*.md -> start in impl list
     - Tasks without research -> start in research list
  d. Decide team composition (sizing heuristic)
  e. Create 4 role-separated task lists
  f. Create/load shared-context.md with initial context
  g. Spawn teammates with role-specific prompts:
     - Each prompt includes: role instructions, file paths,
       task claiming rules, communication rules
     - Model selection per role

PHASE 2: PARALLEL WORK (self-coordinating)

  Researcher:
    claim research task -> read codebase + docs ->
    write research/task-N.md -> update shared-context.md ->
    mark complete -> claim next (loop until idle)

  Executor(s):
    claim impl task -> read research +      Lead monitors:
    shared-context -> implement code ->     - Promotes tasks
    append integration notes to               between lists
    shared-context -> mark complete ->      - Handles fails
    claim next (loop until idle)            - Checkpoints

  Code Reviewer:
    claim review task -> read standards + shared-context ->
    check quality, patterns, duplication ->
    PASS: mark complete | FAIL: mark failed with feedback ->
    claim next (loop until idle)

  Tester:
    claim test task -> read success criteria ->
    run tests -> PASS: mark complete |
    FAIL: SendMessage feedback to Lead ->
    claim next (loop until idle)

PHASE 3: CHECKPOINT (triggered periodically by Lead)
  Triggers: every 3 completed tasks, TeammateIdle,
            user /uc:checkpoint, Stop hook (session ending)
  Saves: 4 task list states, checkpoint file, decisions
  shared-context.md + research files already on disk

PHASE 4: FAILURE HANDLING (Lead manages)
  Review failure: Lead re-queues to impl list + feedback
  Test failure: Lead re-queues to impl list + feedback
  Max 2 retries per task -> escalate to user
  Teammate crash: re-queue task, spawn replacement
  Session death: user reruns /uc:execute, reads checkpoint

PHASE 5: COMPLETION (Lead actions)
  a. All tasks reach done across all 4 lists
  b. Lead asks Tester to run full test suite (final gate)
     - Not per-task -- entire suite as regression check
     - If fail: Lead decides whether to re-queue or report
  c. Produce summary: tasks, files changed, decisions, tests
  d. Shutdown: request each teammate to shut down
     -> teammates acknowledge and exit
     -> shared resources (plan dir) kept for reference
  e. Present summary to user
```
