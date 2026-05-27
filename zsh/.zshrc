# Startup banner (only for interactive shells)
if [[ -o interactive ]] && command -v pokemon-colorscripts >/dev/null 2>&1 && command -v fastfetch >/dev/null 2>&1 && [[ -f "$HOME/.config/fastfetch/config-pokemon.jsonc" ]]; then
  pokemon-colorscripts --no-title -s -r | fastfetch -c "$HOME/.config/fastfetch/config-pokemon.jsonc" --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
fi

export PATH="$HOME/.local/bin:$PATH"
[[ -d "/opt/nvim/bin" ]] && export PATH="/opt/nvim/bin:$PATH"
[[ -d "$HOME/llama.cpp/build/bin" ]] && export PATH="$PATH:$HOME/llama.cpp/build/bin"
[[ -d "$HOME/.opencode/bin" ]] && export PATH="$HOME/.opencode/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting z colored-man-pages)

if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

if command -v oh-my-posh >/dev/null 2>&1 && [[ -f "$HOME/omp-config/myconfig.json" ]]; then
  eval "$(oh-my-posh init zsh --config "$HOME/omp-config/myconfig.json")"
fi

if [[ -z "${SSH_CONNECTION:-}" ]] && [[ -n "${DISPLAY:-}" ]]; then
  export DISPLAY
fi
export EZA_COLORS="di=1;36:fi=1;36:ln=1;36:ex=1;36:pi=1;36:so=1;36:bd=1;36:cd=1;36:su=1;36:sg=1;36:da=1;36:ur=1;36:uw=1;36:ux=1;36:gr=1;36:gw=1;36:gx=1;36:tr=1;36:tw=1;36:tx=1;36"

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --group-directories-first'
  alias la='eza -a --icons --group-directories-first'
  alias lt='eza --tree --level=2 --icons'
fi

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

# Optional conda init (portable path)
if [[ -x "$HOME/miniconda3/bin/conda" ]]; then
  __conda_setup="$($HOME/miniconda3/bin/conda shell.zsh hook 2>/dev/null)"
  if [[ $? -eq 0 ]]; then
    eval "$__conda_setup"
  elif [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
  else
    export PATH="$HOME/miniconda3/bin:$PATH"
  fi
  unset __conda_setup
fi

# Local machine-specific values (secrets, tokens, host-only paths)
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Auto-start tmux for interactive local terminals when enabled.
if [[ "${AUTO_TMUX:-0}" == "1" ]] && [[ -o interactive ]] && command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" ]] && [[ -z "$SSH_CONNECTION" ]]; then
  SESSION_NAME="term-$(date +%s%N | cut -c1-13)"
  tmux new-session -d -s "$SESSION_NAME" -n code
  tmux new-window -t "$SESSION_NAME":2 -n codex
  tmux new-window -t "$SESSION_NAME":3 -n terminal
  if command -v btop >/dev/null 2>&1; then
    tmux new-window -t "$SESSION_NAME":4 -n monitoring "btop"
  else
    tmux new-window -t "$SESSION_NAME":4 -n monitoring
  fi
  tmux new-window -t "$SESSION_NAME":5 -n misc
  exec tmux attach -t "$SESSION_NAME"
fi
