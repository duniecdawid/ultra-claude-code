#!/usr/bin/env bash
# Auto-create or attach to a tmux session named after the working directory.

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not found, falling back to plain shell"
  exec "${SHELL:-bash}"
fi

if [ -n "$TMUX" ]; then
  exec "${SHELL:-bash}"
fi

PROJECT_DIR="${1:-$(pwd)}"
PROJECT_NAME="$(basename "$PROJECT_DIR" | tr -c '[:alnum:]_-' '_')"
SESSION="${USER}_${PROJECT_NAME}"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n editor
fi

exec tmux attach -t "$SESSION"
