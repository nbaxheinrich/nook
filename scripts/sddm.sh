#!/usr/bin/env bash
# Theme the login screen, for whichever login manager is installed (needs sudo: both run as
# their own user and only read system-wide files). Run apply.sh first: the cursor, Plasma style
# and wallpaper come from it.
#   SDDM (Kubuntu, older Fedora): the Nook greeter in theme/sddm/nook and the cursor.
#   Plasma Login (Plasma 6.6+, Fedora/Nobara): its greeter is built in and takes no themes, so it
#     gets Nook's colours, Plasma style, font, cursor and the desktop's wallpaper instead.
#
# usage: sddm.sh            install, and make it the current login theme
#        sddm.sh --remove   take it out again; the login screen falls back to the distro's look
set -euo pipefail
source "$(dirname "$0")/lib.sh"

THEME=/usr/share/sddm/themes/nook
CURSOR=/usr/share/icons/Nook-Cursors
# sorts after the distro's and System Settings' files (kde_settings.conf), so it wins
CONF=/etc/sddm.conf.d/zz-nook.conf
# Plasma Login reads the wallpaper from this one file; System Settings writes it too
PLM_CONF=/etc/plasmalogin.conf
COLORS=/usr/share/color-schemes/Nook.colors
PSTYLE=/usr/share/plasma/desktoptheme/nook

has_sddm() { have sddm || have sddm-greeter-qt6; }
plm_home() { have plasmalogin && getent passwd plasmalogin | cut -d: -f6; }

if [ "${1:-}" = --remove ]; then
  step "login screen: removing the Nook theme"
  sudo rm -rf "$THEME" "$CURSOR" "$CONF" "$COLORS" "$PSTYLE"
  if home=$(plm_home) && [ -n "$home" ]; then
    sudo rm -rf "$home/.config/kdeglobals" "$home/.config/plasmarc" "$home/.config/kcminputrc" \
                "$home/.cache" "$home/wallpapers/nook.png"
    sudo kwriteconfig6 --file "$PLM_CONF" --group Greeter --group Wallpaper --group org.kde.image \
      --group General --key Image --delete
  fi
  ok "the login screen is back on the distro's look"
  exit 0
fi

home=$(plm_home || true)
if ! has_sddm && [ -z "$home" ]; then
  warn "neither SDDM nor Plasma Login is installed; the login screen stays as it is"
  exit 0
fi
FONT=$(mono_font)

# ── the cursor, shared by both ──
# and the files from before the rename, if any
sudo rm -rf /usr/share/sddm/themes/hackmachine /usr/share/icons/Hackmachine-Cursors /etc/sddm.conf.d/zz-hackmachine.conf
cursor=""
src_cursor="$XDG_DATA_HOME/icons/Nook-Cursors"
if [ -d "$src_cursor/cursors" ]; then
  sudo rm -rf "$CURSOR"
  sudo cp -r "$src_cursor" "$CURSOR"
  sudo chmod -R a+rX "$CURSOR"
  cursor=Nook-Cursors
else
  warn "no Nook cursor yet (run apply.sh first); the login screen keeps its cursor"
fi

if has_sddm; then
  step "login screen: SDDM theme + cursor"
  tmp=$(mktemp -d)
  cp -r "$REPO/theme/sddm/nook" "$tmp/nook"
  sed -i "s|^font=.*|font=$FONT|" "$tmp/nook/theme.conf"
  sudo rm -rf "$THEME"
  sudo install -d "$(dirname "$THEME")"
  sudo cp -r "$tmp/nook" "$THEME"
  sudo chmod -R a+rX "$THEME"
  rm -rf "$tmp"
  sudo install -d /etc/sddm.conf.d
  printf '%s\n' "# Written by Nook's scripts/sddm.sh; 'scripts/sddm.sh --remove' takes it out." \
    "[Theme]" "Current=nook" "Font=$FONT,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" \
    ${cursor:+"CursorTheme=$cursor" "CursorSize=32"} \
    | sudo tee "$CONF" >/dev/null
  ok "SDDM theme nook (shows at the next login; preview: sddm-greeter-qt6 --test-mode --theme $THEME)"
fi

if [ -n "$home" ]; then
  step "login screen: Plasma Login in Nook colours"
  pstyle_src="$XDG_DATA_HOME/plasma/desktoptheme/nook"
  [ -d "$pstyle_src" ] || die "no Nook Plasma style yet; run scripts/apply.sh first"
  sudo install -Dm644 "$REPO/theme/color-schemes/Nook.colors" "$COLORS"
  sudo rm -rf "$PSTYLE"
  sudo cp -r "$pstyle_src" "$PSTYLE"
  sudo chmod -R a+rX "$PSTYLE"

  # The greeter is a small Plasma session of the plasmalogin user, so it reads that user's
  # kdeglobals, plasmarc and kcminputrc, like System Settings' "Apply Plasma Settings" writes
  # them. Breeze icons: Nook's icon theme lives in your home, which the greeter can't read.
  f="$FONT,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  tmp=$(mktemp -d)
  printf '%s\n' "[General]" "ColorScheme=Nook" "font=$f" "fixed=$f" "menuFont=$f" "toolBarFont=$f" \
    "smallestReadableFont=$FONT,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" "" \
    "[Icons]" "Theme=breeze-dark" "" "[KDE]" "LookAndFeelPackage=org.kde.breezedark.desktop" "widgetStyle=Breeze" \
    > "$tmp/kdeglobals"
  printf '%s\n' "[Theme]" "name=nook" > "$tmp/plasmarc"
  [ -n "$cursor" ] && printf '%s\n' "[Mouse]" "cursorTheme=$cursor" "cursorSize=32" > "$tmp/kcminputrc"
  for c in "$tmp"/*; do
    sudo install -D -o plasmalogin -g plasmalogin -m644 "$c" "$home/.config/${c##*/}"
  done
  # Plasma caches theme SVGs and colours; start the greeter from a clean cache
  sudo rm -rf "$home/.cache"
  rm -rf "$tmp"

  # the primary screen's wallpaper, the same one the lock screen shows
  wp=$(kread --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image)
  wp=${wp#file://}
  if [ -f "$wp" ]; then
    sudo install -D -o plasmalogin -g plasmalogin -m644 "$wp" "$home/wallpapers/nook.png"
    sudo kwriteconfig6 --file "$PLM_CONF" --group Greeter --key WallpaperPluginId org.kde.image
    sudo kwriteconfig6 --file "$PLM_CONF" --group Greeter --group Wallpaper --group org.kde.image \
      --group General --key Image "file://$home/wallpapers/nook.png"
  else
    warn "no Nook wallpaper yet (run apply.sh first); the login screen keeps its wallpaper"
    wp=""
  fi
  ok "Plasma Login: Nook colours, Plasma style, $FONT${cursor:+, $cursor}${wp:+, the desktop wallpaper} (shows at the next login)"
fi
