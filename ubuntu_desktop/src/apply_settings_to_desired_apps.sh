#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBUNTU_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$UBUNTU_ROOT/.." && pwd)"

# shellcheck source=lib/read_desired_apps.sh
source "$SCRIPT_DIR/lib/read_desired_apps.sh"

SETTINGS_TOML="$UBUNTU_ROOT/desired-apps-settings.toml"
read_settings_toml "$SETTINGS_TOML"

if [[ -d "$REPO_ROOT/windows/src/apps_settings/zsh" ]]; then
  ZSH_SRC="$REPO_ROOT/windows/src/apps_settings/zsh"
elif [[ -d "$UBUNTU_ROOT/zsh" ]]; then
  ZSH_SRC="$UBUNTU_ROOT/zsh"
else
  echo "Missing zsh configs: windows/src/apps_settings/zsh" >&2
  exit 1
fi

echo "==> apply_settings_to_desired_apps (zsh dotfiles)"
echo "    source: $ZSH_SRC"
echo "    profile: $ZSH_PROFILE"

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  export RUNZSH=no CHSH=no KEEP_ZSHRC=yes
  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
fi

export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
bash "$ZSH_SRC/install-omz-extras.sh"

copy_dot() {
  local src="$ZSH_SRC/$1"
  [[ -f "$src" ]] || return 0
  sed 's/\r$//' "$src" | sed '1s/^\xEF\xBB\xBF//' > "$HOME/$2"
  echo "  -> ~/$2"
}

if [[ "$ZSH_PROFILE" == minimal ]]; then
  if [[ -f "$ZSH_SRC/.zshrc.minimal" ]]; then
    sed 's/\r$//' "$ZSH_SRC/.zshrc.minimal" | sed '1s/^\xEF\xBB\xBF//' > "$HOME/.zshrc"
    echo "  -> ~/.zshrc (minimal)"
  else
    copy_dot ".zshrc" ".zshrc"
  fi
else
  copy_dot ".zshrc" ".zshrc"
fi
copy_dot ".p10k.zsh" ".p10k.zsh"

ZSH_PATH="$(command -v zsh)"
CURRENT="$(getent passwd "$USER" | cut -d: -f7 || true)"
if [[ "$CURRENT" != "$ZSH_PATH" ]]; then
  chsh -s "$ZSH_PATH" 2>/dev/null || echo "Run: chsh -s $ZSH_PATH"
fi

echo "Done. Run: exec zsh -il"
