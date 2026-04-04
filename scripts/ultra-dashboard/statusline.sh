#!/bin/bash
# Ultra Claude statusline — displays prompt info + persists usage data per account for the dashboard.
# Installed by /uc:setup. Configured via settings.json: statusLine.command

# Read JSON input from stdin
input=$(cat)

# --- Resolve identity (cached per session) ---
session_id=$(echo "$input" | jq -r '.session_id // empty')
auth_cache_dir="$HOME/.claude/ultra/statusline-auth"
mkdir -p "$auth_cache_dir" 2>/dev/null
auth_cache="${auth_cache_dir}/${session_id}.json"

if [ -n "$session_id" ] && [ -f "$auth_cache" ]; then
  email=$(jq -r '.email // empty' "$auth_cache")
  org_name=$(jq -r '.orgName // empty' "$auth_cache")
  sub_type=$(jq -r '.subscriptionType // empty' "$auth_cache")
else
  auth_json=$(claude auth status --json 2>/dev/null || echo '{}')
  email=$(echo "$auth_json" | jq -r '.email // empty')
  org_name=$(echo "$auth_json" | jq -r '.orgName // empty')
  sub_type=$(echo "$auth_json" | jq -r '.subscriptionType // empty')
  if [ -n "$session_id" ] && [ -n "$email" ]; then
    echo "$auth_json" > "$auth_cache"
  fi
fi

# --- Persist usage data keyed by account email ---
usage_file="$HOME/.claude/ultra/usage-status.json"
if [ -n "$session_id" ] && [ -n "$email" ]; then
  snippet=$(echo "$input" | jq -c \
    --arg email "$email" \
    --arg org "$org_name" \
    --arg sub "$sub_type" \
    '{
      email: $email,
      orgName: (if $org == "" then null else $org end),
      subscriptionType: (if $sub == "" then null else $sub end),
      session_id: .session_id,
      model: .model.display_name,
      context_used: .context_window.used_percentage,
      cost_usd: .cost.total_cost_usd,
      rate_limits: .rate_limits,
      updated_at: (now | todate)
    }')
  # Atomic write: update accounts map keyed by email (flock to prevent concurrent corruption)
  # Overwrite guard: never replace higher rate-limit usage with lower values unless the
  # reset window has passed. Prevents account-switch misidentification from corrupting data.
  (
    flock -w 2 9 || exit 0
    if [ -f "$usage_file" ]; then
      jq -c --arg key "$email" \
        --argjson new "$snippet" \
        '
        .accounts //= {} |
        (.accounts[$key] // null) as $old |
        # Merge rate limits: keep higher usage if reset window has not passed
        (if $old and $old.rate_limits and $new.rate_limits then
          ($new.rate_limits | to_entries | map(
            .key as $k | .value as $nv |
            ($old.rate_limits[$k] // null) as $ov |
            if $ov and $nv and
               ($ov.used_percentage > $nv.used_percentage) and
               ($ov.resets_at > now)
            then {key: $k, value: $ov}
            else {key: $k, value: $nv}
            end
          ) | from_entries)
        else
          $new.rate_limits
        end) as $merged_rl |
        .accounts[$key] = ($new | .rate_limits = $merged_rl) |
        .updated_at = (now | todate)
        ' \
        "$usage_file" \
        > "${usage_file}.tmp" 2>/dev/null && mv "${usage_file}.tmp" "$usage_file"
    else
      echo "$snippet" | jq -c --arg key "$email" \
        '{accounts: {($key): .}, updated_at: (now | todate)}' \
        > "$usage_file" 2>/dev/null
    fi
  ) 9>"${usage_file}.lock"
fi

# --- Location ---
host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd=$(pwd)
project=$(basename "$cwd")

# --- Model (short name) ---
model_raw=$(echo "$input" | jq -r '.model.display_name // empty')
model=""
case "${model_raw,,}" in
  *opus*)   model="opus" ;;
  *sonnet*) model="sonnet" ;;
  *haiku*)  model="haiku" ;;
  *)        model="$model_raw" ;;
esac

# --- Context window ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# --- Rate limits (compact) ---
rl_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Colors
reset="\033[0m"
bold="\033[1m"
cyan="\033[36m"
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
dim="\033[2m"

pct_color() {
  local v=$(printf "%.0f" "$1" 2>/dev/null)
  if [ "$v" -ge 90 ] 2>/dev/null; then echo "$red"
  elif [ "$v" -ge 70 ] 2>/dev/null; then echo "$yellow"
  else echo "$green"; fi
}

# --- Left side: email host:project ---
left=""
[ -n "$email" ] && left="${dim}${email}${reset}  "
left="${left}${bold}${green}${host}${reset}:${cyan}${project}${reset}"

# --- Right side: model + context + rate limits ---
right=""
if [ -n "$model" ]; then
  right="${dim}[${model}]${reset}"
fi
if [ -n "$used" ]; then
  c=$(pct_color "$used")
  right="${right}  ${dim}ctx:${reset}${c}$(printf '%.0f' "$used")%%${reset}"
fi
if [ -n "$rl_5h" ]; then
  c=$(pct_color "$rl_5h")
  right="${right}  ${dim}5h:${reset}${c}$(printf '%.0f' "$rl_5h")%%${reset}"
fi
if [ -n "$rl_7d" ]; then
  c=$(pct_color "$rl_7d")
  right="${right}  ${dim}7d:${reset}${c}$(printf '%.0f' "$rl_7d")%%${reset}"
fi

# --- Output: left | right ---
printf "%b  ${dim}│${reset}  %b" "$left" "$right"

# --- Cleanup stale auth cache (>24h, runs in background) ---
find "$HOME/.claude/ultra/statusline-auth" -name '*.json' -mmin +1440 -delete 2>/dev/null &
