#!/usr/bin/env bash
# Ultra Claude usage monitor — the single source of truth for rate-limit usage.
# Account resolution + thresholds live here and ONLY here; callers never hand-write
# jq against usage-status.json (picking the wrong account is a known failure mode).
#
# Subcommands:
#   status [ACCOUNT_KEY]                       one-shot: print current usage JSON + band, then exit
#   watch  <PLAN_DIR> [ACCOUNT_KEY] [MODE]     persistent: emit a JSON line ONLY on actionable milestones
#
# `watch` emits (one stdout line each → one Monitor notification):
#   {"alert":"CRITICAL","window":"5h|7d","pct":N,"resets_at":N}                 in-flight work must STOP now
#   {"alert":"USAGE-RESET","window":"5h|7d","pct":N[,"reason":"reset_time_passed"]}  work may RESTART
#   {"alert":"NUDGE","task_id":"task-N","silent_minutes":N,"count":K}           protocol-violation candidate (all modes)
# It is SILENT on clean ticks, on the soft band (handled at spawn time, never emitted), and on the
# first tick (no STATUS). With MODE=push-through, usage milestones are suppressed entirely; NUDGE
# still fires — it is about pipeline liveness, not usage.
#
# Silence trace (all modes, never emitted): tasks silent >10 min get a `silence_observed` event
# appended to events.json for post-mortem visibility. No alert, no escalation — long tool calls
# look identical to real stalls, so alerting on silence produced noise no one could act on.
#
# NUDGE (all modes): NOT stall detection — a protocol-violation candidate per the execution
# communication protocol §3 yield rule. Emitted only on the full conjunction: task silent >10 min
# AND its latest signal is not WAITING_ON/BLOCKED_ON (agent recorded no named wait) AND no file
# changed anywhere in the repo tree in 10 min (nothing is building/editing). PM verifies before
# acting (the emit is a candidate, not a verdict); count increments per consecutive qualifying
# window so PM can escalate on count>=2.
#
# Window-rollover trace (all modes, never emitted): when a window's resets_at advances while tasks
# are in_progress, a `usage_window_rolled` event is appended to events.json — PM's per-task
# cost_pct assumes monotonic usage inside one window, so tasks spanning a rollover get cost null.
#
# Bands: clear  <  soft (stop starting NEW work — enforced by the pre-spawn check)  <  critical (stop in-flight).

set -uo pipefail

USAGE_FILE="$HOME/.claude/ultra/usage-status.json"
LIB="$HOME/.claude/ultra/lib.sh"

# Thresholds (used %). soft = don't start new work; critical = stop in-flight work.
SOFT_5H=80; CRIT_5H=90
SOFT_7D=90; CRIT_7D=95

STATE_FILE=""
DEBUG_LOG=""

log()  { [ -n "$DEBUG_LOG" ] && echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$DEBUG_LOG" 2>/dev/null; return 0; }
emit() { echo "$1"; log "EMIT: $1"; }

# Resolve the active account key in ONE place. Prefer an explicitly-passed key; else
# derive it from the logged-in email via slugifyEmail; else fall back to a single-account file.
resolve_account() {
  local key="${1:-}"
  if [ -n "$key" ] && [ "$key" != "-" ]; then echo "$key"; return 0; fi
  local email=""
  email=$(claude auth status --json 2>/dev/null | jq -r '.email // empty' 2>/dev/null || echo "")
  if [ -n "$email" ] && [ -f "$LIB" ]; then
    ( source "$LIB" 2>/dev/null && slugifyEmail "$email" )
    return 0
  fi
  [ -f "$USAGE_FILE" ] && jq -r '.accounts | keys[0] // empty' "$USAGE_FILE" 2>/dev/null || echo ""
}

band_for() { # pct soft crit
  local pct="$1" soft="$2" crit="$3"
  if   [ "$pct" -ge "$crit" ] 2>/dev/null; then echo critical
  elif [ "$pct" -ge "$soft" ] 2>/dev/null; then echo soft
  else echo clear; fi
}

worst_band() { case "$1 $2" in *critical*) echo critical;; *soft*) echo soft;; *) echo clear;; esac; }

# Echoes "pct resets_epoch" for the given account + window (five_hour|seven_day).
read_window() {
  local acct="$1" win="$2" pct resets
  pct=$(jq -r --arg k "$acct" --arg w "$win" '.accounts[$k].rate_limits[$w].used_percentage // 0' "$USAGE_FILE" 2>/dev/null || echo 0)
  resets=$(jq -r --arg k "$acct" --arg w "$win" '.accounts[$k].rate_limits[$w].resets_at // 0' "$USAGE_FILE" 2>/dev/null || echo 0)
  pct=$(printf "%.0f" "$pct" 2>/dev/null || echo 0)
  if ! echo "$resets" | grep -q '^[0-9]\+$'; then resets=$(date -d "$resets" +%s 2>/dev/null || echo 0); fi
  echo "$pct $resets"
}

set_state() { # key field json-value
  jq ".${1}.${2} = ${3}" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# ---------------------------------------------------------------------------- status

cmd_status() {
  local acct; acct=$(resolve_account "${1:-}")
  if [ -z "$acct" ] || [ ! -f "$USAGE_FILE" ]; then
    jq -nc --arg a "${acct:-}" '{error:"no usage data", account:$a, band:"clear"}'
    return 0
  fi
  local pct5 res5 pct7 res7 b5 b7 bb updated stale now data_epoch re5 re7
  read -r pct5 res5 < <(read_window "$acct" five_hour)
  read -r pct7 res7 < <(read_window "$acct" seven_day)
  now=$(date +%s)

  # Time-authoritative band (mirrors watch mode): usage-status.json can hold a STALE
  # percentage whose reset time has already passed — statusline rewrites updated_at on
  # every refresh even when the rate-limit numbers are not refreshed, so a window can read
  # e.g. 101% minutes AFTER it actually rolled over. resets_at comes from the API and is
  # authoritative: if it has passed, the window HAS reset and the band is clear regardless
  # of the stale pct. (reset_elapsed surfaces this so callers see the pct is pre-reset.)
  re5=false; [ "$res5" -gt 0 ] 2>/dev/null && [ "$now" -ge "$res5" ] 2>/dev/null && re5=true
  re7=false; [ "$res7" -gt 0 ] 2>/dev/null && [ "$now" -ge "$res7" ] 2>/dev/null && re7=true
  b5=$([ "$re5" = true ] && echo clear || band_for "$pct5" "$SOFT_5H" "$CRIT_5H")
  b7=$([ "$re7" = true ] && echo clear || band_for "$pct7" "$SOFT_7D" "$CRIT_7D")
  bb=$(worst_band "$b5" "$b7")

  # stale_minutes is derived from updated_at, which statusline rewrites every refresh — so it
  # is NOT a reliable staleness signal (it is usually ~0 even when numbers are stale). Kept
  # for visibility only; reset_elapsed is the trustworthy staleness/rollover indicator.
  updated=$(jq -r --arg k "$acct" '.accounts[$k].updated_at // ""' "$USAGE_FILE" 2>/dev/null || echo "")
  stale=-1
  if [ -n "$updated" ] && [ "$updated" != "null" ]; then
    data_epoch=$(date -d "$updated" +%s 2>/dev/null || echo 0)
    [ "$data_epoch" -gt 0 ] 2>/dev/null && stale=$(( (now - data_epoch) / 60 ))
  fi
  jq -nc --arg acct "$acct" \
    --argjson p5 "$pct5" --argjson r5 "$res5" --arg b5 "$b5" --argjson re5 "$re5" \
    --argjson p7 "$pct7" --argjson r7 "$res7" --arg b7 "$b7" --argjson re7 "$re7" \
    --arg band "$bb" --argjson stale "$stale" \
    '{account:$acct,
      five_hour:{pct:$p5,resets_at:$r5,band:$b5,reset_elapsed:$re5},
      seven_day:{pct:$p7,resets_at:$r7,band:$b7,reset_elapsed:$re7},
      band:$band, stale_minutes:$stale}'
}

# ---------------------------------------------------------------------------- watch

# Emit only the critical-stop crossing and the work-can-restart reset, with a latch so we
# don't re-fire CRITICAL on the same stale data right after a time-based reset.
check_window() { # key label pct resets crit soft
  local key="$1" label="$2" pct="$3" resets="$4" crit="$5" soft="$6"
  local last latch now alerted=0
  last=$(jq -r ".${key}.last_signal // \"\"" "$STATE_FILE" 2>/dev/null || echo "")
  latch=$(jq -r ".${key}.reset_latch // 0" "$STATE_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  [ "$last" = "critical" ] && alerted=1

  # Latch: after a time-based reset the file is still stale (same resets_at). Stay silent until
  # the data refreshes (resets_at advances after work resumes), then re-arm.
  if [ "$latch" != "0" ] && [ "$latch" != "null" ]; then
    if [ "$resets" = "$latch" ]; then return 0; else set_state "$key" reset_latch 0; fi
  fi

  # Time-authoritative reset: known reset time passed while we were in the critical state.
  if [ "$alerted" -eq 1 ] && [ "$resets" -gt 0 ] 2>/dev/null && [ "$now" -ge "$resets" ] 2>/dev/null; then
    emit "{\"alert\":\"USAGE-RESET\",\"window\":\"$label\",\"pct\":$pct,\"reason\":\"reset_time_passed\"}"
    set_state "$key" last_signal null
    set_state "$key" reset_latch "$resets"
    return 0
  fi

  # Upward crossing into the critical band → stop in-flight work.
  if [ "$pct" -ge "$crit" ] 2>/dev/null && [ "$alerted" -eq 0 ]; then
    emit "{\"alert\":\"CRITICAL\",\"window\":\"$label\",\"pct\":$pct,\"resets_at\":$resets}"
    set_state "$key" last_signal '"critical"'
    return 0
  fi

  # Genuine drop below the soft band on fresh data while we were critical → work may restart.
  if [ "$alerted" -eq 1 ] && [ "$pct" -lt "$soft" ] 2>/dev/null; then
    emit "{\"alert\":\"USAGE-RESET\",\"window\":\"$label\",\"pct\":$pct}"
    set_state "$key" last_signal null
  fi
}

# Quiet silence trace + NUDGE candidates — kept in all modes.
# Trace: >10 min task silence appends a `silence_observed` event to events.json (never stdout).
# NUDGE: protocol-violation candidate (§3 yield rule) — silent AND no named wait recorded AND no
# repo file activity. Emits to stdout for PM to verify; count grows per consecutive qualifying
# window. Both debounces self-clear as soon as the task shows real activity again.
check_silence() {
  local plan_dir="$1"
  [ -f "$plan_dir/events.json" ] && [ -f "$plan_dir/plan.json" ] || return 0
  local now task_id last_event task_num signal_file last_sig last_sig_name sig_epoch evt_epoch silent already
  local repo_root plan_prune nudge_last nudge_count
  now=$(date +%s)
  repo_root=$(git -C "$plan_dir" rev-parse --show-toplevel 2>/dev/null || echo "")
  # Physical path for the find prune — git returns symlink-resolved paths, so the prune must too.
  plan_prune=$(cd "$plan_dir" 2>/dev/null && pwd -P || echo "$plan_dir")
  for task_id in $(jq -r '.tasks[]? | select(.status=="in_progress") | .task_id' "$plan_dir/plan.json" 2>/dev/null); do
    [ -z "$task_id" ] && continue
    # silence_observed is our own trace, not task activity — excluding it keeps the clock honest.
    last_event=$(jq -r --arg t "$task_id" '[.events[]? | select(.task_id==$t and .type!="silence_observed") | .timestamp] | sort | last // ""' "$plan_dir/events.json" 2>/dev/null || echo "")
    task_num=${task_id#task-}
    signal_file="$plan_dir/tasks/task-${task_num}/signals.jsonl"
    last_sig_name=""
    if [ -s "$signal_file" ]; then
      last_sig=$(tail -1 "$signal_file" | jq -r '.ts // ""' 2>/dev/null || echo "")
      last_sig_name=$(tail -1 "$signal_file" | jq -r '.signal // ""' 2>/dev/null || echo "")
      if [ -n "$last_sig" ] && [ "$last_sig" != "null" ]; then
        sig_epoch=$(date -d "$last_sig" +%s 2>/dev/null || echo 0)
        evt_epoch=$(date -d "$last_event" +%s 2>/dev/null || echo 0)
        [ "$sig_epoch" -gt "$evt_epoch" ] 2>/dev/null && last_event="$last_sig"
      fi
    fi
    [ -z "$last_event" ] || [ "$last_event" = "null" ] && continue
    evt_epoch=$(date -d "$last_event" +%s 2>/dev/null || echo 0)
    silent=$(( (now - evt_epoch) / 60 ))
    already=$(jq -r --arg t "$task_id" '.silence_logged[$t] // ""' "$STATE_FILE" 2>/dev/null || echo "")
    if [ "$silent" -gt 10 ] && [ -z "$already" ]; then
      local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      jq --arg t "$task_id" --arg ts "$ts" --argjson m "$silent" \
        '.events += [{timestamp:$ts, type:"silence_observed", task_id:$t, agent:"usage-monitor", message:("No activity from " + $t + " for " + ($m|tostring) + " minutes"), silent_minutes:$m}]' \
        "$plan_dir/events.json" > "$plan_dir/events.json.tmp" 2>/dev/null && mv "$plan_dir/events.json.tmp" "$plan_dir/events.json"
      log "SILENCE: $task_id silent ${silent}m (traced to events.json)"
      jq --arg t "$task_id" --arg ts "$ts" '.silence_logged[$t]=$ts' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    elif [ "$silent" -le 10 ] && [ -n "$already" ]; then
      jq --arg t "$task_id" 'del(.silence_logged[$t])' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi

    # --- NUDGE candidate (protocol §3 yield rule violation) ---
    if [ "$silent" -le 10 ]; then
      # Activity ⇒ episode over; re-arm the nudge ladder.
      jq -e --arg t "$task_id" '.nudge_state[$t]' "$STATE_FILE" >/dev/null 2>&1 && \
        { jq --arg t "$task_id" 'del(.nudge_state[$t])' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"; }
      continue
    fi
    # A recorded named wait (or explicit heartbeat) is a legitimate park — trace only, no NUDGE.
    case "$last_sig_name" in WAITING_ON|BLOCKED_ON) continue;; esac
    # Activity suppressor: anything changing in the repo tree (builds touch build dirs) means work
    # is happening somewhere — imprecise across teams, but a real fleet-stop quiets the whole tree.
    # Prune .git and the plan dir itself (our own events/state/log writes must not count as work).
    if [ -n "$repo_root" ]; then
      local recent
      recent=$(timeout 3 find "$repo_root" \( -name .git -o -path "$plan_prune" \) -prune -o -type f -newermt "@$((now - 600))" -print -quit 2>/dev/null || echo "")
      [ -n "$recent" ] && continue
    fi
    nudge_last=$(jq -r --arg t "$task_id" '.nudge_state[$t].last_emit // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    nudge_count=$(jq -r --arg t "$task_id" '.nudge_state[$t].count // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    # One emit per qualifying 10-min window: first immediately, then every 600s while it persists.
    if [ $(( now - nudge_last )) -ge 600 ] 2>/dev/null; then
      nudge_count=$(( nudge_count + 1 ))
      emit "{\"alert\":\"NUDGE\",\"task_id\":\"$task_id\",\"silent_minutes\":$silent,\"count\":$nudge_count}"
      jq --arg t "$task_id" --argjson e "$now" --argjson c "$nudge_count" \
        '.nudge_state[$t] = {last_emit:$e, count:$c}' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi
  done
}

# Quiet window-rollover trace — all modes, never stdout. PM's per-task cost_pct assumes monotonic
# usage within one window; a sub-threshold reset mid-task silently breaks that (run 012: end_pct <
# start_pct). Appends `usage_window_rolled` to events.json when resets_at advances while any task
# is in_progress, so PM can null the affected cost instead of recording a bogus value.
check_rollover() {
  local plan_dir="$1" acct="$2"
  [ -n "$acct" ] && [ -f "$USAGE_FILE" ] && [ -f "$plan_dir/events.json" ] || return 0
  local win label pct resets prev active ts
  active=$(jq -r '[.tasks[]? | select(.status=="in_progress")] | length' "$plan_dir/plan.json" 2>/dev/null || echo 0)
  for win in five_hour seven_day; do
    label=$([ "$win" = five_hour ] && echo 5h || echo 7d)
    read -r pct resets < <(read_window "$acct" "$win")
    [ "$resets" -gt 0 ] 2>/dev/null || continue
    prev=$(jq -r ".rollover.${win} // 0" "$STATE_FILE" 2>/dev/null || echo 0)
    if [ "$prev" -gt 0 ] 2>/dev/null && [ "$resets" -gt "$prev" ] 2>/dev/null && [ "$active" -gt 0 ] 2>/dev/null; then
      ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      jq --arg ts "$ts" --arg w "$label" --argjson o "$prev" --argjson n "$resets" \
        '.events += [{timestamp:$ts, type:"usage_window_rolled", task_id:null, agent:"usage-monitor", message:("Usage window " + $w + " rolled over mid-execution (resets_at " + ($o|tostring) + " -> " + ($n|tostring) + ") — per-task cost_pct spanning this point is unreliable"), window:$w, old_resets_at:$o, new_resets_at:$n}]' \
        "$plan_dir/events.json" > "$plan_dir/events.json.tmp" 2>/dev/null && mv "$plan_dir/events.json.tmp" "$plan_dir/events.json"
      log "ROLLOVER: $label window resets_at $prev -> $resets (traced to events.json)"
    fi
    [ "$resets" != "$prev" ] && set_state rollover "$win" "$resets"
  done
}

cmd_watch() {
  local plan_dir="${1:-}" acct mode
  [ -z "$plan_dir" ] && { echo "watch: PLAN_DIR required" >&2; exit 2; }
  acct=$(resolve_account "${2:-}")
  mode="${3:-pause}"
  STATE_FILE="$plan_dir/.usage-monitor-state.json"
  DEBUG_LOG="$plan_dir/.usage-monitor-debug.log"
  [ -f "$STATE_FILE" ] || echo '{"five_hour":{"last_signal":null,"reset_latch":0},"seven_day":{"last_signal":null,"reset_latch":0},"silence_logged":{},"nudge_state":{},"rollover":{}}' > "$STATE_FILE"
  log "watch start acct=$acct mode=$mode"
  while true; do
    if [ "$mode" != "push-through" ] && [ -f "$USAGE_FILE" ] && [ -n "$acct" ]; then
      local p5 r5 p7 r7
      read -r p5 r5 < <(read_window "$acct" five_hour)
      read -r p7 r7 < <(read_window "$acct" seven_day)
      check_window five_hour 5h "$p5" "$r5" "$CRIT_5H" "$SOFT_5H"
      check_window seven_day 7d "$p7" "$r7" "$CRIT_7D" "$SOFT_7D"
    fi
    check_silence "$plan_dir"
    check_rollover "$plan_dir" "$acct"
    # 120s poll: the loop is silent on clean ticks, so this is churn/debug-log reduction, not
    # output-rate reduction. Usage % moves slowly and the >10-min silence threshold dominates
    # trace latency, so a 2-min cadence loses nothing actionable.
    sleep 120
  done
}

# ---------------------------------------------------------------------------- dispatch

# Only dispatch when executed directly; when sourced (e.g. by tests) expose the functions only.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    status) shift; cmd_status "$@" ;;
    watch)  shift; cmd_watch  "$@" ;;
    *) echo "usage: usage-monitor.sh {status [ACCOUNT_KEY] | watch <PLAN_DIR> [ACCOUNT_KEY] [pause|push-through]}" >&2; exit 2 ;;
  esac
fi
