#!/bin/bash
# Ultra Claude SessionStart hook — establishes per-session account identity.
# Reads hook input from stdin, resolves the current Claude account,
# and writes account + session files for the statusline and dashboard.
# Installed by /uc:setup. Must complete in <500ms.

set -euo pipefail

# Source shared library
source "$HOME/.claude/ultra/lib.sh"

# Read hook input from stdin
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

[ -z "$session_id" ] && exit 0
[ -z "$cwd" ] && exit 0

# Resolve current Claude account
auth_json=$(claude auth status --json 2>/dev/null || echo '{}')
email=$(echo "$auth_json" | jq -r '.email // empty')
[ -z "$email" ] && exit 0

org_name=$(echo "$auth_json" | jq -r '.orgName // empty')
sub_type=$(echo "$auth_json" | jq -r '.subscriptionType // empty')
account_id=$(slugifyEmail "$email")

# Upsert account registry file
mkdir -p "$ACCOUNTS_DIR"
jq -n \
  --arg id "$account_id" \
  --arg email "$email" \
  --arg org "$org_name" \
  --arg sub "$sub_type" \
  '{
    account_id: $id,
    email: $email,
    orgName: (if $org == "" then null else $org end),
    subscriptionType: (if $sub == "" then null else $sub end),
    updated_at: (now | todate)
  }' > "${ACCOUNTS_DIR}/${account_id}.json"

# Create session file in project directory
sessions_dir="${cwd}/.claude/ultra/sessions"
mkdir -p "$sessions_dir"
jq -n \
  --arg id "$account_id" \
  '{
    account_id: $id,
    started_at: (now | todate),
    active: true
  }' > "${sessions_dir}/${session_id}.json"

# Revive the limit sentinel lazily — the first session after any reboot restarts it.
# Backgrounded + disowned so the hook stays fast; missing symlink (pre-setup) is a no-op.
if [ -x "$HOME/.claude/ultra/limit-sentinel.sh" ] || [ -L "$HOME/.claude/ultra/limit-sentinel.sh" ]; then
  (bash "$HOME/.claude/ultra/limit-sentinel.sh" ensure >/dev/null 2>&1 &) 2>/dev/null
fi
