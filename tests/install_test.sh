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

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
