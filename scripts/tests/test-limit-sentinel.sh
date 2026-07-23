#!/usr/bin/env bash
# Proves the limit sentinel's core logic (scripts/limit-sentinel.sh) without a real tmux or
# claude: machine-context parsing + runtime fallback, spool consumption into the parked ledger,
# per-window latching (advisory / wake / pre-open fire exactly once per (account, resets_at)),
# fleet + standalone wake mechanics via a recording tmux shim, pre-open chain-guards, 7d notice,
# registration pruning, and the ensure/status/stop lifecycle.
#
# ck conditions are SINGLE-quoted and evaluated (eval) in this shell's scope.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SENTINEL_SRC="$SCRIPT_DIR/../limit-sentinel.sh"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass=0; fail=0
ck() { if eval "$2"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1"; fi; }

# ---------------------------------------------------------------- sandbox + shims
export HOME="$TEST_DIR/home"
mkdir -p "$HOME/.claude/ultra" "$TEST_DIR/bin"
cat > "$HOME/.claude/ultra/lib.sh" <<'EOF'
slugifyEmail() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/@/-at-/; s/\./-/g; s/[^a-z0-9-]//g'; }
EOF

CALLS="$TEST_DIR/tmux-calls.log"; : > "$CALLS"
cat > "$TEST_DIR/bin/fake-tmux" <<EOF
#!/usr/bin/env bash
# recording tmux shim: panes "exist" unless named %dead; fg command overridable per pane via
# file tmux-fg-<pane>; screen content via tmux-screen-<pane>; send-keys are recorded.
D="$TEST_DIR"
EOF
cat >> "$TEST_DIR/bin/fake-tmux" <<'EOF'
case "$1" in
  display-message)
    pane="$4"; fmt="$5"
    [ "$pane" = "%dead" ] && exit 1
    case "$fmt" in
      '#{pane_id}') echo "$pane" ;;
      '#{pane_current_command}') [ -f "$D/tmux-fg-$pane" ] && cat "$D/tmux-fg-$pane" || echo claude ;;
    esac ;;
  capture-pane) pane="$4"; [ -f "$D/tmux-screen-$pane" ] && cat "$D/tmux-screen-$pane" ;;
  send-keys) shift; echo "send-keys $*" >> "$D/tmux-calls.log" ;;
  list-panes) [ -f "$D/tmux-panes.txt" ] && cat "$D/tmux-panes.txt" ;;
esac
exit 0
EOF
chmod +x "$TEST_DIR/bin/fake-tmux"

cat > "$TEST_DIR/bin/fake-claude" <<EOF
#!/usr/bin/env bash
echo "CLAUDE_CONFIG_DIR=\${CLAUDE_CONFIG_DIR:-} args=\$*" >> "$TEST_DIR/preopen.log"
EOF
chmod +x "$TEST_DIR/bin/fake-claude"

cat > "$TEST_DIR/bin/fake-notify" <<EOF
#!/usr/bin/env bash
echo "\$1" >> "$TEST_DIR/notify.log"
EOF
chmod +x "$TEST_DIR/bin/fake-notify"

export UC_SENTINEL_DIR="$TEST_DIR/sentinel"
export UC_USAGE_FILE="$TEST_DIR/usage-status.json"
export UC_SENTINEL_MC="$TEST_DIR/mc.md"
export UC_TEAMS_DIR="$TEST_DIR/teams"
export SENTINEL_TMUX="$TEST_DIR/bin/fake-tmux"
export CLAUDE_BIN="$TEST_DIR/bin/fake-claude"

source "$SENTINEL_SRC"
init_dirs

NOW=$(date +%s)
iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }

usage_entry() { # acct pct5 res5 pct7 res7 updated_at
  jq -nc --arg k "$1" --argjson p5 "$2" --argjson r5 "$3" --argjson p7 "$4" --argjson r7 "$5" --arg u "$6" \
    '{($k): {rate_limits:{five_hour:{used_percentage:$p5, resets_at:$r5},
                          seven_day:{used_percentage:$p7, resets_at:$r7}}, updated_at:$u}}'
}
write_usage() { # entries...
  jq -sc '{accounts: (add)}' <<<"$*" > "$UC_USAGE_FILE"
}

# ---------------------------------------------------------------- 1. machine context
cat > "$UC_SENTINEL_MC" <<EOF
map: acct-c = $TEST_DIR/profC
map: acct-d = $TEST_DIR/profD
map: acct-e = $TEST_DIR/profE
notify: $TEST_DIR/bin/fake-notify
EOF
ck "mc map hit"            '[ "$(mc_get_profile acct-c)" = "$TEST_DIR/profC" ]'
ck "mc unmapped -> empty"  '[ -z "$(mc_get_profile nobody-at-nowhere)" ]'
ck "mc notify cmd"         '[ "$(mc_notify_cmd)" = "$TEST_DIR/bin/fake-notify" ]'
ck "standalone-wake default on" '[ "$(mc_standalone_wake)" = "on" ]'
echo "standalone-wake: off" >> "$UC_SENTINEL_MC"
ck "standalone-wake off honored" '[ "$(mc_standalone_wake)" = "off" ]'
sed -i '/standalone-wake/d' "$UC_SENTINEL_MC"

# runtime fallback (no map line): profile dir scan by oauth email
mkdir -p "$HOME/.claude-profiles/testprof"
echo '{"oauthAccount":{"emailAddress":"Map.Me@Example.co"}}' > "$HOME/.claude-profiles/testprof/.claude.json"
ck "mc fallback via profile scan" '[ "$(mc_get_profile map-me-at-example-co)" = "$HOME/.claude-profiles/testprof" ]'
echo '{"oauthAccount":{"emailAddress":"root@example.co"}}' > "$HOME/.claude/.claude.json"
ck "mc fallback default profile" '[ "$(mc_get_profile root-at-example-co)" = "default" ]'

# ---------------------------------------------------------------- 2. spool consume + plan trace
REPO="$TEST_DIR/repo"
PLAN_DIR="$REPO/documentation/plans/testplan"
mkdir -p "$PLAN_DIR/tasks/task-1"
echo '{"events":[]}' > "$PLAN_DIR/events.json"
jq -nc --arg pd "$PLAN_DIR" '{tasks:[{task_id:"task-1", status:"in_progress"}]}' > "$PLAN_DIR/plan.json"
jq -nc --arg pd "$PLAN_DIR" '{plan_dir:$pd, account_key:"acct-b", gating:"on", lead_pane:"%L", tmux_session:"s"}' \
  > "$PLANS_DIR/testplan.json"

jq -nc --arg ts "$(iso $((NOW - 400)))" --arg cwd "$REPO" \
  '{ts:$ts, session_id:"sid-b-1", cwd:$cwd, error:"rate_limit",
    banner:"You'\''ve hit your session limit · resets 8pm", tmux_pane:"%S", account_id:"acct-b", config_dir:""}' \
  > "$EVENTS_DIR/1-sid-b-1.json"
consume_spool
ck "parked ledger entry"    '[ "$(get_state ".parked[\"sid-b-1\"].status")" = "parked" ]'
ck "spool file moved"       '[ -f "$EVENTS_DIR/processed/1-sid-b-1.json" ] && [ ! -f "$EVENTS_DIR/1-sid-b-1.json" ]'
ck "usage_limit_hit traced" 'jq -e ".events[] | select(.type==\"usage_limit_hit\" and .session_id==\"sid-b-1\")" "$PLAN_DIR/events.json" >/dev/null'

# ---------------------------------------------------------------- 3. advisory + latch + gating
write_usage \
  "$(usage_entry acct-a 92 $((NOW + 3000)) 40 $((NOW + 86400)) "$(iso "$NOW")")" \
  "$(usage_entry acct-b 100 $((NOW - 200)) 50 $((NOW + 86400)) "$(iso $((NOW - 3600)))")"
jq -nc --arg pd "$TEST_DIR/nowhere" '{plan_dir:$pd, account_key:"acct-a", gating:"on", lead_pane:"%A"}' \
  > "$PLANS_DIR/aplan.json"
mkdir -p "$TEST_DIR/nowhere"; echo '{"events":[],"tasks":[]}' > /dev/null

check_account acct-a
ck "advisory injected to lead"   'grep -q "SENTINEL ADVISORY \[5h\]: 92% used" "$CALLS"'
ck "advisory latched"            '[ "$(get_state ".accounts[\"acct-a\"].advisory_latch")" = "$((NOW + 3000))" ]'
: > "$CALLS"
check_account acct-a
ck "advisory fires once per window" '! grep -q "ADVISORY" "$CALLS"'
# gating off suppresses advisories
set_state '.accounts["acct-a"].advisory_latch = 0'
jq '.gating = "off"' "$PLANS_DIR/aplan.json" > "$PLANS_DIR/aplan.json.tmp" && mv "$PLANS_DIR/aplan.json.tmp" "$PLANS_DIR/aplan.json"
check_account acct-a
ck "gating off suppresses advisory" '! grep -q "ADVISORY" "$CALLS"'
rm -f "$PLANS_DIR/aplan.json"

# ---------------------------------------------------------------- 4. reset wake (plan + standalone)
mkdir -p "$UC_TEAMS_DIR/session-1"
jq -nc '{members:[{name:"pm-testplan", backendType:"tmux", tmuxPaneId:"%P"},
                  {name:"executor-1", backendType:"tmux", tmuxPaneId:"%W"},
                  {name:"team-lead", backendType:"tmux", tmuxPaneId:"%L"}]}' \
  > "$UC_TEAMS_DIR/session-1/config.json"
: > "$CALLS"
check_account acct-b
ck "sentinel RESUME in signals"  'grep -q "\"author\":\"sentinel\"" "$PLAN_DIR/tasks/task-1/signals.jsonl"'
ck "worker pane woken"           'grep -q "^send-keys -t %W -l RESUME: usage reset" "$CALLS"'
ck "lead got SENTINEL RESET"     'grep -q "%L -l SENTINEL RESET \[5h\]" "$CALLS"'
ck "workers woken before lead"   '[ "$(grep -n "%W" "$CALLS" | head -1 | cut -d: -f1)" -lt "$(grep -n "SENTINEL RESET" "$CALLS" | head -1 | cut -d: -f1)" ]'
ck "standalone pane woken"       'grep -q "%S -l SENTINEL RESET \[5h\]: the usage limit that interrupted you" "$CALLS"'
ck "parked marked resumed"       '[ "$(get_state ".parked[\"sid-b-1\"].status")" = "resumed" ]'
ck "wake latched"                '[ "$(get_state ".accounts[\"acct-b\"].wake_done")" = "$((NOW - 200))" ]'
ck "usage_reset_wake traced"     'jq -e ".events[] | select(.type==\"usage_reset_wake\")" "$PLAN_DIR/events.json" >/dev/null'
: > "$CALLS"
check_account acct-b
ck "wake fires once per window"  '[ ! -s "$CALLS" ]'

# busy pane is skipped (idempotent no-op)
set_state '.accounts["acct-b"].wake_done = 0'
set_state '.parked["sid-b-1"].status = "parked"'
echo "✻ Working… esc to interrupt" > "$TEST_DIR/tmux-screen-%S"
: > "$CALLS"
check_account acct-b
ck "busy pane skipped"           '! grep -q -- "-t %S -l" "$CALLS"'
rm -f "$TEST_DIR/tmux-screen-%S"

# ---------------------------------------------------------------- 5. pre-open + chain-guards
write_usage \
  "$(usage_entry acct-c 3 $((NOW - 300)) 10 $((NOW + 86400)) "$(iso $((NOW - 3600)))")" \
  "$(usage_entry acct-d 1 $((NOW - 300)) 10 $((NOW + 86400)) "$(iso $((NOW - 3600)))")" \
  "$(usage_entry acct-e 50 $((NOW - 300)) 10 $((NOW + 86400)) "$(iso "$NOW")")"
set_state '.accounts["acct-c"].last_window = {resets_at: 1, pct: 50}'
set_state '.accounts["acct-d"].last_window = {resets_at: 1, pct: 1}'
set_state '.accounts["acct-e"].last_window = {resets_at: 1, pct: 50}'
check_account acct-c; check_account acct-d; check_account acct-e
sleep 0.5
ck "preopen fired for mapped active-window acct" 'grep -q "CLAUDE_CONFIG_DIR=$TEST_DIR/profC args=-p ok --model haiku" "$TEST_DIR/preopen.log"'
ck "chain-guard: idle window skipped"  '! grep -q "profD" "$TEST_DIR/preopen.log" && grep -q "preopen skip acct-d: last window pct=1" "$LOG_FILE"'
ck "active account skipped"            '! grep -q "profE" "$TEST_DIR/preopen.log" && grep -q "preopen skip acct-e: account active" "$LOG_FILE"'
ck "preopen once per window"           '[ "$(grep -c profC "$TEST_DIR/preopen.log")" -eq 1 ]'

# unmapped account: wake latch still set, no preopen call
write_usage "$(usage_entry acct-x 80 $((NOW - 300)) 10 $((NOW + 86400)) "$(iso $((NOW - 3600)))")"
set_state '.accounts["acct-x"].last_window = {resets_at: 1, pct: 80}'
check_account acct-x; sleep 0.3
ck "unmapped account: no preopen"      '! grep -q "acct-x" "$TEST_DIR/preopen.log" && grep -q "preopen skip acct-x: unmapped" "$LOG_FILE"'

# stale-resets_at guard: resets_at PREDATES the parked event (idle account, stale statusline
# data) — the wake must NOT fire now; wake_at falls back to event+5h.
write_usage "$(usage_entry acct-g 100 $((NOW - 900)) 10 $((NOW + 86400)) "$(iso $((NOW - 7200)))")"
jq -nc --arg ts "$(iso "$NOW")" \
  '{ts:$ts, session_id:"sid-g-1", cwd:"/tmp/none", error:"rate_limit",
    banner:"You'\''ve hit your session limit · resets 9pm", tmux_pane:"%G", account_id:"acct-g", config_dir:""}' \
  > "$EVENTS_DIR/3-sid-g-1.json"
consume_spool
: > "$CALLS"
check_account acct-g
ck "stale resets_at: wake deferred (guard)" '! grep -q -- "-t %G" "$CALLS" && grep -q "wake guard acct-g" "$LOG_FILE"'
ck "stale resets_at: session still parked" '[ "$(get_state ".parked[\"sid-g-1\"].status")" = "parked" ]'

# ---------------------------------------------------------------- 6. 7d notice via spool banner
write_usage "$(usage_entry acct-f 10 $((NOW + 3000)) 100 $((NOW + 4*86400)) "$(iso "$NOW")")"
jq -nc --arg ts "$(iso "$NOW")" \
  '{ts:$ts, session_id:"sid-f-1", cwd:"/tmp/none", error:"rate_limit",
    banner:"You'\''ve hit your weekly limit · resets Mon 12am", tmux_pane:"", account_id:"acct-f", config_dir:""}' \
  > "$EVENTS_DIR/2-sid-f-1.json"
consume_spool; sleep 0.5
ck "7d notice notified"          'grep -q "weekly limit hit on acct-f" "$TEST_DIR/notify.log"'
ck "7d notice latched"           '[ "$(get_state ".accounts[\"acct-f\"].notice_7d_latch")" = "$((NOW + 4*86400))" ]'

# ---------------------------------------------------------------- 7. pruning
jq -nc --arg pd "$PLAN_DIR" '{plan_dir:$pd, account_key:"acct-b"}' > "$PLANS_DIR/doneplan.json"
jq '.status = "completed"' "$PLAN_DIR/plan.json" > "$PLAN_DIR/plan.json.tmp" && mv "$PLAN_DIR/plan.json.tmp" "$PLAN_DIR/plan.json"
prune
ck "completed plan registration pruned" '[ ! -f "$PLANS_DIR/doneplan.json" ]'

# ---------------------------------------------------------------- 8. lifecycle
UC_TICK_SECONDS=1 bash "$SENTINEL_SRC" ensure
sleep 1.2
ck "status running after ensure" '[ "$(bash "$SENTINEL_SRC" status | jq -r .running)" = "true" ]'
pid1=$(bash "$SENTINEL_SRC" status | jq -r .pid)
UC_TICK_SECONDS=1 bash "$SENTINEL_SRC" ensure
ck "ensure is a singleton"       '[ "$(bash "$SENTINEL_SRC" status | jq -r .pid)" = "$pid1" ]'
bash "$SENTINEL_SRC" stop >/dev/null
sleep 0.3
ck "stop works"                  '[ "$(bash "$SENTINEL_SRC" status | jq -r .running)" = "false" ]'

if [ "$fail" -eq 0 ]; then echo "PASS ($pass checks)"; exit 0
else echo "FAILED ($fail of $((pass+fail)) checks)"; exit 1; fi
