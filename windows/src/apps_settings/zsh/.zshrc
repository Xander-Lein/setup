# Windows MSYS2 + zsh — minimal (hotkeys: .zsh-hotkeys.zsh + Alacritty)

typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
if [[ ! -f ~/.p10k.zsh ]]; then
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git history zsh-autosuggestions zsh-syntax-highlighting)

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

if command -v fzf &>/dev/null; then
  eval "$(fzf --zsh 2>/dev/null)" || true
fi

if [[ "$(uname -o 2>/dev/null)" == Msys || "${OSTYPE:-}" == msys* ]]; then
  _ws_win_ssh="/c/Windows/System32/OpenSSH"
  if [[ -x "$_ws_win_ssh/ssh.exe" ]]; then
    alias ssh="$_ws_win_ssh/ssh.exe"
    alias scp="$_ws_win_ssh/scp.exe"
    export GIT_SSH_COMMAND="$_ws_win_ssh/ssh.exe"
  fi
  unset _ws_win_ssh
fi

bindkey -e
setopt transient_rprompt 2>/dev/null

[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
[[ -o interactive ]] && [[ -f ~/.zsh-hotkeys.zsh ]] && source ~/.zsh-hotkeys.zsh
