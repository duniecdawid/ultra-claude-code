---
name: plan-execution
description: Executes approved plans through per-task pipeline teams. Each task gets a dedicated mini-team (Executor/Reviewer/Tester) that self-coordinates internally, plus a shared Tech Knowledge team member for external library documentation. Lead spawns teams and tracks progress. Use when user says 'execute plan', 'run plan', 'start execution', or '/uc:plan-execution'. NEVER auto-trigger after plan approval — planning modes print the execution command for the user to run manually.
argument-hint: "plan number or name (e.g., '1', '001-user-auth')"
user-invocable: true
---

> **All work delegation in this skill happens through teammates (TeamCreate / SendMessage), not the Agent tool.** Teammates are persistent team members that stay alive, communicate peer-to-peer, and coordinate through the full task lifecycle. Never use the Agent tool for execution — always use TeamCreate to spawn and SendMessage to communicate.

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

**Quick setup check:** Read `~/.claude/uc-setup.json`. If missing or `version` is older than the current plugin version (from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`), warn: "Run `/uc:setup` to configure your environment." Continue with the checks below regardless.

Before starting, verify:

1. Plan exists at `documentation/plans/$ARGUMENTS/README.md`
2. Agent teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` in settings)
3. tmux installed (required for agent teams)
4. Testing config: If `.claude/system-test.md` exists and `documentation/technology/testing/` does NOT exist, warn: "Testing config uses legacy format (.claude/system-test.md). Run `/uc:init-project` to migrate to documentation/technology/testing/." Continue execution — agents fall back gracefully.

If prerequisites 1-3 are missing, suggest running `/uc:setup` and stop.

---

## Phase 1: Setup

Read plan, detect resume state, decide concurrency, create tasks, spawn shared team members (PM + Knowledge).
→ Read `references/phase-1-setup.md`

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
- **Shared knowledge team member** — `knowledge-{PLAN_NAME}` is spawned once and serves all task teams with external library documentation.
- **ALL team members stay alive** through the full task lifecycle — they communicate directly via SendMessage until the task passes all stages.
- **Executor is the team coordinator** — it drives the pipeline sequence internally and does its own codebase research.
- **Lead is the orchestrator** — spawns teams, shuts down teams, approves pipeline implementations, reviews plans for coherence, handles escalations.
- **PM is the monitoring layer** — maintains the dashboard, detects stalls/rate limits, sends ALERTs to Lead with recommendations.
- **Reviewer and Tester can query the knowledge team member** if they need external library documentation during their work.
- **Max 10 fix cycles** between executor/reviewer/tester before escalating to Lead → user.

### Team Composition

Every task gets the same team: **Executor + Reviewer + Tester**. The shared Tech Knowledge team member (`knowledge-{PLAN_NAME}`) serves all tasks.

### Orchestration Loop

The Lead handles all orchestration — spawning, shutdowns, implementation approvals, plan reviews. The PM monitors and maintains the dashboard.

```
Phase 2 startup:
  1. Spawn initial task-teams to fill concurrency slots.
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
  g. PM "Dashboard live at {URL}" → IMMEDIATELY display the URL to the user as a visible message:
     "📊 Live dashboard: {URL}" — this is the user's primary way to monitor execution.
     Do NOT silently consume this message. The user needs the link.
  h. PM "ALERT: ..." → Act on recommendation (re-spawn team member, pause spawning, etc.)
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

When ready to spawn teammates, read the detailed spawn prompts for each role.
→ Read `references/phase-2-spawn-prompts.md`

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

Save a checkpoint when ANY of these occur:
- Every 3 completed tasks
- User runs `/uc:checkpoint`
- Before risky plan amendments

When triggered → Read `references/phase-3-checkpoint.md` for the checkpoint template and content format.

---

## Phase 4: Failure Handling

Retry flow, escalation, crash recovery, session death.
→ Read `references/phase-4-failure-handling.md`

---

## Phase 5: Completion

Final gate, operational report, summary, shutdown.
→ Read `references/phase-5-completion.md`

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
| **Knowledge task-start** | Lead → knowledge-{PLAN_NAME} | "TASK-START: Task {N} — ..." on task spawn. Knowledge team member proactively researches and sends RESEARCH BRIEF to executor. |
| **Knowledge load** | Lead → knowledge-{PLAN_NAME} | "LOAD: {technology}" to add docs mid-execution. |
| **Plan review (teammate)** | Executor → Reviewer | Advisory feedback on `tasks/task-N/plan.md`. Reviewer replies LGTM/CONCERNS. |
| **Plan review (Lead)** | Executor → Lead | Domain/coherence review of plan. **Blocking gate.** Lead replies APPROVED/CONCERNS. |
| **Operational status** | Executor → Lead | "Implementation complete", "task done", "escalation needed", "planning complete". Lead acts directly. |
| **Lead spawns teams** | Lead → TeamCreate | Lead spawns task-teams directly. |
| **Lead shuts down teams** | Lead → team members | Lead sends shutdown_request directly after executor reports "task done". |
| **Lead approves pipeline** | Lead → Executor | Lead approves pipeline implementations when predecessor passes. |
| **Lead → PM** | Lead → PM | Terse status updates (`SPAWNED`, `COMPLETED`, `STAGE`, `SHUTDOWN`, etc.) for dashboard. |
| **PM → Lead** | PM → Lead | Dashboard URL (startup), health ALERTs (stalls, rate limits). |
| **PM → team members** | PM → any team member | Status checks for monitoring purposes only. |
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
- **Display the dashboard URL to the user** when PM sends it — this is the user's primary monitoring tool
- Checkpoint when triggered
- Run Phase 5 when all tasks are done

### What You Do NOT Do
- Narrate what team members are doing to the user
- Comment on state transitions to the user
- Send verbose status summaries (PM status updates are terse one-liners)
- Silently consume the PM's dashboard URL without showing it to the user

### Anti-Patterns

Real examples from past executions — do NOT produce output like this:
- "Executor-1 is idle waiting for knowledge team member response. Normal flow..."
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
