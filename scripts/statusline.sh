#!/bin/bash
# Ultra Claude statusline — displays prompt info + persists usage data per account for the dashboard.
# Installed by /uc:setup. Configured via settings.json: statusLine.command

# Source shared library
source "$HOME/.claude/ultra/lib.sh"

# Read JSON input from stdin
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

# --- Detect new response vs stale refresh tick ---
# cost changes = new API response with fresh rate limit data. No cost change = refresh tick with stale data.
is_new_response=false
cost_usd_early=$(echo "$input" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
if [ -n "$session_id" ] && [ -n "$cost_usd_early" ]; then
  sl_state="/tmp/uc-sl-${session_id}"
  if [ -f "$sl_state" ]; then
    prev_cost_early=$(cut -d'|' -f2 "$sl_state")
    [ "$cost_usd_early" != "$prev_cost_early" ] && is_new_response=true
  else
    is_new_response=true
  fi
fi

# --- Persist usage data keyed by account_id ---
# Only write on new API responses — stale refresh ticks would overwrite fresh data from other sessions.
usage_file="$HOME/.claude/ultra/usage-status.json"
if [ -n "$session_id" ] && [ -n "$account_id" ] && [ "$is_new_response" = true ]; then
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
    usage_log="$HOME/.claude/ultra/usage-status.log"
    printf '[%s] WRITE session=%s account=%s 5h=%s 7d=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$session_id" \
      "$account_id" \
      "$(echo "$snippet" | jq -r '.rate_limits.five_hour.used_percentage // "null"')" \
      "$(echo "$snippet" | jq -r '.rate_limits.seven_day.used_percentage // "null"')" \
      >> "$usage_log" 2>/dev/null
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
elif [ -n "$session_id" ] && [ -n "$account_id" ] && [ "$is_new_response" = false ]; then
  usage_log="$HOME/.claude/ultra/usage-status.log"
  rl_5h_skip=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // "null"' 2>/dev/null)
  rl_7d_skip=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // "null"' 2>/dev/null)
  printf '[%s] SKIP  session=%s account=%s 5h=%s 7d=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$session_id" \
    "$account_id" \
    "$rl_5h_skip" \
    "$rl_7d_skip" \
    >> "$usage_log" 2>/dev/null
fi

# --- Extract display values from input ---
model_raw=$(echo "$input" | jq -r '.model.display_name // empty' 2>/dev/null)
model=""
case "${model_raw,,}" in
  *opus*)   model="opus" ;;
  *sonnet*) model="sonnet" ;;
  *haiku*)  model="haiku" ;;
  *)        model="$model_raw" ;;
esac
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
rl_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
rl_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)

# --- Cache state tracking ---
# State file: pipe-delimited to handle spaces in model_raw.
# Format: response_ts|cost_usd|used|model|model_raw|rl_5h|rl_7d|email
# response_ts only updates when cost changes (= new response), NOT on refresh ticks.
cache_warm=false
gap=0
state_file=""

if [ -n "$session_id" ]; then
  state_file="/tmp/uc-sl-${session_id}"
  now=$(date +%s)

  if [ -f "$state_file" ]; then
    IFS='|' read -r prev_response_ts prev_cost prev_used prev_model prev_model_raw prev_5h prev_7d prev_email < "$state_file"

    if [ -n "$cost_usd" ] && [ "$cost_usd" != "$prev_cost" ]; then
      printf '%s' "${now}|${cost_usd}|${used}|${model}|${model_raw}|${rl_5h}|${rl_7d}|${email}" > "$state_file"
      gap=0
    else
      gap=$((now - prev_response_ts))
      [ -z "$used" ] && used="$prev_used"
      [ -z "$model" ] && model="$prev_model"
      [ -z "$model_raw" ] && model_raw="$prev_model_raw"
      [ -z "$rl_5h" ] && rl_5h="$prev_5h"
      [ -z "$rl_7d" ] && rl_7d="$prev_7d"
      [ -z "$email" ] && email="$prev_email"
    fi
  else
    printf '%s' "${now}|${cost_usd}|${used}|${model}|${model_raw}|${rl_5h}|${rl_7d}|${email}" > "$state_file"
    gap=0
  fi

  [ "$gap" -lt 300 ] && cache_warm=true
fi

# --- Model display (after state restore so model_raw is populated on stale ticks) ---
model_version=$(echo "$model_raw" | grep -oP '\d+\.\d+' | head -1)
model_display="$model"
[ -n "$model_version" ] && model_display="${model} ${model_version}"

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
  right="${dim}[${model_display}]${reset}"
fi
if [ -n "$used" ]; then
  c=$(pct_color "$used")
  right="${right}  ${dim}ctx:${reset}${c}$(printf '%.0f' "$used")%${reset}"
fi

# Cache indicator — pie chart depletes over 5 min: ● → ◕ → ◑ → ◔ → ○
if [ -n "$state_file" ]; then
  if [ "$cache_warm" = true ]; then
    if   [ "$gap" -lt 75  ]; then pie="●"
    elif [ "$gap" -lt 150 ]; then pie="◕"
    elif [ "$gap" -lt 225 ]; then pie="◑"
    else                          pie="◔"
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
  right="${right}  ${dim}5h:${reset}${c}$(printf '%.0f' "$rl_5h")%${reset}"
fi
if [ -n "$rl_7d" ]; then
  c=$(pct_color "$rl_7d")
  right="${right}  ${dim}7d:${reset}${c}$(printf '%.0f' "$rl_7d")%${reset}"
fi

# --- Output ---
printf "%b  %b" "$left" "$right"
