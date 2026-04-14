# Usage Control

This reference is read by Lead when PM forwards a usage alert from the watchdog. It guides Lead's decision on how to respond. Lead does NOT read this proactively or on every spawn — only when a usage-related message arrives from PM.

## Pre-Task-1 Budget Assessment

Before spawning the first task-team, Lead reads the current usage percentage:

```bash
pct=$(jq -r '.accounts | [.[]] | sort_by(.updated_at) | last | .rate_limits.five_hour.used_percentage // 0' ~/.claude/ultra/usage-status.json 2>/dev/null || echo 0)
```

If usage is already elevated, Lead reasons about whether the plan can complete within the remaining budget. Consider:
- Total number of tasks in the plan
- Complexity of the work (from task.md descriptions)
- Remaining percentage available (100 - current_pct)

Lead may decide:
- **Proceed normally** — plenty of budget for the work.
- **Proceed with reduced concurrency** — run 1 team at a time instead of parallel.
- **Wait for reset** — usage is too high to start. Enter low-power mode (see below). Inform the user if possible.

There is no formula. This is Lead's judgment call based on the scope of the plan.

## On USAGE SOFT-LIMIT from PM

PM forwards this when the watchdog detects usage ≥ 75%. PM's message includes: current percentage, resets_at, active team count, remaining task count, and avg cost per completed task (if available).

Lead considers:
- **How many teams are active and how far along they are.** Teams near completion (in testing stage) will finish soon and cost little more. Teams early in implementation will burn significant additional tokens.
- **What tasks remain and their estimated complexity.** Read the next task.md headings if needed — a one-line config change is different from a multi-file refactor.
- **PM's avg task cost.** If PM reports "avg task cost ~5%" and current_pct is 76% with 2 teams active, that's 76 + 10 = ~86%, uncomfortably close to the hard limit.

Lead may decide:
- **Continue with caution** — active work is nearly done and remaining tasks are small. Do not spawn new teams until current ones finish, then reassess.
- **Stop spawning new teams** — let all active teams finish their current task. Do not start new tasks until usage drops or resets.
- **Pause active teams** — if active work alone would push past 90%. SendMessage each active team: "Complete your current stage if close to done, otherwise save work and stop."

## On USAGE HARD-LIMIT from PM

PM forwards this when the watchdog detects usage ≥ 90%. This is an emergency.

Lead acts immediately:
1. **Stop all active teams.** SendMessage each active team: "STOP: usage emergency at {pct}%. Save your work and stop immediately."
2. **Do not spawn anything new.**
3. **Wait for USAGE RESET from PM.**

There is no nuance here. At 90%+, the rate-limit hard wall is imminent. All work stops.

## On USAGE RESET from PM

PM forwards this when the watchdog detects usage has dropped below 75% (or the resets_at window has passed).

Lead resumes normal operations:
1. Check remaining tasks in the plan.
2. Reassess budget (same reasoning as the pre-task-1 assessment — but now with historical task cost data from PM).
3. Start spawning task-teams for remaining work.

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

## Low-Power Mode

When Lead decides to stop all work (due to hard-limit, or a conscious decision to wait for reset):

1. Ensure all teams have received stop/shutdown messages.
2. Note in `shared/lead.md`: "Entered low-power due to usage. Waiting for reset at {resets_at}."
3. Wait for PM's `USAGE RESET` message. The watchdog continues ticking every minute during the pause — it will detect the reset and signal PM, who forwards to Lead.
4. On USAGE RESET: resume operations (see above).

Lead does NOT need to create its own cron during pause — the watchdog's cron is the heartbeat that detects the reset.

## Completion Messages

When reporting task completion to PM, Lead includes the current usage percentage:

```
SendMessage PM: "COMPLETED task-{N}, current_pct={pct}"
```

This feeds PM's per-task budget tracking. The `current_pct` is read from usage-status.json at completion time — one `jq` call, negligible cost.
