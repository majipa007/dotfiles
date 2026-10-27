# herdr + herdr-spreader setup (for a Claude agent)

You are setting up Sulav's herdr workspace layout on a new Linux/WSL machine.
Work through the steps in order. Check each step's output before moving on.

## What this setup is

- **herdr** (https://herdr.dev) is a terminal multiplexer for agent workspaces.
  Every local interactive zsh does `exec herdr`, so the whole terminal runs inside it.
- **herdr-spreader** (`yuk1ty/herdr-spreader`) is a herdr plugin + CLI that builds
  workspaces → tabs → panes from YAML (like tmuxinator).
- **herdr-navigator** (`thanhdat77/herdr-navigator`) is a fuzzy jump plugin, bound to `prefix+t`.
- On a **cold start** (no herdr server running), `.zshrc` starts herdr and applies
  `tools.yaml` in the background. Later terminals only attach.
- Project workspaces are opened by hand:
  `herdr-spreader apply -f ~/.config/herdr-spreader/<name>.yaml`

Everything lives in the dotfiles repo `git@github.com:majipa007/dotfiles.git`:

| Repo path | Linked to |
|---|---|
| `herdr/config.toml` | `~/.config/herdr/config.toml` |
| `herdr/spreader/` | `~/.config/herdr-spreader/` |
| `herdr/setup-workspaces.sh` | `~/.local/bin/herdr-workspaces` (old, not used by `.zshrc` anymore) |
| `zsh/.zshrc` | `~/.zshrc` (has the herdr wrapper + auto-start block) |

Known working versions: herdr `0.7.5`, herdr-spreader `0.1.0`
(commit `206ae55`), herdr-navigator `v0.3.3`.

## Prerequisites

`zsh`, `git`, `curl`, `jq` and a Rust toolchain (`cargo`). herdr builds its plugins
with `cargo build --release`.

```bash
sudo apt-get update && sudo apt-get install -y zsh git curl jq build-essential
command -v cargo || { curl -fsSL https://sh.rustup.rs | sh -s -- -y; . "$HOME/.cargo/env"; }
```

## Step 1: Get the dotfiles

```bash
[ -d ~/dotfiles ] || git clone git@github.com:majipa007/dotfiles.git ~/dotfiles
cd ~/dotfiles && git pull
```

If SSH keys aren't set up, use `https://github.com/majipa007/dotfiles.git`.

## Step 2: Install herdr and link the config

**Option A: use the installer (preferred).** It installs herdr and makes the links.
It's interactive, so ask the human to run it and to pick at least `herdr` and `zsh`:

```bash
! ~/dotfiles/install.sh
```

**Option B: by hand** (if the human doesn't want the full dotfiles install):

```bash
command -v herdr || curl -fsSL https://herdr.dev/install.sh | sh
mkdir -p ~/.config/herdr ~/.local/bin
ln -sfn ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml
ln -sfn ~/dotfiles/herdr/spreader    ~/.config/herdr-spreader
```

Before overwriting an existing `~/.config/herdr/config.toml` or `~/.config/herdr-spreader`,
back it up (`mv x x.bak.$(date +%Y%m%d%H%M%S)`).

Verify: `herdr --version` prints `herdr 0.7.x` or newer.

## Step 3: Install the plugins

If a command complains that no server is running, start a headless one with
`herdr server &`. Stop it again at Step 6.

```bash
herdr plugin install yuk1ty/herdr-spreader -y
herdr plugin install thanhdat77/herdr-navigator --ref v0.3.3 -y
herdr plugin list
```

Put the `herdr-spreader` CLI on `PATH`, because `.zshrc` and the YAML headers call it by name:

```bash
ln -sfn "$(ls -d ~/.config/herdr/plugins/github/herdr-spreader-*/ | head -1)target/release/herdr-spreader" \
  ~/.local/bin/herdr-spreader
herdr-spreader --help
```

## Step 4: The zsh wiring

If you used `install.sh` with `zsh`, `~/.zshrc` already links to `~/dotfiles/zsh/.zshrc`.
Skip to Step 5.

If not, add these two blocks to `~/.zshrc`. Put the wrapper before the auto-start
block and keep the auto-start block near the end of the file:

```zsh
# Cold start: herdr would restore session.json and bring back dead panes,
# so drop the saved layout whenever no server is running.
herdr() {
  [[ "$(command herdr session list 2>/dev/null | awk '$1=="default"{print $2}')" == running ]] ||
    rm -f "$HOME/.config/herdr/session.json"
  command herdr "$@"
}

# Local interactive terminals boot into herdr. Only the shell that cold-starts
# the server applies tools.yaml (spreader has no dedupe). AUTO_HERDR=0 disables it.
if [[ "${AUTO_HERDR:-1}" == "1" ]] && [[ -o interactive ]] && [[ -z "${HERDR_ENV:-}" ]] &&
   [[ -z "${SSH_CONNECTION:-}" ]] && (( $+commands[herdr] )); then
  if [[ "$(command herdr session list 2>/dev/null | awk '$1=="default"{print $2}')" != running ]]; then
    (
      for _ in {1..60}; do
        command herdr workspace list 2>/dev/null | jq -e 'has("result")' >/dev/null 2>&1 && break
        sleep 0.5
      done
      herdr-spreader apply -f "$HOME/.config/herdr-spreader/tools.yaml" >/dev/null 2>&1
    ) &!
  fi
  exec herdr
fi
```

Make sure `~/.local/bin` and `~/.cargo/bin` are on `PATH` **above** this block.

## Step 5: Adapt the layouts to this machine

The YAMLs in `~/.config/herdr-spreader/` have **hard-coded `root:` paths from the
original machine**, such as `/mnt/c/Users/SulavKumarShresta/OneDrive - ...` and
`/home/sukuna/projects/...`. On the new machine:

1. Ask the human which projects they want here and where those repos live.
2. Fix each `root:` to match, or remove YAMLs for projects that aren't on this machine.
3. `tools.yaml` runs `gotodo`, `btop`, `nodder run` and `cd ~/assistant && claude -c`.
   Drop any tab whose tool isn't installed.
4. If the username differs, edit the dotfiles copy (it's a symlink) and ask the
   human before committing machine-specific paths back to the repo.

Dry-run every file you touch. Any path error or bad key shows up here:

```bash
for f in ~/.config/herdr-spreader/*.yaml; do echo "== $f"; herdr-spreader apply -f "$f" --dry-run; done
```

### Layout format cheat-sheet

```yaml
workspaces:
  - name: myproj
    root: "~/projects/myproj"      # quote paths with spaces
    focus: true                    # optional
    tabs:
      - label: claude              # the first tab renames herdr's default tab
        panes:
          - command: claude -c
      - label: dev
        panes:
          - command: nvim .
          - split: right           # right | down, splits the previous pane
            ratio: 0.25
            command: claude -c
      - label: terminal
        panes:
          - {}                     # plain shell; every tab needs a `panes:` key
```

Unknown keys are rejected. Other keys: `env:` (workspace or pane), `cwd:`
(tab or pane, relative to `root`) and `wait_for:`. See the plugin's README under
`~/.config/herdr/plugins/github/herdr-spreader-*/README.md`.

## Step 6: Verify

0. Force a real cold start: `command herdr server stop`, then check that
   `command herdr session list` no longer shows `default` as `running`.
1. Close every terminal and open a fresh one. herdr should start, and a `tools`
   workspace should appear within about 30 seconds.
2. Open a second terminal. It should attach to the same session with **no** second `tools` workspace.
3. `herdr-spreader apply -f ~/.config/herdr-spreader/<project>.yaml` adds that project's workspace.
4. `prefix+t` opens the navigator.
5. `herdr server reload-config` applies `config.toml` edits without a restart.

## Gotchas

- **Bare `root: ~` is YAML null, not home.** spreader then falls back to the
  directory it was launched from. Write `root: "~"` instead. `--dry-run` shows
  the resolved `--cwd`.
- **Use `-f`, not the plugin menu's "Apply layout".** The menu action reads
  `~/.config/herdr/plugins/config/herdr-spreader/config.yaml`, which isn't part of this setup.
- **No dedupe.** Applying the same YAML twice creates two workspaces with the same
  name. Don't add a second auto-apply anywhere.
- **Stale panes on restart.** That's `session.json`. The `herdr()` wrapper deletes it on a
  cold start. zsh's `exec herdr` still goes through the wrapper.
- **Layouts aren't herdr state.** `reload-config` and detach/reattach don't rebuild
  them. To get a clean layout, restart the server and re-apply.
- **Two terminals cold-starting at the same moment** can both apply `tools.yaml`.
  This is a known edge case and isn't handled.
- **WSL cursor:** `config.toml` sets `ui.host_cursor = "native"` so nvim's insert-mode
  bar cursor shows. For cursor, mouse or colour oddities, check herdr's config before the app's.
- **Escape hatch:** put `export AUTO_HERDR=0` in `~/.zshrc.local`. SSH sessions never auto-start.
- **Security:** several layouts launch `claude --dangerously-skip-permissions`.
  Confirm with the human that they want this on the new machine. If not, use plain `claude -c`.
