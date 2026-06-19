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
fresh_state(){ echo '{"five_hour":{"last_signal":null,"reset_latch":0},"seven_day":{"last_signal":null,"reset_latch":0},"stall_pinged":{}}' > "$STATE_FILE"; }
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

if [ "$fail" -eq 0 ]; then echo "PASS ($pass checks)"; exit 0; else echo "FAILED ($fail of $((pass+fail)))"; exit 1; fi
