#!/usr/bin/env bash
set -euo pipefail

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/themes" "$ZSH_CUSTOM/plugins"

clone_if_missing() {
  local dest="$1"
  local url="$2"
  if [[ ! -d "$dest" ]]; then
    git clone --depth=1 "$url" "$dest"
  fi
}

clone_if_missing "$ZSH_CUSTOM/themes/powerlevel10k" https://github.com/romkatv/powerlevel10k.git
clone_if_missing "$ZSH_CUSTOM/plugins/zsh-autosuggestions" https://github.com/zsh-users/zsh-autosuggestions
clone_if_missing "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" https://github.com/zsh-users/zsh-syntax-highlighting.git
clone_if_missing "$ZSH_CUSTOM/plugins/zsh-history-substring-search" https://github.com/zsh-users/zsh-history-substring-search
