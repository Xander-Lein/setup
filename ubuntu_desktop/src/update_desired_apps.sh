#!/usr/bin/env bash
set -euo pipefail

need_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

echo "==> update_desired_apps (apt upgrade)"
need_sudo apt-get update -qq
need_sudo apt-get upgrade -y
echo "Done."
