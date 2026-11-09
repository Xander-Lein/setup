#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBUNTU_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$UBUNTU_ROOT/.." && pwd)"

# shellcheck source=lib/read_desired_apps.sh
source "$SCRIPT_DIR/lib/read_desired_apps.sh"

TOML="$UBUNTU_ROOT/desired-apps.toml"
read_desired_apps_toml "$TOML"

need_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

echo "==> download_desired_apps (apt install)"
need_sudo apt-get update -qq

for pkg in "${PACKAGES[@]}"; do
  echo "  install: $pkg"
  need_sudo apt-get install -y "$pkg"
done

for pkg in "${OPTIONAL_PACKAGES[@]}"; do
  echo "  optional: $pkg"
  need_sudo apt-get install -y "$pkg" 2>/dev/null || echo "    skip optional $pkg"
done

echo "Done."
