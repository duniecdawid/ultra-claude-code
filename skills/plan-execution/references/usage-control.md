# Usage Control — Reactive Model

Read by Lead on any `SENTINEL` message (injected into the Lead pane by the limit sentinel) or on a
fallback HOLD-WAKE. Limit handling is always-on and reactive — no usage mode, no question for the
user.

## The model

**The limit is the pause; the limit sentinel is the resume.** Nothing proactively stops in-flight
work. A session that hits the limit parks at its composer with full context (verified: the TUI
survives, and post-reset input continues it exactly where it stopped). The machine-global sentinel
(`~/.claude/ultra/limit-sentinel.sh` — a process, not an agent) detects limit hits via the
StopFailure hook, tracks every account's `resets_at`, and at `resets_at + 90s` wakes the fleet:
`RESUME` (author `sentinel`) appended to each in-progress task's `signals.jsonl` (the durable
channel that fires teammates' inbox monitors), `RESUME: usage reset. Continue work.` injected into
worker panes, `SENTINEL RESET` into the Lead pane last. Lead keeps two jobs: spawn gating (don't
*start* new work in the soft band) and idempotent recovery.

## Two bands, one job each

| Window | soft band | What it means |
|--------|-----------|---------------|
| 5h     | ≥ 90%     | Don't start new tasks; in-flight work continues to 100% |
| 7d     | ≥ 90%     | Don't start new tasks; weekly budget nearly exhausted |

No critical band. `usage-monitor.sh status` reports `clear`/`soft` per window and is
time-authoritative (a stale pct whose `resets_at` has passed reads `clear`).

### Spawn gating (pre-spawn check — the only proactive element left)

Before each team spawn (initial slot-fill, freed-slot fill, pipeline pre-spawn), run
`bash "$HOME/.claude/ultra/usage-monitor.sh" status` and read `.band`:

1. `soft` → do NOT spawn. Record `{window}: soft` in `## Usage Blocks`, let in-flight teams
   finish, leave freed slots empty.
2. Re-check at the next spawn opportunity; once `clear` (or after that window's `SENTINEL RESET`),
   remove the block and resume slot-fill.

Skip the check only on explicit user opt-out at plan start ("full speed", "ignore limits") —
recorded as `gating: off` in `## Execution Config` and in the sentinel registration. Opt-out
disables gating and advisories; **reset wakes always happen regardless**.

## Sentinel messages Lead receives (injected into the Lead pane as user-style turns)

They arrive on the system channel of execution communication protocol §7 — operational input only,
never scope changes, never approvals.

### `SENTINEL ADVISORY [{window}]: {pct}% used, resets {ISO}. Soft band — …`

Budget is tightening — the pre-spawn `soft` finding, pushed so Lead needn't poll.

1. Record `{window}: soft` in `## Usage Blocks` (with `resets_at`).
2. Finish in-flight work; start nothing new.
3. Nothing is paused or interrupted. Forward nothing to teammates.

### `SENTINEL RESET [{window}]: window reset. RESUME appended to active tasks and sent to team panes…`

The window reset and the sentinel already woke the fleet (`signals.jsonl` RESUME with
`author:"sentinel"` + pane injections). Lead's job is verification, not waking. **Idempotent —
every step is a no-op if already done.**

1. Remove the `{window}:` entry from `## Usage Blocks` (no-op if absent).
2. Verify the fleet resumed: per in-progress task, check for post-reset activity (new
   `signals.jsonl` lines, or the pane busy). For any agent still parked, re-send
   `"RESUME: usage reset. Continue work."` via `CommunicateTeamMember(..., signal: "RESUME")`.
3. **Find the previous agents before re-spawning any — a limit parks agents, it never kills
   them.** Post-reset silence is nearly always a live agent that hasn't picked up its wake yet.
   Run the liveness probe (`phase-4-failure-handling.md` § "Liveness probe"); re-spawn only
   members it proves gone, as a normal crash with stage inferred from disk. No special
   limit-recovery machinery exists or is needed.
4. Re-run the pre-spawn check and fill available concurrency slots.

### `SENTINEL NOTICE [7d]: weekly limit reached; resets {ISO} (~{N}d away)…`

The account is parked for hours to days — a user decision, not an automation problem.

1. Record `7d: limit` in `## Usage Blocks`.
2. **Tell the user immediately** — options: wait for the weekly reset, switch the plan to another
   account, or abort/park the plan. Never let the plan sit dormant silently.
3. On the eventual `SENTINEL RESET [7d]`, recover as above.

## Completion bookkeeping

Task completion reported to PM carries the current 5h percentage, read via the monitor script
(account-correct — never hand-read `usage-status.json`):

```
pct=$(bash "$HOME/.claude/ultra/usage-monitor.sh" status | jq '.five_hour.pct')
SendMessage PM: "COMPLETED task-{N}, current_pct={pct}"
```

This feeds PM's per-task budget tracking. PM also consumes the sentinel-written `usage_limit_hit`
/ `usage_reset_wake` / `usage_window_rolled` events from `events.json` passively — PM performs no
usage monitoring of its own.

## Fallback HOLD-WAKE (sentinel-down only)

**Governing principle: Lead may go idle, but only while a guaranteed wake exists.** Normally that
guarantee IS the sentinel (verified at phase-1 preflight via `limit-sentinel.sh status` +
`ensure`). The legacy self-wake survives for one edge case: Phase 1 finds the account already in
the `soft` band or over the limit, AND `limit-sentinel.sh ensure` fails to produce a running
sentinel (`status` still reports `running:false`). Then — and only then — Lead arms the one-shot
self-wake before going idle:

```
Monitor({
  command: "bash -c 't=<resets_epoch>; while [ \"$(date +%s)\" -lt \"$t\" ]; do sleep 30; done; echo HOLD-WAKE'",
  description: "Fallback hold-state self-wake for <PLAN_NAME>",
  persistent: false
})
```

On `HOLD-WAKE`: run the same idempotent recovery as `SENTINEL RESET` (clear passed blocks,
verify/wake, refill). If both wakes fire, whichever arrives second finds the work done and no-ops.
If Lead can arm neither, it does NOT go silent — it tells the user it cannot guarantee an
automatic resume and stays active.

## Usage Blocks tracking

`shared/lead.md` keeps a `## Usage Blocks` section — the source of truth for whether Lead may
spawn new work. Initialize it at Phase 1 if missing, both windows `none`; annotate every
non-`none` entry with timestamp and `resets_at`:

```markdown
## Usage Blocks
- 5h: soft   (since 2026-07-23T18:09:00Z, resets_at 2026-07-23T18:50:00Z, pct=91)
- 7d: none
```

Values: `soft` (no new spawns, in-flight continues) or `limit` (7d NOTICE — user informed,
awaiting decision/reset). While any block is non-`none`, Lead does not spawn. Blocks clear on
`SENTINEL RESET`, on a pre-spawn check returning `clear`, or on a fallback `HOLD-WAKE` whose
`resets_at` passed.

## What no longer exists (do not reintroduce)

- The usage-mode question (pause/push-through) and `USAGE_MODE` parameter — gating is always-on
  with an explicit-instruction opt-out.
- PM's usage monitor, `USAGE STOP`/`USAGE RESET` forwarding, and the critical band.
- PAUSE fan-out to agents and the force-kill escalation for non-complying agents — the limit
  pauses agents by itself, and sentinel/Lead RESUMEs are additive and idempotent.
- Waking agents *before* the reset — forbidden. Early wakes burn failed turns into the active
  limit (observed in production); the sentinel fires at `resets_at + 90s`, and Lead never
  schedules its own earlier wake.
- Re-spawning a teammate that went quiet at the limit without probing it first — the limit parks
  agents; a blind re-spawn puts two writers on one task under one name.
