#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf "\n[dotfiles] %s\n" "$1"
}

need_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

have_apt_package() {
  apt-cache show "$1" >/dev/null 2>&1
}

backup_file() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$target" "$backup"
    log "Backed up $target -> $backup"
  fi
}

link_file() {
  local src="$1"
  local dst="$2"
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  backup_file "$dst"
  ln -s "$src" "$dst"
  log "Linked $dst"
}

install_base_packages() {
  log "Installing base packages"
  need_sudo apt update
  need_sudo apt install -y \
    zsh tmux git curl wget unzip build-essential ca-certificates \
    python3 python3-pip ripgrep fd-find fzf btop

  if have_apt_package eza; then
    need_sudo apt install -y eza
  fi
}

install_latest_neovim() {
  log "Installing latest Neovim"
  local tmp_dir
  local arch
  local archive
  local extracted_dir
  tmp_dir="$(mktemp -d)"
  arch="$(uname -m)"
  case "$arch" in
    x86_64)
      archive="nvim-linux-x86_64.tar.gz"
      extracted_dir="nvim-linux-x86_64"
      ;;
    aarch64|arm64)
      archive="nvim-linux-arm64.tar.gz"
      extracted_dir="nvim-linux-arm64"
      ;;
    *)
      log "Unsupported architecture for automatic Neovim install: $arch"
      return 1
      ;;
  esac
  curl -fsSL -o "$tmp_dir/nvim.tar.gz" "https://github.com/neovim/neovim/releases/latest/download/$archive"
  need_sudo rm -rf /opt/nvim
  need_sudo tar -C /opt -xzf "$tmp_dir/nvim.tar.gz"
  need_sudo mv "/opt/$extracted_dir" /opt/nvim
  need_sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp_dir"
}

install_oh_my_zsh() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    log "Oh My Zsh already installed"
  fi

  local custom_plugins="$HOME/.oh-my-zsh/custom/plugins"
  mkdir -p "$custom_plugins"

  if [[ ! -d "$custom_plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$custom_plugins/zsh-autosuggestions"
  fi
  if [[ ! -d "$custom_plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$custom_plugins/zsh-syntax-highlighting"
  fi
}

install_oh_my_posh() {
  if ! command -v oh-my-posh >/dev/null 2>&1; then
    log "Installing Oh My Posh"
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
  else
    log "Oh My Posh already installed"
  fi
}

install_opencode() {
  if ! command -v opencode >/dev/null 2>&1; then
    log "Installing OpenCode"
    curl -fsSL https://opencode.ai/install | bash
  else
    log "OpenCode already installed"
  fi
}

install_tpm() {
  if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    log "Installing TPM"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  else
    log "TPM already installed"
  fi
}

install_tmux_plugins() {
  log "Installing tmux plugins"
  "$HOME/.tmux/plugins/tpm/bin/install_plugins"
}

bootstrap_nvim_plugins() {
  log "Bootstrapping LazyVim plugins"
  nvim --headless "+Lazy! sync" +qa
}

set_default_shell() {
  local current_shell
  local target_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  target_shell="$(command -v zsh)"
  if [[ "$current_shell" != "$target_shell" ]]; then
    log "Setting zsh as default shell (may ask password)"
    chsh -s "$target_shell"
  fi
}

main() {
  install_base_packages
  install_latest_neovim
  install_oh_my_zsh
  install_oh_my_posh
  install_opencode
  install_tpm

  log "Linking dotfiles"
  mkdir -p "$HOME/.local/bin"
  link_file "$ROOT_DIR/zsh/.zshrc" "$HOME/.zshrc"
  link_file "$ROOT_DIR/zsh/.zprofile" "$HOME/.zprofile"
  link_file "$ROOT_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
  link_file "$ROOT_DIR/tmux/start-workspace.sh" "$HOME/.local/bin/start-tmux-workspace"
  mkdir -p "$HOME/omp-config"
  link_file "$ROOT_DIR/omp-config/myconfig.json" "$HOME/omp-config/myconfig.json"

  mkdir -p "$HOME/.config"
  link_file "$ROOT_DIR/nvim" "$HOME/.config/nvim"

  mkdir -p "$HOME/.config/opencode"
  link_file "$ROOT_DIR/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"

  install_tmux_plugins
  bootstrap_nvim_plugins
  set_default_shell

  log "Done. Restart terminal or run: exec zsh"
  printf "sh setup completed\n"
}

main "$@"
