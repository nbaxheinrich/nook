# Ramen Sign palette for the nook zsh prompt (nook-tile). Sourced by zshrc when
# NOOK_THEME=ramen (kitty sets it there). Same prompt shape, neon colours:
#   λ / ❯ aqua (red after a failure) · user cream · host cyan · path blue · git cream, ✓ aqua, ● orange

typeset -g NOOK_LINE='#343434' NOOK_FAINT='#626262' NOOK_MUTED='#a8a8a8'
typeset -g NOOK_MINT='#4fd8cf' NOOK_SKY='#62a5ff' NOOK_LAV='#45c8e6' NOOK_LILAC='#ffd98f'
typeset -g NOOK_PEACH='#ff9a3c' NOOK_CORAL='#ff6458' NOOK_TEAL='#4fd8cf'

ZSH_THEME_GIT_PROMPT_PREFIX=" %F{$NOOK_LINE}─%f %F{$NOOK_LILAC} "
ZSH_THEME_GIT_PROMPT_DIRTY=" %F{$NOOK_PEACH}●%f"
ZSH_THEME_GIT_PROMPT_CLEAN=" %F{$NOOK_MINT}✓%f"

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#626262'
ZSH_HIGHLIGHT_STYLES[command]='fg=#4fd8cf'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#4fd8cf'
ZSH_HIGHLIGHT_STYLES[function]='fg=#4fd8cf'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#45c8e6'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#ffb14a,italic'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#ff7a5c'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ff6458'
ZSH_HIGHLIGHT_STYLES[path]='fg=#62a5ff,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#ff9a3c'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#ffc247'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#ffc247'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#ffc247'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#a8a8a8'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#a8a8a8'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#a8a8a8'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#a8a8a8'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#626262'
