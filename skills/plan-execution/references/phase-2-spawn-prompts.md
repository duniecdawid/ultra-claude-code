# Phase 2: Spawn Prompts

All task-team spawn prompts = **minimal pointers**. Per-task content live in `tasks/task-{N}/task.md`. Every agent read own task directory first action (see `task-team-startup.md`).

Spawn teammates with **`Agent` tool in teammate mode** (Mode T per `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`): `run_in_background: true`, `subagent_type` = **registered agent type name** (listed per role below — e.g. `uc:Task Executor`, NOT file path; file path silently fall back to generic agent), `model`, `mode`. No `team_name` (deprecated/ignored). **MANDATORY naming** — `name` MUST be exactly `{role}-{N}` (`executor-1`, `reviewer-1`, `tester-1`, ...); plan-wide PM = `pm-{PLAN_NAME}`. **NEVER** use other formats like `task-1-executor`, `e1`, `Executor_1`, or descriptive names.

## Pre-Spawn Checklist

Run in order before EVERY teammate spawn (`Agent` tool, teammate mode) for task team (initial spawn AND pipeline pre-spawn):

### 1. Ensure `task.md` exists

New-format plans: already exist from planning Stage 4. If not (legacy plan), run legacy-plan self-heal from `phase-1-setup.md` §1.1 — pull task section from README into `tasks/task-{N}/task.md` before proceed.

### 2. Knowledge review — outcome goal: every core technology this task touches has research available before spawning

Scope = planner job. Lead never change scope. Research **primarily** planner job (Stage 2 run `/uc:research`, Stage 4 record pointers in task.md), but Lead have final-review mandate: before spawn, every core technology this task touch must have pointer in task.md `**Research:**` section.

Most time planner already meet bar, Lead do nothing. Gap or stale exist → Lead fill.

**Concretely:**

1. **Read `tasks/task-{N}/task.md`** with task in focus — description, files, success criteria, existing Research pointers.
2. **Staleness check:** for each referenced research file under `documentation/technology/research/`, check frontmatter staleness window (rules owned by `/uc:research`). Stale → invoke `/uc:research {lib} --refresh`. Pointer path stay same; content update in place.
3. **Coverage check:** list core technologies this task actually touch — external libraries/frameworks in Files list, APIs in Description, architectural patterns task inherently involve (retry, cache invalidation, queue, migration, auth flow, etc.). Each one: confirm task.md have pointer. Missing → invoke `/uc:research {missing-tech}`, append new pointer to task.md Research section (with one-line gloss of what matter for this task).
4. **Depth check:** existing pointer cover topic shallow (e.g. library overview, but task hit specific API surface not in research) → invoke `/uc:research` with narrower query, refresh existing pointer or append extra one.
5. **Bar:** by spawn time, you can say "every core technology this task depends on has been researched and is referenced from task.md." That the contract.

**What Lead does NOT do:**
- Rewrite task scope or change planner Files list.
- Add speculative research for tech task have no real connection to.
- Replace existing pointers that fine — research additive, pointers cheap, history matter.

No `FILE-UPDATED` broadcast needed here — no task-team member for task-{N} alive yet. Lead write, then spawn. Agents read current `task.md` state during startup read.

### 2.5. Initialize signals.jsonl

Create empty signal file for task:

```bash
touch "$PLAN_DIR/tasks/task-{N}/signals.jsonl"
```

Must happen before teammate spawn so agents can read + append from first action. File start empty — signals appended as pipeline events occur.

### 2.6. Re-assert the main-context pane label

Phase 1 §1.1b label Lead pane once, but one-shot fragile (controlling pane differ from `$TMUX_PANE`, mid-session invocation). Re-run same idempotent setup script before every spawn so main pane guaranteed labelled before first teammate pane appear:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-layout-setup.sh"
```

### 3. Pipeline-mode block (pipeline pre-spawn only)

Pipeline pre-spawn (Executor `code complete` on predecessor task {P} free slot, task-{N} next unblocked dependent) → append Pipeline mode block to `tasks/task-{N}/task.md` after knowledge review. Commented-out template inside task.md template show exact format. Fill `{P}`, uncomment.

### 4. Spawn the team

Spawn task team with minimal spawn prompts below — each via `Agent` tool in teammate mode (`name`, `run_in_background: true`, plus role agent file / `model` / `mode`). `code` task: Executor, Reviewer, Tester spawn together **in parallel** (single message, multiple `Agent` calls). `ops` task (task.md `**Type:** ops`): spawn Executor **alone** — no Reviewer, no Tester — use ops variant in Executor Spawn section. Each agent self-label own pane on startup — no PM intervention.

After spawn, send to PM:

```
SendMessage to PM: "SPAWNED task-{N}: {short description from task.md heading}"
```

## Executor Spawn

subagent_type: `uc:Task Executor` (defined in `${CLAUDE_PLUGIN_ROOT}/agents/task-executor.md`)
Model: task.md `**Executor model:**` — `sonnet` / `opus` / `fable`; absent → `opus` | Mode: `bypassPermissions`

```
You are the team coordinator for task {N} of the "$ARGUMENTS" plan.

TASK_ID={N}
ROLE=task
PLAN_DIR=documentation/plans/$ARGUMENTS
SIGNAL_FILE=documentation/plans/$ARGUMENTS/tasks/task-{N}/signals.jsonl

**Teammates (SendMessage):**
- Reviewer: reviewer-{N} (spawned with you — will send you a REVIEWER TAKE shortly)
- Tester: tester-{N} (spawned with you — will send you a TESTER TAKE shortly)
- Lead: team-lead (ADVICE channel — send `ADVICE REQUEST task-{N} [{case}]: ...` for complicated / deep-reasoning / knowledge / deviation cases. QUERY channel — send `QUERY: {question}` for external library docs.)
- Project Manager: pm-{PLAN_NAME} (reads signals.jsonl for stage tracking — no direct messages needed)

Your first action is the startup read — follow
${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/task-team-startup.md.
Then run your agent workflow.
```

**If pipeline-spawned**, Pipeline mode block already appended to `tasks/task-{N}/task.md` during pre-spawn checklist. Executor read it during startup, behave accordingly — spawn prompt above unchanged.

**Ops variant** (task.md `**Type:** ops`): same prompt, two changes — add `TASK_TYPE=ops` on line after SIGNAL_FILE, drop Reviewer + Tester lines from teammates list (never spawned). Executor agent file define ops workflow deltas.

## Reviewer Spawn

Code tasks only — never spawn for ops task.

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

Code tasks only — never spawn for ops task.

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

Your first action is the startup read — follow
${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/task-team-startup.md.
Then run your agent workflow — note that your step 1 is to build a test
strategy and send a TESTER TAKE to the Executor BEFORE it writes plan.md
(the Executor is blocked on it). While implementation runs you may draft
black-box acceptance tests; "ready for test" arrives when code is done.

IMPORTANT: Test against task.md's success criteria and product docs, NOT
against impl.md. You may read impl.md only for the file list.
```

## Final Gate Tester Spawn

subagent_type: `uc:Task Tester` (defined in `${CLAUDE_PLUGIN_ROOT}/agents/task-tester.md`)
Model: `sonnet` | Mode: `bypassPermissions` | Name: `tester-final-gate`

For final regression gate after all tasks complete, spawn fresh team member (teammate mode: `name="tester-final-gate"` + `run_in_background: true`):

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

Spawn **once** before any task-teams. Project Manager run whole plan duration — NOT per-task. Name it `pm-{PLAN_NAME}` (e.g., `pm-user-auth`).

```
You are the Project Manager for the "$ARGUMENTS" plan execution.

PLAN_NAME={PLAN_NAME}
ROLE=oversight
PLAN_DIR=documentation/plans/$ARGUMENTS

**Lead name:** team-lead
**Total tasks:** {N}
**Concurrency limit:** {M} concurrent task-teams

**Task dependency graph:**
(Read each tasks/task-N/task.md's Dependencies field to build this graph.
Example:)
- Task 1: no dependencies
- Task 2: depends on task 1
- Task 3: depends on task 1
- Task 4: depends on task 2, task 3

Follow the workflow in your team member instructions — First Action
(pane label + liveness monitor), status update processing, signals.jsonl
reading, budget tracking, and NUDGE handling are all defined there.
```
