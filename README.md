# Portable dotfiles (Ubuntu/Debian)

This repository bootstraps:

- zsh + Oh My Zsh + Oh My Posh
- tmux + TPM + tmux plugins
- latest Neovim + LazyVim config
- OpenCode baseline config

## Quick setup

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
bash install.sh
```

## Notes

- `install.sh` creates timestamped backups before linking files.
- Put secrets and machine-specific values in `~/.zshrc.local`.
- Example local file: `zsh/.zshrc.local.example`.
- Enable auto tmux startup by setting `AUTO_TMUX=1` in `~/.zshrc.local` if you want it.
- After install, restart shell or run `exec zsh`.
