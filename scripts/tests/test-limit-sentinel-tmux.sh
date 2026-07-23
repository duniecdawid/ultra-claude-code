#!/usr/bin/env bash
# Proves the limit sentinel's REAL tmux interactions on a private socket (tmux -L):
#   - pane discovery via @agent-name labels (team_panes_for_plan fallback path)
#   - inject_pane: -l literal text + separate Enter actually reaches the pane's stdin
#   - foreground-process guard (non-claude pane is never typed into)
#   - busy-footer guard ("esc to interrupt" visible -> no-op)
#   - menu-dismiss pre-step (rate-limit menu visible -> Enter first, then the message)
# SKIPs cleanly when tmux is unavailable.
set -uo pipefail

command -v tmux >/dev/null 2>&1 || { echo "SKIP (tmux not installed)"; exit 0; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SENTINEL_SRC="$SCRIPT_DIR/../limit-sentinel.sh"

TEST_DIR=$(mktemp -d)
SOCK="uc-test-$$"
T() { tmux -L "$SOCK" "$@"; }
trap 'tmux -L "$SOCK" kill-server 2>/dev/null; rm -rf "$TEST_DIR"' EXIT

pass=0; fail=0
ck() { if eval "$2"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1"; fi; }

# A fake "claude" binary: tmux reports pane_current_command from argv[0], so a cat copy named
# `claude` satisfies the sentinel's foreground guard while capturing injected keystrokes.
mkdir -p "$TEST_DIR/bin"
cp /bin/cat "$TEST_DIR/bin/claude"

export HOME="$TEST_DIR/home"; mkdir -p "$HOME/.claude/ultra"
export UC_SENTINEL_DIR="$TEST_DIR/sentinel"
export UC_USAGE_FILE="$TEST_DIR/usage-status.json"
export UC_SENTINEL_MC="$TEST_DIR/mc.md"
export UC_TEAMS_DIR="$TEST_DIR/teams"
export SENTINEL_TMUX="tmux -L $SOCK"
source "$SENTINEL_SRC"
init_dirs

wait_for() { # condition timeout_s
  local n=0; until eval "$1" || [ $n -ge $((${2:-10} * 2)) ]; do sleep 0.5; n=$((n+1)); done; eval "$1"
}

# ---------------------------------------------------------------- pane zoo
T new-session -d -s zoo -x 200 -y 50 "exec $TEST_DIR/bin/claude > $TEST_DIR/received-plain.txt"
T set-option -p -t zoo:0.0 @agent-name "task-1-executor"
PLAIN=$(T display-message -p -t zoo:0.0 '#{pane_id}')

T split-window -d -t zoo:0 "echo '✻ Churning… (esc to interrupt)'; exec $TEST_DIR/bin/claude > $TEST_DIR/received-busy.txt"
BUSY=$(T list-panes -t zoo:0 -F '#{pane_id}' | tail -1)

# Menu pane: the rate-limit menu is SCREEN CONTENT while the claude fg process keeps reading
# stdin — the menu-dismiss Enter lands as the first (empty) input line, then the message.
T new-window -d -t zoo -n menu \
  "printf '  What do you want to do?\n  ❯ 1. Stop and wait for limit to reset\n    2. Add funds\n'; exec $TEST_DIR/bin/claude > $TEST_DIR/received-menu.txt"
MENU=$(T list-panes -t zoo:menu -F '#{pane_id}')

T new-window -d -t zoo -n shell "exec bash -i"
SHELL_PANE=$(T list-panes -t zoo:shell -F '#{pane_id}')
T set-option -p -t "$SHELL_PANE" @agent-name "pm-fakeplan"

wait_for "pane_fg \"$PLAIN\" | grep -q claude" 10

# ---------------------------------------------------------------- discovery (label fallback)
found=$(team_panes_for_plan fakeplan)
ck "label scan finds executor pane" 'grep -q "task-1-executor $PLAIN" <<<"$found"'
ck "label scan finds pm pane"       'grep -q "pm-fakeplan $SHELL_PANE" <<<"$found"'

# ---------------------------------------------------------------- injection into a live pane
inject_pane "$PLAIN" "RESUME: usage reset. Continue work."
rc=$?
ck "inject returns 0"        '[ "$rc" -eq 0 ]'
wait_for "grep -q 'RESUME: usage reset' \"$TEST_DIR/received-plain.txt\"" 10
ck "text reached pane stdin" 'grep -q "^RESUME: usage reset. Continue work.$" "$TEST_DIR/received-plain.txt"'

# ---------------------------------------------------------------- guards
inject_pane "$SHELL_PANE" "SHOULD-NOT-ARRIVE"
rc=$?
ck "non-claude fg refused"   '[ "$rc" -ne 0 ]'

inject_pane "$BUSY" "SHOULD-NOT-ARRIVE-BUSY"
rc=$?
ck "busy footer refused"     '[ "$rc" -ne 0 ]'
ck "busy pane got no input"  '! grep -q "SHOULD-NOT-ARRIVE-BUSY" "$TEST_DIR/received-busy.txt" 2>/dev/null'

inject_pane "%999" "SHOULD-NOT-ARRIVE" ; rc=$?
ck "dead pane refused"       '[ "$rc" -ne 0 ]'

# ---------------------------------------------------------------- menu-dismiss pre-step
wait_for "pane_has_limit_menu \"$MENU\"" 5
inject_pane "$MENU" "SENTINEL RESET [5h]: continue."
rc=$?
ck "menu inject returns 0"   '[ "$rc" -eq 0 ]'
wait_for "grep -q 'SENTINEL RESET' \"$TEST_DIR/received-menu.txt\"" 10
ck "menu dismissed then message delivered" 'grep -q "SENTINEL RESET \[5h\]: continue." "$TEST_DIR/received-menu.txt"'
ck "dismiss Enter preceded the message" '[ -z "$(head -1 "$TEST_DIR/received-menu.txt")" ]'

if [ "$fail" -eq 0 ]; then echo "PASS ($pass checks)"; exit 0
else echo "FAILED ($fail of $((pass+fail)) checks)"; exit 1; fi
