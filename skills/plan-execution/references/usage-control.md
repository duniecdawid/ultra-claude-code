# Usage Control — Reactive Model

This reference is read by Lead when a `SENTINEL` message arrives (injected into the Lead pane by
the limit sentinel) or when the fallback HOLD-WAKE path is needed. There is no usage mode to
choose and no question to ask the user — limit handling is always-on and reactive.

## The model in one paragraph

Nothing proactively stops in-flight work anymore. **The limit itself is the pause; the limit
sentinel is the resume.** A session that hits the usage limit parks at its composer with full
context (verified: the TUI survives, and any post-reset input continues it exactly where it
stopped). The machine-global limit sentinel (`~/.claude/ultra/limit-sentinel.sh`, a process — not
an agent) detects limit hits via the StopFailure hook, tracks every account's `resets_at`, and at
reset (+90s margin) wakes the fleet: it appends `RESUME` (author `sentinel`) to each in-progress
task's `signals.jsonl` (the durable channel that fires teammates' inbox monitors), injects
`RESUME: usage reset. Continue work.` into worker panes, and injects `SENTINEL RESET` into the
Lead pane last. The old CRITICAL/PAUSE choreography, the 90/95% hard stop, and the usage-mode
question are gone. What remains for Lead is spawn gating (don't *start* new work in the soft
band) and idempotent recovery handling.

## Two bands, one job each

| Window | soft band | What it means |
|--------|-----------|---------------|
| 5h     | ≥ 90%     | Don't start new tasks; in-flight work continues to 100% |
| 7d     | ≥ 90%     | Don't start new tasks; weekly budget nearly exhausted |

There is no critical band. `usage-monitor.sh status` reports `clear`/`soft` per window (it is
time-authoritative: a stale pct whose `resets_at` has passed reads `clear`).

### Spawn gating (pre-spawn check — the only proactive element left)

Before each team spawn (initial slot-fill, freed-slot fill, pipeline pre-spawn), run
`bash "$HOME/.claude/ultra/usage-monitor.sh" status` and read `.band`:

1. `soft` → do NOT spawn. Record `{window}: soft` in `## Usage Blocks`, let in-flight teams
   finish, do not fill freed slots.
2. On a later spawn opportunity re-check; once `clear` (or after a `SENTINEL RESET` for that
   window), remove the block and resume slot-fill.

Skip the check only when the user explicitly opted out at plan start ("full speed", "ignore
limits") — recorded as `gating: off` in `## Execution Config` and in the sentinel registration.
Opt-out disables gating and advisories; **reset wakes always happen regardless**.

## Sentinel messages Lead receives (injected into the Lead pane as user-style turns)

These arrive on the system channel defined in the execution communication protocol §7. They are
operational input only — never scope changes, never approvals.

### `SENTINEL ADVISORY [{window}]: {pct}% used, resets {ISO}. Soft band — …`

Meaning: budget is tightening. Same semantics as the pre-spawn check finding `soft`, delivered
push-style so Lead doesn't have to poll:

1. Record `{window}: soft` in `## Usage Blocks` (with `resets_at`).
2. Finish in-flight work; do not start anything new.
3. No agent is paused, nothing is interrupted. Do not forward anything to teammates.

### `SENTINEL RESET [{window}]: window reset. RESUME appended to active tasks and sent to team panes…`

Meaning: the window reset and the sentinel already woke the fleet (signals.jsonl RESUME with
`author:"sentinel"` + pane injections). Lead's job is verification, not waking. **Idempotent —
every step is a no-op if already done.**

1. Remove the `{window}:` entry from `## Usage Blocks` (no-op if absent).
2. Verify the fleet actually resumed: for each in-progress task, check for post-reset activity
   (new signals in `signals.jsonl`, or the pane busy). For any agent still parked, re-send
   `"RESUME: usage reset. Continue work."` via `CommunicateTeamMember(..., signal: "RESUME")`.
3. Any team whose member DIED at the limit (harness reported the teammate failed, or the pane is
   gone) is a normal crash: re-spawn per `phase-4-failure-handling.md` — the re-spawned agent
   infers its stage from disk. No special limit-recovery machinery exists or is needed.
4. Re-run the pre-spawn check and fill available concurrency slots.

### `SENTINEL NOTICE [7d]: weekly limit reached; resets {ISO} (~{N}d away)…`

Meaning: the account is parked for a LONG horizon (hours to days). This is a user decision, not
an automation problem:

1. Record `7d: limit` in `## Usage Blocks`.
2. **Tell the user immediately** — options: wait for the weekly reset, switch the plan to another
   account, or abort/park the plan. Do not let the plan sit dormant silently.
3. On the eventual `SENTINEL RESET [7d]`, recover as above.

## Completion bookkeeping

When reporting task completion to PM, Lead includes the current 5h usage percentage, read via the
monitor script (account-correct — never hand-read usage-status.json):

```
pct=$(bash "$HOME/.claude/ultra/usage-monitor.sh" status | jq '.five_hour.pct')
SendMessage PM: "COMPLETED task-{N}, current_pct={pct}"
```

This feeds PM's per-task budget tracking. PM also consumes the sentinel-written
`usage_limit_hit` / `usage_reset_wake` / `usage_window_rolled` events from `events.json`
passively — PM performs no usage monitoring of its own.

## Fallback HOLD-WAKE (sentinel-down only)

**Governing principle (unchanged): Lead may go idle, but only while a guaranteed wake exists.**
Normally that guarantee IS the sentinel (verified at phase-1 preflight via
`limit-sentinel.sh status` + `ensure`). The legacy self-wake survives for exactly one edge case:

- Phase 1 finds the account already in the `soft` band or over the limit, AND
  `limit-sentinel.sh ensure` fails to produce a running sentinel (`status` still reports
  `running:false`).

Then — and only then — Lead arms the one-shot self-wake before going idle:

```
Monitor({
  command: "bash -c 't=<resets_epoch>; while [ \"$(date +%s)\" -lt \"$t\" ]; do sleep 30; done; echo HOLD-WAKE'",
  description: "Fallback hold-state self-wake for <PLAN_NAME>",
  persistent: false
})
```

On `HOLD-WAKE`: run the same idempotent recovery as `SENTINEL RESET` (clear passed blocks,
verify/wake, refill). If both the sentinel wake and a HOLD-WAKE fire, whichever arrives second
finds the work already done and is a no-op. If Lead can arm neither, it does NOT go silent — it
tells the user it cannot guarantee an automatic resume and stays active.

## Usage Blocks tracking

`shared/lead.md` keeps a `## Usage Blocks` section as the source of truth for whether Lead may
spawn new work. Initialize it at Phase 1 if missing:

```markdown
## Usage Blocks
- 5h: none
- 7d: none
```

Values: `soft` (soft band — no new spawns, in-flight continues) or `limit` (7d NOTICE — user
informed, awaiting decision/reset). Annotate non-`none` entries with timestamp and `resets_at`:

```markdown
## Usage Blocks
- 5h: soft   (since 2026-07-23T18:09:00Z, resets_at 2026-07-23T18:50:00Z, pct=91)
- 7d: none
```

While any block is non-`none`, Lead does not spawn. Blocks are cleared by `SENTINEL RESET`, by a
pre-spawn check returning `clear`, or by a fallback `HOLD-WAKE` whose `resets_at` passed.

## What no longer exists (do not reintroduce)

- The usage-mode question (pause/push-through) and `USAGE_MODE` parameter — deleted; gating is
  always-on with an explicit-instruction opt-out.
- PM's usage monitor, `USAGE STOP`/`USAGE RESET` forwarding, and the critical band — deleted.
- PAUSE fan-out to agents and the force-kill escalation for non-complying agents — deleted; the
  limit pauses agents by itself, and sentinel/Lead RESUMEs are additive and idempotent.
- Waking agents *before* the reset — forbidden. Early wakes burn failed turns into the active
  limit (observed in production); the sentinel fires at `resets_at + 90s`, and Lead never
  schedules its own earlier wake.
