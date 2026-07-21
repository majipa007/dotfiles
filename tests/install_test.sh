#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
assert() {
  local desc="$1"; shift
  if "$@"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
  fi
}

# Sourcing install.sh must not execute main
source ./install.sh

# --- Task 1: tui_init ---
NO_COLOR=1 tui_init
assert "NO_COLOR disables TUI" [ "$TUI" -eq 0 ]
assert "NO_COLOR empties color vars" [ -z "$C_CYAN" ]

unset NO_COLOR
tui_init >/dev/null   # stdout is not a tty under test either → TUI stays 0
assert "non-tty disables TUI" [ "$TUI" -eq 0 ]
TUI=0

# --- Task 2: confirm ---
assert "confirm: empty input = yes" confirm "Q" <<< ""
assert "confirm: y = yes" confirm "Q" <<< "y"
assert "confirm: n = no" bash -c 'source ./install.sh; ! confirm "Q" <<< "n"'

# --- Task 2: menu_multiselect ---
names=(one two three); descs=(d1 d2 d3)

sel=(1 1 1)
menu_multiselect "Pick" names descs sel < <(printf ' \n')   # toggle item 0 off, Enter
assert "menu: space toggles current" [ "${sel[0]}${sel[1]}${sel[2]}" = "011" ]

sel=(0 0 0)
menu_multiselect "Pick" names descs sel < <(printf '\033[B \n')  # down, toggle item 1, Enter
assert "menu: arrow moves cursor" [ "${sel[0]}${sel[1]}${sel[2]}" = "010" ]

sel=(0 0 0)
menu_multiselect "Pick" names descs sel < <(printf 'a\n')   # select all, Enter
assert "menu: a selects all" [ "${sel[0]}${sel[1]}${sel[2]}" = "111" ]

sel=(1 0 1)
menu_multiselect "Pick" names descs sel < <(printf '')      # EOF keeps selection
assert "menu: EOF keeps selection" [ "${sel[0]}${sel[1]}${sel[2]}" = "101" ]

sel=(0 0 0)
menu_multiselect "Pick" names descs sel < <(printf '\033 \n')  # bare ESC, then space, Enter
assert "menu: key after bare ESC not swallowed" [ "${sel[0]}${sel[1]}${sel[2]}" = "100" ]

# --- Task 3: apply_component_selection ---
sel=(1 0 1 0 1)
apply_component_selection sel
assert "map: zsh on"      [ "$INSTALL_ZSH" -eq 1 ]
assert "map: tmux off"    [ "$INSTALL_TMUX" -eq 0 ]
assert "map: nvim on"     [ "$INSTALL_NVIM" -eq 1 ]
assert "map: opencode off" [ "$INSTALL_OPENCODE" -eq 0 ]
assert "map: claude on"   [ "$INSTALL_CLAUDE" -eq 1 ]

# --- Task 6: run_step (non-TUI path: TUI=0 under test) ---
assert "run_step runs command" run_step "true step" true
assert "run_step propagates failure" bash -c 'source ./install.sh; ! (run_step "false step" false)'

# --- Task 4: write_tab_config ---
export HOME="$(mktemp -d)"
tabs=("editor:nvim" "logs" "mon:btop")
write_tab_config tabs
assert "tab config written" [ -f "$HOME/.tmux-workspace.conf" ]
assert "tab config has command tab" grep -q '^editor:nvim$' "$HOME/.tmux-workspace.conf"
assert "tab config has plain tab" grep -q '^logs$' "$HOME/.tmux-workspace.conf"
assert "tab config has session name" grep -q '^session_name=workspace$' "$HOME/.tmux-workspace.conf"

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
