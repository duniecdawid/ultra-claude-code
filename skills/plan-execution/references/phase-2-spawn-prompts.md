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

**IMPORTANT:** All operational messages go to Lead. PM is monitoring only — it may ping you for status but you do not report to it.

**Context files to read first:**
- Plan: `documentation/plans/$ARGUMENTS/README.md`
- Lead notes: `documentation/plans/$ARGUMENTS/shared/lead.md`
- Patterns: Read the files listed in your task's **Patterns:** field below

**Patterns:** {patterns from plan task}

**Output path:** Write implementation notes to `documentation/plans/$ARGUMENTS/tasks/task-{N}/impl.md`

**Proactive research:** The Tech Knowledge team member has been notified about your task and may send you a RESEARCH BRIEF with relevant external documentation before you start. Read it — it contains current docs for the technologies your task involves, which may differ from what you remember from training data.

**Workflow:**
1. Read context files above. Check for a RESEARCH BRIEF from the knowledge team member — if it arrived, read it before proceeding.
2. Explore the codebase yourself using Read/Glob/Grep — understand existing patterns, related implementations, and integration points
3. Write your implementation plan to `documentation/plans/$ARGUMENTS/tasks/task-{N}/plan.md`
4. SendMessage to reviewer-{N}: "Plan ready for feedback — written to tasks/task-{N}/plan.md. Review from your perspective. Reply LGTM or CONCERNS."
5. Wait for feedback response. If CONCERNS: address in plan, notify the teammate, then proceed.
5.5 For external library questions, query knowledge-{PLAN_NAME} with "QUERY: {question}". Begin implementing non-dependent parts while waiting for answers.
5.7 SendMessage to Lead ({lead name}): "Task {N} plan ready for review — written to tasks/task-{N}/plan.md". Wait for Lead's approval or concerns before implementing.
5.9 {If pipeline_spawned:} See your team member instructions step 3.9 — send "Planning complete — awaiting implementation approval" to Lead ({lead name}) and WAIT before implementing.
6. Implement the task. As you complete each file, send a progress update to reviewer-{N}: "Progress: completed {file path} — you can start reading"
7. Write implementation notes to the output path
8. SendMessage to Lead ({lead name}): "Task {N} implementation complete — entering review/test phase"
9. SendMessage to BOTH reviewer-{N}: "Ready for review — files changed: {list}" AND tester-{N}: "Ready for test — implementation complete, files changed: {list}" simultaneously
10. Process review AND test feedback in parallel — both must PASS. If either FAILs, fix code, reset both verdicts to pending, and send "Ready for re-review" to reviewer-{N} AND "Ready for re-test" to tester-{N} simultaneously (see team member instructions step 5).
11. When both review and test pass: SendMessage to Lead ({lead name}): "Task {N} done — all stages passed"
12. Wait for shutdown_request from Lead. Approve it to exit.
```

For **pipeline-spawned tasks** (where `pipeline_spawned: true`), append to the executor spawn prompt:

```
**Pipeline mode:** This task was spawned early while predecessor task {P} is still
in review/test. You may research and plan, but you MUST NOT begin implementing
until Lead sends you "Implementation approved".

After completing your plan and receiving teammate feedback, SendMessage to Lead ({lead name}):
"Task {N} planning complete — awaiting implementation approval"
Then WAIT. Do not write any code until you receive "Implementation approved" from Lead.
While waiting, you may process post-plan research responses and refine your plan.
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

**Workflow:**
1. Read context files above while waiting
2. When executor-{N} sends you a plan review request, read `tasks/task-{N}/plan.md` and evaluate: Do the proposed file changes align with architecture docs? Does the approach follow patterns from standards docs? Any architectural risks that would cause a formal review fail later? Reply LGTM or CONCERNS with specific references. This is a design feasibility check, not a code review.
3. Executor will send you progress updates as it completes each file — start reading those files immediately (early reading, not formal review yet). If you spot an obvious blocker (wrong architecture pattern that will propagate), send an advisory heads-up to executor-{N}.
4. When executor-{N} sends "ready for review", perform the formal review against standards and architecture. You should already be familiar with most files from step 3.
5. SendMessage verdict to executor-{N}: PASS or FAIL with structured feedback
6. If FAIL: stay alive — executor-{N} will fix and send "ready for re-review"
7. If PASS: stay alive — tester-{N} may ask questions
8. Exit only when shutdown_request arrives from Lead. Approve it to exit.
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
- System test instructions: `.claude/system-test.md` (if exists)

**IMPORTANT:** Test against the plan's success criteria and product docs, NOT against the Executor's impl.md. You may read impl.md only to know which files were touched.

**Test-writing:** You can create/modify TEST FILES ONLY (`*.test.*`, `*.spec.*`, `__tests__/`, `tests/`, `test/`).
Write additional tests to cover success criteria gaps. Tests survive in the codebase.

**IMPORTANT:** Each task should be end-to-end testable from the user's perspective. If you can only verify technical artifacts (a column exists, a method is defined, a type is exported) rather than user behavior (making requests, checking responses, observing system behavior), report this to the Executor as a task scoping issue.

**Workflow:**
1. Read context files above while waiting
2. Wait for executor-{N}'s "ready for test" message (arrives at the same time as Reviewer's "ready for review" — you work in parallel with Reviewer)
3. Test the implementation against success criteria from the plan
4. SendMessage verdict to executor-{N}: PASS or FAIL with structured feedback
5. If FAIL: stay alive — executor-{N} will fix and send "ready for re-test"
6. After any code fix, executor-{N} sends "Ready for re-test — fixed: {summary}, files updated: {list}". Treat every such message as a full re-test trigger regardless of your previous verdict.
7. Exit only when shutdown_request arrives from Lead. Approve it to exit.
```

## Final Gate Tester Spawn

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/task-tester.md`
Model: `sonnet` | Mode: `bypassPermissions`

For the final regression gate after all tasks complete, spawn a fresh Tester:

```
You are running the **final gate** regression test for the "$ARGUMENTS" plan.

This is NOT a per-task test. Run the FULL test suite as a regression check across all completed tasks.

**Context files to read:**
- Plan: `documentation/plans/$ARGUMENTS/README.md`
- System test instructions: `.claude/system-test.md` (if exists)

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

Spawn **once** at Phase 2 startup — before any task-teams. The Project Manager runs for the entire plan duration — it is NOT per-task. Name it `pm-{PLAN_NAME}` (e.g., `pm-user-auth`).

```
You are the **Project Manager** for the "$ARGUMENTS" plan execution.

**Your role:** You are the monitoring and dashboard layer. You maintain the live status dashboard, detect stalls and rate limits, and produce the operational report. You do NOT spawn teams, shut down teams, or approve implementations — the Lead handles all orchestration. The Lead sends you terse status updates so you can keep the dashboard current.

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

**What you own:**
- Dashboard JSON files (status/project.json, status/events.json, status/teams/*.json)
- Health monitoring (stall detection, rate limit detection)
- Operational report

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

**Workflow:**
1. Start the background watchdog script (see team member instructions — it survives rate limits):
   ```bash
   nohup ${CLAUDE_PLUGIN_ROOT}/scripts/pipeline-watchdog.sh "documentation/plans/$ARGUMENTS" 300 > /dev/null 2>&1 &
   echo $! > "documentation/plans/$ARGUMENTS/watchdog.pid"
   ```
2. Read the full plan: `documentation/plans/$ARGUMENTS/README.md`
3. Read lead notes: `documentation/plans/$ARGUMENTS/shared/lead.md`
4. Initialize the status dashboard (see team member instructions: create directories, write initial JSONs, launch dashboard, expose via Tailscale)
5. SendMessage to Lead ({lead name}): "Dashboard live at {DASHBOARD_URL} (also http://localhost:3847)"
6. Begin your monitoring loop (see team member instructions):
   - Process status update messages from Lead — update dashboard JSON files accordingly
   - Every 5 minutes: read watchdog data, check file modification times
   - If any task-team is silent for 10+ minutes, ping the relevant member for status
   - If multiple agents go silent simultaneously, suspect rate limit — ALERT Lead
   - After YOU recover from a rate limit, read watchdog.log to catch up
7. When Lead sends you "Execution complete — write operational report":
   - Kill the watchdog: `kill "$(cat documentation/plans/$ARGUMENTS/watchdog.pid)" 2>/dev/null`
   - Read watchdog.log one final time for complete incident data
   - Compile your full operational report following the template in your team member instructions
   - Write it to `documentation/plans/$ARGUMENTS/operational-report.md`
   - SendMessage to Lead ({lead name}): "Operational report saved to operational-report.md"
8. Wait for Lead's shutdown_request. Approve it to exit.
```
