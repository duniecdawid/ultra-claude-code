---
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

**Quick setup check:** Read `~/.claude/ultra/uc-setup.json`. If missing or `version` is older than the current plugin version (from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`), warn: "Run `/uc:setup` to configure your environment." Continue with the checks below regardless.

Before starting, read:
- `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/SKILL.md` — task executors write to `documentation/` and must follow docs-manager structure, references, and routing rules.

Then verify:

1. Plan exists at `documentation/plans/$ARGUMENTS/README.md`
2. Agent teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` in settings)
3. tmux installed (required for agent teams)
4. Testing config: Verify `documentation/technology/testing/` exists. If missing, warn: "No testing configuration found. Run `/uc:migrate` to set up documentation/technology/testing/." Continue execution — agents will have limited testing guidance.

If prerequisites 1-3 are missing, suggest running `/uc:setup` and stop.

---

## Phase 1: Setup

Read plan, detect resume state, decide concurrency, create tasks, spawn shared team members (PM + Knowledge).
→ Read `references/phase-1-setup.md`

---

## Phase 2: Pipeline Orchestration

Each task gets a dedicated mini-team that self-coordinates internally. The **Lead** orchestrates everything — spawning executor + reviewer, lazy-spawning the tester, managing shutdowns, reviewing plans. The **PM** maintains the dashboard and monitors usage.

### How a Task-Team Works

Executor and Reviewer spawn together at task start. Tester is lazy-spawned when implementation is complete:

```
Executor:   explores codebase → plans → sends plan to Reviewer (advisory) then Lead (blocking)
            → queries knowledge-{PLAN_NAME} for external library docs as needed
            → sends per-file progress updates to Reviewer during implementation
            → signals Lead "implementation complete" (Lead spawns Tester)
            → tells Reviewer "ready for review" AND Tester "ready for test" simultaneously
            → sends STAGE-DONE / RETRY directly to PM for dashboard tracking
Reviewer:   reads standards + architecture early → advisory plan feedback → reads files as executor progresses
            → formal review on "ready for review" → sends PASS/FAIL to Executor
Tester:     (lazy-spawned after implementation) reads context → tests against PRODUCT DOCS
            → sends PASS/FAIL to Executor (in parallel with Reviewer)
            → if FAIL: Executor fixes → "Ready for re-review" + "Ready for re-test" sent to both simultaneously
Both PASS:  Executor tells Lead "task done" → Lead sends shutdown_request → team exits
```

**Key principles:**
- **ONE dedicated team per task, NO sharing.** Task 1 gets its own Executor-1, Reviewer-1, Tester-1. Task 2 gets its own set. They never cross.
- **Reviewer spawns early** — the Reviewer has unique context (standards, architecture, technology docs) and applies it continuously: plan feedback, early file reading, and formal review. This catches pattern mistakes before they spread.
- **Tester is lazy-spawned** — the Tester is spawned by the Lead when the Executor signals "implementation complete". This saves tester token spend by avoiding idle waiting during planning/implementation.
- **Shared knowledge team member** — `knowledge-{PLAN_NAME}` is spawned once and serves all task teams with external library documentation.
- **Executor is the team coordinator** — it drives the pipeline sequence internally and does its own codebase research.
- **Lead is the orchestrator** — spawns executor + reviewer, lazy-spawns tester, shuts down teams, reviews plans for coherence, handles escalations.
- **PM is the monitoring layer** — maintains the dashboard, tracks parallel review/test timing, monitors usage limits.
- **Reviewer and Tester can query the knowledge team member** if they need external library documentation during their work.
- **Max 10 fix cycles** between executor/reviewer/tester before escalating to Lead → user.

### Team Composition

Every task gets the same team: **Executor + Reviewer + Tester**. The shared Tech Knowledge team member (`knowledge-{PLAN_NAME}`) serves all tasks.

### Orchestration Loop

The Lead handles all orchestration — spawning, shutdowns, implementation approvals, plan reviews. The PM monitors and maintains the dashboard.

```
Phase 2 startup:
  1. Spawn initial task-teams to fill concurrency slots.
     For each slot: find next pending unblocked task (all dependencies completed),
     create tasks/task-N/ directory, spawn executor-N and reviewer-N in parallel.
     (Tester-N is spawned later, after implementation complete.)
     After spawning:
       SendMessage to PM "SPAWNED task-{N}: {task description}" then "STAGE task-{N} planning"
       SendMessage to knowledge-{PLAN_NAME}: "TASK-START: Task {N} — {task title}\nDescription: {task description}\nSuccess criteria: {success criteria}\nExecutor: executor-{N}\nPlan path (when available): documentation/plans/$ARGUMENTS/tasks/task-{N}/plan.md"

Lead loop:
WAIT for messages. Process each message, then return to waiting.

  --- From Executors ---
  a. Executor "Task {N} done — all stages passed" →
     Send shutdown_request to all team members (executor-{N}, reviewer-{N}, tester-{N}).
     SendMessage to PM: "COMPLETED task-{N}" then "SHUTDOWN task-{N}"
     Check: does the freed slot allow spawning the next pending task?
       → Find next unblocked task (all dependencies completed).
       → If found: spawn executor-{M}, SendMessage to PM: "SPAWNED task-{M}: {description}" then "STAGE task-{M} planning"

  b. Executor "Task {N} implementation complete — entering review/test phase" →
     Spawn tester-{N} (reviewer-{N} is already alive from task start).
     SendMessage to PM: "SPAWNED-TESTER task-{N}"
     SendMessage to PM: "STAGE task-{N} review" then "STAGE task-{N} testing"
     SendMessage to Executor: "Tester spawned — proceed to drive review/test"

  c. Executor "Task {N} plan ready for review" →
     SendMessage to PM: "STAGE task-{N} planning"
     Read tasks/task-{N}/plan.md. Evaluate domain coherence, architectural alignment,
     scope correctness. Reply to executor: APPROVED or CONCERNS with specifics.
     If APPROVED: SendMessage to PM: "STAGE task-{N} implementation"

  d. Executor "Task {N} escalation needed" → Escalate to user

  e. Executor "PLAN-INVALIDATING: ..." → Pause, evaluate, amend plan

  --- From PM ---
  f. PM "Dashboard live at {URL}" → IMMEDIATELY display the URL to the user as a visible message:
     "📊 Live dashboard: {URL}" — this is the user's primary way to monitor execution.
     Do NOT silently consume this message. The user needs the link.
  g. PM "ALERT: ..." → Act on recommendation:
     - **"ALERT: USAGE-PAUSE ..."** → Enter usage pause mode:
       1. Do NOT spawn any new task-teams until USAGE-RESUME
       2. Note expected resume time in `shared/lead.md`
       3. Trigger checkpoint (Phase 3) — ensures clean recovery if session dies during pause
       4. Process incoming "task done" messages — shut down teams as tasks complete, but do NOT fill slots
       5. **Do NOT send status updates or queries to PM** — PM is in low-power mode (only checking usage every 5 min)
       6. **Do NOT query team members for status** — the system is idle, just wait
       7. Do NOT narrate the pause to the user — silence is expected
     - **"ALERT: USAGE-RESUME ..."** → Exit usage pause mode:
       1. Resume normal spawning — fill any empty concurrency slots (spawn fresh teams for remaining tasks)
       2. Update `shared/lead.md` to record the pause duration
       3. Send appropriate status updates to PM for any teams spawned

  Checkpoint if triggered.
  Fill slots whenever a slot frees up → SendMessage to PM "SPAWNED task-{N}: ..." for each.
```

### Lead Priority Order

1. **Executor "task done"** — shutdown team, fill slots with next unblocked task.
2. **Executor plan reviews** — blocking gate (domain coherence).
3. **Executor "implementation complete"** — lazy-spawn tester.
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
- On USAGE-PAUSE (saves state before potentially long pause)

When triggered → Read `references/phase-3-checkpoint.md` for the checkpoint template and content format.

---

## Phase 4: Failure Handling

Retry flow, escalation, crash recovery, session death.
→ Read `references/phase-4-failure-handling.md`

---

## Phase 5: Completion

Final gate, operational report, summary, shutdown.
→ Read `references/phase-5-completion.md`

**Follow-up work:** If execution revealed follow-up work, bugs, ideas, or tech debt not covered by the plan, list them in the completion summary under "Follow-up Items". Do NOT add them to the backlog automatically — saving to backlog NEVER happens without explicit user consent.

---

## Mid-Execution Plan Changes

### Discovered gaps (missing work that's in-scope)

When a teammate discovers that work covered by the plan's scope was missed in task breakdown (e.g., a server endpoint needed for a client feature to function):

1. **Assess effort:** Is this a focused piece of work (single file, single endpoint, < 1 task worth of effort)?
2. **If small:** Amend the current task's scope or add a new task to the plan. Write the amendment to `shared/lead.md`. Proceed with building it — do NOT defer to backlog or ask the user.
3. **If large:** Escalate to user — the gap is too big to silently add.
4. **Always log it:** Record every discovered gap and how it was handled in the completion summary under "Amendments" so the user has full visibility.

### Plan invalidations (from executor directly)

When a teammate discovers something that invalidates part of the plan:

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
| **Operational status** | Executor → Lead | "Implementation complete", "task done", "escalation needed", "plan-invalidating". Lead acts on these. |
| **Stage progress** | Executor → PM | "STAGE-DONE task-{N} {stage}", "RETRY task-{N}". PM updates dashboard directly. |
| **Lead spawns executor + reviewer** | Lead → TeamCreate | Lead spawns executor and reviewer when slot opens. |
| **Lead lazy-spawns tester** | Lead → TeamCreate | Lead spawns tester when executor signals "implementation complete". |
| **Lead shuts down teams** | Lead → team members | Lead sends shutdown_request directly after executor reports "task done". |
| **Pane self-labeling** | Agent local | Spawn prompt defines `TASK_ID`/`ROLE`; agent runs tmux label per agent instructions. PM verifies after SPAWNED. |
| **Lead → PM** | Lead → PM | Terse status updates (`SPAWNED`, `SPAWNED-TESTER`, `STAGE`, `COMPLETED`, `SHUTDOWN`, etc.) for dashboard. |
| **PM → Lead** | PM → Lead | Dashboard URL (startup), usage ALERTs. |
| **PM → team members** | PM → any team member | Status checks for monitoring purposes only. |
| **Per-task files** | Persistent | `tasks/task-N/plan.md`, `tasks/task-N/impl.md` — pipeline artifacts. |

---

## Lead Behavior

You are the **orchestrator and domain authority**. You spawn executor + reviewer pairs, lazy-spawn testers, manage shutdowns, review plans, and handle escalations. You send terse status updates to PM after each action so it keeps the dashboard current.

### What You Do
- Spawn executor + reviewer to fill concurrency slots (tasks spawn only when all deps are completed)
- Lazy-spawn tester when executor signals "implementation complete"
- Shut down completed teams (send shutdown_request to all members)
- Review executor plans for domain coherence and cross-task alignment (APPROVED/CONCERNS)
- Handle escalations (relay to user)
- Handle plan-invalidating discoveries (pause, evaluate, amend)
- Send status updates to PM after each action (SPAWNED, SPAWNED-TESTER, STAGE, COMPLETED, SHUTDOWN, etc.) — note: STAGE-DONE and RETRY go directly from Executor to PM
- **Display the dashboard URL to the user** when PM sends it — this is the user's primary monitoring tool
- Handle usage pause/resume from PM (defer spawning during pause, shut down teams as tasks complete, checkpoint on pause, go quiet until USAGE-RESUME)
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
- During USAGE-PAUSE: system is paused — do not spawn teams, do not query PM or team members, only process incoming "task done" to shut down teams, wait for USAGE-RESUME
- Always run final gate test suite before declaring completion (skip for single-task plans — per-task tester already covers it)
- Keep shared/lead.md updated with all decisions and amendments
