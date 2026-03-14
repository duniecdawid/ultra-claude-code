---
description: Executes approved plans through per-task pipeline teams. Each task gets a dedicated mini-team (Executor/Reviewer/Tester) that self-coordinates internally, plus a shared Tech Knowledge agent for external library documentation. Lead spawns teams and tracks progress. Use when user says 'execute plan', 'run plan', 'start execution', or '/uc:plan-execution'. NEVER auto-trigger after plan approval — planning modes print the execution command for the user to run manually.
argument-hint: "plan number or name (e.g., '1', '001-user-auth')"
user-invocable: true
---

# Plan Execution

You are the **Lead** — the orchestrator and domain authority for plan execution. You spawn teams, manage the pipeline, handle shutdowns, and approve pipeline implementations. The PM (Project Manager) monitors health, maintains the live dashboard, and produces operational reports. You send terse status updates to PM so it keeps the dashboard current.

**Plan:** $ARGUMENTS

## Plan Resolution

Before anything else, resolve `$ARGUMENTS` to a full plan directory name:

1. **Pure number** (e.g., `1`, `3`, `12`) — zero-pad to 3 digits, scan `documentation/plans/` for a directory matching `{NNN}-*` (e.g., `1` → `001-*`)
2. **Already `NNN-*` format** (e.g., `001-user-auth`) — use as-is
3. **Semantic name** (e.g., `user-auth`) — scan `documentation/plans/` for a directory matching `*-{ARGUMENTS}`

If no match is found, inform the user and stop. Store the resolved full directory name — all subsequent `$ARGUMENTS` references in this skill use the resolved name.

## Prerequisites

Before starting, verify:

1. Plan exists at `documentation/plans/$ARGUMENTS/README.md`
2. Agent teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` in settings)
3. tmux installed (required for agent teams)

If any prerequisite is missing, inform the user and stop.

---

## Phase 1: Setup

### 1.1 Read Entire Plan Directory

Read ALL files in `documentation/plans/$ARGUMENTS/`:

- `README.md` — plan document with embedded task list
- `tasks/*/` — existing per-task pipeline artifacts (if resuming)
- `shared/lead.md` — Lead-level shared notes (if resuming)
- `checkpoint-*.md` — checkpoint files (if any)

You now have the full picture.

### 1.2 Resume Detection

If `checkpoint-*.md` files exist:

1. Read the LATEST checkpoint (highest timestamp)
2. Read `shared/lead.md`
3. Present to user:
   ```
   Found checkpoint from [timestamp].
   Progress: [X/Y] tasks completed, [Z] in pipeline.
   Completed: [brief list]
   Remaining: [brief list]
   Resume from checkpoint? (yes/no)
   ```
4. If yes: skip completed work, re-spawn teams for incomplete tasks using per-task files as context
5. If no: confirm user wants to discard progress, then start fresh

### 1.3 Task Pipeline

Every task gets the full pipeline team: **Executor + Reviewer + Tester**. There is no classification step. A shared Tech Knowledge agent handles external library documentation for all tasks.

### 1.4 Concurrency Decision

Determine how many task-teams can run concurrently:

| Plan Size | Max Concurrent Task-Teams |
|-----------|--------------------------|
| 1-3 tasks | 1-2 |
| 4-8 tasks | 2-3 |
| 9+ tasks  | 3-4 |

Max ceiling: **4 concurrent task-teams** (each team = 3 agents: Executor + Reviewer + Tester), plus 1 shared knowledge agent.

Each slot = 1 full task-team. All team members spawned together when a slot opens, all exit together when the task is done.

**Pipeline-spawned tasks do NOT count against the concurrency limit** while in planning-only mode (executor planning, blocked from implementing). They count as a full slot only once implementation is approved. This allows successor tasks to get a head start on planning without blocking the pipeline. The PM tracks this distinction when making spawn requests.

### Model Assignment

| Role | Model | Rationale |
|------|-------|-----------|
| **Executor** | **opus** | Code generation, architectural decisions, codebase research — highest capability required |
| Reviewer | sonnet | Pattern recognition, architecture conformance |
| Tester | sonnet | Test execution, failure diagnosis |
| Tech Knowledge | sonnet | Documentation retrieval — shared across all tasks |
| Project Manager | sonnet | Operational observation — read-only, low overhead |

### Permission Modes

| Role | Mode | Rationale |
|------|------|-----------|
| **Executor** | **`bypassPermissions`** | **Writes code autonomously; plan reviewed by teammates before implementation** |
| Tech Knowledge | `bypassPermissions` | Read-only documentation retrieval, no approval needed |
| Reviewer | `bypassPermissions` | Read-only analysis, no approval needed |
| Tester | `bypassPermissions` | Runs tests autonomously, no approval needed |
| Project Manager | `bypassPermissions` | Read-only observation, no approval needed |

### 1.5 Present Cost Estimate and Get Confirmation

Present to user BEFORE spawning any teams:

```
Plan: $ARGUMENTS
Tasks: N total
Concurrency: up to M task-teams in parallel
Estimated cost: ~[N * 150]K tokens

Cost per task pipeline: ~150K tokens (Executor + Reviewer + Tester)
Tech Knowledge agent (plan-wide): ~100K tokens (shared documentation retrieval)
Project Manager (plan-wide): ~50K tokens (observational, runs entire execution)

Proceed? (yes/no)
```

**Wait for explicit user confirmation.** Do not spawn teams without it.

### 1.6 Create Task List

Create ONE task per plan task — no role prefixes. Pipeline stage is tracked in metadata:

```
TaskCreate({
  subject: "task-1: Add JWT middleware",
  description: "Success criteria: ...\nFiles: src/middleware/auth.ts\n...",
  activeForm: "Processing task 1: Add JWT middleware",
  metadata: { "stage": "pending", "retry_count": 0 }
  // stage values: "pending" | "planning" | "impl" | "review" | "test" | "done"
})
```

Each task description must include:
- Success criteria from the plan
- Files involved
- Dependencies on other tasks (use `addBlockedBy` for sequential ordering)

### 1.7 Set Up Directory Structure

```
documentation/plans/$ARGUMENTS/
  README.md
  shared/
    lead.md              # Global Lead notes
  tasks/                 # Per-task pipeline artifacts (created just-in-time)
  checkpoint-*.md
```

Create `shared/lead.md` with: plan overview, concurrency decision, key architectural constraints, task dependency graph, critical decisions.

Create `tasks/` directory. Per-task subdirs (`tasks/task-N/`) are created just-in-time when the first agent spawns for that task.

### 1.8 Proceed to Orchestration

No task-team agents are spawned during setup. Proceed directly to Phase 1.9.

### 1.9 Knowledge Agent Setup

Before spawning any task-teams, set up the shared Tech Knowledge agent:

1. Read plan README.md `## Tech Stack` section for the technology list
2. Also scan `documentation/technology/architecture/` and `.claude/app-context-for-research.md` for additional technology references
3. Use pane-diffing to capture the pane ID (see "Pane Title Tracking" section), then spawn `knowledge-{PLAN_NAME}`:
4. After spawn, send PM the pane ID: `"SPAWNED knowledge-{PLAN_NAME} | pane: %XX"`
5. Spawn using the Tech Knowledge agent:

Agent: `${CLAUDE_PLUGIN_ROOT}/agents/tech-knowledge.md`
Model: `sonnet` | Mode: `bypassPermissions`

```
You are the shared **Tech Knowledge** agent for the "$ARGUMENTS" plan execution.

**Technologies to load documentation for:**
{list from Tech Stack section + any additional technologies identified}

**Architecture docs to read for context:**
- `documentation/technology/architecture/`
- `.claude/app-context-for-research.md` (if exists)

**Lead name:** {lead name}

Load documentation for all listed technologies using mcp__ref__ref_search_documentation and mcp__ref__ref_read_url. Read the architecture docs for project context. Then SendMessage to Lead: "Knowledge base ready — loaded docs for: {technology list}"

You will receive QUERY and LOAD messages from team members throughout execution. Respond per your agent instructions.

Exit only when shutdown_request arrives from Lead. Approve it to exit.
```

6. Wait for "Knowledge base ready" signal before proceeding to Phase 2.

---

## Phase 2: Pipeline Orchestration

Each task gets a dedicated mini-team that self-coordinates internally. The **Lead** orchestrates everything — spawning teams, managing the pipeline, handling shutdowns, approving pipeline implementations. The **PM** maintains the dashboard and monitors health.

### How a Task-Team Works

All members are spawned at once, stay alive, and communicate peer-to-peer. Executors report operational status directly to the Lead:

```
Executor:   explores codebase → plans → sends plan to Lead for review
            → queries knowledge-{PLAN_NAME} for external library docs as needed
            → sends per-file progress updates to Reviewer during implementation
            → signals Lead "implementation complete" (Lead handles pipeline decisions)
            → tells Reviewer "ready for review" AND Tester "ready for test" simultaneously
Reviewer:   reads files early (advisory feedback) → formal review on "ready for review"
            → sends PASS/FAIL to Executor
            → if FAIL: Executor fixes → "Ready for re-review" + "Ready for re-test" sent to both simultaneously
Tester:     tests against PRODUCT DOCS (not impl.md) → sends PASS/FAIL to Executor (in parallel with Reviewer)
            → if FAIL: Executor fixes → "Ready for re-test" + "Ready for re-review" sent to both simultaneously
Both PASS:  Executor tells Lead "task done" → Lead sends shutdown_request → team exits
```

**Key principles:**
- **ONE dedicated team per task, NO sharing.** Task 1 gets its own Executor-1, Reviewer-1, Tester-1. Task 2 gets its own set. They never cross.
- **Shared knowledge agent** — `knowledge-{PLAN_NAME}` is spawned once and serves all task teams with external library documentation.
- **ALL team members stay alive** through the full task lifecycle — they communicate directly via SendMessage until the task passes all stages.
- **Executor is the team coordinator** — it drives the pipeline sequence internally and does its own codebase research.
- **Lead is the orchestrator** — spawns teams, shuts down teams, approves pipeline implementations, reviews plans for coherence, handles escalations.
- **PM is the monitoring layer** — maintains the dashboard, detects stalls/rate limits, sends ALERTs to Lead with recommendations.
- **Reviewer and Tester can query the knowledge agent** if they need external library documentation during their work.
- **Max 10 fix cycles** between executor/reviewer/tester before escalating to Lead → user.

### Team Composition

Every task gets the same team: **Executor + Reviewer + Tester**. The shared Tech Knowledge agent (`knowledge-{PLAN_NAME}`) serves all tasks.

### Orchestration Loop

The Lead handles all orchestration — spawning, shutdowns, implementation approvals, plan reviews. The PM monitors and maintains the dashboard.

```
Phase 2 startup:
  1. Spawn the Project Manager (pm-{PLAN_NAME}) using the PM spawn prompt.
  2. Spawn initial task-teams to fill concurrency slots.
     For each slot: find next pending unblocked task, create tasks/task-N/ directory,
     spawn team members ONE AT A TIME (executor-N, then reviewer-N, then tester-N),
     recording each pane ID via the diffing method after each spawn.
     After spawning all 3:
       SendMessage to PM "SPAWNED task-{N}: {task description}" then "STAGE task-{N} planning"
       SendMessage to knowledge-{PLAN_NAME}: "TASK-START: Task {N} — {task title}\nDescription: {task description}\nSuccess criteria: {success criteria}\nExecutor: executor-{N}\nPlan path (when available): documentation/plans/$ARGUMENTS/tasks/task-{N}/plan.md"

Lead loop:
WAIT for messages. Process each message, then return to waiting.

  --- From Executors ---
  a. Executor "Task {N} done — all stages passed" →
     Send shutdown_request to all team members (executor-{N}, reviewer-{N}, tester-{N}).
     SendMessage to PM: "COMPLETED task-{N}" then "SHUTDOWN task-{N}"
     Check: does this task have a pipeline-spawned successor awaiting implementation approval?
       → If yes: SendMessage to successor executor-{M}: "Implementation approved — predecessor passed all stages. Proceed to implement."
         SendMessage to PM: "APPROVED-IMPL task-{M}"
     Check: does the freed slot allow spawning the next pending task?
       → If yes: spawn next unblocked task, SendMessage to PM: "SPAWNED task-{M}: {description}" then "STAGE task-{M} planning"

  b. Executor "Task {N} implementation complete — entering review/test phase" →
     SendMessage to PM: "STAGE task-{N} review"
     Check: does this task have dependent successors still in "pending" state?
       → If yes: spawn successor in pipeline mode (planning only, implementation blocked).
         SendMessage to PM: "PIPELINE-SPAWN task-{M}" then "STAGE task-{M} planning"
         SendMessage to knowledge-{PLAN_NAME}: "TASK-START: Task {M} — {task title}\nDescription: {task description}\nSuccess criteria: {success criteria}\nExecutor: executor-{M}\nPlan path (when available): documentation/plans/$ARGUMENTS/tasks/task-{M}/plan.md"
         Pipeline-spawned tasks in planning-only mode do NOT count against the concurrency limit.

  c. Executor "Task {N} plan ready for review" →
     SendMessage to PM: "STAGE task-{N} planning"
     Read tasks/task-{N}/plan.md. Evaluate domain coherence, architectural alignment,
     scope correctness. Reply to executor: APPROVED or CONCERNS with specifics.
     If APPROVED: SendMessage to PM: "STAGE task-{N} implementation"

  d. Executor "Task {N} planning complete — awaiting implementation approval" (pipeline-spawned) →
     Note it. Approval depends on predecessor completing — you will approve when predecessor passes.

  e. Executor "Task {N} escalation needed" → Escalate to user

  f. Executor "PLAN-INVALIDATING: ..." → Pause pipeline, evaluate, amend plan

  --- From PM ---
  g. PM "Dashboard live at {URL}" → Output URL to user
  h. PM "ALERT: ..." → Act on recommendation (re-spawn agent, pause spawning, etc.)
     After acting, send appropriate status update to PM.

  Checkpoint if triggered.
  Fill pipeline slots whenever a slot frees up → SendMessage to PM "SPAWNED task-{N}: ..." for each.
```

### Lead Priority Order

1. **Executor "task done"** — shutdown team, check pipeline successors, fill slots.
2. **Executor plan reviews** — blocking gate (domain coherence).
3. **Executor "implementation complete"** — pipeline spawn decisions.
4. **PM alerts** — act on recommendations.
5. **Escalations** — relay to user.
6. **Checkpoint** — periodic save per Phase 3 triggers.

### Spawn Prompts

All team members for a task are spawned at once. Each gets: task context, paths to read, output path, **names of ALL teammates**.

Use the Agent tool with `team_name` set to the active team. **MANDATORY naming convention** — the `name` parameter MUST follow exactly `{role}-{N}` where role is one of `executor`, `reviewer`, `tester` and N is the task number:

| Task | Executor | Reviewer | Tester |
|------|----------|----------|--------|
| 1 | `executor-1` | `reviewer-1` | `tester-1` |
| 2 | `executor-2` | `reviewer-2` | `tester-2` |
| N | `executor-N` | `reviewer-N` | `tester-N` |

**Shared (plan-wide):** `knowledge-{PLAN_NAME}` — spawned once, serves all tasks.

**NEVER** use alternative formats like `task-1-executor`, `e1`, `Executor_1`, or descriptive names. The `/uc:tmux-team-grid` skill depends on this exact `{role}-{N}` pattern to organize panes.

#### Pane Title Tracking (MANDATORY)

Agents cannot reliably set their own tmux pane titles (some don't have Bash access, others skip the instruction). The **Lead identifies pane IDs** at spawn time and the **PM sets the titles** as an operational task.

**Lead's responsibility — identify pane IDs via diffing:**

Agents must be spawned **one at a time** (not all 3 in a single message with parallel tool calls). Between each spawn, diff the pane list to capture which new pane appeared:

```
For EACH agent spawn:
  1. Before: PANES_BEFORE=$(tmux list-panes -F '#{pane_id}' | sort)
  2. Spawn the agent (single Agent tool call)
  3. After:  PANES_AFTER=$(tmux list-panes -F '#{pane_id}' | sort)
  4. Find new pane: NEW_PANE=$(comm -13 <(echo "$PANES_BEFORE") <(echo "$PANES_AFTER"))
  5. Record the mapping: {agent-name} = {NEW_PANE}
```

After spawning all members of a task-team, include the pane mapping in the SPAWNED message to PM:

```
SendMessage to PM: "SPAWNED task-{N}: {description} | panes: executor-{N}=%XX reviewer-{N}=%YY tester-{N}=%ZZ"
```

For shared agents, include pane IDs in their respective messages:
- After spawning knowledge: `"SPAWNED knowledge-{PLAN_NAME} | pane: %XX"`
- After spawning PM: set PM's own title directly since PM isn't alive yet to receive a message: `tmux select-pane -t "$NEW_PANE" -T "pm-{PLAN_NAME}"`

**PM's responsibility — set pane titles:**

See the PM agent instructions. On receiving any SPAWNED message with `| panes:` data, PM parses the pane IDs and sets tmux titles immediately.

#### Executor Spawn

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

**Proactive research:** The Tech Knowledge agent has been notified about your task and may send you a RESEARCH BRIEF with relevant external documentation before you start. Read it — it contains current docs for the technologies your task involves, which may differ from what you remember from training data.

**Workflow:**
1. Read context files above. Check for a RESEARCH BRIEF from the knowledge agent — if it arrived, read it before proceeding.
2. Explore the codebase yourself using Read/Glob/Grep — understand existing patterns, related implementations, and integration points
3. Write your implementation plan to `documentation/plans/$ARGUMENTS/tasks/task-{N}/plan.md`
4. SendMessage to reviewer-{N}: "Plan ready for feedback — written to tasks/task-{N}/plan.md. Review from your perspective. Reply LGTM or CONCERNS."
5. Wait for feedback response. If CONCERNS: address in plan, notify the teammate, then proceed.
5.5 For external library questions, query knowledge-{PLAN_NAME} with "QUERY: {question}". Begin implementing non-dependent parts while waiting for answers.
5.7 SendMessage to Lead ({lead name}): "Task {N} plan ready for review — written to tasks/task-{N}/plan.md". Wait for Lead's approval or concerns before implementing.
5.9 {If pipeline_spawned:} See your agent instructions step 3.9 — send "Planning complete — awaiting implementation approval" to Lead ({lead name}) and WAIT before implementing.
6. Implement the task. As you complete each file, send a progress update to reviewer-{N}: "Progress: completed {file path} — you can start reading"
7. Write implementation notes to the output path
8. SendMessage to Lead ({lead name}): "Task {N} implementation complete — entering review/test phase"
9. SendMessage to BOTH reviewer-{N}: "Ready for review — files changed: {list}" AND tester-{N}: "Ready for test — implementation complete, files changed: {list}" simultaneously
10. Process review AND test feedback in parallel — both must PASS. If either FAILs, fix code, reset both verdicts to pending, and send "Ready for re-review" to reviewer-{N} AND "Ready for re-test" to tester-{N} simultaneously (see agent instructions step 5).
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

#### Reviewer Spawn

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

#### Tester Spawn

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

#### Final Gate Tester Spawn

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

#### Project Manager Spawn

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
- "ALERT: {agent}-{N} stalled for 13+ minutes, recommend re-spawn"
- "ALERT: Rate limit suspected — recommend pause spawning"
- "ALERT: {agent}-{N} unresponsive after rate limit recovery, recommend re-spawn"

**Workflow:**
1. Start the background watchdog script (see agent instructions — it survives rate limits):
   ```bash
   nohup ${CLAUDE_PLUGIN_ROOT}/scripts/pipeline-watchdog.sh "documentation/plans/$ARGUMENTS" 300 > /dev/null 2>&1 &
   echo $! > "documentation/plans/$ARGUMENTS/watchdog.pid"
   ```
2. Read the full plan: `documentation/plans/$ARGUMENTS/README.md`
3. Read lead notes: `documentation/plans/$ARGUMENTS/shared/lead.md`
4. Initialize the status dashboard (see agent instructions: create directories, write initial JSONs, launch dashboard, expose via Tailscale)
5. SendMessage to Lead ({lead name}): "Dashboard live at {DASHBOARD_URL} (also http://localhost:3847)"
6. Begin your monitoring loop (see agent instructions):
   - Process status update messages from Lead — update dashboard JSON files accordingly
   - Every 5 minutes: read watchdog data, check file modification times
   - If any task-team is silent for 10+ minutes, ping the relevant member for status
   - If multiple agents go silent simultaneously, suspect rate limit — ALERT Lead
   - After YOU recover from a rate limit, read watchdog.log to catch up
7. When Lead sends you "Execution complete — write operational report":
   - Kill the watchdog: `kill "$(cat documentation/plans/$ARGUMENTS/watchdog.pid)" 2>/dev/null`
   - Read watchdog.log one final time for complete incident data
   - Compile your full operational report following the template in your agent instructions
   - Write it to `documentation/plans/$ARGUMENTS/operational-report.md`
   - SendMessage to Lead ({lead name}): "Operational report saved to operational-report.md"
8. Wait for Lead's shutdown_request. Approve it to exit.
```

### Plan Review

Executors write implementation plans to `tasks/task-N/plan.md` and request feedback at two levels:

**Level 1 — Teammate review (advisory):** Executor sends plan to Reviewer for technical feedback. This happens first and is advisory — Reviewer replies LGTM or CONCERNS, Executor addresses and proceeds.

**Level 2 — Lead review (domain/coherence gate):** After teammate feedback, Executor sends plan directly to Lead for domain and coherence review. The Lead checks:
- Does this plan align with the overall plan objective and scope?
- Is it coherent with what other tasks are doing (no conflicts, no duplication)?
- Does the approach fit the project's domain and architecture vision?

**Lead replies directly to Executor:** APPROVED or CONCERNS with specifics. This is a **blocking gate** — Executor must not implement until Lead approves.

**Why two levels:** Teammates catch technical issues (patterns, standards, feasibility). Lead catches strategic issues (scope creep, cross-task coherence, domain alignment). The PM is NOT involved in plan review — this is a technical/domain decision channel.

### Communication Model

**Two channels — orchestration (Lead) and monitoring (PM):**

- **Team-internal**: Executor↔Reviewer, Executor↔Tester — direct peer-to-peer
- **Knowledge queries**: Any team member → knowledge-{PLAN_NAME} — "QUERY: {question}" for external library docs
- **Executor → Lead**: ALL operational status — "implementation complete", "task done", "escalation needed", plan reviews, plan-invalidating discoveries
- **Lead → Executor**: Plan review responses (APPROVED/CONCERNS), implementation approvals for pipeline-spawned tasks, shutdown_request
- **Lead → PM**: Terse status updates (`SPAWNED task-1: ...`, `COMPLETED task-2`, `STAGE task-3 review`, etc.)
- **PM → Lead**: Dashboard URL (once at startup), health ALERTs (stalls, rate limits)
- **PM → any team member**: Status checks for monitoring purposes
- **Executor drives the pipeline** internally — it tells teammates when to act and processes their feedback

---

## Phase 3: Checkpoint

### Triggers

Save a checkpoint when ANY of these occur:
- Every 3 completed tasks
- User runs `/uc:checkpoint`
- Before risky plan amendments

### Content

Write to `documentation/plans/$ARGUMENTS/checkpoint-{YYYY-MM-DD-HHmm}.md`:

```markdown
# Checkpoint: $ARGUMENTS

**Saved:** {ISO timestamp}

## Active Pipeline Teams

| Task | Active Team Members | Notes |
|------|---------------------|-------|
| task-1 | E-1, Rev-1, T-1 | In review stage |
| task-2 | E-2, Rev-2, T-2 | Implementing |

## Task Pipeline Status

| # | Task | Stage | Retry | Notes |
|---|------|-------|-------|-------|
| 1 | JWT middleware | done | 0 | All stages passed |
| 2 | Login endpoint | review | 1 | Retry after review fail |
| 3 | Env config | active | 0 | In implementation |
| 4 | User model | pending | 0 | Blocked by task 1 |
| 5 | Dashboard  | planning | 0 | Pipeline-spawned, awaiting task 3 |

## Progress Summary

- Done: N/{total} tasks
- In pipeline: M tasks (planning: A, impl: B, review: C, test: D)
- Pending: K tasks

## Decisions Made

- {decision}: {rationale}

## Files Modified

- {path} — {created/modified} — {purpose}

## Blockers

- {description}: {status}
```

Note: `shared/lead.md` and `tasks/*/` files are already on disk — no need to duplicate in checkpoint.

---

## Phase 4: Failure Handling

### Retry Flow (Team-Internal)

Failures are handled entirely within the task-team — no Lead involvement:

1. Reviewer/Tester sends FAIL verdict directly to Executor
2. Executor fixes code, updates `tasks/task-N/impl.md`
3. Executor tells Reviewer/Tester "ready for re-review/re-test"
4. Same Reviewer/Tester re-evaluates (they're still alive with full context)
5. Repeat up to 10 fix cycles total

If 10 cycles exceeded: Executor tells Lead "escalation needed" with history.

### Escalation to User

When the Lead receives an escalation:

```
Task "{name}" has exceeded 10 fix cycles.

Latest failure:
  {reviewer/tester feedback summary}

Fix history:
  {brief summary of each cycle's feedback}

Options:
1. Provide additional guidance for the executor
2. Skip this task
3. Abort execution
```

### Team Member Crash

Lead detects: idle notification without preceding "task done" message, or extended silence.

Recovery:
1. Re-spawn the crashed role into the existing team with per-task file context
2. Include names of surviving teammates in the spawn prompt
3. Surviving teammates continue — Executor drives re-coordination
4. Log crash in `shared/lead.md`

### Session Death

Handled automatically by Phase 1.2 (Resume Detection) when user reruns `/uc:plan-execution $ARGUMENTS`. Checkpoint + `shared/lead.md` + `tasks/*/` files preserve all progress. Lead reconstructs task state from metadata.stage and per-task files on disk, then re-spawns teams for incomplete tasks.

---

## Phase 5: Completion

### 5.1 All Tasks Done

When all tasks reach "done" stage (all task-teams have exited).

### 5.2 Final Gate

Spawn a single Final Gate Tester (fresh agent) for full regression suite:
- Use pane-diffing to capture the pane ID, then set the title directly: `tmux select-pane -t "$NEW_PANE" -T "final-gate"`
- Use the Final Gate Tester spawn prompt above
- If PASS: proceed to operational report
- If FAIL: evaluate whether to re-spawn task-teams for specific fixes or report to user

### 5.3 Collect Operational Report

SendMessage to the Project Manager (`pm-{PLAN_NAME}`): "Execution complete — write operational report"

Wait for PM's confirmation that `operational-report.md` is saved.

Then send `shutdown_request` to the Project Manager.

### 5.4 Produce Summary

Append to `documentation/plans/$ARGUMENTS/shared/lead.md`:

```markdown
## Execution Complete

**Plan:** $ARGUMENTS
**Tasks:** N completed, M skipped, K escalated

### Tasks Completed
- {task}: {brief description of what was done}

### Files Modified
- {path} — {created/modified}

### Decisions Made During Execution
- {decision}: {rationale}

### Test Results
- Per-task tests: X/Y passed
- Final gate (full suite): PASS/FAIL

### Follow-up Items
- {any recommendations or remaining work}
```

### 5.5 Shutdown

1. All task-teams have already self-exited after their tasks passed
2. Final Gate Tester exits after reporting
3. Project Manager exits after delivering operational report
4. Knowledge agent exits last (send shutdown_request to `knowledge-{PLAN_NAME}` after PM exits)
5. Keep plan directory with all artifacts (including `operational-report.md`)
6. Present summary to user — mention that the operational report is available at `documentation/plans/$ARGUMENTS/operational-report.md`

---

## Mid-Execution Plan Changes

When a teammate discovers something that invalidates part of the plan (from executor directly):

1. **Receive urgent message** with evidence
2. **Pause pipeline** — do not spawn new task-teams
3. **Evaluate scope:**
   - **Single task affected** — update task description, let current team handle it
   - **Multiple tasks affected** — write amendment to `shared/lead.md`, update affected tasks, cancel pending tasks if necessary
   - **Plan fundamentally wrong** — escalate to user with evidence. User decides: amend or abort.
4. **Resume pipeline** after resolution

---

## Communication Protocol

| Channel | Direction | Use For |
|---------|-----------|---------|
| **Team-internal** | Executor↔Reviewer, Executor↔Tester | Direct peer-to-peer within the task team. Technical collaboration. |
| **Knowledge query** | Any team member → knowledge-{PLAN_NAME} | "QUERY: {question}" for external library docs. Returns verbatim excerpts. |
| **Knowledge task-start** | Lead → knowledge-{PLAN_NAME} | "TASK-START: Task {N} — ..." on task spawn. Knowledge agent proactively researches and sends RESEARCH BRIEF to executor. |
| **Knowledge load** | Lead → knowledge-{PLAN_NAME} | "LOAD: {technology}" to add docs mid-execution. |
| **Plan review (teammate)** | Executor → Reviewer | Advisory feedback on `tasks/task-N/plan.md`. Reviewer replies LGTM/CONCERNS. |
| **Plan review (Lead)** | Executor → Lead | Domain/coherence review of plan. **Blocking gate.** Lead replies APPROVED/CONCERNS. |
| **Operational status** | Executor → Lead | "Implementation complete", "task done", "escalation needed", "planning complete". Lead acts directly. |
| **Lead spawns teams** | Lead → Agent tool | Lead spawns task-teams directly. |
| **Lead shuts down teams** | Lead → team members | Lead sends shutdown_request directly after executor reports "task done". |
| **Lead approves pipeline** | Lead → Executor | Lead approves pipeline implementations when predecessor passes. |
| **Lead → PM** | Lead → PM | Terse status updates (`SPAWNED`, `COMPLETED`, `STAGE`, `SHUTDOWN`, etc.) for dashboard. |
| **PM → Lead** | PM → Lead | Dashboard URL (startup), health ALERTs (stalls, rate limits). |
| **PM → team members** | PM → any agent | Status checks for monitoring purposes only. |
| **Per-task files** | Persistent | `tasks/task-N/plan.md`, `tasks/task-N/impl.md` — pipeline artifacts. |

---

## Lead Behavior

You are the **orchestrator and domain authority**. You spawn teams, manage shutdowns, approve pipeline implementations, review plans, and handle escalations. You send terse status updates to PM after each action so it keeps the dashboard current.

### What You Do
- Spawn task-teams to fill concurrency slots
- Shut down completed teams (send shutdown_request to all members)
- Approve implementation for pipeline-spawned tasks
- Review executor plans for domain coherence and cross-task alignment (APPROVED/CONCERNS)
- Handle escalations (relay to user)
- Handle plan-invalidating discoveries (pause, evaluate, amend)
- Send status updates to PM after each action (SPAWNED, COMPLETED, STAGE, SHUTDOWN, etc.)
- Checkpoint when triggered
- Run Phase 5 when all tasks are done

### What You Do NOT Do
- Narrate what agents are doing to the user
- Comment on state transitions to the user
- Send verbose status summaries (PM status updates are terse one-liners)

### Anti-Patterns

Real examples from past executions — do NOT produce output like this:
- "Executor-1 is idle waiting for knowledge agent response. Normal flow..."
- "Tester-1 ready and waiting. All team members standing by"
- "Plan looks solid." (unless formal APPROVED response to plan review)
- "Executor-1 processing the approval"
- "Executor-1 has finished implementation and notified both"

---

## Constraints

- Never write implementation code — you orchestrate, not implement
- Never skip user confirmation before spawning teams
- Never narrate or comment on operational events to the user
- Always send terse status updates to PM after spawning, shutdowns, stage transitions
- Always checkpoint before session end
- Max 10 fix cycles per task before escalating to user
- Always run final gate test suite before declaring completion
- Keep shared/lead.md updated with all decisions and amendments
