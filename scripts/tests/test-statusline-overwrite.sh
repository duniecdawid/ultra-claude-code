#!/bin/bash
# Test: statusline usage-status.json overwrite behavior
# Proves that most-recent-write-wins: wrong data is overwritten by correct data.
# Exit 0 = pass, Exit 1 = fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUSLINE="$SCRIPT_DIR/../statusline.sh"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

echo "=== Test: statusline overwrite guard removed ==="
echo "Test dir: $TEST_DIR"

# --- Setup mock environment ---
export HOME="$TEST_DIR"
mkdir -p "$TEST_DIR/.claude/ultra/accounts"
mkdir -p "$TEST_DIR/project/.claude/ultra/sessions"

# Create lib.sh with shared functions
cat > "$TEST_DIR/.claude/ultra/lib.sh" << 'LIBEOF'
ULTRA_DIR="$HOME/.claude/ultra"
ACCOUNTS_DIR="$ULTRA_DIR/accounts"
slugifyEmail() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/@/-at-/g; s/\./-/g; s/[^a-z0-9-]//g'
}
LIBEOF

# Create account file for "user@example.com" → "user-at-example-com"
ACCOUNT_ID="user-at-example-com"
cat > "$TEST_DIR/.claude/ultra/accounts/${ACCOUNT_ID}.json" << EOF
{"account_id":"${ACCOUNT_ID}","email":"user@example.com","orgName":null,"subscriptionType":"pro"}
EOF

# Create session files
SESSION_WRONG="wrong-session-111"
SESSION_CORRECT="correct-session-222"
cat > "$TEST_DIR/project/.claude/ultra/sessions/${SESSION_WRONG}.json" << EOF
{"account_id":"${ACCOUNT_ID}","started_at":"2026-04-11T10:00:00Z","active":true,"pid":1,"tmux_pane":null,"last_activity":"2026-04-11T10:00:00Z"}
EOF
cat > "$TEST_DIR/project/.claude/ultra/sessions/${SESSION_CORRECT}.json" << EOF
{"account_id":"${ACCOUNT_ID}","started_at":"2026-04-11T10:05:00Z","active":true,"pid":2,"tmux_pane":null,"last_activity":"2026-04-11T10:05:00Z"}
EOF

# --- Step 1: Write "wrong" data (misattributed high usage from wrong session) ---
echo ""
echo "Step 1: Writing wrong data (high rate limits from wrong session)..."

WRONG_INPUT=$(cat << EOF
{
  "session_id": "${SESSION_WRONG}",
  "workspace": {"current_dir": "$TEST_DIR/project"},
  "model": {"display_name": "Claude Sonnet 4.6"},
  "context_window": {"used_percentage": 45},
  "cost": {"total_cost_usd": 1.50},
  "rate_limits": {
    "five_hour": {"used_percentage": 85, "resets_at": "2026-04-11T15:00:00Z"},
    "seven_day": {"used_percentage": 60, "resets_at": "2026-04-17T10:00:00Z"}
  }
}
EOF
)

echo "$WRONG_INPUT" | bash "$STATUSLINE" > /dev/null 2>&1 || true

USAGE_FILE="$TEST_DIR/.claude/ultra/usage-status.json"
if [ ! -f "$USAGE_FILE" ]; then
  echo "FAIL: usage-status.json not created after first write"
  exit 1
fi

WRONG_SESSION_ID=$(jq -r ".accounts[\"${ACCOUNT_ID}\"].source_session_id" "$USAGE_FILE")
WRONG_5H=$(jq -r ".accounts[\"${ACCOUNT_ID}\"].rate_limits.five_hour.used_percentage" "$USAGE_FILE")
echo "  source_session_id: $WRONG_SESSION_ID (expect: $SESSION_WRONG)"
echo "  5h rate limit: $WRONG_5H (expect: 85)"

if [ "$WRONG_SESSION_ID" != "$SESSION_WRONG" ]; then
  echo "FAIL: Wrong session ID not written"
  exit 1
fi

# --- Step 2: Write "correct" data (lower usage from correct session — must overwrite) ---
echo ""
echo "Step 2: Writing correct data (lower rate limits from correct session)..."

CORRECT_INPUT=$(cat << EOF
{
  "session_id": "${SESSION_CORRECT}",
  "workspace": {"current_dir": "$TEST_DIR/project"},
  "model": {"display_name": "Claude Opus 4.6"},
  "context_window": {"used_percentage": 20},
  "cost": {"total_cost_usd": 3.00},
  "rate_limits": {
    "five_hour": {"used_percentage": 30, "resets_at": "2026-04-11T15:00:00Z"},
    "seven_day": {"used_percentage": 25, "resets_at": "2026-04-17T10:00:00Z"}
  }
}
EOF
)

echo "$CORRECT_INPUT" | bash "$STATUSLINE" > /dev/null 2>&1 || true

# --- Step 3: Verify correct data overwrote wrong data ---
echo ""
echo "Step 3: Verifying overwrite..."

FINAL_SESSION_ID=$(jq -r ".accounts[\"${ACCOUNT_ID}\"].source_session_id" "$USAGE_FILE")
FINAL_5H=$(jq -r ".accounts[\"${ACCOUNT_ID}\"].rate_limits.five_hour.used_percentage" "$USAGE_FILE")
FINAL_7D=$(jq -r ".accounts[\"${ACCOUNT_ID}\"].rate_limits.seven_day.used_percentage" "$USAGE_FILE")
FINAL_MODEL=$(jq -r ".accounts[\"${ACCOUNT_ID}\"].model" "$USAGE_FILE")

echo "  source_session_id: $FINAL_SESSION_ID (expect: $SESSION_CORRECT)"
echo "  5h rate limit: $FINAL_5H (expect: 30)"
echo "  7d rate limit: $FINAL_7D (expect: 25)"
echo "  model: $FINAL_MODEL (expect: Claude Opus 4.6)"

PASS=true

if [ "$FINAL_SESSION_ID" != "$SESSION_CORRECT" ]; then
  echo "FAIL: source_session_id not overwritten (got $FINAL_SESSION_ID, expected $SESSION_CORRECT)"
  PASS=false
fi

if [ "$FINAL_5H" != "30" ]; then
  echo "FAIL: 5h rate limit not overwritten (got $FINAL_5H, expected 30)"
  echo "  This means the old overwrite guard is still active — higher values were kept"
  PASS=false
fi

if [ "$FINAL_7D" != "25" ]; then
  echo "FAIL: 7d rate limit not overwritten (got $FINAL_7D, expected 25)"
  PASS=false
fi

if [ "$FINAL_MODEL" != "Claude Opus 4.6" ]; then
  echo "FAIL: model not overwritten (got $FINAL_MODEL, expected Claude Opus 4.6)"
  PASS=false
fi

echo ""
if [ "$PASS" = true ]; then
  echo "PASS: Most-recent-write-wins confirmed — correct data overwrote wrong data"
  exit 0
else
  echo "FAIL: Overwrite guard still active or data corruption detected"
  echo "Full usage-status.json:"
  jq '.' "$USAGE_FILE"
  exit 1
fi
