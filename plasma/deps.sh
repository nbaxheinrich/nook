#!/usr/bin/env bash
# Install the packages the Plasma rice uses. Needs sudo. Safe to re-run.
# (zsh, the prompt and the command-line tools are the shell part's: shared/shell/install.sh)
set -euo pipefail
source "$(dirname "$0")/../lib/lib.sh"

fam=$(distro_family)
step "installing packages for: $fam"

case "$fam" in
  fedora)
    sudo dnf install -y --skip-unavailable \
      jetbrains-mono-fonts-all fzf figlet lolcat toilet librsvg2-tools curl konsole alacritty kde-cli-tools git
    ;;
  debian)
    sudo apt-get update
    pkgs=(fonts-jetbrains-mono fzf figlet lolcat toilet librsvg2-bin curl konsole alacritty kde-cli-tools git)
    sudo apt-get install -y "${pkgs[@]}"
    ;;
  arch)
    sudo pacman -S --needed --noconfirm \
      ttf-jetbrains-mono fzf figlet lolcat toilet librsvg curl konsole alacritty git
    ;;
  suse)
    sudo zypper install -y jetbrains-mono-fonts fzf figlet lolcat toilet rsvg-convert curl konsole alacritty git
    ;;
  *)
    warn "unknown distro; install by hand: JetBrains Mono, fzf, figlet, lolcat, rsvg-convert, alacritty"
    ;;
esac

# VT323 pixel font (wallpaper headings) is not packaged anywhere; fetch it from Google Fonts.
fontdir="$XDG_DATA_HOME/fonts/nook"
if ! fc-list | grep -q VT323; then
  mkdir -p "$fontdir"
  if curl -fsSL -o "$fontdir/VT323-Regular.ttf" \
       https://raw.githubusercontent.com/google/fonts/main/ofl/vt323/VT323-Regular.ttf; then
    fc-cache -f "$fontdir" >/dev/null && ok "VT323 installed"
  else
    warn "could not download VT323; wallpaper headings fall back to JetBrains Mono"
  fi
fi
ok "packages done"
