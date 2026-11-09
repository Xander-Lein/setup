#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBUNTU_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/read_desired_apps.sh
source "$SCRIPT_DIR/lib/read_desired_apps.sh"

TOML="$UBUNTU_ROOT/desired-apps.toml"
read_desired_apps_toml "$TOML"

need_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

echo "==> delete_desired_apps (remove packages from this machine)"
echo "    Config: $TOML"

for pkg in "${OPTIONAL_PACKAGES[@]}" "${PACKAGES[@]}"; do
  echo "  purge: $pkg"
  need_sudo apt-get remove -y "$pkg" 2>/dev/null || true
done

echo "Done."
