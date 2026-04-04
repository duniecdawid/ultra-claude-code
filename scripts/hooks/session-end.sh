#!/bin/bash
# Ultra Claude SessionEnd hook — marks the session as inactive.
# Reads hook input from stdin, updates the session file.
# Installed by /uc:setup. Handles missing session file gracefully.

set -euo pipefail

# Source shared library
source "$HOME/.claude/ultra/lib.sh"

# Read hook input from stdin
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

[ -z "$session_id" ] && exit 0
[ -z "$cwd" ] && exit 0

# Update session file if it exists
session_file="${cwd}/.claude/ultra/sessions/${session_id}.json"
[ ! -f "$session_file" ] && exit 0

jq '.active = false | .ended_at = (now | todate)' "$session_file" > "${session_file}.tmp" \
  && mv "${session_file}.tmp" "$session_file"
