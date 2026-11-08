# Nook oh-my-zsh theme: cocoa terminal, pastel prompt.
#
#   ╭─λ user@host ─ ~/proj/kde-rice ─  main ✓
#   ╰─❯                                   (base) 3s ✗ 1 16:34
#
# mint λ + prompt (coral after a failed command), lilac user, lavender host, sky path,
# lilac git branch with a mint ✓ or peach ● when dirty; right side: conda/venv in teal,
# how long the last command took in peach (if ≥ 2s), its exit code in coral, the time.

typeset -g NOOK_LINE='#4a3f38' NOOK_FAINT='#7d6d62' NOOK_MUTED='#bfae9f'
typeset -g NOOK_MINT='#a6e6bf' NOOK_SKY='#a3cdf5' NOOK_LAV='#c4b2f5' NOOK_LILAC='#e2b5f0'
typeset -g NOOK_PEACH='#f9c49a' NOOK_CORAL='#f7a59a' NOOK_TEAL='#94dcd6'

ZSH_THEME_GIT_PROMPT_PREFIX=" %F{$NOOK_LINE}─%f %F{$NOOK_LILAC} "
ZSH_THEME_GIT_PROMPT_SUFFIX="%f"
ZSH_THEME_GIT_PROMPT_DIRTY=" %F{$NOOK_PEACH}●%f"
ZSH_THEME_GIT_PROMPT_CLEAN=" %F{$NOOK_MINT}✓%f"
VIRTUAL_ENV_DISABLE_PROMPT=1

zmodload zsh/datetime
autoload -Uz add-zsh-hook
_nook_preexec() { typeset -g _nook_start=$EPOCHREALTIME }
_nook_precmd() {
  typeset -g _nook_took=""
  if [[ -n $_nook_start ]]; then
    local d=$(( EPOCHREALTIME - _nook_start ))
    if (( d >= 2 )); then
      local t
      if (( d >= 60 )); then t="$(( ${d%.*} / 60 ))m$(( ${d%.*} % 60 ))s"
      else t="$(printf '%.1fs' $d)"; fi
      _nook_took="%F{$NOOK_PEACH}$t%f "
    fi
  fi
  unset _nook_start
  print ""   # one blank line between commands
}
add-zsh-hook preexec _nook_preexec
add-zsh-hook precmd _nook_precmd

_nook_env() {
  local env=${CONDA_DEFAULT_ENV:-${VIRTUAL_ENV:t}}
  [[ -n $env ]] && print -n "%F{$NOOK_TEAL}($env)%f "
}

PROMPT='%F{$NOOK_LINE}╭─%f%F{$NOOK_MINT}λ%f %F{$NOOK_LILAC}%n%f%F{$NOOK_FAINT}@%f%F{$NOOK_LAV}%m%f %F{$NOOK_LINE}─%f %F{$NOOK_SKY}%~%f$(git_prompt_info)
%F{$NOOK_LINE}╰─%f%(?.%F{$NOOK_MINT}.%F{$NOOK_CORAL})❯%f '
RPROMPT='$(_nook_env)$_nook_took%(?..%F{$NOOK_CORAL}✗ %?%f )%F{$NOOK_FAINT}%D{%H:%M}%f'
PROMPT2='%F{$NOOK_LINE}  %f%F{$NOOK_FAINT}…%f '
