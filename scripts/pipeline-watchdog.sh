#!/usr/bin/env bash
# Pipeline Watchdog — runs independently of Claude agents
# Survives rate limits because it's a plain bash process
#
# Usage: ./pipeline-watchdog.sh <plan-directory> [check-interval-seconds]
# Example: ./pipeline-watchdog.sh documentation/plans/user-auth 300
#
# What it does:
#   - Checks file modification times in task directories every N seconds (default: 300 = 5 min)
#   - Logs stall warnings when no task artifacts change for 10+ minutes
#   - Detects likely rate limits (all tasks stall simultaneously)
#   - Writes status to <plan-dir>/watchdog.log and <plan-dir>/watchdog-status.json
#   - The PM agent reads watchdog-status.json to get data it couldn't collect while rate-limited
#
# The PM agent starts this script at the beginning of execution and kills it at the end.

set -euo pipefail

PLAN_DIR="${1:?Usage: pipeline-watchdog.sh <plan-directory> [check-interval-seconds]}"
CHECK_INTERVAL="${2:-300}"
STALL_THRESHOLD=600  # 10 minutes in seconds

LOG_FILE="${PLAN_DIR}/watchdog.log"
STATUS_FILE="${PLAN_DIR}/watchdog-status.json"

log() {
    local timestamp
    timestamp="$(date -Iseconds)"
    echo "[${timestamp}] $*" >> "$LOG_FILE"
}

write_status() {
    local now stalled_tasks total_tasks status rate_limit_suspected
    now="$(date -Iseconds)"
    stalled_tasks="$1"
    total_tasks="$2"
    status="$3"
    rate_limit_suspected="$4"

    cat > "$STATUS_FILE" <<STATUSEOF
{
  "timestamp": "${now}",
  "status": "${status}",
  "stalled_tasks": ${stalled_tasks},
  "total_active_tasks": ${total_tasks},
  "rate_limit_suspected": ${rate_limit_suspected},
  "check_interval_seconds": ${CHECK_INTERVAL},
  "stall_threshold_seconds": ${STALL_THRESHOLD}
}
STATUSEOF
}

# Initialize
log "Watchdog started for plan directory: ${PLAN_DIR}"
log "Check interval: ${CHECK_INTERVAL}s, Stall threshold: ${STALL_THRESHOLD}s"
write_status 0 0 "starting" "false"

# Track rate limit state
rate_limit_start=""
rate_limit_logged="false"

while true; do
    now_epoch="$(date +%s)"
    task_dirs=()
    stalled_count=0
    active_count=0

    # Find all task directories
    if [[ -d "${PLAN_DIR}/tasks" ]]; then
        for task_dir in "${PLAN_DIR}"/tasks/task-*/; do
            [[ -d "$task_dir" ]] || continue
            task_dirs+=("$task_dir")
        done
    fi

    if [[ ${#task_dirs[@]} -eq 0 ]]; then
        write_status 0 0 "waiting_for_tasks" "false"
        sleep "$CHECK_INTERVAL"
        continue
    fi

    # Check each task directory for recent modifications
    for task_dir in "${task_dirs[@]}"; do
        task_name="$(basename "$task_dir")"
        latest_mod=0

        # Find the most recently modified file in this task dir
        while IFS= read -r file; do
            mod_time="$(stat -c '%Y' "$file" 2>/dev/null || echo 0)"
            if (( mod_time > latest_mod )); then
                latest_mod=$mod_time
            fi
        done < <(find "$task_dir" -type f -name "*.md" 2>/dev/null)

        if (( latest_mod == 0 )); then
            # No files yet — task just started
            continue
        fi

        active_count=$((active_count + 1))
        seconds_since_mod=$(( now_epoch - latest_mod ))

        if (( seconds_since_mod > STALL_THRESHOLD )); then
            stalled_count=$((stalled_count + 1))
            log "STALL: ${task_name} — no file changes for ${seconds_since_mod}s (threshold: ${STALL_THRESHOLD}s)"
        fi
    done

    # Rate limit detection: if ALL active tasks are stalled, likely a rate limit
    if (( active_count > 0 && stalled_count == active_count )); then
        if [[ -z "$rate_limit_start" ]]; then
            rate_limit_start="$(date -Iseconds)"
            rate_limit_logged="false"
        fi
        if [[ "$rate_limit_logged" == "false" ]]; then
            log "RATE LIMIT SUSPECTED — all ${active_count} active tasks stalled simultaneously"
            rate_limit_logged="true"
        fi
        write_status "$stalled_count" "$active_count" "rate_limit_suspected" "true"
    elif (( stalled_count > 0 )); then
        # Some but not all stalled — individual issues
        if [[ -n "$rate_limit_start" ]]; then
            log "RATE LIMIT RECOVERED — activity resumed. Limit started at ${rate_limit_start}"
            rate_limit_start=""
            rate_limit_logged="false"
        fi
        write_status "$stalled_count" "$active_count" "partial_stall" "false"
    else
        # All healthy
        if [[ -n "$rate_limit_start" ]]; then
            log "RATE LIMIT RECOVERED — activity resumed. Limit started at ${rate_limit_start}"
            rate_limit_start=""
            rate_limit_logged="false"
        fi
        write_status 0 "$active_count" "healthy" "false"
    fi

    sleep "$CHECK_INTERVAL"
done
