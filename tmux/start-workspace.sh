#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${TMUX_WORKSPACE_CONFIG:-$HOME/.tmux-workspace.conf}"
SESSION_NAME="workspace"
ATTACH_EXISTING=1

TAB_NAMES=()
TAB_COMMANDS=()

load_config() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    case "$line" in
      session_name=*) SESSION_NAME="${line#session_name=}" ;;
      attach_existing=*) ATTACH_EXISTING="${line#attach_existing=}" ;;
      *:*)
        TAB_NAMES+=("${line%%:*}")
        TAB_COMMANDS+=("${line#*:}")
        ;;
      *)
        TAB_NAMES+=("$line")
        TAB_COMMANDS+=("")
        ;;
    esac
  done < "$CONFIG_FILE"
}

use_default_tabs() {
  TAB_NAMES=(code codex claude terminal monitoring misc)
  TAB_COMMANDS=("" opencode claude "" btop "")
}

# Only run a tab command if its binary exists, otherwise open a plain shell.
resolve_command() {
  local cmd="$1"
  if [[ -n "$cmd" ]] && command -v "${cmd%% *}" >/dev/null 2>&1; then
    printf '%s' "$cmd"
  fi
}

main() {
  load_config
  if [[ ${#TAB_NAMES[@]} -eq 0 ]]; then
    use_default_tabs
  fi

  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    if [[ "$ATTACH_EXISTING" == "1" ]]; then
      exec tmux attach-session -t "$SESSION_NAME"
    fi
    SESSION_NAME="${SESSION_NAME}-$(date +%s%N | cut -c1-13)"
  fi

  local cmd
  cmd="$(resolve_command "${TAB_COMMANDS[0]}")"
  if [[ -n "$cmd" ]]; then
    tmux new-session -d -s "$SESSION_NAME" -n "${TAB_NAMES[0]}" "$cmd"
  else
    tmux new-session -d -s "$SESSION_NAME" -n "${TAB_NAMES[0]}"
  fi

  local i
  for ((i = 1; i < ${#TAB_NAMES[@]}; i++)); do
    cmd="$(resolve_command "${TAB_COMMANDS[$i]}")"
    if [[ -n "$cmd" ]]; then
      tmux new-window -t "$SESSION_NAME:" -n "${TAB_NAMES[$i]}" "$cmd"
    else
      tmux new-window -t "$SESSION_NAME:" -n "${TAB_NAMES[$i]}"
    fi
  done

  tmux select-window -t "$SESSION_NAME:1"
  exec tmux attach-session -t "$SESSION_NAME"
}

main "$@"
