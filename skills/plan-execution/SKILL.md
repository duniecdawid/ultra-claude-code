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
            → writes code files, sends per-file progress updates to Reviewer
            → signals Lead "code complete — writing impl report" BEFORE writing impl.md
              (Lead spawns Tester + may pre-spawn the next dependent team in parallel)
            → writes tasks/task-N/impl.md while tester-N is cold-reading context
            → tells Reviewer "ready for review" AND Tester "ready for test" simultaneously
            → sends STAGE-DONE / RETRY directly to PM for dashboard tracking
Reviewer:   reads standards + architecture early → advisory plan feedback → reads files as executor progresses
            → formal review on "ready for review" → sends PASS/FAIL to Executor
Tester:     (lazy-spawned the moment code is done, before impl.md is written)
            → reads plan + product docs + testing config while executor finishes impl.md
            → tests against PRODUCT DOCS → sends PASS/FAIL to Executor (in parallel with Reviewer)
            → if FAIL: Executor fixes → "Ready for re-review" + "Ready for re-test" sent to both simultaneously
Both PASS:  Executor confirms teammates ready to exit → tells Lead "task done" → Lead sends shutdown_request → team exits
```

**Key principles:**
- **ONE dedicated team per task, NO sharing.** Task 1 gets its own Executor-1, Reviewer-1, Tester-1. Task 2 gets its own set. They never cross.
- **Reviewer spawns early** — the Reviewer has unique context (standards, architecture, technology docs) and applies it continuously: plan feedback, early file reading, and formal review. This catches pattern mistakes before they spread.
- **Tester is lazy-spawned (but early)** — the Tester is spawned by the Lead when the Executor signals `code complete — writing impl report`, which fires *before* the Executor writes `impl.md` or makes any commit. The Tester reads plan + product docs + testing config while the Executor finishes the impl report, hiding the Tester's cold-start latency behind work the Executor is doing anyway. Tester never sits idle during research or implementation — it's still lazy, just triggered a few seconds earlier.
- **Successor pre-spawn (pipeline)** — the same `code complete` signal also evaluates whether the next dependent task can start early. If there's a free concurrency slot and a pending task whose only remaining blocker is this task, the Lead pre-spawns that successor's Executor + Reviewer in `planning` stage. The pre-spawned Executor researches, plans, and receives Lead plan approval while the predecessor finishes review/test, then parks at a wait gate until Lead sends `Implementation approved` once the predecessor reaches `task done`. At most one pre-spawn per `code complete` event — no cascading chains.
- **Shared knowledge team member** — `knowledge-{PLAN_NAME}` is spawned once and serves all task teams with external library documentation.
- **Executor is the team coordinator** — it drives the pipeline sequence internally and does its own codebase research.
- **Lead is the orchestrator** — spawns executor + reviewer, lazy-spawns tester (early), pre-spawns successors when slots allow, shuts down teams, reviews plans for coherence, handles escalations.
- **PM is the monitoring layer** — maintains the dashboard, tracks parallel review/test timing, monitors usage limits.
- **Reviewer and Tester can query the knowledge team member** if they need external library documentation during their work.
- **Max 10 fix cycles** between executor/reviewer/tester before escalating to Lead → user.

### Team Composition

Every task gets the same team: **Executor + Reviewer + Tester**. The shared Tech Knowledge team member (`knowledge-{PLAN_NAME}`) serves all tasks.

### Phase 2 Startup

Spawn initial task-teams to fill concurrency slots. For each slot: find next pending unblocked task (all dependencies completed), create `tasks/task-N/` directory, spawn executor-N and reviewer-N in parallel. (Tester-N is spawned later, the moment the Executor signals `code complete`.)

After spawning each team:
- SendMessage to PM: `"SPAWNED task-{N}: {task description}"` then `"STAGE task-{N} planning"`
- SendMessage to knowledge-{PLAN_NAME}: `"TASK-START: Task {N} — {task title}\nDescription: {task description}\nSuccess criteria: {success criteria}\nExecutor: executor-{N}\nPlan path (when available): documentation/plans/$ARGUMENTS/tasks/task-{N}/plan.md"`

### Message Handlers

When you receive a message, match it against the table below and execute the action. Between messages, **be silent** — do NOT produce any text output to the user. The dashboard (maintained by PM) is how the user monitors progress.

**The ONLY user-visible outputs from the Lead during execution are:**
1. The dashboard URL (relay from PM)
2. Escalation questions (relay to user)
3. The Phase 5 completion summary

| Message | Action |
|---------|--------|
| Executor: `"Task {N} done — all stages passed"` | Send shutdown_request to executor-{N}, reviewer-{N}, tester-{N}. SendMessage to PM: `"COMPLETED task-{N}"` then `"SHUTDOWN task-{N}"`. **Then check for parked successors:** scan your `shared/lead.md` pipeline-parked list — if any pre-spawned executor-{M} is parked at the wait gate with its predecessor recorded as task-{N}, SendMessage to executor-{M}: `"Implementation approved — predecessor task {N} passed all stages. Proceed to implement."` and clear M from the parked list. **Then fill freed slot:** find the next unblocked, non-pre-spawned pending task → spawn if found (skip any task already running as a pre-spawned successor), SendMessage to PM: `"SPAWNED task-{K}: {description}"` then `"STAGE task-{K} planning"`. |
| Executor: `"Task {N} code complete — writing impl report"` | **Lazy-spawn tester-{N}** (use the Tester Spawn prompt from `references/phase-2-spawn-prompts.md`). SendMessage to PM: `"SPAWNED-TESTER task-{N}"`, `"STAGE task-{N} review"`, `"STAGE task-{N} testing"`. (Dashboard STAGE transitions fire here even though the actual review/test work starts ~30s later when the Executor finishes `impl.md` and sends `Ready for review/test` — the small overreporting window is intentional.) Reply to Executor: `"Tester spawned — proceed with impl report."` **Then evaluate pipeline pre-spawn:** find at most one pending task M where (a) all of M's blockers are `done` except for task N, (b) current active task-teams `<` concurrency limit, and (c) no other pre-spawned successor is already parked at the wait gate. If found: create `tasks/task-{M}/` directory, TeamCreate executor-{M} + reviewer-{M} using the phase-2 spawn prompts with the **Pipeline mode** block appended (predecessor task N noted in the prompt), set task-{M} stage = `planning`, record `M → blocked_by N` in the pipeline-parked list in `shared/lead.md`. SendMessage to PM: `"SPAWNED task-{M}: {description} (pipeline)"` then `"STAGE task-{M} planning"`. If no eligible successor or slot unavailable: do nothing — the normal slot-fill will handle it when task N reaches `task done`. |
| Executor: `"Task {M} planning complete — awaiting implementation approval"` | Pipeline-spawned executor has finished planning and Lead plan review, and is now parked at the wait gate. Confirm M is in your `shared/lead.md` parked list. No reply needed — the executor waits silently. When the predecessor's `task done` arrives, the done-row handler above will send the `Implementation approved` message. |
| Executor: `"Task {N} plan ready for review"` | SendMessage to PM: `"STAGE task-{N} planning"`. Read `tasks/task-{N}/plan.md`, evaluate domain coherence, architectural alignment, scope correctness. Reply to executor: APPROVED or CONCERNS with specifics. If APPROVED: SendMessage to PM: `"STAGE task-{N} implementation"`. (This works the same for pipeline-spawned tasks — approval lets the Executor finish planning, after which it parks at its own wait gate per its agent instructions.) |
| Executor: `"Task {N} escalation needed"` | Escalate to user with evidence. If any pre-spawned successor M is parked with N as its predecessor, note this in the escalation — the parked team stays alive while the user decides. On user "abort/skip": shut down parked M before proceeding. On user "continue/retry": M stays parked and will receive `Implementation approved` when N eventually reaches `task done`. |
| Executor: `"PLAN-INVALIDATING: ..."` | Pause pipeline. Evaluate scope. Amend or escalate. Parked pipeline successors stay parked through the pause. If the amendment drops or materially changes a parked successor's task, shut down that successor explicitly before resuming. |
| PM: `"Dashboard live at {URL}"` | Display to user immediately: `"📊 Live dashboard: {URL}"` — do NOT silently consume. |
| PM: `"ALERT: USAGE-PAUSE ..."` | Enter usage-pause mode (see below). |
| PM: `"ALERT: USAGE-RESUME ..."` | Exit usage-pause mode, resume spawning (see below). |
| PM: `"ALERT: STALL ..."` | Investigate — check if agent crashed, re-spawn if needed. |

After processing a message, return to waiting silently. Checkpoint if triggered. Fill slots whenever one frees up.

### Usage-Pause Protocol

**On USAGE-PAUSE:**
1. Do NOT spawn any new task-teams until USAGE-RESUME
2. Note expected resume time in `shared/lead.md`
3. Trigger checkpoint (Phase 3) — ensures clean recovery if session dies during pause
4. Process incoming "task done" messages — shut down teams as tasks complete, but do NOT fill slots
5. Do NOT send status updates or queries to PM — PM is in low-power mode
6. Do NOT query team members for status — the system is idle, just wait

**On USAGE-RESUME:**
1. Resume normal spawning — fill any empty concurrency slots (spawn fresh teams for remaining tasks)
2. Update `shared/lead.md` to record the pause duration
3. Send appropriate status updates to PM for any teams spawned

### Lead Priority Order

1. **Executor "task done"** — shutdown team, send `Implementation approved` to any parked successor, fill slots with next unblocked task.
2. **Executor plan reviews** — blocking gate (domain coherence).
3. **Executor "code complete"** — lazy-spawn tester + evaluate pipeline pre-spawn of the next dependent task.
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
- **Executor → Lead**: ALL operational status — "code complete — writing impl report", "planning complete — awaiting implementation approval" (pipeline-spawned only), "task done", "escalation needed", plan reviews, plan-invalidating discoveries
- **Lead → Executor**: Plan review responses (APPROVED/CONCERNS), "Tester spawned — proceed with impl report" confirmation, "Implementation approved" for pipeline-spawned tasks once their predecessor completes, shutdown_request
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
| **Operational status** | Executor → Lead | "Code complete — writing impl report", "planning complete — awaiting implementation approval" (pipeline-spawned), "task done", "escalation needed", "plan-invalidating". Lead acts on these. |
| **Pipeline pre-spawn** | Lead → TeamCreate | Lead pre-spawns the next dependent task's executor + reviewer when the predecessor signals `code complete` and a concurrency slot is free. Successor's spawn prompt includes Pipeline mode, so the executor parks at a wait gate after Lead plan approval. |
| **Implementation approval** | Lead → Executor (pipeline-spawned) | `"Implementation approved — predecessor task {N} passed all stages. Proceed to implement."` — sent to a parked executor when its predecessor reaches `task done`. |
| **Stage progress** | Executor → PM | "STAGE-DONE task-{N} {stage}", "RETRY task-{N}". PM updates dashboard directly. |
| **Lead spawns executor + reviewer** | Lead → TeamCreate | Lead spawns executor and reviewer when slot opens. |
| **Lead lazy-spawns tester** | Lead → TeamCreate | Lead spawns tester when executor signals "code complete — writing impl report" — i.e. before the executor writes `impl.md`, so the tester cold-reads context in parallel with the impl-report write. |
| **Lead shuts down teams** | Lead → team members | Lead sends shutdown_request after executor reports "task done" (executor first confirms all teammates replied "READY TO EXIT"). |
| **Pane self-labeling** | Agent local | Spawn prompt defines `TASK_ID`/`ROLE`; agent runs tmux label per agent instructions. PM verifies after SPAWNED. |
| **Lead → PM** | Lead → PM | Terse status updates (`SPAWNED`, `SPAWNED-TESTER`, `STAGE`, `COMPLETED`, `SHUTDOWN`, etc.) for dashboard. |
| **PM → Lead** | PM → Lead | Dashboard URL (startup), usage ALERTs. |
| **PM → team members** | PM → any team member | Status checks for monitoring purposes only. |
| **Per-task files** | Persistent | `tasks/task-N/plan.md`, `tasks/task-N/impl.md` — pipeline artifacts. |

---

## Lead Behavior

You are the **orchestrator and domain authority**. You spawn executor + reviewer pairs, lazy-spawn testers, manage shutdowns, review plans, and handle escalations. You send terse status updates to PM after each action so it keeps the dashboard current.

### What You Do
- Spawn executor + reviewer to fill concurrency slots (tasks normally spawn only when all deps are completed)
- Lazy-spawn tester the moment an Executor signals `code complete — writing impl report` (before impl.md is written)
- **Pre-spawn the next dependent task team** when an Executor signals `code complete` and a concurrency slot is free (pipeline mode) — at most one pre-spawn per event
- **Send `Implementation approved`** to a parked pipeline successor when its predecessor's `task done` arrives
- Shut down completed teams (send shutdown_request to all members)
- Review executor plans for domain coherence and cross-task alignment (APPROVED/CONCERNS) — works identically for pipeline-spawned tasks
- Handle escalations (relay to user, keep parked successors alive unless user aborts)
- Handle plan-invalidating discoveries (pause, evaluate, amend; shut down parked successors if their tasks are dropped)
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
- "Reviewed building context. Pipeline progressing."
- "Waiting for executor-1 plan submission"
- "Executor-2 is writing. Implementing approved plan."
- "Executor-1 passed review. Publishing."
- "Waiting for executor-1 results. Executor-2 building fast."
- "Shared documentation plan and style guide with executor-1 and executor-2."
- "Executor-1 is idle waiting for knowledge team member response. Normal flow..."
- "Tester-1 ready and waiting. All team members standing by"
- "Plan looks solid." (unless formal APPROVED response to plan review)
- "Executor-1 processing the approval"
- "Executor-1 has finished implementation and notified both"

**Why this matters:** Every text output from Lead burns context tokens and distracts the user. The dashboard exists for monitoring. The Lead's job is to process messages and take actions (spawn, shutdown, review, escalate) — not to narrate.

---

## Constraints

- Never write implementation code — you orchestrate, not implement
- Never spawn teams before the user answers the AskUserQuestion in section 1.5
- Never narrate or comment on operational events to the user
- Always send terse status updates to PM after spawning, shutdowns, stage transitions
- Always checkpoint before session end
- Max 10 fix cycles per task before escalating to user
- During USAGE-PAUSE: system is paused — do not spawn teams, do not query PM or team members, only process incoming "task done" to shut down teams, wait for USAGE-RESUME
- Always run final gate test suite before declaring completion (skip for single-task plans — per-task tester already covers it)
- Keep shared/lead.md updated with all decisions and amendments
