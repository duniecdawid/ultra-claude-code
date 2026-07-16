#!/bin/bash
# Test: scripts/usage-monitor.sh — watch-mode milestone logic + status-mode account resolution.
# Proves the monitor wakes ONLY on the critical-stop crossing and the work-can-restart reset,
# stays silent on clear/soft/stale ticks, and that status mode reads the resolved account.
# Exit 0 = pass, Exit 1 = fail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MONITOR="$SCRIPT_DIR/../usage-monitor.sh"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Source functions (the script self-guards dispatch when sourced), then point globals at the sandbox.
source "$MONITOR"
USAGE_FILE="$TEST_DIR/usage.json"
STATE_FILE="$TEST_DIR/state.json"
DEBUG_LOG="$TEST_DIR/dbg.log"

pass=0; fail=0
ck(){ if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "  FAIL: $1 (exp [$2] got [$3])"; fail=$((fail+1)); fi; }
fresh_state(){ echo '{"five_hour":{"last_signal":null,"reset_latch":0},"seven_day":{"last_signal":null,"reset_latch":0},"silence_logged":{},"nudge_state":{},"rollover":{}}' > "$STATE_FILE"; }
mkusage(){ jq -nc --arg a "$1" --argjson p5 "$2" --argjson r5 "$3" --argjson p7 "$4" --argjson r7 "$5" \
  '{accounts:{($a):{rate_limits:{five_hour:{used_percentage:$p5,resets_at:$r5},seven_day:{used_percentage:$p7,resets_at:$r7}},updated_at:"2026-01-01T00:00:00Z"}}}' > "$USAGE_FILE"; }

echo "=== Test: usage-monitor.sh ==="
now=$(date +%s); past=$((now-120)); future=$((now+3600))

# --- watch: check_window ---
fresh_state; ck "clear → silent" "" "$(check_window five_hour 5h 50 "$future" 90 80)"
fresh_state; ck "soft → silent (spawn-time only)" "" "$(check_window five_hour 5h 85 "$future" 90 80)"
fresh_state
ck "critical crossing → CRITICAL" 1 "$(check_window five_hour 5h 91 "$future" 90 80 | grep -c '"alert":"CRITICAL"')"
ck "no re-emit while critical" "" "$(check_window five_hour 5h 92 "$future" 90 80)"
ck "reset-time-passed → USAGE-RESET reason" 1 "$(check_window five_hour 5h 92 "$past" 90 80 | grep -c reset_time_passed)"
ck "latch suppresses re-CRITICAL on stale data" "" "$(check_window five_hour 5h 92 "$past" 90 80)"
ck "fresh low data → silent + latch clears" "" "$(check_window five_hour 5h 5 "$future" 90 80)"
ck "latch cleared" 0 "$(jq -r '.five_hour.reset_latch' "$STATE_FILE")"
ck "re-cross critical → CRITICAL again" 1 "$(check_window five_hour 5h 91 "$future" 90 80 | grep -c '"alert":"CRITICAL"')"
fresh_state; jq '.five_hour.last_signal="critical"' "$STATE_FILE" > "$STATE_FILE.t" && mv "$STATE_FILE.t" "$STATE_FILE"
ck "fresh drop below soft → USAGE-RESET (no reason)" 0 "$(check_window five_hour 5h 10 "$future" 90 80 | grep -c reason)"
fresh_state; ck "never-critical + reset passed → no spurious reset" "" "$(check_window five_hour 5h 50 "$past" 90 80)"

# --- status: account resolution + bands ---
mkusage "acct-hot" 91 "$future" 40 "$future"
jq '.accounts["acct-cold"]={rate_limits:{five_hour:{used_percentage:2,resets_at:'"$future"'},seven_day:{used_percentage:3,resets_at:'"$future"'}},updated_at:"2026-01-01T00:00:00Z"}' \
  "$USAGE_FILE" > "$USAGE_FILE.t" && mv "$USAGE_FILE.t" "$USAGE_FILE"
js=$(cmd_status "acct-hot")
ck "status valid json" 0 "$(echo "$js" | jq empty >/dev/null 2>&1; echo $?)"
ck "reads resolved account (91 not 2)" 91 "$(echo "$js" | jq '.five_hour.pct')"
ck "overall band critical" critical "$(echo "$js" | jq -r '.band')"
ck "different account is clear" clear "$(cmd_status acct-cold | jq -r '.band')"
mkusage "acct-soft" 84 "$future" 50 "$future"
ck "soft band classified" soft "$(cmd_status acct-soft | jq -r '.band')"
# Time-authoritative status: a STALE high pct whose reset time has passed must read clear
# (this is the "file has stale data" bug — statusline rewrites updated_at but not the numbers).
mkusage "acct-stale" 101 "$past" 80 "$past"
js3=$(cmd_status acct-stale)
ck "stale-after-reset 5h band clear" clear "$(echo "$js3" | jq -r '.five_hour.band')"
ck "stale-after-reset reset_elapsed true" true "$(echo "$js3" | jq -r '.five_hour.reset_elapsed')"
ck "stale-after-reset overall band clear" clear "$(echo "$js3" | jq -r '.band')"
# Genuinely over (high pct, reset still in the future) must read critical
mkusage "acct-over" 96 "$future" 50 "$future"
ck "real over-limit reads critical" critical "$(cmd_status acct-over | jq -r '.five_hour.band')"

# --- watch: check_silence — quiet trace + NUDGE ladder (protocol §3 yield-rule violations) ---
REPO="$TEST_DIR/repo"; PLAN_DIR="$REPO/docs/plans/p1"
mkdir -p "$PLAN_DIR"; git init -q "$REPO" 2>/dev/null
stale_ts=$(date -u -d "20 minutes ago" +%Y-%m-%dT%H:%M:%SZ)
park_ts=$(date -u -d "15 minutes ago" +%Y-%m-%dT%H:%M:%SZ)
fresh_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p "$PLAN_DIR/tasks/task-1"
echo '{"tasks":[{"task_id":"task-1","status":"in_progress"}]}' > "$PLAN_DIR/plan.json"
jq -nc --arg ts "$stale_ts" '{events:[{timestamp:$ts,type:"stage_entered",task_id:"task-1",agent:"pm",message:"x"}]}' > "$PLAN_DIR/events.json"
fresh_state
out=$(check_silence "$PLAN_DIR")
ck "wrongly parked (no named wait, quiet tree) → NUDGE count:1" 1 "$(echo "$out" | grep -c '"alert":"NUDGE".*"count":1')"
ck "silence_observed traced to events.json" 1 "$(jq '[.events[] | select(.type=="silence_observed" and .task_id=="task-1")] | length' "$PLAN_DIR/events.json")"
ck "immediate re-run → no second NUDGE (600s window)" "" "$(check_silence "$PLAN_DIR")"
ck "no duplicate trace while still silent" 1 "$(jq '[.events[] | select(.type=="silence_observed")] | length' "$PLAN_DIR/events.json")"
jq '.nudge_state["task-1"].last_emit -= 700' "$STATE_FILE" > "$STATE_FILE.t" && mv "$STATE_FILE.t" "$STATE_FILE"
ck "violation persists into next window → NUDGE count:2" 1 "$(check_silence "$PLAN_DIR" | grep -c '"count":2')"
# A recorded named wait is a legitimate park: trace still happens, NUDGE must not.
fresh_state
echo '{"ts":"'"$park_ts"'","signal":"WAITING_ON","author":"executor-1","note":"REVIEW_PASS from reviewer-1"}' > "$PLAN_DIR/tasks/task-1/signals.jsonl"
ck "WAITING_ON latest → no NUDGE" "" "$(check_silence "$PLAN_DIR")"
ck "WAITING_ON park still traced quietly" 2 "$(jq '[.events[] | select(.type=="silence_observed")] | length' "$PLAN_DIR/events.json")"
ck "no nudge state for legitimate park" 0 "$(jq '.nudge_state | has("task-1") | if . then 1 else 0 end' "$STATE_FILE")"
# Repo file activity suppresses the NUDGE even with no named wait (someone is building/editing).
fresh_state
echo '{"ts":"'"$park_ts"'","signal":"ADVICE_RESPONSE","author":"lead","note":"x"}' > "$PLAN_DIR/tasks/task-1/signals.jsonl"
touch "$REPO/src.txt"
ck "repo activity suppresses NUDGE" "" "$(check_silence "$PLAN_DIR")"
touch -d "20 minutes ago" "$REPO/src.txt"
ck "tree quiet again → NUDGE fires" 1 "$(check_silence "$PLAN_DIR" | grep -c '"alert":"NUDGE"')"
# Fresh task activity ends the episode: both debounces self-clear.
echo '{"ts":"'"$fresh_ts"'","signal":"REVIEW_REQUESTED","author":"executor-1"}' >> "$PLAN_DIR/tasks/task-1/signals.jsonl"
check_silence "$PLAN_DIR"
ck "silence debounce self-clears on fresh activity" 0 "$(jq '.silence_logged | has("task-1") | if . then 1 else 0 end' "$STATE_FILE")"
ck "nudge ladder self-clears on fresh activity" 0 "$(jq '.nudge_state | has("task-1") | if . then 1 else 0 end' "$STATE_FILE")"

# --- watch: check_rollover (quiet usage_window_rolled trace — never stdout) ---
fresh_state
PLAN2="$TEST_DIR/plan2"; mkdir -p "$PLAN2"
echo '{"tasks":[{"task_id":"task-1","status":"in_progress"}]}' > "$PLAN2/plan.json"
echo '{"events":[]}' > "$PLAN2/events.json"
mkusage "acct-roll" 50 "$future" 40 "$future"
ck "rollover first sight → no stdout, no event" "" "$(check_rollover "$PLAN2" "acct-roll")"
ck "rollover first sight stores resets_at" "$future" "$(jq -r '.rollover.five_hour' "$STATE_FILE")"
mkusage "acct-roll" 5 "$((future+3600))" 40 "$future"
check_rollover "$PLAN2" "acct-roll"
ck "resets_at advanced mid-task → usage_window_rolled" 1 "$(jq '[.events[] | select(.type=="usage_window_rolled" and .window=="5h")] | length' "$PLAN2/events.json")"
ck "unchanged 7d window → no extra event" 1 "$(jq '[.events[] | select(.type=="usage_window_rolled")] | length' "$PLAN2/events.json")"
echo '{"tasks":[{"task_id":"task-1","status":"completed"}]}' > "$PLAN2/plan.json"
mkusage "acct-roll" 5 "$((future+7200))" 40 "$future"
check_rollover "$PLAN2" "acct-roll"
ck "no in_progress task → rollover not evented" 1 "$(jq '[.events[] | select(.type=="usage_window_rolled")] | length' "$PLAN2/events.json")"

if [ "$fail" -eq 0 ]; then echo "PASS ($pass checks)"; exit 0; else echo "FAILED ($fail of $((pass+fail)))"; exit 1; fi
