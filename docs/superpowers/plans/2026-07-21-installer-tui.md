# Installer TUI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `install.sh` into an oh-my-zsh-style guided installer: banner, arrow-key component picker, styled tab customization, pre-install summary, and per-step ✓/✗ progress — in pure bash.

**Architecture:** All TUI code lives in `install.sh` itself (single-file installer stays single-file). A `TUI` flag gates every fancy path; when stdout isn't a tty or `NO_COLOR` is set, the installer falls back to the existing plain prompts, and non-interactive runs (`--all`, `curl | bash`) stay fully unattended. Long command output is redirected to a log file so the screen shows one status line per step; the log tail is printed on failure.

**Tech Stack:** bash ≥ 4.3 (namerefs, already standard on Ubuntu/Debian), ANSI escape codes, `tput` (optional, guarded). No new dependencies — no whiptail, dialog, or gum.

## Global Constraints

- No new dependencies. Pure bash + ANSI escapes only.
- bash ≥ 4.3 required (namerefs); target platform is Ubuntu/Debian where this holds.
- `NO_COLOR` set or stdout not a tty → no colors, no cursor movement, fall back to numeric prompts.
- `--all` / `-y` / piped stdin (e.g. `curl | bash`) → zero prompts, install everything. This behavior exists today and must not regress.
- Existing function names (`install_base_packages`, `link_file`, `backup_file`, `configure_tmux_tabs`, etc.) keep their signatures; TUI wraps them, doesn't rewrite them.
- Git identity for every commit: `majipa007 <sulavstha007@gmail.com>` (repo-local config already set). No Co-Authored-By trailer.
- UI glyphs limited to `❯ ✓ ✗ …` (UTF-8, safe in modern terminals); everything else ASCII.
- Tests live in `tests/install_test.sh`, plain assert-style bash, run with `bash tests/install_test.sh`.

## File Structure

- `install.sh` — gains: source guard, `tui_init`, `banner`, `confirm`, `menu_multiselect`, `select_components_menu`, `show_summary`, `run_step`, `prime_sudo`, `link_selected_dotfiles`. Existing install functions untouched.
- `tests/install_test.sh` — new; sources `install.sh` and asserts on the pure functions (menu key handling, confirm, selection mapping). Grows one section per task.
- `README.md` — short update describing the guided installer.

---

### Task 1: Source guard + TUI primitives

**Files:**
- Modify: `install.sh` (top of file + last line)
- Test: `tests/install_test.sh` (create)

**Interfaces:**
- Produces: `TUI` (0/1 global), color vars `C_RESET C_BOLD C_DIM C_CYAN C_GREEN C_RED C_YELLOW`, `tui_init()`, `banner()`. Sourcing `install.sh` runs nothing (main guarded).
- Consumes: nothing.

- [ ] **Step 1: Write the failing test**

Create `tests/install_test.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/install_test.sh`
Expected: FAIL — sourcing `install.sh` executes `main` (tries `apt update`) because the last line is `main "$@"`. Interrupt if needed; that proves the guard is required.

- [ ] **Step 3: Implement**

In `install.sh`, replace the last line `main "$@"` with:

```bash
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

Directly below `ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` add:

```bash
TUI=0
C_RESET="" C_BOLD="" C_DIM="" C_CYAN="" C_GREEN="" C_RED="" C_YELLOW=""

tui_init() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    TUI=1
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_CYAN=$'\033[36m'
    C_GREEN=$'\033[32m'
    C_RED=$'\033[31m'
    C_YELLOW=$'\033[33m'
  else
    TUI=0
    C_RESET="" C_BOLD="" C_DIM="" C_CYAN="" C_GREEN="" C_RED="" C_YELLOW=""
  fi
}

banner() {
  [[ "$TUI" -eq 1 ]] || return 0
  printf '%s' "${C_CYAN}${C_BOLD}"
  cat <<'BANNER'
     _       _    __ _ _
  __| | ___ | |_ / _(_) | ___  ___
 / _` |/ _ \| __| |_| | |/ _ \/ __|
| (_| | (_) | |_|  _| | |  __/\__ \
 \__,_|\___/ \__|_| |_|_|\___||___/
BANNER
  printf '%s  %sone command, whole setup%s\n\n' "$C_RESET" "$C_DIM" "$C_RESET"
}
```

At the top of `main()`, before the `--all` argument loop, add:

```bash
  tui_init
  banner
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/install_test.sh`
Expected: `PASS=3 FAIL=0`, exit 0, and no apt commands run.

Also run: `bash -n install.sh`
Expected: no output (syntax OK).

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install_test.sh
git commit -m "Add TUI init, banner, and source guard to installer"
```

---

### Task 2: `confirm` and `menu_multiselect` primitives

**Files:**
- Modify: `install.sh` (below `banner()`)
- Test: `tests/install_test.sh` (append)

**Interfaces:**
- Consumes: color vars from Task 1.
- Produces:
  - `confirm "Question text"` → returns 0 for yes (default), 1 for no. Reads one line from stdin.
  - `menu_multiselect "Title" names_arrayname descs_arrayname sel_arrayname` → interactive checkbox list. `sel` is an in/out array of 0/1. Keys: ↑/↓ or k/j move, space toggles, `a` selects all, Enter confirms. Returns 0.

- [ ] **Step 1: Write the failing test**

Append to `tests/install_test.sh` (before the final summary block):

```bash
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
menu_multiselect "Pick" names descs sel < <(printf '')      # EOF ends menu safely
assert "menu: EOF keeps selection" [ "${sel[0]}${sel[1]}${sel[2]}" = "101" ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/install_test.sh`
Expected: FAIL with `confirm: command not found`.

- [ ] **Step 3: Implement**

Add to `install.sh` below `banner()`:

```bash
confirm() {
  local question="$1" answer
  printf '%s%s%s [Y/n]: ' "$C_BOLD" "$question" "$C_RESET"
  read -r answer || answer=""
  case "$answer" in
    n|N|no|NO) return 1 ;;
    *) return 0 ;;
  esac
}

# menu_multiselect "Title" names descs sel
# names/descs/sel are array NAMES (namerefs). sel holds 0/1 per item, updated in place.
# Keys: up/down or k/j move, space toggle, a all, Enter confirm.
menu_multiselect() {
  local title="$1"
  local -n _mm_names="$2" _mm_descs="$3" _mm_sel="$4"
  local count="${#_mm_names[@]}"
  local cur=0 i key key2 mark pointer

  tput civis 2>/dev/null || true
  while true; do
    printf '%s%s%s  %s(space: toggle, a: all, enter: confirm)%s\n' \
      "$C_BOLD" "$title" "$C_RESET" "$C_DIM" "$C_RESET"
    for ((i = 0; i < count; i++)); do
      mark="[ ]"
      [[ "${_mm_sel[$i]}" -eq 1 ]] && mark="[${C_GREEN}x${C_RESET}]"
      pointer="  "
      [[ "$i" -eq "$cur" ]] && pointer="${C_CYAN}❯ ${C_RESET}"
      printf ' %b%b %s  %s%s%s\n' \
        "$pointer" "$mark" "${_mm_names[$i]}" "$C_DIM" "${_mm_descs[$i]}" "$C_RESET"
    done

    if ! IFS= read -rsn1 key; then
      break  # EOF (piped input ran out) — accept current selection
    fi
    if [[ "$key" == $'\033' ]]; then
      key2=""
      read -rsn2 -t 0.05 key2 || true
      key="esc:$key2"
    fi
    case "$key" in
      "esc:[A"|k) cur=$(( (cur - 1 + count) % count )) ;;
      "esc:[B"|j) cur=$(( (cur + 1) % count )) ;;
      " ")        _mm_sel[$cur]=$(( 1 - _mm_sel[$cur] )) ;;
      a)          for ((i = 0; i < count; i++)); do _mm_sel[$i]=1; done ;;
      "")         break ;;
    esac
    # redraw in place: cursor up over title + items, clear to end
    printf '\033[%dA\033[J' "$((count + 1))"
  done
  tput cnorm 2>/dev/null || true
}
```

Note the arithmetic style: `var=$(( ... ))` assignments, never bare `(( var = ... ))` — a result of 0 would make `(( ))` return nonzero and kill the script under `set -e`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/install_test.sh`
Expected: `PASS=10 FAIL=0`.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install_test.sh
git commit -m "Add confirm and arrow-key multiselect menu primitives"
```

---

### Task 3: Component selection via menu

**Files:**
- Modify: `install.sh` (replace `select_components`)
- Test: `tests/install_test.sh` (append)

**Interfaces:**
- Consumes: `menu_multiselect` (Task 2), `is_interactive` (existing).
- Produces: `select_components()` (same name main() already calls) now dispatching to `select_components_menu` (TUI) or `select_components_basic` (plain tty, the current numeric prompt verbatim). Sets the existing globals `INSTALL_ZSH INSTALL_TMUX INSTALL_NVIM INSTALL_OPENCODE INSTALL_CLAUDE`. Also produces `apply_component_selection sel_arrayname` (pure, testable mapping).

- [ ] **Step 1: Write the failing test**

Append to `tests/install_test.sh`:

```bash
# --- Task 3: apply_component_selection ---
sel=(1 0 1 0 1)
apply_component_selection sel
assert "map: zsh on"      [ "$INSTALL_ZSH" -eq 1 ]
assert "map: tmux off"    [ "$INSTALL_TMUX" -eq 0 ]
assert "map: nvim on"     [ "$INSTALL_NVIM" -eq 1 ]
assert "map: opencode off" [ "$INSTALL_OPENCODE" -eq 0 ]
assert "map: claude on"   [ "$INSTALL_CLAUDE" -eq 1 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/install_test.sh`
Expected: FAIL with `apply_component_selection: command not found`.

- [ ] **Step 3: Implement**

In `install.sh`, replace the whole existing `select_components()` function with:

```bash
COMPONENT_NAMES=(zsh tmux neovim opencode claude)
COMPONENT_DESCS=(
  "Oh My Zsh, plugins, Oh My Posh prompt"
  "config, TPM plugins, workspace tabs"
  "latest release + LazyVim config"
  "OpenCode CLI"
  "Claude Code CLI"
)

apply_component_selection() {
  local -n _cs_sel="$1"
  INSTALL_ZSH="${_cs_sel[0]}"
  INSTALL_TMUX="${_cs_sel[1]}"
  INSTALL_NVIM="${_cs_sel[2]}"
  INSTALL_OPENCODE="${_cs_sel[3]}"
  INSTALL_CLAUDE="${_cs_sel[4]}"
}

select_components_menu() {
  local sel=(1 1 1 1 1)
  menu_multiselect "Select components to install" COMPONENT_NAMES COMPONENT_DESCS sel
  apply_component_selection sel
}

select_components_basic() {
  cat <<'EOF'

Select components to install:
  1) zsh       Oh My Zsh, Oh My Posh, .zshrc
  2) tmux      config, TPM plugins, workspace launcher
  3) neovim    latest release, LazyVim config
  4) opencode  OpenCode CLI
  5) claude    Claude Code CLI
EOF
  printf "Enter numbers separated by spaces, or press Enter for all: "
  local selection token
  read -r selection
  [[ -z "$selection" ]] && return 0

  INSTALL_ZSH=0
  INSTALL_TMUX=0
  INSTALL_NVIM=0
  INSTALL_OPENCODE=0
  INSTALL_CLAUDE=0
  for token in ${selection//,/ }; do
    case "$token" in
      1) INSTALL_ZSH=1 ;;
      2) INSTALL_TMUX=1 ;;
      3) INSTALL_NVIM=1 ;;
      4) INSTALL_OPENCODE=1 ;;
      5) INSTALL_CLAUDE=1 ;;
      *) log "Ignoring unknown selection: $token" ;;
    esac
  done
}

select_components() {
  is_interactive || return 0
  if [[ "$TUI" -eq 1 ]]; then
    select_components_menu
  else
    select_components_basic
  fi
}
```

(`select_components_basic` is the current numeric implementation moved verbatim; `main()` needs no change.)

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/install_test.sh`
Expected: `PASS=15 FAIL=0`.

Manual check in a real terminal (do NOT let it install — Ctrl-C at the tab question):
Run: `bash install.sh`
Expected: banner, then an arrow-key checkbox list with all five components pre-checked.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install_test.sh
git commit -m "Drive component selection with arrow-key menu"
```

---

### Task 4: Styled tmux tab flow

**Files:**
- Modify: `install.sh` (`configure_tmux_tabs`)
- Test: `tests/install_test.sh` (append)

**Interfaces:**
- Consumes: `confirm` (Task 2), `backup_file`, `is_interactive`, `log` (existing).
- Produces: `configure_tmux_tabs()` (same name, same call site) — now prints the default tab table with colors, uses `confirm`, and delegates file writing to `write_tab_config tabs_arrayname` (pure, testable).

- [ ] **Step 1: Write the failing test**

Append to `tests/install_test.sh`:

```bash
# --- Task 4: write_tab_config ---
export HOME="$(mktemp -d)"
tabs=("editor:nvim" "logs" "mon:btop")
write_tab_config tabs
assert "tab config written" [ -f "$HOME/.tmux-workspace.conf" ]
assert "tab config has command tab" grep -q '^editor:nvim$' "$HOME/.tmux-workspace.conf"
assert "tab config has plain tab" grep -q '^logs$' "$HOME/.tmux-workspace.conf"
assert "tab config has session name" grep -q '^session_name=workspace$' "$HOME/.tmux-workspace.conf"
```

Note: the `export HOME=` redirect must come AFTER earlier test sections and stay at the end of the file (nothing later reads the real `$HOME`).

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/install_test.sh`
Expected: FAIL with `write_tab_config: command not found`.

- [ ] **Step 3: Implement**

Replace the body of `configure_tmux_tabs()` in `install.sh` with:

```bash
write_tab_config() {
  local -n _wt_tabs="$1"
  local config="$HOME/.tmux-workspace.conf"
  backup_file "$config"
  {
    echo "# tmux workspace tabs: name or name:command"
    echo "# Generated by dotfiles install.sh; edit freely."
    echo "session_name=workspace"
    echo "attach_existing=1"
    local tab
    for tab in "${_wt_tabs[@]}"; do
      echo "$tab"
    done
  } > "$config"
  log "Wrote $config"
}

configure_tmux_tabs() {
  is_interactive || return 0

  printf '\n%sDefault tmux workspace tabs%s\n' "$C_BOLD" "$C_RESET"
  printf '  %s1%s code        %sshell%s\n'      "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '  %s2%s codex       %sopencode%s\n'   "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '  %s3%s claude      %sclaude%s\n'     "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '  %s4%s terminal    %sshell%s\n'      "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '  %s5%s monitoring  %sbtop%s\n'       "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '  %s6%s misc        %sshell%s\n'      "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"

  if confirm "Use these default tabs"; then
    return 0
  fi

  printf '\n%sDefine your tabs.%s Format: %sname%s or %sname:command%s. Empty line to finish.\n' \
    "$C_BOLD" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"
  local tabs=() line
  while true; do
    printf '  %sTab %d:%s ' "$C_CYAN" "$(( ${#tabs[@]} + 1 ))" "$C_RESET"
    read -r line || line=""
    [[ -z "$line" ]] && break
    tabs+=("$line")
  done

  if [[ ${#tabs[@]} -eq 0 ]]; then
    log "No tabs entered; keeping defaults"
    return 0
  fi
  write_tab_config tabs
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/install_test.sh`
Expected: `PASS=19 FAIL=0`.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install_test.sh
git commit -m "Style tmux tab customization and extract config writer"
```

---

### Task 5: Pre-install summary screen

**Files:**
- Modify: `install.sh` (new function + two lines in `main()`)
- Test: manual (pure display + one confirm; logic already covered)

**Interfaces:**
- Consumes: `INSTALL_*` globals, `confirm`, `is_interactive`, color vars.
- Produces: `show_summary()` → prints what will happen, returns `confirm` result. Non-interactive → returns 0 silently.

- [ ] **Step 1: Implement**

Add to `install.sh` below `select_components()`:

```bash
summary_line() {
  local enabled="$1" name="$2"
  if [[ "$enabled" -eq 1 ]]; then
    printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$name"
  else
    printf '  %s-%s %s%s (skipped)%s\n' "$C_DIM" "$C_RESET" "$C_DIM" "$name" "$C_RESET"
  fi
}

show_summary() {
  is_interactive || return 0
  printf '\n%sReady to install%s\n' "$C_BOLD" "$C_RESET"
  summary_line "$INSTALL_ZSH" "zsh + Oh My Zsh + Oh My Posh"
  summary_line "$INSTALL_TMUX" "tmux + TPM + workspace"
  summary_line "$INSTALL_NVIM" "Neovim + LazyVim"
  summary_line "$INSTALL_OPENCODE" "OpenCode CLI"
  summary_line "$INSTALL_CLAUDE" "Claude Code CLI"
  if [[ "$INSTALL_TMUX" -eq 1 ]]; then
    if [[ -f "$HOME/.tmux-workspace.conf" ]]; then
      printf '  %s✓%s tmux tabs: %s~/.tmux-workspace.conf%s\n' "$C_GREEN" "$C_RESET" "$C_CYAN" "$C_RESET"
    else
      printf '  %s✓%s tmux tabs: defaults\n' "$C_GREEN" "$C_RESET"
    fi
  fi
  printf '\n'
  confirm "Proceed"
}
```

In `main()`, right after the `configure_tmux_tabs` block, add:

```bash
  if ! show_summary; then
    log "Aborted. Nothing was installed."
    exit 0
  fi
```

- [ ] **Step 2: Verify**

Run: `bash tests/install_test.sh`
Expected: still `PASS=19 FAIL=0` (no regression).

Run: `bash -n install.sh`
Expected: no output.

Manual in a real terminal: `bash install.sh`, pick components, answer tab question, then answer `n` at "Proceed".
Expected: summary shows ✓ for chosen and dimmed `-` for skipped components; answering `n` prints "Aborted. Nothing was installed." and exits without touching the system.

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "Show install summary with confirm before touching the system"
```

---

### Task 6: Step runner with ✓/✗ progress and logging

**Files:**
- Modify: `install.sh` (new functions + rewrite of `main()` body after the summary)
- Test: `tests/install_test.sh` (append)

**Interfaces:**
- Consumes: `TUI`, color vars, `log`, all existing `install_*` / `bootstrap_*` functions.
- Produces:
  - `LOG_FILE` global (`${TMPDIR:-/tmp}/dotfiles-install.log`)
  - `run_step "Description" command args...` → TUI: one status line, output to `LOG_FILE`, on failure prints last 15 log lines and exits 1. Non-TUI: `log` + run command directly (output visible, `set -e` handles failure).
  - `prime_sudo()` → visible `sudo -v` before the first step so the password prompt is never swallowed by log redirection.
  - `link_selected_dotfiles()` → all the `link_file` calls from `main()`, moved verbatim into one function so it can be a step.

- [ ] **Step 1: Write the failing test**

Append to `tests/install_test.sh`:

```bash
# --- Task 6: run_step (non-TUI path: TUI=0 under test) ---
assert "run_step runs command" run_step "true step" true
assert "run_step propagates failure" bash -c 'source ./install.sh; ! (run_step "false step" false)'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/install_test.sh`
Expected: FAIL with `run_step: command not found`.

- [ ] **Step 3: Implement**

Add to `install.sh` below `show_summary()`:

```bash
LOG_FILE="${TMPDIR:-/tmp}/dotfiles-install.log"

prime_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    printf '%sSome steps need sudo.%s\n' "$C_DIM" "$C_RESET"
    sudo -v
  fi
}

run_step() {
  local desc="$1"
  shift
  if [[ "$TUI" -eq 1 ]]; then
    printf ' %s…%s %s' "$C_YELLOW" "$C_RESET" "$desc"
    if "$@" >>"$LOG_FILE" 2>&1; then
      printf '\r %s✓%s %s \n' "$C_GREEN" "$C_RESET" "$desc"
    else
      printf '\r %s✗%s %s \n' "$C_RED" "$C_RESET" "$desc"
      printf '%sLast lines of %s:%s\n' "$C_DIM" "$LOG_FILE" "$C_RESET"
      tail -n 15 "$LOG_FILE"
      exit 1
    fi
  else
    log "$desc"
    "$@"
  fi
}

link_selected_dotfiles() {
  mkdir -p "$HOME/.local/bin"

  if [[ "$INSTALL_ZSH" -eq 1 ]]; then
    link_file "$ROOT_DIR/zsh/.zshrc" "$HOME/.zshrc"
    link_file "$ROOT_DIR/zsh/.zprofile" "$HOME/.zprofile"
    mkdir -p "$HOME/omp-config"
    link_file "$ROOT_DIR/omp-config/myconfig.json" "$HOME/omp-config/myconfig.json"
  fi

  if [[ "$INSTALL_TMUX" -eq 1 ]]; then
    link_file "$ROOT_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
    link_file "$ROOT_DIR/tmux/start-workspace.sh" "$HOME/.local/bin/start-tmux-workspace"
  fi

  if [[ "$INSTALL_NVIM" -eq 1 ]]; then
    mkdir -p "$HOME/.config"
    link_file "$ROOT_DIR/nvim" "$HOME/.config/nvim"
  fi

  if [[ "$INSTALL_OPENCODE" -eq 1 ]]; then
    mkdir -p "$HOME/.config/opencode"
    link_file "$ROOT_DIR/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
  fi
}
```

Rewrite everything in `main()` after the `show_summary` block as:

```bash
  : > "$LOG_FILE"
  prime_sudo

  run_step "Installing base packages" install_base_packages

  if [[ "$INSTALL_NVIM" -eq 1 ]]; then
    run_step "Installing Neovim" install_latest_neovim
  fi
  if [[ "$INSTALL_ZSH" -eq 1 ]]; then
    run_step "Installing Oh My Zsh + plugins" install_oh_my_zsh
    run_step "Installing Oh My Posh" install_oh_my_posh
  fi
  if [[ "$INSTALL_OPENCODE" -eq 1 ]]; then
    run_step "Installing OpenCode" install_opencode
  fi
  if [[ "$INSTALL_CLAUDE" -eq 1 ]]; then
    run_step "Installing Claude Code" install_claude_code
  fi
  if [[ "$INSTALL_TMUX" -eq 1 ]]; then
    run_step "Installing TPM" install_tpm
  fi

  run_step "Linking dotfiles" link_selected_dotfiles

  if [[ "$INSTALL_TMUX" -eq 1 ]]; then
    run_step "Installing tmux plugins" install_tmux_plugins
  fi
  if [[ "$INSTALL_NVIM" -eq 1 ]]; then
    run_step "Bootstrapping LazyVim plugins" bootstrap_nvim_plugins
  fi
  if [[ "$INSTALL_ZSH" -eq 1 ]]; then
    set_default_shell
  fi

  printf '\n%s✓ Done.%s Restart terminal or run: %sexec zsh%s\n' \
    "$C_GREEN$C_BOLD" "$C_RESET" "$C_CYAN" "$C_RESET"
```

`set_default_shell` stays outside `run_step` on purpose — `chsh` prompts for a password and must not have its stdio redirected. Its existing `log` message explains the prompt.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/install_test.sh`
Expected: `PASS=21 FAIL=0`.

Run: `bash -n install.sh`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install_test.sh
git commit -m "Run install steps through status runner with log capture"
```

---

### Task 7: README + end-to-end verify + push

**Files:**
- Modify: `README.md` (Install section)
- Test: full test suite + stub-driven dry run

**Interfaces:**
- Consumes: everything above.
- Produces: documented behavior; pushed branch.

- [ ] **Step 1: Update README**

In `README.md`, replace the paragraph under `## Install` that begins "The installer walks you through two questions:" with:

```markdown
The installer is a guided TUI: pick components with arrow keys and space,
customize your tmux tabs, review a summary, then watch each step complete
with a ✓. Full command output goes to `/tmp/dotfiles-install.log`; on
failure the last lines are shown automatically.

Plain terminals (or `NO_COLOR=1`) get simple numbered prompts instead.
Existing config files are still backed up with a timestamp before anything
is symlinked.
```

Keep the "Unattended install" subsection as is — `--all` behavior is unchanged.

- [ ] **Step 2: Full verification**

Run: `bash tests/install_test.sh`
Expected: `PASS=21 FAIL=0`.

Run: `bash -n install.sh && bash -n tmux/start-workspace.sh`
Expected: no output.

Non-interactive regression check (must not prompt, must decide to install everything). Run:

```bash
bash -c 'source ./install.sh; ASSUME_ALL=1; select_components; configure_tmux_tabs; show_summary; echo "zsh=$INSTALL_ZSH tmux=$INSTALL_TMUX nvim=$INSTALL_NVIM oc=$INSTALL_OPENCODE cl=$INSTALL_CLAUDE"' < /dev/null
```

Expected output: `zsh=1 tmux=1 nvim=1 oc=1 cl=1` with no prompts and no summary text.

Manual TUI smoke test in a real terminal: `bash install.sh`, navigate the menu, deselect something, choose custom tabs, add one tab, answer `n` at the summary.
Expected: clean render at every screen, exit with "Aborted. Nothing was installed.", and `~/.tmux-workspace.conf` written with your tab.

- [ ] **Step 3: Commit and push**

```bash
git add README.md
git commit -m "Document guided TUI installer"
git push origin master
```

---

## Self-Review Notes

- Spec coverage: banner ✓ (T1), intuitive selection ✓ (T3), tab flow ✓ (T4), oh-my-zsh-style polish (summary + step ticks) ✓ (T5, T6), docs ✓ (T7). Non-interactive parity preserved (T3 fallback, T7 regression check).
- Type consistency: `menu_multiselect` signature identical in T2 definition and T3 call. `apply_component_selection`/`write_tab_config` take array names (namerefs) in both definition and tests. `run_step` used only with function names, never quoted compound commands.
- Placeholder scan: every step carries full code or an exact command with expected output.
- Deliberate ceilings: no spinner animation (static `…` line, rewrite on completion — background-job spinner adds trap/cleanup complexity for zero function); menu redraws whole list per keypress (fine for ≤10 items).
