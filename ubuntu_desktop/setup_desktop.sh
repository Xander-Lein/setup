#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$ROOT/download_desired_apps.sh"
bash "$ROOT/apply_settings_to_desired_apps.sh"
