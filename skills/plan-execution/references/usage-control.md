# Usage Control

This reference is read by Lead when PM forwards a `USAGE STOP`/`USAGE RESET` event, or when Lead needs the recovery flow. The usage **mode** is chosen up front (Phase 1.0b) and PM owns the monitor; Lead does NOT read this on every spawn.

## Two Rate-Limit Windows

There are two independent rate-limit windows, each with its own reset. The monitor script (`scripts/usage-monitor.sh`) owns the thresholds and account resolution; Lead works with two bands per window plus the reset.

| Window | soft (don't start new work) | critical (stop in-flight) | Typical reset horizon |
|--------|------------------------------|----------------------------|-----------------------|
| 5h     | ≥ 80%                        | ≥ 90%                      | Minutes to a few hours |
| 7d     | ≥ 90%                        | ≥ 95%                      | Hours to days          |

The two windows are independent. Track each as a separate block in `shared/lead.md` under `## Usage Blocks`.

## Two bands + reset (and the mode that gates them)

In `push-through` mode, none of this stops work — the monitor suppresses usage emits and Lead skips the pre-spawn check. In `pause` mode:

### Soft band — pre-spawn check, NOT an interrupt

Meaning: budget is tightening. Finish in-flight work; don't start anything new. The monitor never emits for this — Lead enforces it **before each spawn**:

1. Before each team spawn, run `bash "$HOME/.claude/ultra/usage-monitor.sh" status` and read `.band`.
2. If `soft` (or `critical`), do NOT spawn — record `{window}: soft` in `## Usage Blocks`, let in-flight teams finish, do NOT fill freed slots.
3. On a later spawn opportunity, re-check; once `.band` is `clear`, remove the `soft` block and resume slot-fill.

### Critical band — `USAGE STOP` (interrupt)

Meaning: in-flight work must stop. PM forwards a `USAGE STOP [{window}]` when the monitor emits `CRITICAL`.

1. **Send PAUSE to all active team members** via the communication protocol (signal append to each active task's `signals.jsonl` + SendMessage — see the `USAGE STOP` handler row in SKILL.md for the exact commands): `"PAUSE: usage {window}={pct}%. Go idle. You will receive RESUME when usage resets."` Idle agents consume zero tokens. If an agent keeps working, escalate that one to `shutdown_request`.
2. **Trigger a Phase 3 checkpoint immediately.**
3. **Record the block** in `shared/lead.md` → `## Usage Blocks` → `{window}: stop`.
4. **Enter hold state** (see the Hold State section — arm the self-owned `HOLD-WAKE` at the known `resets_at` before going idle). While in hold: do not respond to ADVICE/QUERY from paused agents; do not spawn; act only on PM's `USAGE RESET` or your own `HOLD-WAKE`.

### USAGE RESET (per window)

Meaning: the window dropped below its soft band on fresh data, or its reset time passed. Triggered by **either** PM's `USAGE RESET` message **or** Lead's own `HOLD-WAKE` at the known `resets_at` — both run the steps below, idempotently (whichever fires first does the work; a duplicate finds the block already cleared and is a no-op).

1. **Remove the entry for this window** from `shared/lead.md` → `## Usage Blocks` (no-op if already removed).
2. **If other usage blocks remain** (e.g., 5h reset while 7d still `stop`): stay in current state.
3. **If all blocks are cleared:**
   - From a `soft`-only block: resume normal operations — fill available concurrency slots with the next unblocked pending tasks.
   - From a `stop` hold: execute the "Recovery After Stop" flow below.

## Recovery After Stop

When all usage blocks clear after a `stop` hold, agents were **paused** (idle), not killed — so the default recovery is the cheap path:

1. **Send RESUME to all paused agents via the communication protocol** (signal append to each active task's `signals.jsonl` + SendMessage — see the `USAGE RESET` handler row in SKILL.md for the exact commands):
   `"RESUME: usage reset. Continue work."`
2. **Agents resume with full context.** They pick up exactly where they stopped — no re-spawn, no re-read, no lost understanding. If an agent had completed a fix but not sent for re-review/re-test, it sends now. If it was mid-fix, it continues.
3. **Resume normal operations.** Re-run the pre-spawn check, then fill available concurrency slots with the next unblocked pending tasks.

**Exception — a team that was force-killed** (an agent that didn't comply with PAUSE and was escalated to `shutdown_request`) must be **re-spawned from checkpoint** rather than resumed:
1. Read the latest checkpoint and `shared/lead.md` for pipeline state.
2. For each force-killed in-progress task, run the Pre-Spawn Checklist and re-spawn the team; the re-spawned agents infer their stage from on-disk file presence:
   - `task.md` only → planning; `+plan.md` → implementation; `+impl.md` → review/test (Executor re-sends "ready for review"/"ready for test").
   This is identical to the crash-recovery flow in `phase-4-failure-handling.md`. Pipeline-parked successors that were force-killed are re-spawned as normal (non-pipeline) tasks once their predecessor completes.

## Usage Blocks Tracking

`shared/lead.md` contains a `## Usage Blocks` section that is the source of truth for whether Lead may spawn new work. Initialize it at Phase 1 if missing:

```markdown
## Usage Blocks
- 5h: none
- 7d: none
```

Set the matching line to `soft` (pre-spawn check found the soft band) or `stop` (critical hold). On each RESET, set it back to `none`. While any line is non-`none`, Lead does not spawn. While any line is `stop`, active teams are paused/idle. Record each non-`none` block's `resets_at`.

Optionally annotate each non-`none` entry with the timestamp and the `resets_at` field from PM's message:

```markdown
## Usage Blocks
- 5h: pause  (since 2026-04-14T14:12:00Z, resets_at 2026-04-14T15:00:00Z, pct=91)
- 7d: conserve  (since 2026-04-14T14:08:00Z, resets_at 2026-04-18T00:00:00Z, pct=92)
```

## Up-front mode, then the limit check

The usage **mode** is the first interaction (Phase 1.0b): ask whether we care about the limits at all, BEFORE reading any usage data. Only if the answer is `pause` does Lead then read `usage-monitor.sh status` to check whether we are already over: `clear` → proceed; `soft` → start with a `soft` block (don't spawn task-1 yet); `critical` → pre-emptive `stop` hold (arm HOLD-WAKE, inform the user). In `push-through` there is no limit check at all. There is no first-tick STATUS message to wait for. All point-in-time usage reads go through `usage-monitor.sh status` (account-correct); Lead never hand-reads `usage-status.json`.

## On STALL from PM

PM forwards this when an executor has been silent for >10 minutes despite being in_progress.

Lead investigates:
1. Check if the stalled executor has a long-running tool call in progress (may be normal).
2. If the executor appears genuinely stuck: re-spawn the task-team. The task.md, plan.md, and impl.md files provide re-spawn context per the failure-handling reference.
3. If multiple executors are stalled simultaneously: suspect a systemic issue (API problems, disk full, etc.) and consider pausing execution.

## Hold State (`stop` block or deliberate wait)

**Governing principle: Lead may go idle, but only while it retains a guaranteed way to wake itself.** Pausing is allowed; abandoning the plan (going idle with no armed wake, so a human must restart it) is forbidden. If Lead cannot arm its self-wake, it does NOT go silent — it tells the user it cannot guarantee an automatic resume and stays active.

When Lead has an active `stop` block:

1. Ensure all teams have received PAUSE (escalate a non-complying agent to `shutdown_request`).
2. Record state in `shared/lead.md` → `## Usage Blocks` with timestamps and the `resets_at` (format below).
3. Trigger Phase 3 checkpoint.
4. **Arm a self-owned one-shot wake at the known reset time.** Compute the earliest `resets_at` (epoch) across all active blocks. Start a non-persistent Monitor that sleeps until that moment and then emits a single `HOLD-WAKE` line:
   ```
   Monitor({
     command: "bash -c 't=<resets_epoch>; while [ \"$(date +%s)\" -lt \"$t\" ]; do sleep 30; done; echo HOLD-WAKE'",
     description: "Hold-state self-wake for <PLAN_NAME>",
     persistent: false
   })
   ```
   This is Lead's own guaranteed restart — it does not depend on PM still being alive. It is the reset time we already know, so there is no polling of usage data.
5. PM's monitor provides a second, independent trigger: its time-authoritative `USAGE-RESET` (forwarded by PM) fires on the known reset time even when usage data is stale.
6. With the self-wake armed, Lead may go idle. It acts only on these wakes during hold:
   - **PM's `USAGE RESET [window]` message**, or
   - **its own `HOLD-WAKE`** Monitor line.
7. On either wake: re-evaluate `## Usage Blocks`. For a window whose `resets_at` has passed (or whose RESET arrived), clear that window's block. If ALL blocks are cleared, run "Recovery After Stop". Otherwise re-arm the self-wake for the next-earliest `resets_at` and stay in hold state.

**Resume is idempotent.** The self-wake and PM's `USAGE-RESET` are two independent triggers for the same recovery. Whichever fires first clears the block and resumes; a later duplicate wake finds the blocks already cleared (or work already resumed) and is a no-op. Never double-resume or double-spawn.

**Note on 7d reset horizon:** 7-day window resets can be hours or days away. If a 7d critical stop triggers, execution may pause for a long time. Lead should inform the user when entering this state — the user may prefer to halt the plan entirely, switch accounts, or resume manually later rather than let the plan sit dormant for days.

## Completion Messages

When reporting task completion to PM, Lead includes the current 5h usage percentage (the tighter window is the one that matters for per-task budget tracking):

```
SendMessage PM: "COMPLETED task-{N}, current_pct={pct_5h}"
```

This feeds PM's per-task budget tracking. The `current_pct` is read from usage-status.json at completion time — one `jq` call, negligible cost.
