# Nook command-line tools, for bash and zsh: zoxide behind cd, eza behind ls, bat behind cat,
# fd for fzf, and every one of them in the palette. A part only kicks in when its tool is chosen
# (NOOK_TOOLS in ~/.local/share/nook/shell.conf, set by ./nook) AND installed, so anything else
# leaves the plain command as it was. Sourced by ~/.local/share/nook/zshrc and bashrc.

_nook_shell=bash; [ -n "${ZSH_VERSION:-}" ] && _nook_shell=zsh
_nook_has() { command -v "$1" >/dev/null 2>&1; }
# chosen in shell.conf (all of them when there's no choice yet)
_nook_on() { case " ${NOOK_TOOLS-zoxide eza bat delta fd ripgrep fzf} " in *" $1 "*) return 0 ;; esac; return 1; }

# Debian and Ubuntu ship bat as batcat and fd as fdfind
_nook_bat="" _nook_fd=""
if _nook_on bat; then
  _nook_has bat || { _nook_has batcat && alias bat='batcat'; }
  _nook_bat=$(command -v bat || command -v batcat)
fi
if _nook_on fd; then
  _nook_has fd || { _nook_has fdfind && alias fd='fdfind'; }
  _nook_fd=$(command -v fd || command -v fdfind)
fi

# fzf in the palette, shared by Ctrl+R, Ctrl+T, Alt+C and `cdi`
_nook_on fzf && export FZF_DEFAULT_OPTS="--layout=reverse --border=sharp --info=inline --pointer='▶' --marker='+' --prompt='λ ' \
--color=bg:-1,bg+:#372f2a,fg:#f6ece4,fg+:#f6ece4,hl:#f5a8c9,hl+:#f5a8c9,prompt:#a6e6bf,pointer:#c4b2f5 \
--color=marker:#a6e6bf,border:#4a3f38,header:#bfae9f,info:#a3cdf5,spinner:#f9c49a,gutter:-1,query:#f6ece4"
if [ -n "$_nook_fd" ]; then
  export FZF_DEFAULT_COMMAND="$_nook_fd --type f --hidden --exclude .git"
  export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
  export FZF_ALT_C_COMMAND="$_nook_fd --type d --hidden --exclude .git"
fi
[ -n "$_nook_bat" ] && export FZF_CTRL_T_OPTS="--preview '$_nook_bat --color=always --style=numbers --line-range=:200 {}'"

# bat: cat with syntax highlighting (plain output when piped), and coloured man pages
if [ -n "$_nook_bat" ]; then
  alias cat="$_nook_bat --paging=never"
  export MANPAGER="sh -c 'col -bx | $_nook_bat -l man -p'" MANROFFOPT='-c'
fi

# eza: ls with git status, directories first; dirs sky, executables mint, symlinks teal
if _nook_on eza && _nook_has eza; then
  export EZA_COLORS="di=38;2;163;205;245:ex=38;2;166;230;191:ln=38;2;148;220;214:or=38;2;247;165;154:\
fi=38;2;246;236;228:da=38;2;125;109;98:sn=38;2;249;196;154:sb=38;2;125;109;98:uu=38;2;196;178;245:\
gu=38;2;191;174;159:ur=38;2;242;226;155:uw=38;2;247;165;154:ux=38;2;166;230;191:tr=38;2;242;226;155:\
tw=38;2;247;165;154:tx=38;2;166;230;191:gr=38;2;242;226;155:gw=38;2;247;165;154:gx=38;2;166;230;191:\
ga=38;2;166;230;191:gm=38;2;242;226;155:gd=38;2;247;165;154:gv=38;2;196;178;245:gt=38;2;148;220;214:\
gi=38;2;125;109;98:hd=38;2;196;178;245:*.md=38;2;245;168;201:*.zip=38;2;226;181;240:*.tar=38;2;226;181;240"
  alias ls='eza --group-directories-first'
  alias ll='eza -l --group-directories-first --git --time-style=relative'
  alias la='eza -la --group-directories-first --git --time-style=relative'
  alias lt='eza --tree --level=2 --group-directories-first'
fi

_nook_on ripgrep && export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"

# zoxide: `cd` learns the directories you use, so `cd proj` jumps to ~/code/proj; `cdi` picks with fzf.
# Plain paths still work as before.
_nook_on zoxide && _nook_has zoxide && eval "$(zoxide init "$_nook_shell" --cmd cd)"

unset _nook_shell _nook_bat _nook_fd
unset -f _nook_has _nook_on
