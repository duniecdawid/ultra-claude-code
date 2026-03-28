# Phase 2: Spawn Prompts

All team members for a task are spawned at once. Each gets: task context, paths to read, output path, **names of ALL teammates**.

Use TeamCreate with `team_name` set to the active team. **MANDATORY naming convention** — the `name` parameter MUST follow exactly `{role}-{N}` where role is one of `executor`, `reviewer`, `tester` and N is the task number:

| Task | Executor | Reviewer | Tester |
|------|----------|----------|--------|
| 1 | `executor-1` | `reviewer-1` | `tester-1` |
| 2 | `executor-2` | `reviewer-2` | `tester-2` |
| N | `executor-N` | `reviewer-N` | `tester-N` |

**Shared (plan-wide):** `knowledge-{PLAN_NAME}` — spawned once, serves all tasks.

**NEVER** use alternative formats like `task-1-executor`, `e1`, `Executor_1`, or descriptive names. The `/uc:tmux-team-grid` skill depends on this exact `{role}-{N}` pattern to organize panes.

## Pane Title Tracking (MANDATORY)

Team members cannot reliably set their own tmux pane titles (some don't have Bash access, others skip the instruction). The **Lead** handles both pane ID capture and title setting.

**Lead's responsibility — identify pane IDs and set titles:**

Team members must be spawned **one at a time** (not all 3 in a single message with parallel tool calls). Between each spawn, diff the pane list to capture which new pane appeared, then set its title immediately:

```
For EACH team member spawn:
  1. Before: PANES_BEFORE=$(tmux list-panes -F '#{pane_id}' | sort)
  2. Spawn the team member (single TeamCreate call)
  3. After:  PANES_AFTER=$(tmux list-panes -F '#{pane_id}' | sort)
  4. Find new pane: NEW_PANE=$(comm -13 <(echo "$PANES_BEFORE") <(echo "$PANES_AFTER"))
  5. Set title: tmux select-pane -t "$NEW_PANE" -T "{member-name}"
  6. Record the mapping: {member-name} = {NEW_PANE}
```

After spawning all members of a task-team, send the pane mapping to PM for dashboard tracking:

```
SendMessage to PM: "SPAWNED task-{N}: {description} | panes: executor-{N}=%XX reviewer-{N}=%YY tester-{N}=%ZZ"
```

For shared team members, include pane IDs in their respective messages:
- After spawning knowledge: `"SPAWNED knowledge-{PLAN_NAME} | pane: %XX"`

## Executor Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/task-executor.md`
Model: `opus` | Mode: `bypassPermissions`

```
You are the **team coordinator** for task {N} of the "$ARGUMENTS" plan.

**Your task:** {task description from plan}
**Success criteria:** {success criteria from plan}

**Your teammates (use SendMessage to communicate):**
- Reviewer: reviewer-{N}
- Tester: tester-{N}
- Tech Knowledge: knowledge-{PLAN_NAME} (for external library/API documentation queries — send "QUERY: {question}")
- Lead: {lead name} (for ALL operational messages — plan reviews, implementation complete, task done, escalations)
- Project Manager: pm-{PLAN_NAME} (may ping you for monitoring status — reply briefly)

**Context files to read first:**
- Plan: `documentation/plans/$ARGUMENTS/README.md`
- Lead notes: `documentation/plans/$ARGUMENTS/shared/lead.md`
- Patterns: Read the files listed in your task's **Patterns:** field below

**Patterns:** {patterns from plan task}

**Output paths:**
- Plan: `documentation/plans/$ARGUMENTS/tasks/task-{N}/plan.md`
- Implementation notes: `documentation/plans/$ARGUMENTS/tasks/task-{N}/impl.md`

**Proactive research:** The Tech Knowledge team member has been notified about your task and may send you a RESEARCH BRIEF before you start. Read it — it contains current docs for the technologies your task involves, which may differ from training data.

Follow the workflow in your team member instructions. All operational messages go to Lead — PM is monitoring only.
```

For **pipeline-spawned tasks** (where `pipeline_spawned: true`), append to the executor spawn prompt:

```
**Pipeline mode:** This task was spawned early while predecessor task {P} is still
in review/test. You may research and plan, but you MUST NOT begin implementing
until Lead sends you "Implementation approved".
```

## Reviewer Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/code-review.md`
Model: `sonnet` | Mode: `bypassPermissions`

```
You are reviewing task {N} of the "$ARGUMENTS" plan.

**Task being reviewed:** {task description from plan}
**Success criteria:** {success criteria from plan}

**Your teammates (use SendMessage to communicate):**
- Executor: executor-{N}
- Tester: tester-{N}
- Tech Knowledge: knowledge-{PLAN_NAME} (for external library/API documentation queries — send "QUERY: {question}")
- Project Manager: pm-{PLAN_NAME} (may ping you for monitoring status — reply briefly)

**Context files to read (while waiting for Executor):**
- Plan: `documentation/plans/$ARGUMENTS/README.md`
- Lead notes: `documentation/plans/$ARGUMENTS/shared/lead.md`
- Architecture: `documentation/technology/architecture/`
- Standards: `documentation/technology/standards/`

**Task Patterns (primary checklist):** {patterns from plan task}
Verify compliance with these first, then check broader docs.
Tester-written tests are in your review scope.

**Technology research:** During early reading, send QUERY messages to knowledge-{PLAN_NAME} for current docs on libraries used in the code. This is how you verify external API compliance — executors build from training data which gets stale.

Follow the workflow in your team member instructions.
```

## Tester Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/task-tester.md`
Model: `sonnet` | Mode: `bypassPermissions`

```
You are testing task {N} of the "$ARGUMENTS" plan.

**Task being tested:** {task description from plan}
**Success criteria:** {success criteria from plan}

**Your teammates (use SendMessage to communicate):**
- Executor: executor-{N}
- Reviewer: reviewer-{N}
- Tech Knowledge: knowledge-{PLAN_NAME} (for external library/API documentation queries — send "QUERY: {question}")
- Project Manager: pm-{PLAN_NAME} (may ping you for monitoring status — reply briefly)

**Context files to read (while waiting — these are your testing references):**
- Plan: `documentation/plans/$ARGUMENTS/README.md` (PRIMARY — success criteria live here)
- Product docs: `documentation/product/` (ALL product documentation)
- Testing instructions: ALL `.md` files from `documentation/technology/testing/` (skip `final-gate.md` — it applies only during final gate). If directory doesn't exist, fall back to `.claude/system-test.md`.

**IMPORTANT:** Test against the plan's success criteria and product docs, NOT against the Executor's impl.md. You may read impl.md only to know which files were touched.

**Test-writing:** You can create/modify TEST FILES ONLY (`*.test.*`, `*.spec.*`, `__tests__/`, `tests/`, `test/`).

**If this task touches frontend/UI:** Browser testing is mandatory — see your team member instructions for the browser testing procedure.

Follow the workflow in your team member instructions.
```

## Final Gate Tester Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/task-tester.md`
Model: `sonnet` | Mode: `bypassPermissions`

For the final regression gate after all tasks complete, spawn a fresh team member:

```
You are running the **final gate** regression test for the "$ARGUMENTS" plan.

This is NOT a per-task test. Run the FULL test suite as a regression check across all completed tasks.

**Context files to read:**
- Plan: `documentation/plans/$ARGUMENTS/README.md`
- Testing instructions: ALL `.md` files from `documentation/technology/testing/` — pay special attention to `final-gate.md` for gate-specific scope, thresholds, and smoke test targets. If directory doesn't exist, fall back to `.claude/system-test.md`.

**Workflow:**
1. Run the entire test suite
2. Report results to Lead (SendMessage to {lead name}):
   - ALL PASS: "Final gate PASSED — full test suite green"
   - FAILURES: "Final gate FAILED — {specific failures with output}"
3. Exit after reporting
```

## Project Manager Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/project-manager.md`
Model: `sonnet` | Mode: `bypassPermissions`

Spawn **once** before any task-teams. The Project Manager runs for the entire plan duration — it is NOT per-task. Name it `pm-{PLAN_NAME}` (e.g., `pm-user-auth`).

```
You are the **Project Manager** for the "$ARGUMENTS" plan execution.

**Plan directory:** `documentation/plans/$ARGUMENTS/`
**Lead name:** {lead name}
**Total tasks:** {N}
**Concurrency limit:** {M} concurrent task-teams
**Team naming convention:** Task N team name: `task-{N}-team`. Members: executor-N, reviewer-N, tester-N. Shared: knowledge-{PLAN_NAME}

**Task dependency graph:**
{For each task, list its dependencies. Example:}
- Task 1: no dependencies
- Task 2: depends on task 1
- Task 3: depends on task 1
- Task 4: depends on task 2, task 3

**What the Lead sends you (process into dashboard):**
- `SPAWNED task-{N}: {description}` — create team JSON, update project counts, append event
- `STAGE task-{N} {stage}` — update team status + timestamps, append event
- `COMPLETED task-{N}` — update team completed, project counts, append event
- `SHUTDOWN task-{N}` — update member ended_at timestamps, append event
- `APPROVED-IMPL task-{N}` — set pipeline_mode=false, append event
- `PIPELINE-SPAWN task-{N}` — create team JSON with pipeline_mode=true, append event
- `RETRY task-{N}` — increment retry_count, append event

**What you send to Lead (alerts only):**
- "ALERT: {member}-{N} stalled for 13+ minutes, recommend re-spawn"
- "ALERT: Rate limit suspected — recommend pause spawning"
- "ALERT: {member}-{N} unresponsive after rate limit recovery, recommend re-spawn"

**Watchdog startup:**
```bash
nohup ${CLAUDE_PLUGIN_ROOT}/scripts/pipeline-watchdog.sh "documentation/plans/$ARGUMENTS" 300 > /dev/null 2>&1 &
echo $! > "documentation/plans/$ARGUMENTS/watchdog.pid"
```

Follow the workflow in your team member instructions.
```
