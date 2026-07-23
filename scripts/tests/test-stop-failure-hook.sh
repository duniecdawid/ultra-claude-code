#!/usr/bin/env bash
# Proves the StopFailure hook contract (scripts/hooks/stop-failure.sh):
#   - writes exactly one well-formed spool event per invocation (atomic tmp+mv)
#   - resolves account_id from the session file written by session-start.sh
#   - falls back to `claude auth status` + slugifyEmail when the session file is missing
#   - captures TMUX_PANE / TMUX / CLAUDE_CONFIG_DIR from the environment
#   - exits 0 and writes nothing harmful on garbage / empty stdin
#   - stays fast (<2s even on the slow path)
#
# Convention: ck conditions are SINGLE-quoted and reference test-shell variables directly;
# they are expanded inside ck's eval, in this shell's scope.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/stop-failure.sh"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass=0; fail=0
ck() { # name condition
  if eval "$2"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1"; fi
}

# Sandbox HOME so the hook writes its spool under the test dir.
export HOME="$TEST_DIR/home"
mkdir -p "$HOME/.claude/ultra"
EVENTS="$HOME/.claude/ultra/sentinel/events"

# Fake lib.sh with the real slugify logic (mirrors scripts/lib.sh).
cat > "$HOME/.claude/ultra/lib.sh" <<'EOF'
slugifyEmail() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/@/-at-/; s/\./-/g; s/[^a-z0-9-]//g'; }
EOF

# Fake project cwd with a session file.
CWD="$TEST_DIR/proj"
SID="11111111-2222-3333-4444-555555555555"
mkdir -p "$CWD/.claude/ultra/sessions"
echo '{"account_id":"tester-at-example-com","email":"tester@example.com"}' \
  > "$CWD/.claude/ultra/sessions/$SID.json"

payload() {
  jq -nc --arg sid "$SID" --arg cwd "$CWD" \
    '{session_id:$sid, transcript_path:"/tmp/x.jsonl", cwd:$cwd, prompt_id:"p1",
      hook_event_name:"StopFailure", error:"rate_limit",
      last_assistant_message:"You'\''ve hit your session limit · resets 7:52pm (Europe/Warsaw)"}'
}

# --- 1. happy path: session-file account resolution + env capture -------------------------
TMUX_PANE="%42" TMUX="/tmp/tmux-1000/default,123,0" CLAUDE_CONFIG_DIR="$TEST_DIR/prof" \
  bash "$HOOK" <<<"$(payload)"
rc=$?
ck "exit 0 happy path"       '[ "$rc" -eq 0 ]'
evt=$(ls "$EVENTS"/*.json 2>/dev/null | head -1)
ck "one spool event written" '[ -n "$evt" ] && [ "$(ls "$EVENTS"/*.json | wc -l)" -eq 1 ]'
ck "no tmp leftovers"        '[ -z "$(ls "$EVENTS"/*.tmp 2>/dev/null)" ]'
ck "event is valid json"     'jq -e . "$evt" >/dev/null 2>&1'
ck "session_id recorded"     '[ "$(jq -r .session_id "$evt")" = "$SID" ]'
ck "account from session file" '[ "$(jq -r .account_id "$evt")" = "tester-at-example-com" ]'
ck "error recorded"          '[ "$(jq -r .error "$evt")" = "rate_limit" ]'
ck "banner recorded"         'jq -r .banner "$evt" | grep -q "hit your session limit"'
ck "tmux_pane captured"      '[ "$(jq -r .tmux_pane "$evt")" = "%42" ]'
ck "config_dir captured"     '[ "$(jq -r .config_dir "$evt")" = "$TEST_DIR/prof" ]'
rm -f "$EVENTS"/*.json

# --- 2. fallback path: no session file -> claude auth status shim ------------------------
mkdir -p "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/claude" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "auth" ] && echo '{"email":"Fallback.User@Example.co"}'
EOF
chmod +x "$TEST_DIR/bin/claude"
rm -f "$CWD/.claude/ultra/sessions/$SID.json"
PATH="$TEST_DIR/bin:$PATH" bash "$HOOK" <<<"$(payload)"
evt=$(ls "$EVENTS"/*.json 2>/dev/null | head -1)
ck "fallback account slugified" '[ "$(jq -r .account_id "$evt")" = "fallback-user-at-example-co" ]'
rm -f "$EVENTS"/*.json

# --- 3. garbage / empty stdin ---------------------------------------------------------------
bash "$HOOK" <<<"this is not json {{{"
rc=$?
ck "exit 0 on garbage"       '[ "$rc" -eq 0 ]'
evt=$(ls "$EVENTS"/*.json 2>/dev/null | head -1)
ck "garbage still spooled (raw evidence)" '[ -n "$evt" ] && jq -e . "$evt" >/dev/null'
rm -f "$EVENTS"/*.json

bash "$HOOK" </dev/null
rc=$?
ck "exit 0 on empty stdin"   '[ "$rc" -eq 0 ]'
ck "empty stdin writes nothing" '[ -z "$(ls "$EVENTS"/*.json 2>/dev/null)" ]'

# --- 4. speed --------------------------------------------------------------------------------
t0=$(date +%s%N)
bash "$HOOK" <<<"$(payload)"
t1=$(date +%s%N)
ck "runs under 2s"           '[ $(( (t1 - t0) / 1000000 )) -lt 2000 ]'

# --- 5. sentinel ensure is attempted when present --------------------------------------------
cat > "$HOME/.claude/ultra/limit-sentinel.sh" <<EOF
#!/usr/bin/env bash
[ "\$1" = "ensure" ] && touch "$TEST_DIR/ensure-called"
EOF
chmod +x "$HOME/.claude/ultra/limit-sentinel.sh"
bash "$HOOK" <<<"$(payload)"
sleep 0.4
ck "sentinel ensure invoked" '[ -f "$TEST_DIR/ensure-called" ]'

if [ "$fail" -eq 0 ]; then echo "PASS ($pass checks)"; exit 0
else echo "FAILED ($fail of $((pass+fail)) checks)"; exit 1; fi
