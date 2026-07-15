# Portable dotfiles (Ubuntu/Debian)

This repository bootstraps:

- zsh + Oh My Zsh + Oh My Posh
- tmux + TPM + tmux plugins
- latest Neovim + LazyVim config
- OpenCode CLI + baseline config
- Claude Code CLI

## Quick setup

```bash
git clone git@github.com:majipa007/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

HTTPS clone:

```bash
git clone https://github.com/majipa007/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

The installer asks which components to install (Enter = all). Pass `--all`
(or `-y`) to skip every prompt and install everything, e.g. for unattended
setups. Non-interactive runs (like `curl | bash`) also default to everything.

## Tmux workspace tabs

If tmux is selected, the installer asks whether to keep the default tabs
(`code`, `codex` running opencode, `claude` running claude, `terminal`,
`monitoring` running btop, `misc`) or define your own — each tab is
`name` or `name:command`.

Custom tabs are written to `~/.tmux-workspace.conf`, which you can edit any
time (see `tmux/tmux-workspace.conf.example`). Without that file the launcher
uses the built-in defaults. Tab commands only run if the binary exists;
otherwise the tab opens a plain shell. By default the launcher reuses an
existing `workspace` session instead of creating a new one per terminal; set
`attach_existing=0` in the config to always create fresh sessions.

## Notes

- `install.sh` creates timestamped backups before linking files.
- `install.sh` installs OpenCode using the official `https://opencode.ai/install` script.
- Your Oh My Posh theme is tracked in `omp-config/myconfig.json` and linked to `~/omp-config/myconfig.json` during install.
- Your tmux workspace launcher is installed as `start-tmux-workspace` and zsh auto-starts it by default on local terminals.
- Put secrets and machine-specific values in `~/.zshrc.local`.
- Example local file: `zsh/.zshrc.local.example`.
- Disable auto tmux startup by setting `AUTO_TMUX=0` in `~/.zshrc.local` if you want it.
- After install, restart shell or run `exec zsh`.
