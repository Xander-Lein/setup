#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

read_desired_apps_toml() {
  local toml="$1"
  PACKAGES=()
  OPTIONAL_PACKAGES=()
  ZSH_PROFILE=minimal

  [[ -f "$toml" ]] || return 0

  local section=""
  local in_array=0
  local array_kind=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^\[([^]]+)\] ]]; then
      section="${BASH_REMATCH[1]}"
      in_array=0
      array_kind=""
      continue
    fi

    if [[ "$section" == "settings" ]]; then
      if [[ "$line" =~ ^zsh_profile[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
        ZSH_PROFILE="${BASH_REMATCH[1]}"
      fi
      continue
    fi

    if [[ "$section" != "apt" ]]; then
      continue
    fi

    if [[ "$line" =~ ^packages[[:space:]]*=[[:space:]]*\[ ]]; then
      in_array=1
      array_kind=packages
      [[ "$line" == *] ]] && in_array=0
      continue
    fi
    if [[ "$line" =~ ^optional_packages[[:space:]]*=[[:space:]]*\[ ]]; then
      in_array=1
      array_kind=optional
      [[ "$line" == *] ]] && in_array=0
      continue
    fi

    if (( in_array )); then
      [[ "$line" == "]" ]] && in_array=0 && continue
      if [[ "$line" =~ \"([^\"]+)\" ]]; then
        local pkg="${BASH_REMATCH[1]}"
        if [[ "$array_kind" == optional ]]; then
          OPTIONAL_PACKAGES+=("$pkg")
        else
          PACKAGES+=("$pkg")
        fi
      fi
    fi
  done < "$toml"
}

read_settings_toml() {
  local toml="$1"
  ZSH_PROFILE=minimal
  [[ -f "$toml" ]] || return 0
  read_desired_apps_toml "$toml"
}
