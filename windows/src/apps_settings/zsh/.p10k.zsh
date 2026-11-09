# Managed by Windows setup — powerlevel10k (минимальные переопределения)
# Resize: https://github.com/romkatv/powerlevel10k#horrific-mess-when-resizing-terminal-window

typeset -g POWERLEVEL9K_MODE='compatible'

# Одна строка: user@host, каталог, > (без RPROMPT)
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir prompt_char)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

# Смягчение бага zsh+reflow при Win+resize (Alacritty)
# transient_rprompt — в .zshrc; transient prompt — схлопывает старый промпт после команды
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=same-dir
typeset -g POWERLEVEL9K_SHOW_RULER=false
typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR=' '

typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=0
typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last

typeset -g POWERLEVEL9K_TIME_FORMAT=''
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=999999

typeset -g POWERLEVEL9K_PROMPT_CHAR_CONTENT_EXPANSION='>'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_CONTENT_EXPANSION='>'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_CONTENT_EXPANSION='>'
