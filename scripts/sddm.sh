#!/usr/bin/env bash
# Theme the login screen, for whichever login manager is installed (needs sudo: both run as
# their own user and only read system-wide files). Run apply.sh first: the cursor, Plasma style
# and wallpaper come from it.
#   SDDM (Kubuntu, older Fedora): the Nook greeter in theme/sddm/nook and the cursor.
#   Plasma Login (Plasma 6.6+, Fedora/Nobara): its greeter is built in and takes no themes, so it
#     gets Nook's colours, Plasma style, font, cursor and a wallpaper instead.
# One login screen serves both sessions (Plasma and nook-tile), so it has one look:
#   ramen  (default) Ramen Sign: neutral greys, neons, cyan focus, Nook-Pixel cursor, a black
#          wallpaper with the glowing NOOK banner (scripts/login_wallpaper.py)
#   pastel the cocoa Plasma rice: Nook colours and Plasma style, Nook cursor, the desktop wallpaper
#
# usage: sddm.sh            install the Ramen Sign look, and make it the current login theme
#        sddm.sh --pastel   install the pastel look instead (needs apply.sh first)
#        sddm.sh --remove   take it out again; the login screen falls back to the distro's look
set -euo pipefail
source "$(dirname "$0")/lib.sh"

THEME=/usr/share/sddm/themes/nook
CURSOR=/usr/share/icons/Nook-Cursors
PIXEL=/usr/share/icons/Nook-Pixel
# sorts after the distro's and System Settings' files (kde_settings.conf), so it wins
CONF=/etc/sddm.conf.d/zz-nook.conf
# Plasma Login reads the wallpaper from this one file; System Settings writes it too
PLM_CONF=/etc/plasmalogin.conf
COLORS=/usr/share/color-schemes/Nook.colors
RCOLORS=/usr/share/color-schemes/NookRamen.colors
PSTYLE=/usr/share/plasma/desktoptheme/nook

has_sddm() { have sddm || have sddm-greeter-qt6; }
plm_home() { have plasmalogin && getent passwd plasmalogin | cut -d: -f6; }

style=ramen
case "${1:-}" in
  --pastel) style=pastel ;;
  --ramen|"") ;;
  --remove) ;;
  *) die "unknown option $1 (--pastel, --remove)" ;;
esac

if [ "${1:-}" = --remove ]; then
  step "login screen: removing the Nook theme"
  sudo rm -rf "$THEME" "$CURSOR" "$PIXEL" "$CONF" "$COLORS" "$RCOLORS" "$PSTYLE"
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
cursor="" csize=32
if [ "$style" = ramen ]; then
  # Nook-Pixel is generated, so it needs nothing from apply.sh
  tmp=$(mktemp -d)
  python3 -I "$REPO/tile/cursors/pixelcursors.py" "$tmp/Nook-Pixel" >/dev/null
  sudo rm -rf "$PIXEL"
  sudo cp -a "$tmp/Nook-Pixel" "$PIXEL"
  sudo chmod -R a+rX "$PIXEL"
  rm -rf "$tmp"
  cursor=Nook-Pixel csize=16
else
  src_cursor="$XDG_DATA_HOME/icons/Nook-Cursors"
  if [ -d "$src_cursor/cursors" ]; then
    sudo rm -rf "$CURSOR"
    sudo cp -r "$src_cursor" "$CURSOR"
    sudo chmod -R a+rX "$CURSOR"
    cursor=Nook-Cursors
  else
    warn "no Nook cursor yet (run apply.sh first); the login screen keeps its cursor"
  fi
fi

if has_sddm; then
  step "login screen: SDDM theme + cursor"
  tmp=$(mktemp -d)
  cp -r "$REPO/theme/sddm/nook" "$tmp/nook"
  sed -i "s|^font=.*|font=$FONT|; s|^palette=.*|palette=$style|" "$tmp/nook/theme.conf"
  sudo rm -rf "$THEME"
  sudo install -d "$(dirname "$THEME")"
  sudo cp -r "$tmp/nook" "$THEME"
  sudo chmod -R a+rX "$THEME"
  rm -rf "$tmp"
  sudo install -d /etc/sddm.conf.d
  printf '%s\n' "# Written by Nook's scripts/sddm.sh; 'scripts/sddm.sh --remove' takes it out." \
    "[Theme]" "Current=nook" "Font=$FONT,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" \
    ${cursor:+"CursorTheme=$cursor" "CursorSize=$csize"} \
    | sudo tee "$CONF" >/dev/null
  ok "SDDM theme nook, $style palette (shows at the next login; preview: sddm-greeter-qt6 --test-mode --theme $THEME)"
fi

if [ -n "$home" ]; then
  step "login screen: Plasma Login, $style"
  if [ "$style" = ramen ]; then
    # Breeze's Plasma style follows the colour scheme, so NookRamen alone gives the neon look
    sudo install -Dm644 "$REPO/tile/qt/NookRamen.colors" "$RCOLORS"
    scheme=NookRamen pstyle=default
  else
    pstyle_src="$XDG_DATA_HOME/plasma/desktoptheme/nook"
    [ -d "$pstyle_src" ] || die "no Nook Plasma style yet; run scripts/apply.sh first"
    sudo install -Dm644 "$REPO/theme/color-schemes/Nook.colors" "$COLORS"
    sudo rm -rf "$PSTYLE"
    sudo cp -r "$pstyle_src" "$PSTYLE"
    sudo chmod -R a+rX "$PSTYLE"
    scheme=Nook pstyle=nook
  fi

  # The greeter is a small Plasma session of the plasmalogin user, so it reads that user's
  # kdeglobals, plasmarc and kcminputrc, like System Settings' "Apply Plasma Settings" writes
  # them. Breeze icons: Nook's icon theme lives in your home, which the greeter can't read.
  f="$FONT,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  tmp=$(mktemp -d)
  printf '%s\n' "[General]" "ColorScheme=$scheme" "font=$f" "fixed=$f" "menuFont=$f" "toolBarFont=$f" \
    "smallestReadableFont=$FONT,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" "" \
    "[Icons]" "Theme=breeze-dark" "" "[KDE]" "LookAndFeelPackage=org.kde.breezedark.desktop" "widgetStyle=Breeze" \
    > "$tmp/kdeglobals"
  printf '%s\n' "[Theme]" "name=$pstyle" > "$tmp/plasmarc"
  [ -n "$cursor" ] && printf '%s\n' "[Mouse]" "cursorTheme=$cursor" "cursorSize=$csize" > "$tmp/kcminputrc"
  for c in "$tmp"/*; do
    sudo install -D -o plasmalogin -g plasmalogin -m644 "$c" "$home/.config/${c##*/}"
  done
  # Plasma caches theme SVGs and colours; start the greeter from a clean cache
  sudo rm -rf "$home/.cache"

  # wallpaper: ramen renders its own (primary screen size), pastel takes the lock screen's
  wp=""
  if [ "$style" = ramen ]; then
    # primary screen size, as the screen shows it (rotated ones swapped); Hyprland or KScreen
    size=""
    if have hyprctl && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
      size=$(timeout 5 hyprctl monitors -j 2>/dev/null | python3 -I -c '
import json, sys
m = sorted(json.load(sys.stdin), key=lambda m: (m["x"], m["y"]))[0]
w, h = (m["height"], m["width"]) if m["transform"] % 2 else (m["width"], m["height"])
print(f"{w}x{h}")' || true)
    elif have kscreen-doctor; then
      size=$(timeout 5 kscreen-doctor -j 2>/dev/null | python3 -I -c '
import json, sys
outs = [o for o in json.load(sys.stdin)["outputs"] if o.get("enabled")]
o = sorted(outs, key=lambda o: o.get("priority", 99))[0]
s = o["size"]; r = o.get("rotation", 1)
w, h = (s["height"], s["width"]) if r in (2, 8) else (s["width"], s["height"])
print(f"{w}x{h}")' || true)
    fi
    python3 -I "$REPO/scripts/login_wallpaper.py" "$tmp/login.svg" "${size:-2560x1440}" "$FONT"
    if have rsvg-convert && rsvg-convert "$tmp/login.svg" -o "$tmp/login.png"; then
      wp="$tmp/login.png"
    fi
  else
    wp=$(kread --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image)
    wp=${wp#file://}
  fi
  if [ -n "$wp" ] && [ -f "$wp" ]; then
    sudo install -D -o plasmalogin -g plasmalogin -m644 "$wp" "$home/wallpapers/nook.png"
    sudo kwriteconfig6 --file "$PLM_CONF" --group Greeter --key WallpaperPluginId org.kde.image
    sudo kwriteconfig6 --file "$PLM_CONF" --group Greeter --group Wallpaper --group org.kde.image \
      --group General --key Image "file://$home/wallpapers/nook.png"
  else
    warn "no login wallpaper (pastel: run apply.sh first; ramen: needs rsvg-convert); it keeps its wallpaper"
    wp=""
  fi
  rm -rf "$tmp"
  ok "Plasma Login: $scheme colours, ${pstyle/default/Breeze} style, $FONT${cursor:+, $cursor}${wp:+, the $style wallpaper} (shows at the next login)"
fi
