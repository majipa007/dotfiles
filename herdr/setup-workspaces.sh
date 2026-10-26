#!/usr/bin/env bash
# Create the standard Herdr workspace layout. Safe to re-run: existing
# workspaces with the same label are skipped.
set -euo pipefail

# Nonzero exit if any workspace failed, so the caller can drop its marker and
# let the next shell retry instead of locking the layout out until reboot.
failed=0

herdr=${HERDR_BIN:-$HOME/.local/bin/herdr}
win_docs=$(ls -d /mnt/c/Users/*/OneDrive*/Documents 2>/dev/null | head -1)

# Right after boot the server answers with {"error":...} and still exits 0
# (seen as "ghostty error -2"), so every call goes through here. Also acts as
# the readiness gate: the first api call blocks until the server is warm.
api() { # subcommand... -> JSON on stdout
  local out
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    out=$("$herdr" "$@" 2>&1) || true
    jq -e 'has("error")' <<<"$out" >/dev/null 2>&1 || {
      printf '%s\n' "$out"
      return 0
    }
    sleep 2
  done
  echo "give up after 10 tries: herdr $* -> $out" >&2
  return 1
}

# label|cwd — each gets "claude", "nvim" and "terminal" tabs
main_workspaces=(
  "california|$win_docs/HF/California"
  "velocity|$HOME/test-velocity"
  "pluto|$win_docs/HF/Pluto"
  "sentinel|$win_docs/HF/Sentinel"
)

claude_cmd=(claude --dangerously-skip-permissions -c)

existing=$(api workspace list | jq -r '.result.workspaces[].label')

create_workspace() { # label cwd -> "<workspace_id> <tab_id> <pane_id>"
  api workspace create --label "$1" --cwd "$2" --no-focus |
    jq -r '.result | [.workspace.workspace_id, .tab.tab_id, .root_pane.pane_id] | @tsv'
}

create_tab() { # workspace_id label cwd -> "<tab_id> <pane_id>"
  api tab create --workspace "$1" --label "$2" --cwd "$3" --no-focus |
    jq -r '.result | [.tab.tab_id, .root_pane.pane_id] | @tsv'
}

# A fresh pane swallows keystrokes until zsh + oh-my-posh finish drawing the
# prompt, so wait for it before typing the command. Match the corner glyph of
# oh-my-posh's second prompt line — the username never appears in it.
run_when_ready() { # pane_id command...
  local pane=$1
  shift
  "$herdr" pane wait-output "$pane" --match "╰" --timeout 20000 >/dev/null ||
    echo "warn: $pane showed no prompt in 20s, sending anyway" >&2
  "$herdr" pane run "$pane" "$@"
}

for spec in "${main_workspaces[@]}"; do
  label=${spec%%|*}
  cwd=${spec#*|}
  grep -qxF "$label" <<<"$existing" && {
    echo "skip $label: already open" >&2
    continue
  }
  [ -d "$cwd" ] || {
    echo "skip $label: $cwd missing" >&2
    continue
  }

  read -r ws tab pane <<<"$(create_workspace "$label" "$cwd" || true)"
  [ -n "${ws:-}" ] || {
    echo "skip $label: create failed, moving on" >&2
    failed=1
    continue
  }
  api tab rename "$tab" claude >/dev/null
  run_when_ready "$pane" "${claude_cmd[@]}"

  read -r _ nvim_pane <<<"$(create_tab "$ws" nvim "$cwd" || true)"
  [ -n "${nvim_pane:-}" ] && run_when_ready "$nvim_pane" nvim .

  create_tab "$ws" terminal "$cwd" >/dev/null || true
  echo "created $label ($ws) at $cwd"
done

# One workspace for the small always-on utilities, a tab each. Add a new tool
# by adding a line: "<tab label>|<command>". An empty command leaves a plain
# shell. The first line that survives the installed-check becomes the root tab.
tool_tabs=(
  "terminal|"
  "monitoring|btop"
  "todo|gotodo"
)

if grep -qxF tools <<<"$existing"; then
  echo "skip tools: already open" >&2
else
  tools_ws=""
  for spec in "${tool_tabs[@]}"; do
    label=${spec%%|*}
    read -ra argv <<<"${spec#*|}"

    if [ ${#argv[@]} -gt 0 ] && ! command -v "${argv[0]}" >/dev/null; then
      echo "skip tools/$label: ${argv[0]} not installed" >&2
      continue
    fi

    if [ -z "$tools_ws" ]; then
      read -r tools_ws tab pane <<<"$(create_workspace tools "$HOME" || true)"
      [ -n "${tools_ws:-}" ] || {
        echo "skip tools/$label: create failed, moving on" >&2
        failed=1
        continue
      }
      api tab rename "$tab" "$label" >/dev/null
    else
      read -r _ pane <<<"$(create_tab "$tools_ws" "$label" "$HOME")"
    fi

    [ ${#argv[@]} -gt 0 ] && run_when_ready "$pane" "${argv[@]}"
  done

  if [ -n "$tools_ws" ]; then
    echo "created tools ($tools_ws)"
  else
    echo "skip tools: nothing to put in it" >&2
  fi
fi

# tools replaces the old misc and monitoring workspaces. Leftovers from an
# earlier run are left alone rather than closed out from under you.
for stale in misc monitoring; do
  grep -qxF "$stale" <<<"$existing" &&
    echo "note: '$stale' is still open — tools replaces it, close it when convenient" >&2
done

# Drop the unlabelled "~" workspace Herdr opens on a fresh session.
current_ws=$(api pane current | jq -r '.result.pane.workspace_id')
api workspace list |
  jq -r '.result.workspaces[] | select(.label == "~") | .workspace_id' |
  while read -r id; do
    if [ "$id" = "$current_ws" ]; then
      echo "keep $id: this script is running in it — close it manually" >&2
    else
      "$herdr" workspace close "$id" >/dev/null
      echo "closed default workspace $id"
    fi
  done

exit "$failed"
