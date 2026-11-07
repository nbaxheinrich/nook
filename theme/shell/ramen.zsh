# Ramen Sign for the nook zsh (nook-tile). Sourced by zshrc when NOOK_THEME=ramen (kitty sets it).
# The prompt is starship with tile/starship/ramen.toml (STARSHIP_CONFIG, also set by kitty):
#   ╭─[λ nbax@nobara-pc]─[~/proj/kde-rice]─[git:main ●2]
#   ╰─▶                                        took 4s · ✗ 1 · 14:55
# Without starship, the nook oh-my-zsh prompt is recoloured in the neons instead.
# Highlighting in the neons either way.

if command -v starship >/dev/null && [[ -f ${STARSHIP_CONFIG:-$HOME/.config/starship/ramen.toml} ]]; then
  export STARSHIP_CONFIG=${STARSHIP_CONFIG:-$HOME/.config/starship/ramen.toml}
  RPROMPT=''
  eval "$(starship init zsh)"
else
  #   λ / ❯ red (orange after a failure) · user cream · host cyan · path blue · git cream, ✓ aqua, ● gold
  typeset -g NOOK_LINE='#343434' NOOK_FAINT='#626262' NOOK_MUTED='#a8a8a8'
  typeset -g NOOK_MINT='#ff6458' NOOK_SKY='#62a5ff' NOOK_LAV='#45c8e6' NOOK_LILAC='#ffd98f'
  typeset -g NOOK_PEACH='#ffc247' NOOK_CORAL='#ff9a3c' NOOK_TEAL='#4fd8cf'
  ZSH_THEME_GIT_PROMPT_PREFIX=" %F{$NOOK_LINE}─%f %F{$NOOK_LILAC} "
  ZSH_THEME_GIT_PROMPT_DIRTY=" %F{$NOOK_PEACH}●%f"
  ZSH_THEME_GIT_PROMPT_CLEAN=" %F{$NOOK_TEAL}✓%f"
fi

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#626262'
ZSH_HIGHLIGHT_STYLES[command]='fg=#4fd8cf'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#4fd8cf'
ZSH_HIGHLIGHT_STYLES[function]='fg=#4fd8cf'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#45c8e6'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#ff6458,italic'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#ff6458'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ff9a3c'
ZSH_HIGHLIGHT_STYLES[path]='fg=#62a5ff,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#ffc247'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#ffd98f'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#ffd98f'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#ffd98f'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#a8a8a8'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#a8a8a8'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#a8a8a8'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#a8a8a8'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#626262'
