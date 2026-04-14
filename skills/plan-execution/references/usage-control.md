# Usage Control

This reference is read by Lead when PM forwards a usage alert from the watchdog. It guides Lead's decision on how to respond. Lead does NOT read this proactively or on every spawn — only when a usage-related message arrives from PM.

## Two Rate-Limit Windows

The watchdog monitors two independent rate-limit windows on every tick. Each has its own thresholds and its own reset. Signals are labeled with their window so Lead can track them separately.

| Window | SOFT-LIMIT | HARD-LIMIT | Typical reset horizon |
|--------|------------|------------|-----------------------|
| 5h     | ≥ 80%      | ≥ 90%      | Minutes to a few hours |
| 7d     | ≥ 90%      | ≥ 95%      | Hours to days          |

The two windows are independent. You may receive SOFT-LIMIT for both windows on the same tick, or HARD-LIMIT for one while the other is healthy. Handle each as a separate block in `shared/lead.md` under the `## Usage Blocks` section.

## Uniform Behavior Across Windows

Lead's response does not depend on *which* window tripped — only on whether the signal is SOFT or HARD. The window label is used for bookkeeping (which block to record, which block to clear on reset) but the action is the same.

### SOFT-LIMIT (5h ≥80% or 7d ≥90%)

Meaning: we are close to a limit but not yet at the wall. Finish in-flight work gracefully; don't start anything new.

1. **Do not stop active teams.** They finish their current task normally.
2. **Stop spawning new teams.** No slot-fill, no pipeline pre-spawn, no new pre-spawn of parked successors. Parked successors stay parked.
3. **Record the block** in `shared/lead.md` → `## Usage Blocks` → `{window}: soft`.
4. **On the next incoming `task done` message,** process the normal shutdown path AND trigger a Phase 3 checkpoint. This preserves state in case the next phase escalates to HARD-LIMIT.
5. Continue processing `task done` messages as they arrive — shut down teams, do NOT fill freed slots. Active team count monotonically decreases until zero or USAGE RESET arrives.

### HARD-LIMIT (5h ≥90% or 7d ≥95%)

Meaning: rate-limit wall imminent. Stop everything immediately.

1. **Stop all active teams immediately.** SendMessage each active executor, reviewer, and tester:
   `"STOP: usage emergency {window}={pct}%. Save work and stop."`
   Expect teams to return quickly. Any in-flight tool calls will complete but no new agent turns will start.
2. **Trigger a Phase 3 checkpoint immediately.** Do not wait for a `task done`.
3. **Record the block** in `shared/lead.md` → `## Usage Blocks` → `{window}: hard`.
4. **Do not spawn anything new.** Wait for USAGE RESET for ALL blocks.

There is no nuance here. At hard-limit, everything stops.

### USAGE RESET (per window)

Meaning: the specified window has dropped below its soft threshold or has rolled over to a fresh rate-limit window.

1. **Remove the entry for this window** from `shared/lead.md` → `## Usage Blocks`.
2. **If other usage blocks remain** (e.g., 5h reset while 7d is still at soft): stay paused. No spawning.
3. **If all blocks are cleared**: resume normal operations.
   - Reassess budget (same reasoning as pre-task-1 assessment — now with historical per-task cost data from PM).
   - Fill available concurrency slots with the next unblocked pending tasks.
   - Normal slot-fill resumes.

## Usage Blocks Tracking

`shared/lead.md` contains a `## Usage Blocks` section that is the source of truth for whether Lead may spawn new work. Initialize it at Phase 1 if missing:

```markdown
## Usage Blocks
- 5h: none
- 7d: none
```

On each SOFT or HARD signal, update the matching line to `soft` or `hard`. On each RESET, set the matching line back to `none`. While any line is non-`none`, Lead does not spawn. While any line is `hard`, active teams are stopped.

Optionally annotate each non-`none` entry with the timestamp and the `resets_at` field from PM's message — useful for the operational report and for the user if they ask about the pause:

```markdown
## Usage Blocks
- 5h: hard  (since 2026-04-14T14:12:00Z, resets_at 2026-04-14T15:00:00Z, pct=91)
- 7d: soft  (since 2026-04-14T14:08:00Z, resets_at 2026-04-18T00:00:00Z, pct=92)
```

## Pre-Task-1 Budget Assessment

Before spawning the first task-team, Lead reads the current usage percentages:

```bash
pct_5h=$(jq -r '.accounts | [.[]] | sort_by(.updated_at) | last | .rate_limits.five_hour.used_percentage // 0' ~/.claude/ultra/usage-status.json 2>/dev/null || echo 0)
pct_7d=$(jq -r '.accounts | [.[]] | sort_by(.updated_at) | last | .rate_limits.seven_day.used_percentage // 0' ~/.claude/ultra/usage-status.json 2>/dev/null || echo 0)
```

`pct_5h` and `pct_7d` are **used** percentages — how much of each rate-limit window has been consumed. `remaining = 100 - pct`.

If either window is already elevated, Lead reasons about whether the plan can complete within the remaining budget. Consider:
- Total number of tasks in the plan
- Complexity of the work (from task.md descriptions)
- Remaining percentage available for each window. The binding constraint is whichever window runs out first.

Lead may decide:
- **Proceed normally** — both windows are low (e.g., <50%), plenty of budget for the work.
- **Proceed with reduced concurrency** — one or both windows are moderate (e.g., 50-70%), run 1 team at a time instead of parallel.
- **Wait for reset** — one or both windows are high (e.g., 5h >70% with a large plan, or 7d >85%), too little budget remaining. Enter pre-emptive pause (same mechanism as low-power mode below). Inform the user if possible.

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

## Low-Power Mode (hard block or deliberate wait)

When Lead decides to stop all work (due to hard-limit, or a conscious pre-task-1 decision to wait for reset):

1. Ensure all teams have received stop/shutdown messages.
2. Record state in `shared/lead.md` → `## Usage Blocks` with timestamps.
3. Trigger Phase 3 checkpoint.
4. Wait for PM's `USAGE RESET [window]` message. The watchdog continues ticking every minute during the pause — it will detect the reset and signal PM, who forwards to Lead.
5. On USAGE RESET: clear that window's block. If ALL blocks cleared, resume operations. Otherwise stay paused.

Lead does NOT need to create its own cron during pause — the watchdog's cron is the heartbeat that detects the reset.

**Note on 7d reset horizon:** 7-day window resets can be hours or days away. If a 7d HARD-LIMIT triggers, execution may pause for a long time. Lead should inform the user when entering this state — the user may prefer to halt the plan entirely, switch accounts, or resume manually later rather than let the plan sit dormant for days.

## Completion Messages

When reporting task completion to PM, Lead includes the current 5h usage percentage (the tighter window is the one that matters for per-task budget tracking):

```
SendMessage PM: "COMPLETED task-{N}, current_pct={pct_5h}"
```

This feeds PM's per-task budget tracking. The `current_pct` is read from usage-status.json at completion time — one `jq` call, negligible cost.
