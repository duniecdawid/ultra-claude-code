# Phase 2: Spawn Prompts

All task-team spawn prompts are **minimal pointers**. Per-task content (description, success criteria, patterns, research, files, dependencies) lives in `documentation/plans/$ARGUMENTS/tasks/task-{N}/task.md`. Every agent reads its task directory as its first action after pane labeling — see `${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/task-team-startup.md`.

Spawn teammates with the **`Agent` tool in teammate mode** (Mode T per `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`): `run_in_background: true`, `subagent_type` set to the **registered agent type name** (listed per role below — e.g. `uc:Task Executor`, NOT a file path), `model`, and `mode`. Passing a file path as `subagent_type` does not resolve and can fall back to a generic agent. Do **not** pass `team_name` — it is deprecated/ignored (the session has a single implicit team). **MANDATORY naming convention** — the `name` parameter MUST follow exactly `{role}-{N}` where role is one of `executor`, `reviewer`, `tester` and N is the task number:

| Task | Executor | Reviewer | Tester |
|------|----------|----------|--------|
| 1 | `executor-1` | `reviewer-1` | `tester-1` |
| 2 | `executor-2` | `reviewer-2` | `tester-2` |
| N | `executor-N` | `reviewer-N` | `tester-N` |

**Shared (plan-wide):** `pm-{PLAN_NAME}` — the only plan-wide teammate. Knowledge lives per-task in `task.md`; mid-execution gaps flow through the `ADVICE` and `QUERY` channels Lead brokers.

**NEVER** use alternative formats like `task-1-executor`, `e1`, `Executor_1`, or descriptive names.

## Pre-Spawn Checklist

Run these in order before EVERY teammate spawn (`Agent` tool, teammate mode) for a task team (initial spawn AND pipeline pre-spawn):

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
5. **Bar:** by the time you spawn the team, you should be able to say "every core technology this task depends on has been researched and is referenced from task.md." That's the contract.

**What Lead does NOT do:**
- Rewrite the task scope or change the planner's Files list.
- Add speculative research for technologies the task has no real connection to.
- Replace existing pointers that are fine — research is additive, pointers are cheap, history matters.

No `FILE-UPDATED` broadcast is needed at this stage because no task-team member for task-{N} is alive yet. Lead writes, then spawns. Agents will read the current state of `task.md` as part of their startup read.

### 2.5. Initialize signals.jsonl

Create the empty signal file for the task:

```bash
touch "$PLAN_DIR/tasks/task-{N}/signals.jsonl"
```

This must happen before the teammate spawn so agents can read and append to it from their first action. The file starts empty — signals are appended as pipeline events occur.

### 2.6. Re-assert the main-context pane label

The layout daemon only manages a window once its Lead pane carries `@agent-name=main-context`; a window whose Lead pane is unlabelled is skipped (teammate panes pile up un-gridded). Phase 1 §1.1b sets this once, but a one-shot is fragile — if the Lead's controlling pane differs from `$TMUX_PANE` at startup, or `/uc:plan-execution` was invoked mid-session, the label may never land on the pane teammates spawn beside. Re-run the same idempotent setup script here, on every spawn, so the main pane is guaranteed labelled before the first teammate pane appears:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-layout-setup.sh"
```

Its only runtime gate is `$TMUX_PANE` (no-op outside tmux); re-running it is cheap and self-logs to `~/.claude/ultra/tmux-layout-setup.log`. The daemon also self-heals an unlabelled Lead pane by inference — this script just makes the common case deterministic.

### 3. Pipeline-mode block (pipeline pre-spawn only)

If this is a pipeline pre-spawn (Executor's `code complete` on predecessor task {P} freed a slot and task-{N} is the next unblocked dependent), append the Pipeline mode block to `tasks/task-{N}/task.md` after the knowledge review — there's a commented-out template inside the task.md template showing the exact format. Fill in `{P}` and uncomment it.

### 4. Spawn the team

Spawn the task team using the minimal spawn prompts below — each via the `Agent` tool in teammate mode (`name`, `run_in_background: true`, plus the role's agent file / `model` / `mode`). Executor and Reviewer are spawned together **in parallel** (single message with multiple `Agent` calls); the Tester is lazy-spawned later. Each agent self-labels its pane on startup — no PM intervention needed.

After spawning, send to PM:

```
SendMessage to PM: "SPAWNED task-{N}: {short description from task.md heading}"
```

## Executor Spawn

subagent_type: `uc:Task Executor` (defined in `${CLAUDE_PLUGIN_ROOT}/agents/task-executor.md`)
Model: `opus` | Mode: `bypassPermissions`

```
You are the team coordinator for task {N} of the "$ARGUMENTS" plan.

TASK_ID={N}
ROLE=task
PLAN_DIR=documentation/plans/$ARGUMENTS
SIGNAL_FILE=documentation/plans/$ARGUMENTS/tasks/task-{N}/signals.jsonl

**Teammates (SendMessage):**
- Reviewer: reviewer-{N} (spawned with you — will send you a REVIEWER TAKE shortly)
- Lead: team-lead (ADVICE channel — send `ADVICE REQUEST task-{N} [{case}]: ...` for complicated / deep-reasoning / knowledge / deviation cases. QUERY channel — send `QUERY: {question}` for external library docs.)
- Project Manager: pm-{PLAN_NAME} (reads signals.jsonl for stage tracking — no direct messages needed)
- Tester: tester-{N} (lazy-spawned by Lead when you signal "code complete")

Your first action is the startup read — follow
${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/task-team-startup.md.
Then run your agent workflow.
```

**If pipeline-spawned**, the Pipeline mode block has already been appended to `tasks/task-{N}/task.md` during the pre-spawn checklist. The Executor reads it during startup and behaves accordingly — no change to the spawn prompt above.

## Reviewer Spawn

subagent_type: `uc:Code Reviewer` (defined in `${CLAUDE_PLUGIN_ROOT}/agents/code-review.md`)
Model: `sonnet` | Mode: `bypassPermissions`

```
You are reviewing task {N} of the "$ARGUMENTS" plan.

TASK_ID={N}
ROLE=task
PLAN_DIR=documentation/plans/$ARGUMENTS
SIGNAL_FILE=documentation/plans/$ARGUMENTS/tasks/task-{N}/signals.jsonl

**Teammates (SendMessage):**
- Executor: executor-{N} (you will send a REVIEWER TAKE to them immediately after your startup read — see your agent workflow step 2)
- Tester: tester-{N}
- Lead: team-lead (ADVICE + QUERY channels, same as Executor)
- Project Manager: pm-{PLAN_NAME} (may ping for monitoring status)

Your first action is the startup read — follow
${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/task-team-startup.md.
Then run your agent workflow — note that your NEW step 2 is to synthesize
and send a REVIEWER TAKE to the Executor BEFORE it writes plan.md.
```

## Tester Spawn

subagent_type: `uc:Task Tester` (defined in `${CLAUDE_PLUGIN_ROOT}/agents/task-tester.md`)
Model: `sonnet` | Mode: `bypassPermissions`

```
You are testing task {N} of the "$ARGUMENTS" plan.

TASK_ID={N}
ROLE=task
PLAN_DIR=documentation/plans/$ARGUMENTS
SIGNAL_FILE=documentation/plans/$ARGUMENTS/tasks/task-{N}/signals.jsonl

**Teammates (SendMessage):**
- Executor: executor-{N}
- Reviewer: reviewer-{N}
- Lead: team-lead (ADVICE + QUERY channels, same as Executor)
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

subagent_type: `uc:Task Tester` (defined in `${CLAUDE_PLUGIN_ROOT}/agents/task-tester.md`)
Model: `sonnet` | Mode: `bypassPermissions` | Name: `tester-final-gate`

For the final regression gate after all tasks complete, spawn a fresh team member (teammate mode: `name="tester-final-gate"` + `run_in_background: true`):

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
2. Report results to Lead (SendMessage to team-lead):
   - ALL PASS: "Final gate PASSED — full test suite green"
   - FAILURES: "Final gate FAILED — {specific failures with output}"
3. Exit after reporting.
```

## Project Manager Spawn

subagent_type: `uc:Project Manager` (defined in `${CLAUDE_PLUGIN_ROOT}/agents/project-manager.md`)
Model: `sonnet` | Mode: `bypassPermissions`

Spawn **once** before any task-teams. The Project Manager runs for the entire plan duration — it is NOT per-task. Name it `pm-{PLAN_NAME}` (e.g., `pm-user-auth`).

```
You are the Project Manager for the "$ARGUMENTS" plan execution.

PLAN_NAME={PLAN_NAME}
ROLE=oversight
PLAN_DIR=documentation/plans/$ARGUMENTS
ACCOUNT_KEY={ACCOUNT_KEY}
USAGE_MODE={pause|push-through}

**Lead name:** team-lead
**Total tasks:** {N}
**Concurrency limit:** {M} concurrent task-teams
**Team naming convention:** Task N team name: `task-{N}-team`. Executor-N and
reviewer-N spawn at task start; tester-N is lazy-spawned when implementation
is complete. The only plan-wide teammate is yourself (PM) — there is no
separate watchdog; you own the usage monitor.

**Task dependency graph:**
(Read each tasks/task-N/task.md's Dependencies field to build this graph.
Example:)
- Task 1: no dependencies
- Task 2: depends on task 1
- Task 3: depends on task 1
- Task 4: depends on task 2, task 3

**Start the usage monitor (First Action).** Via the Monitor tool:
  Monitor({ command: "bash \"$HOME/.claude/ultra/usage-monitor.sh\" watch \"$PLAN_DIR\" \"$ACCOUNT_KEY\" \"$USAGE_MODE\"",
            description: "Usage monitor for {PLAN_NAME}", persistent: true })
It is silent on clean ticks and emits only actionable milestones:
`CRITICAL` (stop in-flight), `USAGE-RESET` (restart), and `NUDGE` (a
task silent with no named wait and no repo activity — verify, then
ping; all modes). In push-through mode it suppresses usage emits
entirely (NUDGE still fires — liveness, not usage). It also quietly
traces >10-min task silence (`silence_observed`) and mid-execution
window rollovers (`usage_window_rolled`) straight into events.json —
never an emit, never your cue to act. Ignore any Monitor line that is
not JSON with an `"alert"` field.

**You are event-driven.** You wake on your monitor's emits and on messages
from Lead (status updates, completions with current_pct) and Executors.
On a monitor emit, apply USAGE_MODE and forward to Lead ONLY when
actionable. See your agent instructions for the full Usage Monitor Handling
protocol.

**Per-task budget tracking:** On SPAWNED, read current usage % and record
budget.start_pct. On COMPLETED (Lead includes current_pct), compute
cost_pct = end_pct - start_pct and persist to plan.json.

**Pane verification:** Agents self-label their panes on startup per their
agent instructions. After each SPAWNED message from Lead, verify labels.

**What Lead sends you (process into dashboard):**
- `SPAWNED task-{N}: {description}` — create team JSON, update counts, event, record budget.start_pct
- `SPAWNED-TESTER task-{N}` — add tester member, event
- `STAGE task-{N} {stage}` — update team status + timestamps, event
- `COMPLETED task-{N}, current_pct={pct}` — team completed, counts, event, compute budget.cost_pct
- `SHUTDOWN task-{N}` — member ended_at timestamps, event

**signals.jsonl reading (replaces direct Executor messages):**
Executors no longer send STAGE-DONE or RETRY. Read `$PLAN_DIR/tasks/task-{N}/signals.jsonl`
for each active task when you wake to derive stage state:
- `REVIEW_PASS` / `TEST_PASS` → close stage, append event
- `REVIEW_FAIL` / `TEST_FAIL` + `REREVIEW_REQUESTED` / `RETEST_REQUESTED` → retry_count++, reset timers, event
See `${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/execution-communication-protocol.md` §6.

**What you send to Lead (actionable events only):**
- `USAGE STOP [{window}]: {pct}% used. ...` — critical limit reached, stop in-flight work (pause mode only)
- `USAGE RESET [{window}]: ...` — work may restart
- `NUDGE-ESCALATION task-{N}: ...` — only after you verified a NUDGE candidate, pinged the executor, and got no response (see your agent instructions)
You do NOT forward soft-band, status, or stale-data messages — those are not Lead-actionable. NUDGE count:1 is yours to verify and ping, never forwarded.

Follow the workflow in your team member instructions.
```
