#!/usr/bin/env bash
# nook-tile: Hyprland + Quickshell, next to (not instead of) Plasma.
# usage: tile/install.sh [--palette=ramen|cocoa] [--no-deps] [--no-login]
#   --palette   the colours (palettes/*.json); ramen (Ramen Sign) is what tile/ is drawn in.
#               Remembered in ~/.local/state/nook/tile-palette.
#   --no-deps   skip everything that needs sudo (packages, login screen); only link the configs
#   --no-login  leave the login screen alone (by default it gets the Ramen Sign look too,
#               via shared/login/login.sh; ./nook passes this and does the login itself)
#
# With ramen the configs are SYMLINKS into this repo, so editing a file here changes the live
# desktop (Hyprland reloads nook.lua on save, Quickshell its folder). Other palettes link to a
# recoloured copy in ~/.local/share/nook/tile-build (re-run this after editing).
# Nothing in the Plasma session is touched. Pick "Hyprland" on the login screen.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/lib.sh"
TILE="$REPO/tile"
CFG="$XDG_CONFIG_HOME"
BACKUP_DIR="$NOOK_STATE/tile-backup-$(date +%Y%m%d-%H%M%S)"

deps=1 login=1
palette=$(cat "$NOOK_STATE/tile-palette" 2>/dev/null || echo ramen)
for a in "$@"; do
  case "$a" in
    --palette=*) palette=${a#--palette=} ;;
    --ramen) palette=ramen ;; --cocoa|--pastel) palette=cocoa ;;
    --no-deps) deps=0 ;;
    --no-login|--no-sddm) login=0 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) die "unknown option $a" ;;
  esac
done

# ── packages ────────────────────────────────────────────────────────────────
# nook.lua is Hyprland's Lua config, so Hyprland must be 0.57 or newer; distro packages are
# usually older, hence the COPR / PPA. Quickshell needs Qt ≥ 6.6 (the launcher's shadow: 6.9).
QS_TAG=v0.3.2                                   # Quickshell release built from source on Ubuntu
OS_RELEASE=${NOOK_OS_RELEASE:-/etc/os-release}   # overridable for testing
os_id=$(. "$OS_RELEASE"; echo "${ID:-}")
os_ver=$(. "$OS_RELEASE"; echo "${VERSION_ID:-0}")
os_like=$(. "$OS_RELEASE"; echo "${ID_LIKE:-}")

copr_enable() { dnf copr list 2>/dev/null | grep -q "$1" || sudo dnf copr enable -y "$1"; }

deps_fedora() {
  # Nobara 44 ships quickshell itself; plain Fedora gets it from errornointernet/quickshell
  [ "${os_ver%%.*}" -ge 44 ] 2>/dev/null || die "Fedora $os_ver: Hyprland 0.57 is only built for Fedora 44 and newer"
  copr_enable sdegler/hyprland
  [ "$os_id" = nobara ] || copr_enable errornointernet/quickshell
  sudo dnf install -y \
    hyprland hyprlock hypridle hyprpolkitagent xdg-desktop-portal-hyprland \
    quickshell kitty mako qt6ct \
    fzf figlet lolcat fastfetch btop playerctl python3 curl \
    grim slurp wl-clipboard jetbrains-mono-fonts-all
  # the prompt; optional (Nobara/Terra have it): without it zsh keeps the recoloured nook prompt
  sudo dnf install -y starship 2>/dev/null || warn "no starship package: the terminal keeps the oh-my-zsh prompt"
}

deps_ubuntu() {
  # Checked by Qt version, not release number, so Ubuntu-based distros (Mint, Pop!_OS, Kubuntu …)
  # work the same: Quickshell needs Qt 6.6+, the launcher's shadow 6.9+. 24.04 has 6.4, 26.04 6.10.
  sudo apt-get update
  local qt
  qt=$(apt-cache policy qt6-base-dev 2>/dev/null | awk '/Candidate:/{print $2}')
  dpkg --compare-versions "${qt:-0}" ge 6.9 \
    || die "Qt ${qt:-not found} here; nook-tile needs Qt 6.9+ (Ubuntu 26.04 or newer, or a distro based on it)"
  sudo apt-get install -y software-properties-common
  grep -rqs cppiber/hyprland /etc/apt/sources.list.d/ || sudo add-apt-repository -y ppa:cppiber/hyprland
  sudo apt-get update
  sudo apt-get install -y \
    hyprland hyprlock hypridle hyprpolkitagent xdg-desktop-portal-hyprland \
    kitty mako-notifier qt6ct \
    fzf figlet lolcat fastfetch btop playerctl python3 curl \
    grim slurp wl-clipboard fonts-jetbrains-mono \
    qml6-module-qtquick qml6-module-qtqml qml6-module-qtqml-models qml6-module-qtqml-workerscript \
    qml6-module-qtquick-effects qml6-module-qtquick-layouts qml6-module-qtquick-window \
    qml6-module-qtquick-templates qml6-module-qtquick-controls libqt6svg6 qt6-wayland
  sudo apt-get install -y starship || warn "no starship package: the terminal keeps the oh-my-zsh prompt"
  if apt-cache policy quickshell 2>/dev/null | grep -q 'Candidate: [0-9]'; then
    sudo apt-get install -y quickshell                  # in the archive from Ubuntu 26.10 on
  elif ! command -v qs >/dev/null; then
    build_quickshell
  fi
}

# Quickshell from source (Ubuntu 26.04): every feature on except the crash handler (cpptrace
# is not packaged). Installs to /usr/local; takes a few minutes.
build_quickshell() {
  step "building quickshell $QS_TAG from source"
  sudo apt-get install -y \
    build-essential git cmake ninja-build pkg-config spirv-tools \
    qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev \
    qt6-wayland-dev qt6-wayland-private-dev qt6-shadertools-dev qt6-svg-dev \
    libcli11-dev libjemalloc-dev libdrm-dev libgbm-dev libvulkan-dev libxcb1-dev \
    libwayland-dev wayland-protocols libpipewire-0.3-dev libpam0g-dev \
    libpolkit-agent-1-dev libpolkit-gobject-1-dev libglib2.0-dev
  local src="$NOOK_STATE/src/quickshell"
  rm -rf "$src"; mkdir -p "$(dirname "$src")"
  git clone --depth 1 --branch "$QS_TAG" https://git.outfoxxed.me/quickshell/quickshell.git "$src"
  cmake -GNinja -S "$src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release -DCRASH_HANDLER=OFF \
        -DDISTRIBUTOR="nook-tile (source build)"
  cmake --build "$src/build"
  sudo cmake --install "$src/build"
  ok "quickshell $QS_TAG → /usr/local"
}

if [ "$deps" = 1 ]; then
  step "packages"
  case " $os_id $os_like " in
    *" fedora "*|*" nobara "*) deps_fedora ;;
    *" ubuntu "*)              deps_ubuntu ;;
    *" debian "*) die "Debian itself is not supported (no Hyprland 0.57 packages); Ubuntu 26.04+ is" ;;
    *) die "supported: Fedora 44+, Nobara 44+, Ubuntu 26.04+. Use --no-deps and install Hyprland ≥0.57 + Quickshell by hand" ;;
  esac
  ok "hyprland, quickshell, kitty, mako and tools"

  fontdir="$XDG_DATA_HOME/fonts/nook"
  if ! fc-list | grep -q VT323; then
    mkdir -p "$fontdir"
    curl -fsSL -o "$fontdir/VT323-Regular.ttf" \
      https://raw.githubusercontent.com/google/fonts/main/ofl/vt323/VT323-Regular.ttf \
      && fc-cache -f "$fontdir" >/dev/null && ok "VT323" || warn "could not fetch VT323"
  fi
fi

# ── palette: ramen is what tile/ is drawn in; anything else is a recoloured copy ──
[ -f "$REPO/palettes/$palette.json" ] || die "unknown palette $palette (have: $(ls "$REPO/palettes" | sed 's/\.json//' | tr '\n' ' '))"
mkdir -p "$NOOK_STATE"; echo "$palette" > "$NOOK_STATE/tile-palette"
if [ "$palette" = ramen ]; then
  TSRC=$TILE
else
  TSRC="$NOOK_SHARE/tile-build"
  rm -rf "$TSRC"; mkdir -p "$TSRC"
  for d in hypr quickshell kitty mako qt systemd; do cp -rL "$TILE/$d" "$TSRC/$d"; done
  python3 -I "$REPO/lib/recolor.py" --from ramen --to "$palette" "$TSRC" >/dev/null
  ok "tile recoloured ramen → $palette in ${TSRC/#$HOME/~}"
fi
ICONS=$([ "$palette" = ramen ] && echo Nook-Ramen || echo Nook)

# link SRC to DEST; an existing real file is backed up first, an old link replaced
link() {
  local src=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then backup "$dest"; rm -rf "$dest"; fi
  ln -sfn "$src" "$dest"
}

# ── hyprland ────────────────────────────────────────────────────────────────
step "hyprland"
link "$TSRC/hypr/nook.lua"       "$CFG/hypr/nook.lua"
link "$TSRC/hypr/hyprlock.conf"  "$CFG/hypr/hyprlock.conf"
link "$TSRC/hypr/hypridle.conf"  "$CFG/hypr/hypridle.conf"
if [ ! -e "$CFG/hypr/machine.lua" ]; then
  install -Dm644 "$TILE/hypr/machine.lua" "$CFG/hypr/machine.lua"
  ok "machine.lua written (monitors, keyboard): edit ~/.config/hypr/machine.lua"
else
  ok "machine.lua kept"
fi
if ! grep -qs 'require("nook")' "$CFG/hypr/hyprland.lua"; then
  backup "$CFG/hypr/hyprland.lua"
  install -Dm644 "$TILE/hypr/hyprland.lua" "$CFG/hypr/hyprland.lua"
fi
ok "~/.config/hypr → nook.lua, machine.lua, hyprlock, hypridle"

# ── quickshell ──────────────────────────────────────────────────────────────
step "quickshell"
link "$TSRC/quickshell/nook" "$CFG/quickshell/nook"
ok "~/.config/quickshell/nook (run: qs -c nook)"

# ── old-school pixel cursors (generated, no extra packages) ──
step "cursor"
python3 -I "$REPO/shared/cursors/pixelcursors.py" "$XDG_DATA_HOME/icons/Nook-Pixel" >/dev/null && ok "Nook-Pixel cursor theme"

# ── icons in this palette (shared/icons/build.sh), for Qt apps in this session ──
"$REPO/shared/icons/build.sh" "$palette" || warn "Qt apps keep the default icons"

# ── Qt apps: qt6ct with the palette's KDE colour scheme (Hyprland session only) ──
step "qt apps"
link "$REPO/palettes/kde/NookRamen.colors" "$XDG_DATA_HOME/color-schemes/NookRamen.colors"
install -Dm644 "$REPO/palettes/kde/Nook.colors" "$XDG_DATA_HOME/color-schemes/Nook.colors"
kscheme=$([ "$palette" = ramen ] && echo NookRamen || echo Nook)
link "$TSRC/qt/qt6ct.conf"   "$CFG/qt6ct/colors/nook-tile.conf"
# The KDE-aware qt6ct (Fedora/Nobara) loads KDE .colors schemes, so Dolphin & co. follow too;
# plain qt6ct (Ubuntu) only reads its own palette format.
scheme="$CFG/qt6ct/colors/nook-tile.conf"
qt6ct_bin=$(command -v qt6ct || true)
if [ -n "$qt6ct_bin" ] && ldd "$qt6ct_bin" 2>/dev/null | grep -q KF6ColorScheme; then
  scheme="$XDG_DATA_HOME/color-schemes/$kscheme.colors"
fi
# Breeze when it's installed (KDE desktops), else Qt's own Fusion
style=Fusion
for d in /usr/lib64/qt6/plugins/styles /usr/lib/qt6/plugins/styles /usr/lib/*/qt6/plugins/styles; do
  ls "$d"/breeze6.so >/dev/null 2>&1 && { style=Breeze; break; }
done
# JetBrains Mono for every piece of UI (design system); qt6ct needs absolute paths, so this
# file is written, not linked
font="JetBrains Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
fixed=$font
# the palette's icons when they were built above, else Plasma's icon theme, else the first one installed
icons=""
[ -d "$XDG_DATA_HOME/icons/$ICONS" ] && icons=$ICONS
[ -n "$icons" ] || icons=$(kread --file kdeglobals --group Icons --key Theme 2>/dev/null || true)
if [ -z "$icons" ]; then
  for t in Nook Papirus-Dark Adwaita; do
    [ -d "$XDG_DATA_HOME/icons/$t" ] || [ -d "/usr/share/icons/$t" ] && { icons=$t; break; }
  done
fi
backup "$CFG/qt6ct/qt6ct.conf"
mkdir -p "$CFG/qt6ct"
cat > "$CFG/qt6ct/qt6ct.conf" <<EOF
# written by tile/install.sh — Qt apps in the Hyprland session (QT_QPA_PLATFORMTHEME=qt6ct)
[Appearance]
color_scheme_path=$scheme
custom_palette=true
icon_theme=${icons:-Adwaita}
standard_dialogs=default
style=$style

[Fonts]
fixed="$fixed"
general="$font"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
dialog_buttons_have_icons=1
menus_have_icons=true
show_shortcuts_in_context_menus=true
toolbutton_style=4
underline_shortcut=1
EOF
ok "qt6ct → $palette ($(basename "$scheme")), $style, ${icons:-default} icons, $(cut -d, -f1-2 <<<"$font")"

# ── terminal, notifications, menu, fastfetch, prompt ────────────────────────
step "kitty, mako, session target"
link "$TSRC/kitty/nook.conf" "$CFG/kitty/nook.conf"
touch "$CFG/kitty/kitty.conf"
grep -q '^include nook.conf' "$CFG/kitty/kitty.conf" || printf '\ninclude nook.conf\n' >> "$CFG/kitty/kitty.conf"
if zsh_bin=$(command -v zsh) && ! grep -q '^shell ' "$CFG/kitty/kitty.conf"; then
  printf 'shell %s\n' "$zsh_bin" >> "$CFG/kitty/kitty.conf"
fi
link "$TILE/bin/nook-gamemode"       "$HOME/.local/bin/nook-gamemode"
link "$TILE/bin/nook-session-look"   "$HOME/.local/bin/nook-session-look"
# Plasma puts its own icon theme back when it starts (KDE apps read it from the shared kdeglobals)
mkdir -p "$CFG/autostart"
cat > "$CFG/autostart/nook-session-look.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Nook session look
Comment=Plasma's icon theme after a nook-tile (Hyprland) session
Exec=$HOME/.local/bin/nook-session-look plasma
NoDisplay=true
OnlyShowIn=KDE;
X-KDE-autostart-phase=1
DESKTOP
link "$TSRC/mako/config"            "$CFG/mako/config"
# graphical-session.target for the portal (Hyprland without uwsm does not start it)
link "$TSRC/systemd/hyprland-session.target" "$CFG/systemd/user/hyprland-session.target"
systemctl --user daemon-reload 2>/dev/null || true
ok "kitty, mako ($palette), hyprland-session.target (the shell and prompt: ./nook → shell)"

[ -d "${BACKUP_DIR}" ] && ok "replaced files backed up to ${BACKUP_DIR/#$HOME/~}"

# ── login screen in this palette (SDDM or Plasma Login; sudo) ──
if [ "$deps" = 1 ] && [ "$login" = 1 ]; then
  "$REPO/shared/login/login.sh" $([ "$palette" = cocoa ] && echo --pastel) || warn "login screen not changed; run shared/login/login.sh alone to see why"
fi
printf '\n%sλ%s done. Log out and pick %sHyprland%s on the login screen.\n' "$c_mint" "$c_off" "$c_lav" "$c_off"
printf '  SUPER ⏎ terminal · SUPER SPACE hack menu · SUPER / keybinds · SUPER ⇧ E back out\n'
