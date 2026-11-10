#!/usr/bin/env bash
# nook shell: zsh, prompt, command-line tools and their themes, for any desktop (or none).
#
# usage: shared/shell/install.sh [--palette=cocoa|ramen] [--with=a,b,c] [--no-deps]
#   --with   what to set up (default: all of them):
#            zsh       zsh as the Nook terminals' shell
#            omz       oh-my-zsh + autosuggestions + syntax highlighting
#            prompt-nook | prompt-starship | prompt-plain   the prompt (default: nook)
#            zoxide eza bat delta fd ripgrep fzf             cd / ls / cat / git diff / search
#            fastfetch btop cava git                         system info, monitor, visualiser, git colours
#            yazi lazygit tldr direnv                        files, git UI, cheat sheets, per-folder env
#            dust duf glow                                   disk use, free space, markdown
#            opencode                                        coding agent (npm @opencode/cli), Nook theme
#   --no-deps  don't install packages (sudo); only set up what's there
# The choice goes to ~/.local/share/nook/shell.conf, which zshrc, bashrc and tools.sh read.
# Every theme file is drawn in one palette and recoloured to the chosen one.
set -euo pipefail
source "$(dirname "$0")/../../lib/lib.sh"
CFG=$XDG_CONFIG_HOME
SH="$REPO/shared/shell" CLI="$REPO/shared/cli"
ALL="zsh omz prompt-nook zoxide eza bat delta fd ripgrep fzf fastfetch btop cava git yazi lazygit tldr direnv dust duf glow opencode"

palette=$(cat "$NOOK_STATE/shell-palette" 2>/dev/null || cat "$NOOK_STATE/palette" 2>/dev/null || echo cocoa)
with=$ALL deps=1
for a in "$@"; do
  case "$a" in
    --palette=*) palette=${a#--palette=} ;;
    --with=*)    with=$(tr ',' ' ' <<<"${a#--with=}") ;;
    --no-deps)   deps=0 ;;
    -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
    *) die "unknown option $a" ;;
  esac
done
[ -f "$REPO/palettes/$palette.json" ] || die "unknown palette $palette"
on() { [[ " $with " == *" $1 "* ]]; }
prompt=nook; on prompt-starship && prompt=starship; on prompt-plain && prompt=plain
mkdir -p "$NOOK_STATE" "$NOOK_SHARE"; echo "$palette" > "$NOOK_STATE/shell-palette"
BACKUP_DIR="$NOOK_STATE/shell-backup-$(date +%Y%m%d-%H%M%S)"

# put a file in place, recoloured from the palette it's drawn in (DRAWN) to the chosen one
put() {  # SRC DEST [DRAWN]
  install -Dm644 "$1" "$2"
  [ "${3:-cocoa}" = "$palette" ] || python3 -I "$REPO/lib/recolor.py" --from "${3:-cocoa}" --to "$palette" "$2" >/dev/null
}

# ── packages ────────────────────────────────────────────────────────────────
if [ "$deps" = 1 ]; then
  step "packages"
  fam=$(distro_family)
  pkgs=()
  for t in $with; do
    case "$fam:$t" in
      *:prompt-starship) pkgs+=(starship) ;;
      *:prompt-*|*:omz) pkgs+=(git) ;;
      fedora:delta|arch:delta|suse:delta|debian:delta) pkgs+=(git-delta) ;;
      fedora:fd|debian:fd) pkgs+=(fd-find) ;;
      *:fd) pkgs+=(fd) ;;
      *:opencode) ;;  # not a distro package; installed below with npm
      *:tldr) pkgs+=(tealdeer) ;;
      arch:dust) pkgs+=(dust) ;;
      *:dust) pkgs+=(du-dust) ;;
      *) pkgs+=("$t") ;;
    esac
  done
  case "$fam" in
    fedora) # lazygit isn't in Fedora; its COPR is the one the lazygit README points to
            if [[ " ${pkgs[*]} " == *" lazygit "* ]] && ! have lazygit && ! dnf copr list 2>/dev/null | grep -q atim/lazygit; then
              sudo dnf copr enable -y atim/lazygit || warn "COPR atim/lazygit not enabled; lazygit skipped"
            fi
            sudo dnf install -y --skip-unavailable "${pkgs[@]}" ;;
    debian) sudo apt-get update -qq
            ok_pkgs=(); for p in "${pkgs[@]}"; do apt-cache show "$p" >/dev/null 2>&1 && ok_pkgs+=("$p") || warn "$p is not in apt; skipped"; done
            [ ${#ok_pkgs[@]} -eq 0 ] || sudo apt-get install -y "${ok_pkgs[@]}" ;;
    arch)   sudo pacman -S --needed --noconfirm "${pkgs[@]}" ;;
    suse)   sudo zypper install -y "${pkgs[@]}" ;;
    *)      warn "unknown distro; install by hand: ${pkgs[*]}" ;;
  esac
  ok "${pkgs[*]}"
  # OpenCode v2 isn't packaged by the distros: npm into the user's prefix when it's writable
  # (no sudo), otherwise OpenCode's own installer
  if on opencode && ! have opencode; then
    if have npm && [ -w "$(npm config get prefix)" ]; then npm install -g @opencode/cli >/dev/null
    else curl -fsSL https://opencode.ai/v2/install | bash; fi
    ok "opencode $(opencode --version 2>/dev/null)"
  fi
fi

# ── what's chosen, for zshrc / bashrc / tools.sh ─────────────────────────────
tools=""; for t in zoxide eza bat delta fd ripgrep fzf yazi lazygit tldr direnv dust duf glow opencode; do on "$t" && tools+="$t "; done
cat > "$NOOK_SHARE/shell.conf" <<EOF
# written by ./nook (shared/shell/install.sh): the nook shell, read by zshrc, bashrc and tools.sh
NOOK_OMZ=$(on omz && echo 1 || echo 0)
NOOK_PROMPT=$prompt
NOOK_TOOLS="${tools% }"
NOOK_FETCH=$(on fastfetch && echo 1 || echo 0)
EOF
ok "shell.conf: prompt $prompt, tools: ${tools:-none}"

# ── zsh, oh-my-zsh, prompt ──────────────────────────────────────────────────
step "zsh ($palette)"
put "$SH/zshrc"  "$NOOK_SHARE/zshrc"
put "$SH/bashrc" "$NOOK_SHARE/bashrc"
put "$SH/tools.sh" "$NOOK_SHARE/tools.sh"
hook='[ -f "$HOME/.local/share/nook/bashrc" ] && . "$HOME/.local/share/nook/bashrc"  # nook'
grep -qF '# nook' "$HOME/.bashrc" 2>/dev/null || printf '\n%s\n' "$hook" >> "$HOME/.bashrc"
if on omz; then
  omz="$HOME/.oh-my-zsh"
  if [ ! -d "$omz" ] && have git; then
    git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$omz" && touch "$NOOK_STATE/omz-installed-by-nook"
  fi
  for r in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting; do
    dst="$omz/custom/plugins/${r#*/}"
    [ -d "$dst" ] || { have git && git clone -q --depth 1 "https://github.com/$r.git" "$dst"; } || true
  done
  [ -d "$omz" ] && put "$SH/nook.zsh-theme" "$omz/custom/themes/nook.zsh-theme"
fi
on prompt-starship && put "$SH/starship.toml" "$CFG/starship/nook.toml" ramen
if on zsh || on omz; then
  backup "$HOME/.zshrc"; touch "$HOME/.zshrc"
  hook='[ -f "$HOME/.local/share/nook/zshrc" ] && . "$HOME/.local/share/nook/zshrc"  # nook'
  if grep -v '# nook$' "$HOME/.zshrc" | grep -q 'oh-my-zsh.sh'; then
    # you already load oh-my-zsh yourself: switch its theme, and add the rest after it
    [ "$prompt" = nook ] && sed -i -E 's/^ZSH_THEME=.*/ZSH_THEME="nook"/' "$HOME/.zshrc"
    grep -qF '# nook' "$HOME/.zshrc" || printf '\n%s\n' "$hook" >> "$HOME/.zshrc"
  elif ! grep -qF '# nook' "$HOME/.zshrc"; then
    printf '%s\n\n%s' "$hook" "$(cat "$HOME/.zshrc")" > "$HOME/.zshrc.nook" && mv "$HOME/.zshrc.nook" "$HOME/.zshrc"
  fi
  have zsh || warn "zsh is not installed yet (run with packages)"
fi
ok "zsh${omz:+ + oh-my-zsh}, prompt $prompt"

# ── command-line tool themes ─────────────────────────────────────────────────
step "tools ($palette)"
if on ripgrep; then put "$CLI/ripgrep/config" "$CFG/ripgrep/config"; fi
if on bat || on delta; then
  # bat (and delta, which reads bat's themes) get the Nook syntax theme
  put "$CLI/bat/Nook.tmTheme" "$CFG/bat/themes/Nook.tmTheme"
  printf '%s\n' '# written by ./nook' '--theme="Nook"' '--style="numbers,changes,header"' '--italic-text=always' > "$CFG/bat/config"
  batbin=$(command -v bat || command -v batcat || true)
  [ -n "$batbin" ] && "$batbin" cache --build >/dev/null
fi
if on git || on delta; then
  have git || warn "git is not installed"
  put "$CLI/git/gitconfig" "$NOOK_SHARE/gitconfig"
  put "$CLI/git/delta.gitconfig" "$NOOK_SHARE/delta.gitconfig"
  if have git; then
    for inc in gitconfig delta.gitconfig; do
      git config --global --fixed-value --unset-all include.path "$NOOK_SHARE/$inc" 2>/dev/null || true
    done
    on git && git config --global --add include.path "$NOOK_SHARE/gitconfig"
    on delta && have delta && git config --global --add include.path "$NOOK_SHARE/delta.gitconfig"
  fi
fi
if on fastfetch; then
  put "$CLI/fastfetch/config.jsonc" "$CFG/fastfetch/config.jsonc"
  put "$CLI/fastfetch/nook-logo.txt" "$CFG/fastfetch/nook-logo.txt"
  put "$CLI/fastfetch/axolotl.jsonc" "$CFG/fastfetch/axolotl.jsonc" ramen
  put "$CLI/fastfetch/axolotl-logo.txt" "$CFG/fastfetch/axolotl-logo.txt" ramen
fi
if on btop; then
  put "$CLI/btop/nook.theme" "$CFG/btop/themes/nook.theme"
  if [ -f "$CFG/btop/btop.conf" ]; then sed -i -E 's|^color_theme *=.*|color_theme = "nook"|' "$CFG/btop/btop.conf"
  else printf 'color_theme = "nook"\ntheme_background = True\n' > "$CFG/btop/btop.conf"; fi
fi
on cava && put "$CLI/cava/config" "$CFG/cava/config"
# yazi: only the colours (theme.toml); yazi.toml and keymap.toml stay the user's
on yazi && put "$CLI/yazi/theme.toml" "$CFG/yazi/theme.toml"
# lazygit: a config of its own that tools.sh loads in front of the user's (LG_CONFIG_FILE)
on lazygit && put "$CLI/lazygit/config.yml" "$NOOK_SHARE/lazygit.yml"
# tealdeer and direnv: only when there's no config of the user's own
mine() { [ ! -e "$1" ] || head -1 "$1" | grep -q 'written by ./nook'; }
on tldr && mine "$CFG/tealdeer/config.toml" && put "$CLI/tealdeer/config.toml" "$CFG/tealdeer/config.toml"
on direnv && mine "$CFG/direnv/direnv.toml" && put "$CLI/direnv/direnv.toml" "$CFG/direnv/direnv.toml"
# opencode: the theme is generated from the palette (v2 themes are hue ramps, not single colours);
# cli.json only gets "theme" when there's no theme picked there yet
if on opencode; then
  python3 -I "$REPO/lib/opencode_theme.py" "$palette" "$CFG/opencode/themes/nook.json"
  python3 -I - "$CFG/opencode/cli.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1]); c = json.loads(p.read_text()) if p.exists() else {}
if "theme" not in c:
    c["theme"] = {"name": "nook", "mode": "dark"}
    p.write_text(json.dumps(c, indent=2) + "\n")
PY
fi
missing=""; for t in $tools; do
  case $t in ripgrep) have rg ;; fd) have fd || have fdfind ;; bat) have bat || have batcat ;; *) have "$t" ;; esac || missing+=" $t"
done
ok "themes in $palette${missing:+ (chosen but not installed:$missing)}"
[ -d "$BACKUP_DIR" ] && ok "replaced files backed up to ${BACKUP_DIR/#$HOME/~}"
true
