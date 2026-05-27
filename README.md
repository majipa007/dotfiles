# Portable dotfiles (Ubuntu/Debian)

This repository bootstraps:

- zsh + Oh My Zsh + Oh My Posh
- tmux + TPM + tmux plugins
- latest Neovim + LazyVim config
- OpenCode CLI + baseline config

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

## Notes

- `install.sh` creates timestamped backups before linking files.
- `install.sh` installs OpenCode using the official `https://opencode.ai/install` script.
- Your Oh My Posh theme is tracked in `omp-config/myconfig.json` and linked to `~/omp-config/myconfig.json` during install.
- Put secrets and machine-specific values in `~/.zshrc.local`.
- Example local file: `zsh/.zshrc.local.example`.
- Enable auto tmux startup by setting `AUTO_TMUX=1` in `~/.zshrc.local` if you want it.
- After install, restart shell or run `exec zsh`.
