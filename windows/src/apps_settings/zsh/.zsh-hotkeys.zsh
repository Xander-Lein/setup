# Managed by setup — горячие клавиши (после OMZ и p10k).

[[ -o interactive && -o zle && -t 1 ]] || return 0

_setup_ensure_region() {
  (( REGION_ACTIVE )) || zle set-mark-command
}

_setup_select_left() {
  _setup_ensure_region
  zle backward-char
}

_setup_select_right() {
  _setup_ensure_region
  zle forward-char
}

_setup_select_word_left() {
  _setup_ensure_region
  zle backward-word
}

_setup_select_word_right() {
  _setup_ensure_region
  zle forward-word
}

_setup_copy() {
  local text
  if (( REGION_ACTIVE )); then
    if (( MARK < CURSOR )); then
      text=${BUFFER:$MARK:$((CURSOR - MARK))}
    else
      text=${BUFFER:$CURSOR:$((MARK - CURSOR))}
    fi
    print -rn -- "$text" | /c/Windows/System32/clip.exe >/dev/null 2>&1
    zle unset-mark
  else
    print -rn -- "$BUFFER" | /c/Windows/System32/clip.exe >/dev/null 2>&1
  fi
  zle reset-prompt
}

_setup_paste() {
  local clip
  clip="$(powershell.exe -NoProfile -Command '(Get-Clipboard -Raw)' 2>/dev/null | tr -d '\r')"
  [[ -n "$clip" ]] && zle -U "$clip"
}

zle -N _setup_select_left
zle -N _setup_select_right
zle -N _setup_select_word_left
zle -N _setup_select_word_right
zle -N _setup_copy
zle -N _setup_paste

bindkey '\e;c' _setup_copy
bindkey '\e[1;2D' _setup_select_left
bindkey '\e[1;2C' _setup_select_right
bindkey '\e[1;6D' _setup_select_word_left
bindkey '\e[1;6C' _setup_select_word_right
bindkey '\e[1;3D' _setup_select_word_left
bindkey '\e[1;3C' _setup_select_word_right
bindkey '\e[1;4D' _setup_select_word_left
bindkey '\e[1;4C' _setup_select_word_right
bindkey '^W' backward-kill-word
bindkey '\e^?' backward-kill-word
bindkey '\e[3;5~' kill-word
bindkey '\e[3~' delete-char
