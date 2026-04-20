#!/bin/bash
# Ultra Claude statusline — displays prompt info + persists usage data per account for the dashboard.
# Installed by /uc:setup. Configured via settings.json: statusLine.command

# Source shared library
source "$HOME/.claude/ultra/lib.sh"

# Read JSON input from stdin (may be empty on refresh calls)
input=$(cat)

# --- Location (needed early for session file lookup) ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd=$(pwd)
project=$(basename "$cwd")

# --- Resolve identity from session file ---
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
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
    }' 2>/dev/null)
  if [ -n "$snippet" ] && [ "$snippet" != "null" ]; then
    (
      flock -w 2 9 || exit 0
      if [ -f "$usage_file" ]; then
        jq -c --arg key "$account_id" \
          --argjson new "$snippet" \
          '
          .accounts //= {} |
          .accounts[$key] = $new |
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
fi

# --- Model (short name) ---
model_raw=$(echo "$input" | jq -r '.model.display_name // empty' 2>/dev/null)
model=""
case "${model_raw,,}" in
  *opus*)   model="opus" ;;
  *sonnet*) model="sonnet" ;;
  *haiku*)  model="haiku" ;;
  *)        model="$model_raw" ;;
esac

# --- Context window ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)

# --- Rate limits (compact) ---
rl_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
rl_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)

# --- Cache state tracking ---
# State file stores last response timestamp + context data for idle refresh calculations
cache_warm=false
cache_display=""
state_file=""

if [ -n "$session_id" ]; then
  state_file="/tmp/uc-sl-${session_id}"
  now=$(date +%s)

  if [ -f "$state_file" ]; then
    IFS=' ' read -r prev_ts prev_used prev_model prev_model_raw < "$state_file"
    gap=$((now - prev_ts))
    mins=$((gap / 60))
    secs=$((gap % 60))
    cache_display=$(printf "%d:%02d" "$mins" "$secs")
    [ "$gap" -lt 300 ] && cache_warm=true

    # On refresh calls (no new JSON), use cached values from state file
    if [ -z "$used" ] && [ -n "$prev_used" ]; then
      used="$prev_used"
      model="$prev_model"
      model_raw="$prev_model_raw"
    fi
  else
    cache_display="new"
  fi

  # Write state: timestamp + context data for future refresh calls
  echo "${now} ${used} ${model} ${model_raw}" > "$state_file"
fi

# --- Weight bar ---
weight_bar=""
w_int=0
if [ -n "$used" ] && [ -n "$model" ]; then
  max_ctx=200000
  case "${model_raw}" in *1[Mm]*|*1,000*) max_ctx=1000000 ;; esac

  case "$model" in
    opus)   mf=5.00 ;;
    sonnet) mf=1.00 ;;
    haiku)  mf=0.27 ;;
    *)      mf=1.00 ;;
  esac

  cf=10; [ "$cache_warm" = true ] && cf=1

  weight=$(awk -v u="$used" -v m="$max_ctx" -v mf="$mf" -v cf="$cf" \
    'BEGIN { printf "%.2f", (u/100) * (m/1000000) * mf * cf }')

  w_int=$(awk -v w="$weight" 'BEGIN { printf "%.0f", w * 100 }')
  if   [ "$w_int" -ge 500 ]; then weight_bar="▇"
  elif [ "$w_int" -ge 200 ]; then weight_bar="▅"
  elif [ "$w_int" -ge 50  ]; then weight_bar="▃"
  elif [ "$w_int" -ge 10  ]; then weight_bar="▂"
  else                             weight_bar="▁"
  fi
fi

# --- Colors ---
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

# --- Left side: email project ---
left=""
[ -n "$email" ] && left="${dim}${email}${reset}  "
left="${left}${cyan}${project}${reset}"

# --- Right side: model + context + cache + weight + rate limits ---
right=""
if [ -n "$model" ]; then
  right="${dim}[${model}]${reset}"
fi
if [ -n "$used" ]; then
  c=$(pct_color "$used")
  right="${right}  ${dim}ctx:${reset}${c}$(printf '%.0f' "$used")%%${reset}"
fi

# Cache indicator — pie chart depletes over 5 min: ● → ◕ → ◑ → ◔ → ○
if [ -n "$cache_display" ]; then
  if [ "$cache_warm" = true ]; then
    if   [ "${gap:-0}" -lt 75  ]; then pie="●"
    elif [ "$gap" -lt 150 ]; then pie="◕"
    elif [ "$gap" -lt 225 ]; then pie="◑"
    else                              pie="◔"
    fi
    pie_color="$green"
    [ "$gap" -ge 180 ] && pie_color="$yellow"
    right="${right}  ${pie_color}${pie}${reset}"
  else
    right="${right}  ${red}○${reset}"
  fi
fi

# Weight bar
if [ -n "$weight_bar" ]; then
  if   [ "$w_int" -ge 500 ]; then wc="$red"
  elif [ "$w_int" -ge 50  ]; then wc="$yellow"
  else                             wc="$green"
  fi
  right="${right} ${wc}\$${weight_bar}${reset}"
fi

if [ -n "$rl_5h" ]; then
  c=$(pct_color "$rl_5h")
  right="${right}  ${dim}5h:${reset}${c}$(printf '%.0f' "$rl_5h")%%${reset}"
fi
if [ -n "$rl_7d" ]; then
  c=$(pct_color "$rl_7d")
  right="${right}  ${dim}7d:${reset}${c}$(printf '%.0f' "$rl_7d")%%${reset}"
fi

# --- Output ---
printf "%b  %b" "$left" "$right"
