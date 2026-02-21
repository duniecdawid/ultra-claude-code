# Execution

The execution engine that runs any plan through a dynamically composed agent team. This is the single source of truth for how plans are executed.

For architecture context, see [Architecture](architecture.md). For component reference, see [Components](components.md).

## Overview

**Plan Execution** reads the entire plan directory (`documentation/plans/{name}/`) and runs it through a dynamically composed agent team. On trigger, the Lead reads ALL files in the plan directory — README.md, any existing `research/` files, `shared/` directory (if resuming), checkpoint files — to build complete context before spawning teammates.

**Prerequisites:**
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` in the plugin's `settings.json` (project-level setting applied by Claude Code when the plugin is active — not a plugin.json field)
- tmux installed
- Plan exists in `documentation/plans/{name}/README.md`

Agent teams only (per [decision D1](decisions.md) and D13).

## The Coordination Model

Four mechanisms work together:

| Mechanism | Purpose |
|-----------|---------|
| **Role-Separated Task Lists** | Lead creates 4 task groups (research, impl, review, test). Promotes tasks between lists as work completes. Each role only sees their own list. |
| **Per-Role Shared Directory** (`plans/{name}/shared/`) | Persistent cross-cutting knowledge split by role. Each role writes only to their own file (`researcher.md`, `executor.md`, `reviewer.md`, `tester.md`, `lead.md`). All teammates read ALL files before each task claim. Survives session death. |
| **Plan README.md** | Source of truth for what needs to be done, task ordering, success criteria. |
| **Per-Task Research Files** (`plans/{name}/research/task-N.md`) | Deep per-task findings from Researcher. Read by Executor before implementing. |

## Context Bridge — How Teammates Get Context

Teammates do NOT inherit the Lead's conversation history. They start with a blank context window + project CLAUDE.md (auto-inherited). The Lead bridges the gap by including these paths in every teammate's spawn prompt:

| Teammate | Receives in Spawn Prompt |
|----------|-------------------------|
| **All teammates** | Plan README.md path, `shared/` directory path, architecture docs path (`documentation/technology/architecture/`) |
| **Researcher** | + research task list claiming instructions |
| **Executor** | + per-task research file path, impl task list claiming instructions, coding standards path (`documentation/technology/standards/`) |
| **Code Reviewer** | + review task list claiming instructions, coding standards path, architecture docs path |
| **Tester** | + success criteria from plan, test task list claiming instructions, SendMessage target (Lead) for failure feedback |

Each teammate is told to re-read ALL files in the `shared/` directory before starting each new task claim — other teammates may have updated their files.

**Example spawn prompt (Executor):**
> "You are an Executor teammate. Read these files for context:
> - Plan: documentation/plans/user-auth/README.md
> - Shared context: documentation/plans/user-auth/shared/ (read ALL files)
> - Architecture: documentation/technology/architecture/
> - Standards: documentation/technology/standards/
> - Your task list: implementation tasks (use TaskList to find pending tasks)
>
> Self-claim tasks by setting them to in_progress. Write integration notes to shared/executor.md (append-only). When your list is empty, write IDLE to shared/executor.md and notify Lead."

## Dynamic Team Composition

The Lead decides team composition based on plan characteristics:

| Plan Size | Team Composition |
|-----------|-----------------|
| Small (1-5 tasks), research done during planning | 1 Executor + 1 Reviewer + 1 Tester |
| Medium (5-10 tasks), some research needed | 1 Researcher + 1-2 Executors + 1 Reviewer + 1 Tester |
| Large (10+ tasks), multi-subsystem | 1 Researcher + 2-3 Executors + 1 Reviewer + 1 Tester |
| Documentation-only | 1-2 Executors + 1 Reviewer (no tester) |

Max ~5-6 concurrent teammates. Lead always reserves the right to override.

Model selection per role (these values correspond to the `model:` field in each agent's `.md` frontmatter — see [Components](components.md#agent-file-format)):

| Role | Model | Rationale |
|------|-------|-----------|
| Researcher | sonnet | Needs reasoning for context gathering, not raw power |
| Executor | opus | Writing production code is the highest-stakes task — quality here reduces downstream review/test failures and retry loops |
| Code Reviewer | sonnet | Pattern matching, quality analysis |
| Tester | sonnet | Per-task test execution + final full test suite gate |

> **Note:** Agent model and tools are declared in each agent's `.md` frontmatter. Spawn prompts from the Lead provide additional runtime context (plan paths, task list instructions, shared directory) on top of the base agent definition.

### Cost Awareness

Before spawning teammates, Lead estimates token cost and presents to user:

| Team Size | Estimated Cost |
|-----------|---------------|
| Minimal (3 teammates) | ~600K tokens |
| Medium (4 teammates) | ~800K tokens |
| Full (5-6 teammates) | ~1M-1.2M tokens |

Lead shows: "This plan has N tasks. Recommended team: [composition]. Estimated ~Xk tokens. Proceed?"
User confirms before any teammates are spawned.

### Required Permissions

Teammates inherit Lead's permission mode. For unattended execution, pre-approve in settings:

- **Bash**: test runners, build commands, linters
- **Write/Edit**: source files, test files, documentation
- **Read/Glob/Grep**: always allowed (read-only)

Tester and Researcher are read-only for source code — they should NOT have Write/Edit on `src/`.
Code Reviewer is fully read-only.

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

**Self-claiming:** A teammate calls TaskList to find `pending` tasks in their role's list, picks the first available task, and calls TaskUpdate to set it to `in_progress` with themselves as owner. No coordination with Lead needed — the task list state is the lock.

**Why 4 lists instead of task states:** Claude Code's built-in task states are only `pending/in_progress/completed`. Rather than fighting the system with metadata hacks, we use the built-in states cleanly within each role's list. The Lead handles promotion between lists.

## Task Classification

Lead classifies each task before creating task lists to avoid 4-stage overhead for simple changes:

| Classification | Criteria | Pipeline | Example |
|----------------|----------|----------|---------|
| **Full** | Multi-file, architectural, complex logic | Research -> Implementation -> Review -> Test | Add new API endpoint with auth middleware, DB migration, tests |
| **Standard** | Single-component, clear requirements | Implementation -> Review -> Test | Add validation to existing form component |
| **Trivial** | Config change, rename, one-liner | Implementation -> Test | Rename env variable, fix typo in config |

Lead sets classification per task when creating lists. Tasks start in the appropriate first stage. A one-line config change skips research and review; a multi-file architectural change goes through all four stages.

## The Plan Execution Team Structure

```
Lead (main session -- user interacts here)
|
+-- Creates 4 role-separated task lists from plan README.md
+-- Creates shared/ directory with per-role files and initial context in lead.md
+-- Decides team composition based on plan size/complexity
|
+-- Researcher teammate (0-1)
|   Model: sonnet | Tools: Read, Grep, Glob, WebFetch, mcp__ref
|   - Reads plan README.md + all files in shared/ at start
|   - Self-claims from research task list
|   - Writes per-task findings to plans/NAME/research/task-N.md
|   - Writes cross-cutting discoveries to shared/researcher.md (append-only)
|   - When list empty: writes IDLE to shared/researcher.md, notifies Lead
|
+-- Executor teammate(s) (1-3)
|   Model: opus | Tools: Read, Write, Edit, Glob, Grep, Bash
|   - Re-reads all files in shared/ + per-task research file before each task
|   - Self-claims from implementation task list
|   - Implements code conforming to plan + architecture docs
|   - Writes integration notes to shared/executor.md (append-only)
|   - When list empty: writes IDLE to shared/executor.md, notifies Lead
|
+-- Code Reviewer teammate (0-1)
|   Model: sonnet | Tools: Read, Glob, Grep
|   - Re-reads all files in shared/ + coding standards before each task
|   - Self-claims from review task list
|   - Checks: code quality, pattern compliance, duplication, architecture conformance
|   - Pass/fail criteria sourced from `documentation/technology/standards/`. Failures include specific file:line references and actionable feedback for Executor.
|   - PASS: marks complete -> Lead promotes to test list
|   - FAIL: marks failed with specific feedback -> Lead re-queues to impl list
|   - Read-only -- cannot modify code
|   - When list empty: writes IDLE to shared/reviewer.md, notifies Lead
|
+-- Tester teammate (0-1)
    Model: sonnet | Tools: Read, Glob, Grep, Bash
    - Re-reads all files in shared/ + success criteria before each task
    - Self-claims from testing task list
    - Per-task: runs relevant tests, checks success criteria from plan
    - PASS: marks complete | FAIL: SendMessage feedback to Lead -> re-queue
    - Read-only -- cannot modify source code
    - When list empty: writes IDLE to shared/tester.md, notifies Lead
    - FINAL GATE: when all tasks done, Lead asks Tester to run full test suite
      (not per-task -- the entire suite as regression check)
    - Reports final gate results to Lead before team shutdown
```

## Shared Memory Pattern

`plans/{name}/shared/` — a directory of per-role files forming persistent shared memory between all teammates:

```
plans/{name}/shared/
  researcher.md      # Researcher writes here
  executor.md        # Executor(s) write here
  reviewer.md        # Code Reviewer writes here
  tester.md          # Tester writes here
  lead.md            # Lead writes here
```

**Read rule:** All teammates read ALL files in `shared/` before each task claim.
**Write rule:** Each role writes ONLY to their own file. Append-only. No teammate ever edits another role's file.

**What goes in per-role files:**
- Cross-cutting architecture decisions made during execution
- Dependency info between tasks ("Task 3 created UserService -- Task 5 should import from `src/services/user.ts`")
- Gotchas discovered ("The API returns snake_case, not camelCase as docs say")
- Integration points between teammates' work
- Code Review findings that affect multiple tasks (pattern violations)
- IDLE status when a teammate's task list is empty

**What does NOT go in:**
- Per-task research (goes to `plans/{name}/research/task-N.md`)
- Task status (managed by task lists)
- Full code snippets (reference file paths instead)

**Why per-role files instead of one shared file:** Concurrent writes to a single `shared-context.md` will clobber each other. Per-role files eliminate write conflicts — each teammate owns exactly one file.

## Lead Intervention Points

Lead does NOT micromanage. Intervenes only at:

1. **Team creation** — decides roster, writes spawn prompts, creates task lists + `shared/` directory with initial `lead.md`
2. **Task promotion** — monitors all 4 lists, promotes completed tasks to the next role's list
3. **Failure handling** — receives failure feedback from Reviewer/Tester, re-queues to impl list with context (max 2 retries per task, then escalates to user)
4. **Checkpoint** — periodic state save (see below)
5. **Plan-invalidating discovery** — if Researcher or Executor discovers something that fundamentally changes the plan (e.g., an API doesn't exist, a dependency is incompatible), they SendMessage Lead immediately. Lead pauses promotion, evaluates impact, and either adjusts tasks or escalates to user.
6. **Completion synthesis** — collects results, produces summary
7. **Team shutdown** — sends shutdown requests, cleans up shared resources

**Lead behavior:** Acts as a project manager — minimal intervention, data-driven decisions, escalates to user when uncertain. Spawn prompts are direct, structured, and context-rich. Does not micromanage task implementation; trusts teammates to self-coordinate within their role's list.

Between these points, teammates self-coordinate via their role-specific task lists.

## Checkpoint Architecture

Progress saved to plan directory at three levels:

| What | Where | When |
|------|-------|------|
| Task list snapshots (all 4 role-lists) | `plans/{name}/checkpoint-{timestamp}.md` | Every N completed tasks (default 3), on teammate idle, on user request, on session end |
| Cross-cutting knowledge | `plans/{name}/shared/*.md` | Written continuously by teammates to per-role files (already on disk) |
| Per-task research | `plans/{name}/research/task-N.md` | Written by Researcher per task (already on disk) |

**Checkpoint file contains:**
- All 4 task list states (research/impl/review/test: pending/in-progress/completed/failed)
- Active teammates and their current assignments
- Decisions made during execution
- Blockers encountered
- Files modified so far

**On resume:** Lead reads plan README.md + latest checkpoint + all files in `shared/` -> knows exactly what's done vs pending -> rebuilds team -> skips completed work.

## Error Recovery

| Failure Class | Detection | Recovery |
|---------------|-----------|---------|
| **Task failure** (review/test fails) | Reviewer or Tester feedback to Lead | Lead re-queues to impl list with feedback (max 2 retries). After 2 failures: Lead escalates to user with full context. |
| **Teammate crash** (session crash, context overflow) | Lead detects stalled progress via periodic polling of task lists and shared files | Lead re-queues their in-progress task to previous state. Spawns replacement teammate with same role prompt + "continue from shared/ directory". |
| **Session death** (everything dies) | User reruns `/uc:plan-execution {plan-name}` | Lead finds latest checkpoint, shows resume prompt. Team rebuilt from scratch, but task states + `shared/` directory + research files preserve all progress. |

## Mid-Execution Plan Changes

When a discovery invalidates part of the plan:

1. **Teammate sends urgent message to Lead** with evidence of the invalidation
2. **Lead pauses task promotion** — no new tasks move between lists
3. **Lead evaluates scope of impact:**
   - **Single task affected** — Lead updates task description, re-queues if needed
   - **Multiple tasks affected** — Lead adds amendment to `plans/{name}/shared/lead.md`, updates affected task descriptions, may cancel pending tasks
   - **Plan fundamentally wrong** — Lead escalates to user with evidence. User decides: amend plan or abort and re-plan.
4. **Lead resumes promotion** after resolution
5. All teammates re-read `shared/` directory on next task claim (existing rule)

## Hook Integration

| Hook | Execution Layer Behavior |
|------|------------------------|
| **PreToolUse (Write/Edit)** | Checks if file changes align with architecture docs. Unchanged from planning layer. |
| **PostToolUse (TaskUpdate)** | When any agent calls TaskUpdate with `status: "completed"`, reads plan README.md success criteria and validates. Blocks completion if criteria unmet. |
| **Stop** | Triggers checkpoint save if execution is in progress. Writes final checkpoint before session closes. |

### Teammate Completion Protocol

When a teammate's role-specific task list is empty, the teammate:
1. Writes `## [Role] IDLE` to their per-role shared file (e.g., `shared/executor.md`)
2. Sends a message to Lead indicating idle status
3. Lead checks if other lists have work that could be promoted to the idle role's list
4. If no more work: Lead acknowledges and teammate shuts down

For Code Reviewer specifically: before going idle, must verify all reviewed tasks have written feedback.

### Session Resume

When `/uc:plan-execution` fires for a plan that has existing checkpoint files, the plan-execution skill handles resume as its first action:
1. Reads latest `checkpoint-{timestamp}.md` file in the plan directory
2. Reads all per-role shared files in `shared/` directory
3. Shows user a resume prompt with progress summary
4. Skips completed work and rebuilds team from current state

This is skill startup behavior, not a hook.

## Workflow: Step-by-Step

```
User: /uc:plan-execution user-auth

PHASE 1: SETUP (Lead actions)
  a. Read ENTIRE plan directory:
     - documentation/plans/user-auth/README.md (plan + tasks)
     - documentation/plans/user-auth/research/*.md (existing)
     - documentation/plans/user-auth/shared/*.md (if resuming)
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
  f. Create/load shared/ directory with initial context in lead.md
  g. Spawn teammates with role-specific prompts:
     - Each prompt includes: role instructions, file paths,
       task claiming rules, communication rules
     - Model selection per role

PHASE 2: PARALLEL WORK (self-coordinating)

  Researcher:
    claim research task -> read codebase + docs ->
    write research/task-N.md -> update shared/researcher.md ->
    mark complete -> claim next
    (when list empty: write IDLE to shared/researcher.md, notify Lead)

  Executor(s):
    claim impl task -> re-read shared/ ->   Lead monitors:
    read research -> implement code ->      - Promotes tasks
    append integration notes to               between lists
    shared/executor.md -> mark complete ->  - Handles fails
    claim next                              - Checkpoints
    (when list empty: write IDLE to shared/executor.md, notify Lead)

  Code Reviewer:
    claim review task -> re-read shared/ + standards ->
    check quality, patterns, duplication ->
    PASS: mark complete | FAIL: mark failed with feedback ->
    claim next
    (when list empty: write IDLE to shared/reviewer.md, notify Lead)

  Tester:
    claim test task -> re-read shared/ + success criteria ->
    run tests -> PASS: mark complete |
    FAIL: SendMessage feedback to Lead ->
    claim next
    (when list empty: write IDLE to shared/tester.md, notify Lead)

PHASE 3: CHECKPOINT (triggered periodically by Lead)
  Triggers: every 3 completed tasks, teammate idle,
            user /uc:checkpoint, Stop hook (session ending)
  Saves: 4 task list states, checkpoint file, decisions
  shared/ files + research files already on disk

PHASE 4: FAILURE HANDLING (Lead manages)
  Review failure: Lead re-queues to impl list + feedback
  Test failure: Lead re-queues to impl list + feedback
  Max 2 retries per task -> escalate to user
  Teammate crash: re-queue task, spawn replacement
  Session death: user reruns /uc:plan-execution, reads checkpoint

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
