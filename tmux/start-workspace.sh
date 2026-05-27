#!/usr/bin/env bash
set -euo pipefail

SESSION_NAME="main"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  exec tmux attach-session -t "$SESSION_NAME"
fi

tmux new-session -d -s "$SESSION_NAME" -n code
tmux new-window -t "$SESSION_NAME":2 -n codex
tmux new-window -t "$SESSION_NAME":3 -n terminal

if command -v btop >/dev/null 2>&1; then
  tmux new-window -t "$SESSION_NAME":4 -n monitoring "btop"
else
  tmux new-window -t "$SESSION_NAME":4 -n monitoring
fi

tmux new-window -t "$SESSION_NAME":5 -n misc

exec tmux attach-session -t "$SESSION_NAME"
