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
tui_init   # stdout is not a tty under test either → TUI stays 0
assert "non-tty disables TUI" [ "$TUI" -eq 0 ]

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

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
