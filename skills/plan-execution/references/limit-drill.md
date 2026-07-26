# Limit Drill — end-to-end sentinel verification without burning quota

A scripted practice run that drives a REAL Claude Code session into the usage-limit state via the
mock gateway (`scripts/tests/mock-limit-rig/`), verifies the whole reactive chain — StopFailure
hook → sentinel spool → park → reset → guarded wake — and proves the session resumes with
context intact. Run it after changing the sentinel, the hook, or the injection logic, and as the
acceptance gate before releasing changes to the reactive-limit machinery.

The same simulation was used to establish the design empirically (2026-07-23): the mock 429
reproduces the exact banner (`You've hit your session limit · resets <local time>`), the
`/rate-limit-options` menu, and a real `StopFailure(rate_limit)` hook payload.

## Prerequisites

- `/uc:setup` completed: `~/.claude/ultra/limit-sentinel.sh` symlinked, StopFailure hook in
  settings.json, sentinel running (`bash ~/.claude/ultra/limit-sentinel.sh status` →
  `running:true`).
- python3 with `requests`; tmux.
- A few cents of real usage (two tiny prompts pass through to the live API).

## Drill

```bash
RIG_SRC="${CLAUDE_PLUGIN_ROOT}/scripts/tests/mock-limit-rig"   # or the repo checkout path
DRILL=$(mktemp -d); mkdir -p "$DRILL/project"

# 1. gateway up (pass mode), disposable session through it
python3 "$RIG_SRC/gateway.py" 8399 --state-dir "$DRILL" &
tmux new-session -d -s limit-drill -c "$DRILL/project" \
  -e ANTHROPIC_BASE_URL=http://127.0.0.1:8399 'claude'
# accept the trust prompt when it appears:
sleep 12; tmux send-keys -t limit-drill Enter

# 2. seed context (proves later that the resume kept it)
tmux send-keys -t limit-drill "Remember the codeword DRILL-99. Reply exactly: ACK DRILL-99"
sleep 1; tmux send-keys -t limit-drill Enter
# wait for: ● ACK DRILL-99

# 3. simulate the limit: reset ~3 min out, reject mode, then any prompt
date -d '+3 minutes' +%s > "$DRILL/RESET_EPOCH"
echo reject > "$DRILL/MODE"
tmux send-keys -t limit-drill "Continue: reply exactly CODEWORD plus the codeword"
sleep 1; tmux send-keys -t limit-drill Enter
```

**Expected within ~15s of step 3:**
- The pane shows the banner `You've hit your session limit · resets …` and/or the
  `Stop and wait for limit to reset` menu, then parks.
- A spool event appears: `ls ~/.claude/ultra/sentinel/events/` (or `events/processed/` once the
  sentinel ticked) — with `error:"rate_limit"`, the session id, and the pane id.
- `bash ~/.claude/ultra/limit-sentinel.sh status` shows `parked: 1`.

```bash
# 4. heal the "API" before the advertised reset, then just WAIT
echo pass > "$DRILL/MODE"
```

**Expected at RESET_EPOCH + 90s (± one 30s tick):** the sentinel injects the wake into the parked
pane (dismissing the menu first if present); the session answers `CODEWORD DRILL-99` — context
survived the limit, and nothing else touched the session. Check
`~/.claude/ultra/sentinel/sentinel.log` for the `inject %N` and `reset handled` lines.

**Negative checks while waiting (before the reset):** the sentinel must NOT wake anything early —
`grep inject ~/.claude/ultra/sentinel/sentinel.log` shows no entry for this pane before
RESET_EPOCH+90s. Early wakes burn failed turns; this is a hard rule.

## Variant A — window heartbeat

The heartbeat is independent of the wake path and of usage data: it fires on cadence alone so a
5h window is always open. Force one without waiting for a reset:

```bash
# clear the throttle stamp for the account, then run a single tick
jq '.accounts["<account-slug>"].last_preopen = 0' ~/.claude/ultra/sentinel/state.json > /tmp/s \
  && mv /tmp/s ~/.claude/ultra/sentinel/state.json
UC_PREOPEN_INTERVAL=1 bash ~/.claude/ultra/limit-sentinel.sh tick
grep preopen ~/.claude/ultra/sentinel/sentinel.log | tail -2
```

Expect exactly one `claude -p "ok" --model haiku` under the account's profile, and a
`last_preopen` stamp that suppresses the next fire until `PREOPEN_INTERVAL` (default 1800s) has
elapsed. Accounts that neither appear in `map:` in
`~/.claude/skills/machine-context/limit-sentinel.md` nor resolve by profile scan are skipped
(`preopen skip … unmapped`). Note the reset-wake path no longer pre-opens at all — a killed
session produces a wake attempt only.

## Variant B — advisory injection

With a plan-execution run active (or a fake registration in `~/.claude/ultra/sentinel/plans/`
pointing `lead_pane` at a scratch claude pane), temporarily edit the registration's account to
one whose 5h usage is ≥90% (or wait for a naturally hot window): the Lead pane receives ONE
`SENTINEL ADVISORY [5h]: …` line for the window, and never a second one (latched per resets_at).

## Cleanup

```bash
tmux kill-session -t limit-drill 2>/dev/null
pkill -f "gateway.py 8399"; rm -rf "$DRILL"
# the drill's parked entry ages out of sentinel state automatically (48h), or clear it:
# jq '.parked = {}' ~/.claude/ultra/sentinel/state.json > /tmp/s && mv /tmp/s ~/.claude/ultra/sentinel/state.json
```

## Pass criteria

1. Hook event spooled with `error:"rate_limit"` + pane id at limit hit.
2. No injection before RESET_EPOCH + 90s.
3. Parked pane woken exactly once; menu dismissed if present; codeword answer proves context.
4. Variant A: exactly one pre-open per interval, correct profile, independent of the wake path.
5. Variant B: exactly one advisory per window into the Lead pane only.
