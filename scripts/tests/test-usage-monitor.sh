#!/bin/bash
# Test: scripts/usage-monitor.sh — liveness watch (NUDGE/silence) + status-mode account
# resolution and bands. Usage-limit handling lives in the limit sentinel (see
# test-limit-sentinel.sh); this script proves the monitor stays in its liveness lane:
# status reads the resolved account with clear/soft bands (soft >= 90, no critical tier),
# and watch emits ONLY the protocol §3 NUDGE candidates while tracing silence quietly.
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
fresh_state(){ echo '{"silence_logged":{},"nudge_state":{}}' > "$STATE_FILE"; }
mkusage(){ jq -nc --arg a "$1" --argjson p5 "$2" --argjson r5 "$3" --argjson p7 "$4" --argjson r7 "$5" \
  '{accounts:{($a):{rate_limits:{five_hour:{used_percentage:$p5,resets_at:$r5},seven_day:{used_percentage:$p7,resets_at:$r7}},updated_at:"2026-01-01T00:00:00Z"}}}' > "$USAGE_FILE"; }

echo "=== Test: usage-monitor.sh ==="
now=$(date +%s); past=$((now-120)); future=$((now+3600))

# --- status: account resolution + bands (clear/soft only; soft = don't START new work) ---
mkusage "acct-hot" 91 "$future" 40 "$future"
jq '.accounts["acct-cold"]={rate_limits:{five_hour:{used_percentage:2,resets_at:'"$future"'},seven_day:{used_percentage:3,resets_at:'"$future"'}},updated_at:"2026-01-01T00:00:00Z"}' \
  "$USAGE_FILE" > "$USAGE_FILE.t" && mv "$USAGE_FILE.t" "$USAGE_FILE"
js=$(cmd_status "acct-hot")
ck "status valid json" 0 "$(echo "$js" | jq empty >/dev/null 2>&1; echo $?)"
ck "reads resolved account (91 not 2)" 91 "$(echo "$js" | jq '.five_hour.pct')"
ck "91% is soft band" soft "$(echo "$js" | jq -r '.five_hour.band')"
ck "overall band soft" soft "$(echo "$js" | jq -r '.band')"
ck "different account is clear" clear "$(cmd_status acct-cold | jq -r '.band')"
mkusage "acct-under" 89 "$future" 50 "$future"
ck "89% still clear (soft starts at 90)" clear "$(cmd_status acct-under | jq -r '.band')"
mkusage "acct-7d" 10 "$future" 92 "$future"
ck "7d soft classified" soft "$(cmd_status acct-7d | jq -r '.seven_day.band')"
# Time-authoritative status: a STALE high pct whose reset time has passed must read clear
# (this is the "file has stale data" bug — statusline rewrites updated_at but not the numbers).
mkusage "acct-stale" 101 "$past" 95 "$past"
js3=$(cmd_status acct-stale)
ck "stale-after-reset 5h band clear" clear "$(echo "$js3" | jq -r '.five_hour.band')"
ck "stale-after-reset reset_elapsed true" true "$(echo "$js3" | jq -r '.five_hour.reset_elapsed')"
ck "stale-after-reset overall band clear" clear "$(echo "$js3" | jq -r '.band')"
# Genuinely over (high pct, reset still in the future) reads soft — never anything stronger:
# there is no critical tier; nothing proactively stops in-flight work anymore.
mkusage "acct-over" 101 "$future" 50 "$future"
ck "over-limit reads soft (no critical tier)" soft "$(cmd_status acct-over | jq -r '.five_hour.band')"

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

# --- removed responsibilities stay removed ---
ck "check_window is gone (sentinel's job)" 1 "$(type check_window >/dev/null 2>&1; echo $?)"
ck "check_rollover is gone (sentinel's job)" 1 "$(type check_rollover >/dev/null 2>&1; echo $?)"

if [ "$fail" -eq 0 ]; then echo "PASS ($pass checks)"; exit 0; else echo "FAILED ($fail of $((pass+fail)))"; exit 1; fi
