# Usage Control

This reference is read by Lead when PM forwards a usage alert from the watchdog. It guides Lead's decision on how to respond. Lead does NOT read this proactively or on every spawn — only when a usage-related message arrives from PM.

## Two Rate-Limit Windows

The watchdog monitors two independent rate-limit windows on every tick. Each has its own thresholds and its own reset. Signals are labeled with their window so Lead can track them separately.

| Window | CONSERVE | PAUSE | KILL | Typical reset horizon |
|--------|----------|-------|------|-----------------------|
| 5h     | ≥ 80%    | ≥ 90% | ≥ 95% | Minutes to a few hours |
| 7d     | ≥ 90%    | ≥ 95% | ≥ 98% | Hours to days          |

The two windows are independent. You may receive signals for both windows on the same tick. Handle each as a separate block in `shared/lead.md` under the `## Usage Blocks` section.

## Three-Tier Response

Lead's response depends on the **tier** of the signal, not which window triggered it. The window label is used for bookkeeping (which block to record, which block to clear on reset) but the action is the same across windows.

### CONSERVE (5h ≥80% or 7d ≥90%)

Meaning: budget is tightening. Finish in-flight work normally; don't start anything new.

1. **Do not stop active teams.** They finish their current task normally. No message is sent to team members.
2. **Stop spawning new teams.** No slot-fill, no pipeline pre-spawn, no new pre-spawn of parked successors. Parked successors stay parked.
3. **Record the block** in `shared/lead.md` → `## Usage Blocks` → `{window}: conserve`.
4. **On the next incoming `task done` message,** process the normal shutdown path AND trigger a Phase 3 checkpoint. This preserves state in case the next tier triggers.
5. Continue processing `task done` messages as they arrive — shut down teams, do NOT fill freed slots. Active team count monotonically decreases until zero or USAGE RESET arrives.

### PAUSE (5h ≥90% or 7d ≥95%)

Meaning: approaching the rate-limit wall. All agents must stop working and go idle.

1. **Send PAUSE to all active team members via the communication protocol** (signal append to each active task's `signals.jsonl` + SendMessage — see the `USAGE PAUSE` handler row in SKILL.md for the exact commands):
   `"PAUSE: usage {window}={pct}%. Go idle. You will receive RESUME when usage resets."`
   Agents stop work at their next natural checkpoint (between fix cycles) and go idle. Idle agents consume zero tokens.
2. **Trigger a Phase 3 checkpoint immediately.** Do not wait for a `task done`.
3. **Record the block** in `shared/lead.md` → `## Usage Blocks` → `{window}: pause`.
4. **Enter hold state.** While in hold state:
   - Do NOT respond to any ADVICE REQUEST or QUERY from paused agents. Responding could unblock agents to continue working.
   - Do NOT spawn anything new.
   - Wait for PM to forward `USAGE RESET` or `USAGE KILL` messages. These are the only messages Lead acts on during hold.
5. If a message arrives from a paused agent (straggler verdict, straggler ADVICE): discard it. The agent will re-send after RESUME if still relevant.

### KILL (5h ≥95% or 7d ≥98%)

Meaning: rate-limit wall hit. If agents didn't stop on PAUSE, force-terminate them.

1. **Write the SHUTDOWN signal to each active task's `signals.jsonl`, then kill all active task teams immediately via `shutdown_request`** (see the `USAGE KILL` handler row in SKILL.md for the exact commands). For each active task-team, send `shutdown_request` to executor-{N}, reviewer-{N}, and tester-{N} (if spawned). Use the protocol message format — do NOT use a plain text message. `shutdown_request` is the only mechanism that reliably terminates agents.
2. **Trigger a Phase 3 checkpoint immediately** (if not already triggered during PAUSE).
3. **Record the block** in `shared/lead.md` → `## Usage Blocks` → `{window}: kill`.
4. **Stay in hold state.** Same rules as PAUSE hold — no responses, no spawning. Wait for USAGE RESET.

There is no nuance at KILL tier. Everything stops immediately.

### USAGE RESET (per window)

Meaning: the specified window has dropped below its CONSERVE threshold or has rolled over to a fresh rate-limit window.

1. **Remove the entry for this window** from `shared/lead.md` → `## Usage Blocks`.
2. **If other usage blocks remain** (e.g., 5h reset while 7d is still at pause): stay in current state. No spawning, no resuming.
3. **If all blocks are cleared**, trigger recovery based on the highest tier that was reached:
   - **Recovering from CONSERVE only:** Resume normal operations — reassess budget, fill available concurrency slots with the next unblocked pending tasks.
   - **Recovering from PAUSE:** Execute the "Recovery After PAUSE" flow below.
   - **Recovering from KILL:** Execute the "Recovery After KILL" flow below.

## Recovery After PAUSE

When all usage blocks clear and agents were paused (not killed):

1. **Send RESUME to all paused agents via the communication protocol** (signal append to each active task's `signals.jsonl` + SendMessage — see the `USAGE RESET` handler row in SKILL.md for the exact commands):
   `"RESUME: usage reset. Continue work."`
2. **Agents resume with full context.** They pick up exactly where they stopped — no re-spawn, no re-read, no lost understanding. If an agent had completed a fix but not sent for re-review/re-test, it sends now. If it was mid-fix, it continues.
3. **Resume normal operations.** Reassess budget (same reasoning as pre-task-1 assessment — now with historical per-task cost data from PM). Fill available concurrency slots with the next unblocked pending tasks. Normal slot-fill resumes.

This is the cheapest recovery path — zero re-spawn cost, full context preserved.

## Recovery After KILL

When all usage blocks clear and agents were killed via `shutdown_request`:

1. **Read the latest checkpoint** written during the KILL stop.
2. **Read `shared/lead.md`** for the current task pipeline state.
3. **Identify tasks that were in-progress when killed.** These are tasks whose stage in the checkpoint is NOT `done` and NOT `pending`. Their task.md, plan.md, and possibly impl.md files are on disk.
4. **Re-spawn teams for in-progress tasks.** For each such task, run the Pre-Spawn Checklist from `references/phase-2-spawn-prompts.md` (ensure task.md exists, knowledge review). Then spawn the task team using the standard spawn prompts. The re-spawned agents will run the startup protocol from `task-team-startup.md`, read the existing per-task files, and infer their pipeline stage from file presence:
   - `task.md` only (no `plan.md`) → agent is in planning stage
   - `task.md` + `plan.md` (no `impl.md`) → agent is in implementation stage
   - `task.md` + `plan.md` + `impl.md` → agent is in review/test stage (Executor re-sends "ready for review" + "ready for test")
   This is identical to the crash-recovery flow in `phase-4-failure-handling.md`.
5. **Fill remaining concurrency slots** with pending unblocked tasks, following the normal Phase 2 slot-fill logic.
6. **Resume normal operations.** Send status updates to PM.

**Pipeline-parked successors** that were killed during KILL are NOT re-spawned in parked state. They are re-spawned as normal (non-pipeline) tasks once their predecessor completes, consistent with the "Session death while a successor is parked" rule in `phase-4-failure-handling.md`.

## PAUSE → KILL Escalation

If agents don't comply with PAUSE and usage reaches the KILL threshold, Lead goes **straight to `shutdown_request`** — no second PAUSE attempt. If the first PAUSE didn't work, a second won't help either.

## Usage Blocks Tracking

`shared/lead.md` contains a `## Usage Blocks` section that is the source of truth for whether Lead may spawn new work. Initialize it at Phase 1 if missing:

```markdown
## Usage Blocks
- 5h: none
- 7d: none
```

On each signal, update the matching line to `conserve`, `pause`, or `kill`. On each RESET, set the matching line back to `none`. While any line is non-`none`, Lead does not spawn. While any line is `pause` or `kill`, active teams are stopped or idle. Track the highest tier reached across both windows for recovery decisions.

Optionally annotate each non-`none` entry with the timestamp and the `resets_at` field from PM's message:

```markdown
## Usage Blocks
- 5h: pause  (since 2026-04-14T14:12:00Z, resets_at 2026-04-14T15:00:00Z, pct=91)
- 7d: conserve  (since 2026-04-14T14:08:00Z, resets_at 2026-04-18T00:00:00Z, pct=92)
```

## Pre-Task-1 Budget Assessment

Before spawning the first task-team, Lead waits for the watchdog's first-tick STATUS report, forwarded by PM:

`"USAGE STATUS: 5h={pct_5h}% 7d={pct_7d}%. Watchdog monitoring active."`

Do NOT read `usage-status.json` directly — the watchdog is the single source of truth for usage data. The STATUS message provides both windows' current percentages.

`pct_5h` and `pct_7d` are **used** percentages — how much of each rate-limit window has been consumed. `remaining = 100 - pct`.

If either window is already elevated, Lead reasons about whether the plan can complete within the remaining budget. Consider:
- Total number of tasks in the plan
- Complexity of the work (from task.md descriptions)
- Remaining percentage available for each window. The binding constraint is whichever window runs out first.

Lead may decide:
- **Proceed normally** — both windows are low (e.g., <50%), plenty of budget for the work.
- **Proceed with reduced concurrency** — one or both windows are moderate (e.g., 50-70%), run 1 team at a time instead of parallel.
- **Wait for reset** — one or both windows are high (e.g., 5h >70% with a large plan, or 7d >85%), too little budget remaining. Enter pre-emptive pause (same mechanism as hold state below). Inform the user if possible.

There is no formula. This is Lead's judgment call based on the scope of the plan and both window percentages.

## On STALE DATA from PM

PM forwards this when usage-status.json hasn't been updated for >5 minutes — meaning no agent has prompted recently. Possible causes: all agents stuck, system idle, or agents working on long tool calls.

Lead considers:
- Are there supposed to be active teams? (If paused, stale data is expected.)
- Has PM also reported stalls? (Stale data + stalls = systemic problem.)
- Is the staleness likely transient? (An agent running a long bash command won't prompt until it finishes.)

Lead may decide to investigate active teams or just note the warning.

## On STALL from PM

PM forwards this when an executor has been silent for >10 minutes despite being in_progress.

Lead investigates:
1. Check if the stalled executor has a long-running tool call in progress (may be normal).
2. If the executor appears genuinely stuck: re-spawn the task-team. The task.md, plan.md, and impl.md files provide re-spawn context per the failure-handling reference.
3. If multiple executors are stalled simultaneously: suspect a systemic issue (API problems, disk full, etc.) and consider pausing execution.

## Hold State (PAUSE/KILL block or deliberate wait)

When Lead has active usage blocks at PAUSE or KILL tier:

1. Ensure all teams have received PAUSE messages or shutdown_request.
2. Record state in `shared/lead.md` → `## Usage Blocks` with timestamps.
3. Trigger Phase 3 checkpoint.
4. Wait for PM's `USAGE RESET [window]` message. The watchdog continues ticking every minute during the pause — it will detect the reset and signal PM, who forwards to Lead.
5. On USAGE RESET: clear that window's block. If ALL blocks cleared, trigger the appropriate recovery flow (PAUSE or KILL). Otherwise stay in hold state.

Lead does NOT need to create its own cron during pause — the watchdog's cron is the heartbeat that detects the reset.

**Note on 7d reset horizon:** 7-day window resets can be hours or days away. If a 7d KILL triggers, execution may pause for a long time. Lead should inform the user when entering this state — the user may prefer to halt the plan entirely, switch accounts, or resume manually later rather than let the plan sit dormant for days.

## Completion Messages

When reporting task completion to PM, Lead includes the current 5h usage percentage (the tighter window is the one that matters for per-task budget tracking):

```
SendMessage PM: "COMPLETED task-{N}, current_pct={pct_5h}"
```

This feeds PM's per-task budget tracking. The `current_pct` is read from usage-status.json at completion time — one `jq` call, negligible cost.
