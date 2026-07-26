#!/usr/bin/env bash
# Ultra Claude limit sentinel — the ONE global per-machine process that manages usage limits
# reactively. Replaces the proactive CRITICAL/PAUSE/HOLD-WAKE choreography: the limit itself is
# the pause; the sentinel is the resume.
#
# Subcommands:
#   ensure    start the singleton if not running (PID file + cmdline verification), then exit
#   run       foreground loop (normally reached only via ensure's detached spawn)
#   status    one-shot JSON: {running, pid, parked, plans, accounts}
#   stop      stop the running sentinel
#
# What the run loop does each tick (30s):
#   1. Consume StopFailure spool events (written by hooks/stop-failure.sh) into the parked ledger;
#      trace usage_limit_hit into a registered plan's events.json when the cwd matches.
#   2. Per account in usage-status.json:
#      - trace window rollovers (usage_window_rolled) into registered plans' events.json
#      - ADVISORY: >= soft band -> inject one advisory line into registered Lead panes (once/window)
#      - RESET WAKE at resets_at + margin: dual-write RESUME to active tasks' signals.jsonl +
#        send-keys to worker panes, Lead pane last; wake parked standalone panes; once/window
#      - 7d NOTICE: weekly-limit park is days-long -> tell the Lead pane + machine-context notify
#   3. WINDOW HEARTBEAT: per mapped account, one tiny headless prompt every PREOPEN_INTERVAL so a
#      5h window is always open and windows tile back-to-back (see heartbeat() for why it reads
#      no usage data at all).
#
# Multi-account first-class: every latch is keyed (account, resets_at) so each action fires
# exactly once per window and restarts are idempotent. Injection is guarded: pane must exist,
# foreground must be the claude binary, busy panes are skipped (no-op = the session already
# resumed), and the rate-limit menu is dismissed via its "Stop and wait" option first.
#
# Machine-specific values (account->profile map, notify command, standalone-wake toggle) come
# from ~/.claude/skills/machine-context/limit-sentinel.md when present; runtime detection is the
# fallback. Nothing in this script is machine-specific.
#
# Env overrides (tests): UC_SENTINEL_DIR, UC_USAGE_FILE, UC_SENTINEL_MC, UC_TEAMS_DIR,
# SENTINEL_TMUX (e.g. "tmux -L test"), CLAUDE_BIN, UC_TICK_SECONDS, UC_PREOPEN_INTERVAL.

set -uo pipefail

SENTINEL_DIR="${UC_SENTINEL_DIR:-$HOME/.claude/ultra/sentinel}"
USAGE_FILE="${UC_USAGE_FILE:-$HOME/.claude/ultra/usage-status.json}"
MC_FILE="${UC_SENTINEL_MC:-$HOME/.claude/skills/machine-context/limit-sentinel.md}"
TEAMS_DIR="${UC_TEAMS_DIR:-$HOME/.claude/teams}"
TMUX_BIN="${SENTINEL_TMUX:-tmux}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
TICK="${UC_TICK_SECONDS:-30}"

PID_FILE="$SENTINEL_DIR/sentinel.pid"
LOG_FILE="$SENTINEL_DIR/sentinel.log"
STATE_FILE="$SENTINEL_DIR/state.json"
EVENTS_DIR="$SENTINEL_DIR/events"
PLANS_DIR="$SENTINEL_DIR/plans"

SOFT_5H=90; SOFT_7D=90       # soft band: advisory + Lead pre-spawn gating; there is no hard stop
WAKE_MARGIN=90               # fire wakes at resets_at + margin (never early — early wakes burn turns)
PREOPEN_INTERVAL="${UC_PREOPEN_INTERVAL:-1800}"  # window-heartbeat cadence (s); worst-case gap
EVENT_RETENTION_H=48

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG_FILE" 2>/dev/null; return 0; }

init_dirs() { mkdir -p "$EVENTS_DIR/processed" "$PLANS_DIR" 2>/dev/null
  [ -f "$STATE_FILE" ] || echo '{"accounts":{},"parked":{}}' > "$STATE_FILE"; }

# All state writes go through jq tmp+mv (single-writer process, so no flock needed here).
set_state() { # jq-program [args...]
  local prog="$1"; shift
  jq "$@" "$prog" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
}
get_state() { jq -r "$1" "$STATE_FILE" 2>/dev/null; }

now_epoch() { date +%s; }

# ---------------------------------------------------------------------------- machine context
# Topic file format (grep-able lines):
#   map: <account-slug> = <profile-dir | default>
#   notify: <shell command; message passed as $1>
#   standalone-wake: on|off
mc_get_profile() { # account -> profile dir ("" if unmapped, "default" for the default profile)
  local acct="$1" line=""
  if [ -f "$MC_FILE" ]; then
    line=$(grep -E "^map:\s*${acct}\s*=" "$MC_FILE" 2>/dev/null | head -1 | sed 's/^map:[^=]*=\s*//')
    [ -n "$line" ] && { echo "$line"; return 0; }
  fi
  # Runtime-detection fallback: scan profile dirs' .claude.json for the account email.
  local lib="$HOME/.claude/ultra/lib.sh" d email slug
  for d in "$HOME/.claude-profiles"/*/ "$HOME/.claude/"; do
    [ -f "$d/.claude.json" ] || continue
    email=$(jq -r '.oauthAccount.emailAddress // empty' "$d/.claude.json" 2>/dev/null)
    [ -n "$email" ] && [ -f "$lib" ] || continue
    slug=$( (source "$lib" 2>/dev/null && slugifyEmail "$email") 2>/dev/null )
    if [ "$slug" = "$acct" ]; then
      case "$d" in "$HOME/.claude/") echo default;; *) echo "${d%/}";; esac
      return 0
    fi
  done
  echo ""
}
mc_list_accounts() { # every account the sentinel can pre-open for (map ∪ runtime detection)
  # Deliberately NOT sourced from usage-status.json: that file only lists accounts a statusline
  # has already reported, and the heartbeat must work for an account that has been idle for days.
  { [ -f "$MC_FILE" ] && grep -E "^map:" "$MC_FILE" 2>/dev/null | sed 's/^map:[[:space:]]*//; s/[[:space:]]*=.*//'
    local lib="$HOME/.claude/ultra/lib.sh" d email
    if [ -f "$lib" ]; then
      for d in "$HOME/.claude-profiles"/*/ "$HOME/.claude/"; do
        [ -f "$d/.claude.json" ] || continue
        email=$(jq -r '.oauthAccount.emailAddress // empty' "$d/.claude.json" 2>/dev/null)
        [ -n "$email" ] || continue
        ( source "$lib" 2>/dev/null && slugifyEmail "$email" ) 2>/dev/null
      done
    fi
  } | awk 'NF && !seen[$0]++'
}
mc_notify_cmd() { [ -f "$MC_FILE" ] && grep -E "^notify:" "$MC_FILE" 2>/dev/null | head -1 | sed 's/^notify:\s*//'; return 0; }
mc_standalone_wake() { # default on
  local v=""; [ -f "$MC_FILE" ] && v=$(grep -E "^standalone-wake:" "$MC_FILE" 2>/dev/null | head -1 | awk '{print $2}')
  [ "$v" = "off" ] && echo off || echo on
}

notify_user() { # message — best-effort, machine-context command only
  local cmd; cmd=$(mc_notify_cmd)
  [ -n "$cmd" ] && (eval "$cmd \"\$1\"" >/dev/null 2>&1 &) 200>&- 2>/dev/null
  log "NOTIFY: $1"
}

# ---------------------------------------------------------------------------- plan events.json
append_plan_event() { # plan_dir type window message [extra-jq-object]
  local plan_dir="$1" type="$2" window="$3" message="$4" extra="${5:-{\}}"
  local ev="$plan_dir/events.json" ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  [ -f "$ev" ] || return 0
  ( flock -w 5 9 || exit 0
    jq --arg ts "$ts" --arg t "$type" --arg w "$window" --arg m "$message" --argjson x "$extra" \
      '.events += [({timestamp:$ts, type:$t, task_id:null, agent:"limit-sentinel", message:$m, window:$w} + $x)]' \
      "$ev" > "$ev.tmp" 2>/dev/null && mv "$ev.tmp" "$ev"
  ) 9>>"$ev.lock" 2>/dev/null
}

# ---------------------------------------------------------------------------- pane operations
pane_exists() { $TMUX_BIN display-message -p -t "$1" '#{pane_id}' >/dev/null 2>&1; }

pane_fg() { $TMUX_BIN display-message -p -t "$1" '#{pane_current_command}' 2>/dev/null; }

# The claude foreground command shows as "claude", "node", or the bare version ("2.1.218").
pane_fg_is_claude() { pane_fg "$1" | grep -qE '^(claude|node|[0-9]+\.[0-9]+\.[0-9]+)'; }

pane_tail() { $TMUX_BIN capture-pane -p -t "$1" 2>/dev/null | grep -v '^\s*$' | tail -15; }

pane_busy() { pane_tail "$1" | grep -qE "esc to interrupt|Retrying in"; }

pane_has_limit_menu() { pane_tail "$1" | grep -q "Stop and wait for limit to reset"; }

# Verified injection recipe: -l literal text, brief settle, separate Enter (bracketed paste).
# If the rate-limit menu is up, select "Stop and wait" (pre-selected option 1) first — this
# returns the session to the composer (verified live 2026-07-23).
inject_pane() { # pane text -> 0 injected / 1 skipped
  local pane="$1" text="$2"
  pane_exists "$pane" || { log "inject skip $pane: pane gone"; return 1; }
  pane_fg_is_claude "$pane" || { log "inject skip $pane: fg=$(pane_fg "$pane")"; return 1; }
  pane_busy "$pane" && { log "inject skip $pane: busy (already active)"; return 1; }
  if pane_has_limit_menu "$pane"; then
    $TMUX_BIN send-keys -t "$pane" Enter; sleep 1
    pane_busy "$pane" && { log "inject $pane: menu dismissed, session resumed by itself"; return 1; }
  fi
  $TMUX_BIN send-keys -t "$pane" -l "$text"
  sleep 0.5
  $TMUX_BIN send-keys -t "$pane" Enter
  log "inject $pane: $text"
  return 0
}

# ---------------------------------------------------------------------------- team pane discovery
# Primary: ~/.claude/teams/*/config.json members[].tmuxPaneId (name -> pane). Fallback: the
# @agent-name pane labels every plan-execution agent sets on itself.
team_panes_for_plan() { # plan_slug -> lines "name pane_id"
  local slug="$1" cfg
  cfg=$(grep -rl "\"pm-${slug}\"" "$TEAMS_DIR"/*/config.json 2>/dev/null | head -1)
  if [ -n "$cfg" ]; then
    jq -r '.members[]? | select(.tmuxPaneId != null and .tmuxPaneId != "") | "\(.name) \(.tmuxPaneId)"' "$cfg" 2>/dev/null
    return 0
  fi
  $TMUX_BIN list-panes -a -F '#{pane_id} #{@agent-name}' 2>/dev/null \
    | awk -v s="$slug" '$2 ~ ("^task-[0-9]+") || $2 == ("pm-" s) {print $2, $1}' | sort -u
}

# ---------------------------------------------------------------------------- actions
do_advisory() { # account window pct resets_at
  local acct="$1" window="$2" pct="$3" resets="$4" reg lead gating iso
  iso=$(date -u -d "@$resets" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
  for reg in "$PLANS_DIR"/*.json; do
    [ -f "$reg" ] || continue
    [ "$(jq -r '.account_key // ""' "$reg")" = "$acct" ] || continue
    gating=$(jq -r '.gating // "on"' "$reg")
    [ "$gating" = "off" ] && continue
    lead=$(jq -r '.lead_pane // ""' "$reg")
    [ -n "$lead" ] && inject_pane "$lead" \
      "SENTINEL ADVISORY [$window]: ${pct}% used, resets $iso. Soft band — finish in-flight work, do not start new tasks until reset." \
      || true
  done
}

do_notice_7d() { # account resets_at
  local acct="$1" resets="$2" reg lead iso days
  iso=$(date -u -d "@$resets" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
  days=$(( (resets - $(now_epoch)) / 86400 ))
  local msg="SENTINEL NOTICE [7d]: weekly limit reached on $acct; resets $iso (~${days}d away). Work on this account is parked. Tell the user now — options: wait, switch account, or abort the plan."
  for reg in "$PLANS_DIR"/*.json; do
    [ -f "$reg" ] || continue
    [ "$(jq -r '.account_key // ""' "$reg")" = "$acct" ] || continue
    lead=$(jq -r '.lead_pane // ""' "$reg")
    [ -n "$lead" ] && inject_pane "$lead" "$msg" || true
  done
  notify_user "limit-sentinel: weekly limit hit on $acct, resets $iso"
}

# Fleet wake for one registered plan: RESUME to signals.jsonl of every in-progress task
# (durable channel — wakes inbox monitors), then worker panes, Lead pane LAST.
wake_plan() { # reg_file account window
  local reg="$1" acct="$2" window="$3"
  local plan_dir slug lead ts name pane woke=0
  plan_dir=$(jq -r '.plan_dir // ""' "$reg"); slug=$(basename "$reg" .json)
  lead=$(jq -r '.lead_pane // ""' "$reg")
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if [ -f "$plan_dir/plan.json" ]; then
    for task_id in $(jq -r '.tasks[]? | select(.status=="in_progress") | .task_id' "$plan_dir/plan.json" 2>/dev/null); do
      local sig="$plan_dir/tasks/$task_id/signals.jsonl"
      [ -d "$(dirname "$sig")" ] || continue
      printf '{"ts":"%s","signal":"RESUME","author":"sentinel","note":"usage reset [%s]"}\n' "$ts" "$window" >> "$sig"
    done
  fi
  while read -r name pane; do
    [ -n "${pane:-}" ] || continue
    [ "$pane" = "$lead" ] && continue
    inject_pane "$pane" "RESUME: usage reset. Continue work." && woke=$((woke+1))
  done < <(team_panes_for_plan "$slug")
  if [ -n "$lead" ]; then
    inject_pane "$lead" \
      "SENTINEL RESET [$window]: window reset. RESUME appended to active tasks and sent to team panes ($woke woken). Clear usage blocks, verify the fleet resumed, refill slots." \
      && woke=$((woke+1))
  fi
  append_plan_event "$plan_dir" usage_reset_wake "$window" \
    "Limit sentinel woke the fleet after $window reset ($woke panes injected)"
  log "wake_plan $slug: $woke panes"
  echo "$woke"
}

# Wake parked standalone sessions (recorded by the StopFailure hook) for this account.
wake_standalone() { # account window -> count woken
  local acct="$1" window="$2" woke=0 sid pane
  [ "$(mc_standalone_wake)" = "off" ] && { echo 0; return 0; }
  while IFS=$'\t' read -r sid pane; do
    [ -n "$pane" ] || continue
    if inject_pane "$pane" "SENTINEL RESET [$window]: the usage limit that interrupted you has reset. Continue where you left off — if a request was cut off mid-turn, redo it now. (automated wake — Ultra Claude limit sentinel)"; then
      woke=$((woke+1))
      set_state '.parked[$sid].status = "resumed"' --arg sid "$sid"
    fi
  done < <(jq -r --arg a "$acct" \
      '.parked | to_entries[] | select(.value.account_id==$a and .value.status=="parked" and (.value.tmux_pane//"")!="") | "\(.key)\t\(.value.tmux_pane)"' \
      "$STATE_FILE" 2>/dev/null)
  echo "$woke"
}

# Window pre-open: one tiny headless prompt, which starts a 5h window if none is open and is a
# no-op inside one that already is. Cheap enough (a haiku "ok") to fire on a blind cadence.
do_preopen() { # account
  local acct="$1" profile
  profile=$(mc_get_profile "$acct")
  [ -z "$profile" ] && { log "preopen skip $acct: unmapped"; return 1; }
  if [ "$profile" = "default" ]; then
    (env -u CLAUDE_CONFIG_DIR timeout 120 "$CLAUDE_BIN" -p "ok" --model haiku >/dev/null 2>&1 &) 200>&-
  else
    (CLAUDE_CONFIG_DIR="$profile" timeout 120 "$CLAUDE_BIN" -p "ok" --model haiku >/dev/null 2>&1 &) 200>&-
  fi
  log "preopen $acct via profile=$profile"
  return 0
}

# Window heartbeat: keep a 5h window open at all times so windows tile back-to-back — every
# boundary that falls inside working hours is a fresh quota grant, so gaps cost throughput.
#
# This reads NO usage data, by design. A headless `claude -p` does not refresh usage-status.json
# (no statusline runs in -p mode), so the sentinel can never observe a window it opened itself;
# anything scheduled off resets_at is structurally blind, and a chain-guard keyed on last-window
# usage caps the chain at one hop because a pre-opened window always reads ~0%. A fixed cadence
# is self-correcting instead: a fire inside an open window is a free no-op, a fire in a gap opens
# the next window. No phase tracking, no limit read, worst-case gap = PREOPEN_INTERVAL.
heartbeat() {
  local acct last now; now=$(now_epoch)
  for acct in $(mc_list_accounts); do
    last=$(get_state ".accounts[\"$acct\"].last_preopen // 0")
    [ "$last" -gt 0 ] 2>/dev/null && [ $((now - last)) -lt "$PREOPEN_INTERVAL" ] 2>/dev/null && continue
    do_preopen "$acct" || continue
    set_state '.accounts[$a].last_preopen = ($t|tonumber)' --arg a "$acct" --arg t "$now"
  done
}

# ---------------------------------------------------------------------------- spool + registry
consume_spool() {
  local f base sid acct cwd pane
  for f in "$EVENTS_DIR"/*.json; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    sid=$(jq -r '.session_id // "unknown"' "$f" 2>/dev/null)
    acct=$(jq -r '.account_id // ""' "$f" 2>/dev/null)
    cwd=$(jq -r '.cwd // ""' "$f" 2>/dev/null)
    pane=$(jq -r '.tmux_pane // ""' "$f" 2>/dev/null)
    if [ "$sid" != "unknown" ] && [ -n "$sid" ]; then
      set_state '.parked[$sid] = ($evt[0] + {status:"parked", recorded_at:$ts})' \
        --slurpfile evt "$f" --arg sid "$sid" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      # Weekly-limit park is a days-long outage — surface it immediately.
      if jq -r '.banner // ""' "$f" | grep -qi "weekly limit"; then
        local r7; r7=$(jq -r --arg k "$acct" '.accounts[$k].rate_limits.seven_day.resets_at // 0' "$USAGE_FILE" 2>/dev/null)
        local latch; latch=$(get_state ".accounts[\"$acct\"].notice_7d_latch // 0")
        if [ "${r7:-0}" -gt 0 ] && [ "$latch" != "$r7" ]; then
          do_notice_7d "$acct" "$r7"
          set_state '.accounts[$a].notice_7d_latch = ($r|tonumber)' --arg a "$acct" --arg r "$r7"
        fi
      fi
    fi
    # Trace into the owning plan's events.json when the cwd belongs to a registration.
    local reg
    for reg in "$PLANS_DIR"/*.json; do
      [ -f "$reg" ] || continue
      local pdir; pdir=$(jq -r '.plan_dir // ""' "$reg")
      case "$cwd/" in "$(dirname "$(dirname "$(dirname "$pdir")")")"/*)
        append_plan_event "$pdir" usage_limit_hit 5h \
          "Session $sid hit the usage limit (recorded by limit sentinel)" \
          "$(jq -nc --arg s "$sid" '{session_id:$s}')" ;;
      esac
    done
    mv "$f" "$EVENTS_DIR/processed/$base" 2>/dev/null
    log "spool consumed: $base acct=$acct pane=$pane"
  done
}

prune() {
  local now; now=$(now_epoch)
  find "$EVENTS_DIR/processed" -type f -mmin +$((EVENT_RETENTION_H * 60)) -delete 2>/dev/null
  # Registrations for finished/vanished plans.
  local reg pdir
  for reg in "$PLANS_DIR"/*.json; do
    [ -f "$reg" ] || continue
    pdir=$(jq -r '.plan_dir // ""' "$reg")
    if [ ! -f "$pdir/plan.json" ] || [ "$(jq -r '.status // ""' "$pdir/plan.json" 2>/dev/null)" = "completed" ]; then
      rm -f "$reg"; log "pruned registration $(basename "$reg")"
    fi
  done
  # Parked entries resolved or older than retention.
  set_state '.parked |= with_entries(select(
      (.value.status == "parked") and
      ((.value.recorded_at // "1970-01-01T00:00:00Z") | fromdateiso8601) > ($now - ($ret*3600))
    ))' --argjson now "$now" --argjson ret "$EVENT_RETENTION_H"
}

# ---------------------------------------------------------------------------- per-account tick
check_account() { # account
  local acct="$1" now pct5 res5 pct7 res7
  now=$(now_epoch)
  pct5=$(jq -r --arg k "$acct" '.accounts[$k].rate_limits.five_hour.used_percentage // 0' "$USAGE_FILE" 2>/dev/null)
  res5=$(jq -r --arg k "$acct" '.accounts[$k].rate_limits.five_hour.resets_at // 0' "$USAGE_FILE" 2>/dev/null)
  pct7=$(jq -r --arg k "$acct" '.accounts[$k].rate_limits.seven_day.used_percentage // 0' "$USAGE_FILE" 2>/dev/null)
  res7=$(jq -r --arg k "$acct" '.accounts[$k].rate_limits.seven_day.resets_at // 0' "$USAGE_FILE" 2>/dev/null)
  pct5=$(printf "%.0f" "$pct5" 2>/dev/null || echo 0); pct7=$(printf "%.0f" "$pct7" 2>/dev/null || echo 0)
  [ "$res5" = "null" ] || [ -z "$res5" ] && res5=0
  [ "$res7" = "null" ] || [ -z "$res7" ] && res7=0

  # -- rollover trace + last-window usage snapshot (wake-gating input) ------------------------
  local prev5; prev5=$(get_state ".accounts[\"$acct\"].win5h.resets_at // 0")
  if [ "$res5" -gt 0 ] 2>/dev/null && [ "$prev5" -gt 0 ] 2>/dev/null && [ "$res5" -gt "$prev5" ] 2>/dev/null; then
    local prev_pct; prev_pct=$(get_state ".accounts[\"$acct\"].win5h.pct // 0")
    set_state '.accounts[$a].last_window = {resets_at: ($p|tonumber), pct: ($c|tonumber)}' \
      --arg a "$acct" --arg p "$prev5" --arg c "$prev_pct"
    local reg pdir
    for reg in "$PLANS_DIR"/*.json; do
      [ -f "$reg" ] || continue
      [ "$(jq -r '.account_key // ""' "$reg")" = "$acct" ] || continue
      pdir=$(jq -r '.plan_dir // ""' "$reg")
      if [ -f "$pdir/plan.json" ] && [ "$(jq -r '[.tasks[]? | select(.status=="in_progress")] | length' "$pdir/plan.json" 2>/dev/null)" -gt 0 ] 2>/dev/null; then
        append_plan_event "$pdir" usage_window_rolled 5h \
          "Usage window 5h rolled over mid-execution (resets_at $prev5 -> $res5) — per-task cost_pct spanning this point is unreliable" \
          "$(jq -nc --argjson o "$prev5" --argjson n "$res5" '{old_resets_at:$o, new_resets_at:$n}')"
      fi
    done
    log "rollover $acct: 5h $prev5 -> $res5"
  fi
  if [ "$res5" -gt 0 ] 2>/dev/null && [ "$now" -lt "$res5" ] 2>/dev/null; then
    set_state '.accounts[$a].win5h = {resets_at: ($r|tonumber), pct: ($p|tonumber)}' \
      --arg a "$acct" --arg r "$res5" --arg p "$pct5"
  fi

  # -- ADVISORY (soft band, once per window, only while the window is still running) ----------
  local adv_latch; adv_latch=$(get_state ".accounts[\"$acct\"].advisory_latch // 0")
  if [ "$res5" -gt 0 ] 2>/dev/null && [ "$now" -lt "$res5" ] 2>/dev/null \
     && [ "$pct5" -ge "$SOFT_5H" ] 2>/dev/null && [ "$adv_latch" != "$res5" ]; then
    do_advisory "$acct" 5h "$pct5" "$res5"
    set_state '.accounts[$a].advisory_latch = ($r|tonumber)' --arg a "$acct" --arg r "$res5"
  fi
  local adv7_latch; adv7_latch=$(get_state ".accounts[\"$acct\"].advisory_7d_latch // 0")
  if [ "$res7" -gt 0 ] 2>/dev/null && [ "$now" -lt "$res7" ] 2>/dev/null \
     && [ "$pct7" -ge "$SOFT_7D" ] 2>/dev/null && [ "$adv7_latch" != "$res7" ]; then
    do_advisory "$acct" 7d "$pct7" "$res7"
    set_state '.accounts[$a].advisory_7d_latch = ($r|tonumber)' --arg a "$acct" --arg r "$res7"
  fi

  # -- RESET WAKE (resets_at + margin passed, once per window) --------------------------------
  # Wake time source: resets_at is API-authoritative for the window it describes — but it must
  # POSTDATE the limit hit it is supposed to clear. A stale resets_at (account idle since a
  # previous window, statusline never refreshed) would otherwise fire the wake immediately into
  # the still-active limit and burn it. When it doesn't postdate the oldest parked event — or is
  # missing entirely — fall back to oldest event + 5h (the window's upper bound).
  local oldest; oldest=$(jq -r --arg a "$acct" \
    '[.parked | to_entries[] | select(.value.account_id==$a and .value.status=="parked") | .value.ts | fromdateiso8601] | min // 0' \
    "$STATE_FILE" 2>/dev/null | cut -d. -f1)
  local wake_at=0
  [ "$res5" -gt 0 ] 2>/dev/null && wake_at="$res5"
  if [ "${oldest:-0}" -gt 0 ] 2>/dev/null && [ "$wake_at" -le "$oldest" ] 2>/dev/null; then
    wake_at=$((oldest + 5*3600))
    log "wake guard $acct: resets_at ${res5:-0} predates parked event $oldest — using event+5h"
  fi
  local wake_latch; wake_latch=$(get_state ".accounts[\"$acct\"].wake_done // 0")
  if [ "$wake_at" -gt 0 ] 2>/dev/null && [ "$now" -ge $((wake_at + WAKE_MARGIN)) ] 2>/dev/null \
     && [ "$wake_latch" != "$wake_at" ]; then
    local parked_n woke=0 reg
    parked_n=$(jq -r --arg a "$acct" '[.parked | to_entries[] | select(.value.account_id==$a and .value.status=="parked")] | length' "$STATE_FILE" 2>/dev/null)
    # Wake only when there was something to recover from: parked sessions, or a plan registered
    # on this account whose window ended >= soft (an unhooked death is still worth a check-in).
    local had_limit=false
    [ "${parked_n:-0}" -gt 0 ] 2>/dev/null && had_limit=true
    local lastw_pct; lastw_pct=$(get_state ".accounts[\"$acct\"].last_window.pct // 0")
    for reg in "$PLANS_DIR"/*.json; do
      [ -f "$reg" ] || continue
      [ "$(jq -r '.account_key // ""' "$reg")" = "$acct" ] || continue
      if [ "$had_limit" = true ] || [ "$lastw_pct" -ge "$SOFT_5H" ] 2>/dev/null; then
        wake_plan "$reg" "$acct" 5h >/dev/null; woke=$((woke+1))
      fi
    done
    [ "$had_limit" = true ] && { local sw; sw=$(wake_standalone "$acct" 5h); woke=$((woke+sw)); }
    # Nothing to pre-open here: the window heartbeat owns that, on its own cadence.
    set_state '.accounts[$a].wake_done = ($w|tonumber)' --arg a "$acct" --arg w "$wake_at"
    log "reset handled $acct: wake_at=$wake_at woke=$woke parked=$parked_n"
  fi
}

tick() {
  init_dirs
  consume_spool
  if [ -f "$USAGE_FILE" ]; then
    local acct
    for acct in $(jq -r '.accounts | keys[]' "$USAGE_FILE" 2>/dev/null); do
      check_account "$acct"
    done
  fi
  heartbeat   # outside the usage-file gate on purpose — it must run for idle/unreported accounts
  prune
}

# ---------------------------------------------------------------------------- lifecycle
# THE LOCK IS THE TRUTH; the PID file is only a note. A stale/deleted PID file while the lock
# holder lives caused a real split-brain (2026-07-24: ensure deleted the live holder's PID file,
# spawned a loser that exited on the lock, and the status gate read "not running"). Every
# liveness decision probes the flock; the holder re-writes its PID note each tick.
lock_held() { # 0 = a sentinel holds the run lock (running)
  [ -f "$SENTINEL_DIR/run.lock" ] || return 1
  ! flock -n "$SENTINEL_DIR/run.lock" true 2>/dev/null
}

sentinel_pid() { # best-effort pid of the holder, validated against its cmdline
  [ -f "$PID_FILE" ] || return 1
  local pid; pid=$(cat "$PID_FILE" 2>/dev/null)
  [ -n "$pid" ] || return 1
  local cmdline=""
  if [ -r "/proc/$pid/cmdline" ]; then cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
  else cmdline=$(ps -o args= -p "$pid" 2>/dev/null); fi
  echo "$cmdline" | grep -q "limit-sentinel" || return 1
  echo "$pid"
}

cmd_ensure() {
  init_dirs
  if lock_held; then exit 0; fi
  setsid nohup bash "$0" run >> "$LOG_FILE" 2>&1 < /dev/null &
  log "ensure: spawned run (pid $!)"
}

cmd_run() {
  init_dirs
  # A hook/session-spawned sentinel must not inherit one session's identity or tmux scope.
  unset CLAUDE_CONFIG_DIR TMUX TMUX_PANE 2>/dev/null
  # Singleton via a lock held for the process lifetime — concurrent `ensure` races (every
  # SessionStart hook calls it) all collapse here: losers exit, the lock dies with the winner.
  exec 200>>"$SENTINEL_DIR/run.lock"
  if ! flock -n 200; then
    log "run: another sentinel holds the lock, exiting"; exit 0
  fi
  echo "$$" > "$PID_FILE"
  set_state '.started_at = $ts' --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  log "run: started (pid $$, tick ${TICK}s)"
  trap 'rm -f "$PID_FILE"; log "run: stopped"; exit 0' TERM INT
  while true; do
    tick
    # Self-heal the PID note each tick — anything may have deleted or clobbered it; the lock,
    # not this file, is what makes us the singleton.
    echo "$$" > "$PID_FILE"
    # Cap the log (mirror of the layout daemon convention).
    if [ -f "$LOG_FILE" ] && [ "$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 2000000 ]; then
      tail -c 500000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
    # Backgrounded sleep keeps the TERM trap responsive (a foreground sleep defers it a full tick).
    # 200>&- : children must NOT inherit the singleton lock fd, or an orphaned sleep/pre-open
    # holds the lock past our death and blocks the next ensure (found live 2026-07-24).
    sleep "$TICK" 200>&- & wait $!
  done
}

cmd_status() {
  init_dirs
  local pid running=false started="" parked plans
  if lock_held; then
    running=true; started=$(get_state '.started_at // ""')
    pid=$(sentinel_pid) || pid=""   # note may lag one tick behind; running is lock-derived
  else
    pid=""
  fi
  parked=$(get_state '[.parked | to_entries[] | select(.value.status=="parked")] | length'); parked=${parked:-0}
  plans=$(ls "$PLANS_DIR"/*.json 2>/dev/null | wc -l)
  jq -nc --argjson running "$running" --arg pid "$pid" --arg started "$started" \
    --argjson parked "${parked:-0}" --argjson plans "${plans:-0}" \
    '{running:$running,
      pid:(if $pid == "" then null else ($pid|tonumber) end),
      started_at:(if $started == "" then null else $started end),
      parked:$parked, plans:$plans}'
}

cmd_stop() {
  local pid
  pid=$(sentinel_pid) || pid=$(fuser "$SENTINEL_DIR/run.lock" 2>/dev/null | awk '{print $1}')
  if [ -n "$pid" ]; then kill "$pid" 2>/dev/null; rm -f "$PID_FILE"; echo "stopped $pid"
  elif lock_held; then echo "running but holder pid unknown (no /proc match, no fuser) — not stopped" >&2; exit 1
  else echo "not running"; fi
}

# ---------------------------------------------------------------------------- dispatch
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    ensure) cmd_ensure ;;
    run)    cmd_run ;;
    status) cmd_status ;;
    stop)   cmd_stop ;;
    tick)   init_dirs; tick ;;   # single tick — used by tests and manual drills
    *) echo "usage: limit-sentinel.sh {ensure|run|status|stop|tick}" >&2; exit 2 ;;
  esac
fi
