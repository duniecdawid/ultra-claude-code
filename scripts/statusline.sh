#!/bin/bash
# Ultra Claude statusline — displays prompt info + persists usage data per account for the dashboard.
# Installed by /uc:setup. Configured via settings.json: statusLine.command

# Source shared library
source "$HOME/.claude/ultra/lib.sh"

# Read JSON input from stdin
input=$(cat)

# --- Location (needed early for session file lookup) ---
host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd=$(pwd)
project=$(basename "$cwd")

# --- Resolve identity from session file ---
session_id=$(echo "$input" | jq -r '.session_id // empty')
email=""
org_name=""
sub_type=""
account_id=""

if [ -n "$session_id" ]; then
  session_file="${cwd}/.claude/ultra/sessions/${session_id}.json"
  if [ -f "$session_file" ]; then
    account_id=$(jq -r '.account_id // empty' "$session_file")
    if [ -n "$account_id" ]; then
      account_file="${ACCOUNTS_DIR}/${account_id}.json"
      if [ -f "$account_file" ]; then
        email=$(jq -r '.email // empty' "$account_file")
        org_name=$(jq -r '.orgName // empty' "$account_file")
        sub_type=$(jq -r '.subscriptionType // empty' "$account_file")
      fi
    fi
  fi
fi

# --- Persist usage data keyed by account_id ---
usage_file="$HOME/.claude/ultra/usage-status.json"
if [ -n "$session_id" ] && [ -n "$account_id" ]; then
  snippet=$(echo "$input" | jq -c \
    --arg account_id "$account_id" \
    --arg email "$email" \
    --arg org "$org_name" \
    --arg sub "$sub_type" \
    '
    # Normalize resets_at: ensure it is always an epoch integer (not ISO string)
    def epoch_int: if type == "string" then (. | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) elif type == "number" then (. | floor) else . end;
    {
      account_id: $account_id,
      email: $email,
      orgName: (if $org == "" then null else $org end),
      subscriptionType: (if $sub == "" then null else $sub end),
      source_session_id: .session_id,
      model: .model.display_name,
      context_used: .context_window.used_percentage,
      cost_usd: .cost.total_cost_usd,
      rate_limits: (.rate_limits | {
        five_hour: { used_percentage: .five_hour.used_percentage, resets_at: (.five_hour.resets_at | epoch_int) },
        seven_day: { used_percentage: .seven_day.used_percentage, resets_at: (.seven_day.resets_at | epoch_int) }
      }),
      updated_at: (now | todate)
    }')
  # Atomic write: update accounts map keyed by account_id (flock to prevent concurrent corruption)
  # Overwrite guard: never replace higher rate-limit usage with lower values unless the
  # reset window has passed. Prevents stale data from overwriting active rate limits.
  (
    flock -w 2 9 || exit 0
    if [ -f "$usage_file" ]; then
      jq -c --arg key "$account_id" \
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
      echo "$snippet" | jq -c --arg key "$account_id" \
        '{accounts: {($key): .}, updated_at: (now | todate)}' \
        > "$usage_file" 2>/dev/null
    fi
  ) 9>"${usage_file}.lock"
fi

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
