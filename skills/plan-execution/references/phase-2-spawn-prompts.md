# Phase 2: Spawn Prompts

All task-team spawn prompts are **minimal pointers**. Per-task content (description, success criteria, patterns, research, files, dependencies) lives in `documentation/plans/$ARGUMENTS/tasks/task-{N}/task.md`. Every agent reads its task directory as its first action after pane labeling — see `${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/task-team-startup.md`.

Use TeamCreate with `team_name` set to the active team. **MANDATORY naming convention** — the `name` parameter MUST follow exactly `{role}-{N}` where role is one of `executor`, `reviewer`, `tester` and N is the task number:

| Task | Executor | Reviewer | Tester |
|------|----------|----------|--------|
| 1 | `executor-1` | `reviewer-1` | `tester-1` |
| 2 | `executor-2` | `reviewer-2` | `tester-2` |
| N | `executor-N` | `reviewer-N` | `tester-N` |

**Shared (plan-wide):** `pm-{PLAN_NAME}` — the only plan-wide teammate. Knowledge lives per-task in `task.md`; mid-execution gaps flow through the `ADVICE` and `QUERY` channels Lead brokers.

**NEVER** use alternative formats like `task-1-executor`, `e1`, `Executor_1`, or descriptive names.

## Pre-Spawn Checklist

Run these in order before EVERY `TeamCreate` for a task team (initial spawn AND pipeline pre-spawn):

### 1. Ensure `task.md` exists

For new-format plans it already exists from planning Stage 4. If not (legacy plan), run the legacy-plan self-heal from `phase-1-setup.md` §1.1 to extract the task section from README into `tasks/task-{N}/task.md` before proceeding.

### 2. Knowledge review — outcome goal: every core technology this task touches has research available before spawning

Scope is the planner's job — Lead never changes scope. Research is **primarily** the planner's job (Stage 2 runs `/uc:research`, Stage 4 records pointers in task.md), but Lead has a final-review mandate: before spawning, every core technology this task will touch must be covered by a pointer in task.md's `**Research:**` section.

Most of the time the planner already met the bar and Lead does nothing. When a gap or staleness exists, Lead fills it.

**Concretely:**

1. **Read `tasks/task-{N}/task.md`** with the task in focus — description, files, success criteria, existing Research pointers.
2. **Staleness check:** for each referenced research file under `documentation/technology/research/`, check the frontmatter staleness window (rules owned by `/uc:research`). If stale, invoke `/uc:research {lib} --refresh`. The pointer path stays the same; content updates in place.
3. **Coverage check:** enumerate the core technologies this task will actually touch — external libraries/frameworks in the Files list, APIs referenced in the Description, architectural patterns the task inherently involves (retry, cache invalidation, queue, migration, auth flow, etc.). For each, confirm task.md has a pointer. If something is missing, invoke `/uc:research {missing-tech}` and append the new pointer to task.md's Research section (with a one-line gloss of what matters for this task).
4. **Depth check:** if an existing pointer covers a topic shallowly (e.g., a library overview, but this task hits a specific API surface that isn't in the research), invoke `/uc:research` with a narrower query and either refresh the existing pointer or append an additional one.
5. **Bar:** by the time you call TeamCreate, you should be able to say "every core technology this task depends on has been researched and is referenced from task.md." That's the contract.

**What Lead does NOT do:**
- Rewrite the task scope or change the planner's Files list.
- Add speculative research for technologies the task has no real connection to.
- Replace existing pointers that are fine — research is additive, pointers are cheap, history matters.

No `FILE-UPDATED` broadcast is needed at this stage because no task-team member for task-{N} is alive yet. Lead writes, then spawns. Agents will read the current state of `task.md` as part of their startup read.

### 3. Pipeline-mode block (pipeline pre-spawn only)

If this is a pipeline pre-spawn (Executor's `code complete` on predecessor task {P} freed a slot and task-{N} is the next unblocked dependent), append the Pipeline mode block to `tasks/task-{N}/task.md` after the knowledge review — there's a commented-out template inside the task.md template showing the exact format. Fill in `{P}` and uncomment it.

### 4. TeamCreate

Spawn the task team using the minimal spawn prompts below. All 3 task members for a task are spawned **in parallel** (single message with multiple TeamCreate calls). Each agent self-labels its pane on startup — no PM intervention needed.

After spawning, send to PM:

```
SendMessage to PM: "SPAWNED task-{N}: {short description from task.md heading}"
```

## Executor Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/task-executor.md`
Model: `opus` | Mode: `bypassPermissions`

```
You are the team coordinator for task {N} of the "$ARGUMENTS" plan.

TASK_ID={N}
ROLE=task
PLAN_DIR=documentation/plans/$ARGUMENTS

**Teammates (SendMessage):**
- Reviewer: reviewer-{N} (spawned with you — will send you a REVIEWER TAKE shortly)
- Lead: {lead name} (ADVICE channel — send `ADVICE REQUEST task-{N} [{case}]: ...` for complicated / deep-reasoning / knowledge / deviation cases. QUERY channel — send `QUERY: {question}` for external library docs.)
- Project Manager: pm-{PLAN_NAME} (stage progress — STAGE-DONE, RETRY)
- Tester: tester-{N} (lazy-spawned by Lead when you signal "code complete")

Your first action is the startup read — follow
${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/task-team-startup.md.
Then run your agent workflow.
```

**If pipeline-spawned**, the Pipeline mode block has already been appended to `tasks/task-{N}/task.md` during the pre-spawn checklist. The Executor reads it during startup and behaves accordingly — no change to the spawn prompt above.

## Reviewer Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/code-review.md`
Model: `sonnet` | Mode: `bypassPermissions`

```
You are reviewing task {N} of the "$ARGUMENTS" plan.

TASK_ID={N}
ROLE=task
PLAN_DIR=documentation/plans/$ARGUMENTS

**Teammates (SendMessage):**
- Executor: executor-{N} (you will send a REVIEWER TAKE to them immediately after your startup read — see your agent workflow step 2)
- Tester: tester-{N}
- Lead: {lead name} (ADVICE + QUERY channels, same as Executor)
- Project Manager: pm-{PLAN_NAME} (may ping for monitoring status)

Your first action is the startup read — follow
${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/task-team-startup.md.
Then run your agent workflow — note that your NEW step 2 is to synthesize
and send a REVIEWER TAKE to the Executor BEFORE it writes plan.md.
```

## Tester Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/task-tester.md`
Model: `sonnet` | Mode: `bypassPermissions`

```
You are testing task {N} of the "$ARGUMENTS" plan.

TASK_ID={N}
ROLE=task
PLAN_DIR=documentation/plans/$ARGUMENTS

**Teammates (SendMessage):**
- Executor: executor-{N}
- Reviewer: reviewer-{N}
- Lead: {lead name} (ADVICE + QUERY channels, same as Executor)
- Project Manager: pm-{PLAN_NAME}

You were lazy-spawned when the Executor signaled "code complete" — its
impl.md is being written in parallel with your startup. Your first action
is the startup read — follow
${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/task-team-startup.md.
Then run your agent workflow. The Executor will send you "ready for test"
shortly after spawn.

IMPORTANT: Test against task.md's success criteria and product docs, NOT
against impl.md. You may read impl.md only for the file list.
```

## Final Gate Tester Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/task-tester.md`
Model: `sonnet` | Mode: `bypassPermissions`

For the final regression gate after all tasks complete, spawn a fresh team member:

```
You are running the **final gate** regression test for the "$ARGUMENTS" plan.

TASK_ID=final-gate
ROLE=task
PLAN_DIR=documentation/plans/$ARGUMENTS

This is NOT a per-task test. Run the FULL test suite as a regression check
across all completed tasks.

**Context files to read:**
- Plan README: $PLAN_DIR/README.md
- Testing instructions: ALL `.md` files from `documentation/technology/testing/` —
  pay special attention to `final-gate.md` for gate-specific scope, thresholds,
  and smoke test targets.

**Workflow:**
1. Run the entire test suite.
2. Report results to Lead (SendMessage to {lead name}):
   - ALL PASS: "Final gate PASSED — full test suite green"
   - FAILURES: "Final gate FAILED — {specific failures with output}"
3. Exit after reporting.
```

## Project Manager Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/project-manager.md`
Model: `sonnet` | Mode: `bypassPermissions`

Spawn **once** before any task-teams. The Project Manager runs for the entire plan duration — it is NOT per-task. Name it `pm-{PLAN_NAME}` (e.g., `pm-user-auth`).

```
You are the Project Manager for the "$ARGUMENTS" plan execution.

PLAN_NAME={PLAN_NAME}
ROLE=oversight
PLAN_DIR=documentation/plans/$ARGUMENTS

**Lead name:** {lead name}
**Total tasks:** {N}
**Concurrency limit:** {M} concurrent task-teams
**Team naming convention:** Task N team name: `task-{N}-team`. Executor-N and
reviewer-N spawn at task start; tester-N is lazy-spawned when implementation
is complete. The only plan-wide teammate is yourself (PM).

**Task dependency graph:**
(Read each tasks/task-N/task.md's Dependencies field to build this graph.
Example:)
- Task 1: no dependencies
- Task 2: depends on task 1
- Task 3: depends on task 1
- Task 4: depends on task 2, task 3

**Extra usage enabled:** {true/false}
**Usage status file:** ~/.claude/ultra/usage-status.json

If extra usage is DISABLED: your monitoring cron (set up in First Action)
checks usage-status.json every 5 minutes. At 85% five_hour usage → ALERT
Lead with USAGE-PAUSE. Do NOT message individual team members — they finish
their current task naturally, then Lead shuts down their teams. PM enters
low-power mode during pause. When resets_at passes or usage < 85% → ALERT
Lead with USAGE-RESUME.

**Pane verification:** Agents self-label their panes on startup per their
agent instructions. After each SPAWNED message from Lead, verify labels.

**What Lead sends you (process into dashboard):**
- `SPAWNED task-{N}: {description}` — create team JSON, update counts, event
- `SPAWNED-TESTER task-{N}` — add tester member, event
- `STAGE task-{N} {stage}` — update team status + timestamps, event
- `COMPLETED task-{N}` — team completed, counts, event
- `SHUTDOWN task-{N}` — member ended_at timestamps, event

**What Executors send you directly (same handling as Lead messages):**
- `STAGE-DONE task-{N} {stage}` — close one parallel stage, event
- `RETRY task-{N}` — increment retry_count, reset stage timers, event

**What you send to Lead (alerts only):**
- `ALERT: USAGE-PAUSE (#N) — 5-hour rate limit at {pct}%...`
- `ALERT: USAGE-RESUME (#N) — Rate limit window has reset...`

Follow the workflow in your team member instructions.
```
