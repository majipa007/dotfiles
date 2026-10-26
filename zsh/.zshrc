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

# Auto-start your default tmux workspace for local interactive terminals.
# if [[ "${AUTO_TMUX:-1}" == "1" ]] && [[ -o interactive ]] && command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" ]] && [[ -z "$SSH_CONNECTION" ]]; then
#   if command -v start-tmux-workspace >/dev/null 2>&1; then
#     exec start-tmux-workspace
#   fi
# fi
export PATH="$HOME/llama.cpp/build-cpu/bin:$PATH"

# herdr is launched by hand now: type `herdr`, then open only the workspaces you
# want with `herdr-spreader apply -f ~/.config/herdr-spreader/<name>.yaml`.
# The wrapper keeps the one thing the old auto-start block was really for: on a
# cold start herdr restores session.json and brings back dead panes, so drop the
# saved layout whenever no server is running.
# ponytail: default session only, add the HERDR_SESSION lookup back if you use
# isolated sessions again.
herdr() {
  [[ "$(command herdr session list 2>/dev/null | awk '$1=="default"{print $2}')" == running ]] ||
    rm -f "$HOME/.config/herdr/session.json"
  command herdr "$@"
}

# bun completions
[ -s "/home/sukuna/.bun/_bun" ] && source "/home/sukuna/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:/usr/local/go/bin

# Local interactive terminals boot straight into herdr with the tools workspace
# laid out. Panes re-source this file, so HERDR_ENV is the recursion guard.
# herdr-spreader has no dedupe (engine.rs always issues `workspace create`), so
# only the shell that cold-starts the server applies the layout — a second
# window just attaches. AUTO_HERDR=0 is the escape hatch.
# ponytail: races if two terminals cold-start at once -> duplicate `tools`.
# Add a flock on the socket path if that ever actually happens.
if [[ "${AUTO_HERDR:-1}" == "1" ]] && [[ -o interactive ]] && [[ -z "${HERDR_ENV:-}" ]] &&
   [[ -z "${SSH_CONNECTION:-}" ]] && (( $+commands[herdr] )); then  # binary only; `command -v` matches the herdr() wrapper
  if [[ "$(command herdr session list 2>/dev/null | awk '$1=="default"{print $2}')" != running ]]; then
    # The server answers {"error":...} with exit 0 while it warms up, so gate on
    # a real result rather than on the exit code (same trick as
    # setup-workspaces.sh). ponytail: 30s ceiling, raise it if a cold boot ever
    # loses the race.
    (
      for _ in {1..60}; do
        command herdr workspace list 2>/dev/null | jq -e 'has("result")' >/dev/null 2>&1 && break
        sleep 0.5
      done
      herdr-spreader apply -f "$HOME/.config/herdr-spreader/tools.yaml" >/dev/null 2>&1
    ) &!
  fi
  exec herdr   # zsh `exec` resolves the herdr() wrapper above, so the stale
               # session.json cleanup still runs on a cold start
fi
export TZ="Asia/Kolkata"

# added by deadline installer
export PATH="$HOME/.local/bin:$PATH"
