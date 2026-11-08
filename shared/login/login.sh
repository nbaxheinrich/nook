#!/usr/bin/env bash
# The login screen, for whichever login manager is installed, in a nook palette. Needs sudo:
# both run as their own user and only read system-wide files. One login screen serves every
# session (Plasma, nook-tile), so it has one look.
#   SDDM (Kubuntu, older Fedora): the nook greeter in shared/login/sddm/nook — the TIME // LOCAL
#     block clock, a launcher-style login card, the bar and the glowing NOOK sign.
#   Plasma Login (Plasma 6.6+, Fedora/Nobara): its greeter is built in and takes no themes, so it
#     gets the palette's KDE colour scheme (Breeze follows it), the font, the cursor and a
#     wallpaper with the glowing NOOK sign (shared/login/wallpaper.py).
# Everything is drawn in Ramen Sign and recoloured to the palette (lib/recolor.py).
#
# usage: login.sh [--palette=ramen|cocoa]   install, and make it the current login theme
#        login.sh --remove                  take it out again (back to the distro's look)
set -euo pipefail
source "$(dirname "$0")/../../lib/lib.sh"
HERE="$REPO/shared/login"

THEME=/usr/share/sddm/themes/nook
PIXEL=/usr/share/icons/Nook-Pixel
# sorts after the distro's and System Settings' files (kde_settings.conf), so it wins
CONF=/etc/sddm.conf.d/zz-nook.conf
# Plasma Login reads the wallpaper from this one file; System Settings writes it too
PLM_CONF=/etc/plasmalogin.conf
SCHEMES=/usr/share/color-schemes
# from nook v1, removed when found
OLD="/usr/share/icons/Nook-Cursors /usr/share/plasma/desktoptheme/nook /usr/share/sddm/themes/hackmachine
     /usr/share/icons/Hackmachine-Cursors /etc/sddm.conf.d/zz-hackmachine.conf"

has_sddm() { have sddm || have sddm-greeter-qt6; }
plm_home() { have plasmalogin && getent passwd plasmalogin | cut -d: -f6; }

palette=$(cat "$NOOK_STATE/login-palette" 2>/dev/null || echo ramen) remove=0
for a in "$@"; do
  case "$a" in
    --palette=*) palette=${a#--palette=} ;;
    --ramen) palette=ramen ;; --pastel|--cocoa) palette=cocoa ;;
    --remove) remove=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) die "unknown option $a (--palette=…, --remove)" ;;
  esac
done

if [ "$remove" = 1 ]; then
  step "login screen: removing the nook theme"
  # shellcheck disable=SC2086
  sudo rm -rf "$THEME" "$PIXEL" "$CONF" "$SCHEMES/Nook.colors" "$SCHEMES/NookRamen.colors" $OLD
  if home=$(plm_home) && [ -n "$home" ]; then
    sudo rm -rf "$home/.config/kdeglobals" "$home/.config/plasmarc" "$home/.config/kcminputrc" \
                "$home/.cache" "$home/wallpapers/nook.png"
    sudo kwriteconfig6 --file "$PLM_CONF" --group Greeter --group Wallpaper --group org.kde.image \
      --group General --key Image --delete
  fi
  ok "the login screen is back on the distro's look"
  exit 0
fi

[ -f "$REPO/palettes/$palette.json" ] || die "unknown palette $palette"
home=$(plm_home || true)
if ! has_sddm && [ -z "$home" ]; then
  warn "neither SDDM nor Plasma Login is installed; the login screen stays as it is"
  exit 0
fi
mkdir -p "$NOOK_STATE"; echo "$palette" > "$NOOK_STATE/login-palette"
FONT=$(mono_font)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
recolor() { [ "$palette" = ramen ] || python3 -I "$REPO/lib/recolor.py" --from ramen --to "$palette" "$@" >/dev/null; }
# shellcheck disable=SC2086
sudo rm -rf $OLD

# ── the cursor, shared by both: Nook-Pixel, generated ──
python3 -I "$REPO/shared/cursors/pixelcursors.py" "$tmp/Nook-Pixel" >/dev/null
sudo rm -rf "$PIXEL"; sudo cp -a "$tmp/Nook-Pixel" "$PIXEL"; sudo chmod -R a+rX "$PIXEL"

if has_sddm; then
  step "login screen: SDDM theme ($palette)"
  cp -r "$HERE/sddm/nook" "$tmp/nook"
  sed -i "s|^font=.*|font=$FONT|; s|^palette=.*|palette=ramen|" "$tmp/nook/theme.conf"
  recolor "$tmp/nook"
  sudo rm -rf "$THEME"; sudo install -d "$(dirname "$THEME")"
  sudo cp -r "$tmp/nook" "$THEME"; sudo chmod -R a+rX "$THEME"
  sudo install -d /etc/sddm.conf.d
  printf '%s\n' "# Written by nook (shared/login/login.sh); 'login.sh --remove' takes it out." \
    "[Theme]" "Current=nook" "Font=$FONT,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" \
    "CursorTheme=Nook-Pixel" "CursorSize=16" | sudo tee "$CONF" >/dev/null
  ok "SDDM theme nook in $palette (preview: sddm-greeter-qt6 --test-mode --theme $THEME)"
fi

if [ -n "$home" ]; then
  step "login screen: Plasma Login ($palette)"
  scheme=$([ "$palette" = ramen ] && echo NookRamen || echo Nook)
  sudo install -Dm644 "$REPO/palettes/kde/$scheme.colors" "$SCHEMES/$scheme.colors"

  # The greeter is a small Plasma session of the plasmalogin user, so it reads that user's
  # kdeglobals, plasmarc and kcminputrc, like System Settings' "Apply Plasma Settings" writes
  # them. Breeze's Plasma style follows the colour scheme; Breeze icons, since the nook icon
  # themes live in your home, which the greeter can't read.
  f="$FONT,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  printf '%s\n' "[General]" "ColorScheme=$scheme" "font=$f" "fixed=$f" "menuFont=$f" "toolBarFont=$f" \
    "smallestReadableFont=$FONT,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1" "" \
    "[Icons]" "Theme=breeze-dark" "" "[KDE]" "LookAndFeelPackage=org.kde.breezedark.desktop" "widgetStyle=Breeze" \
    > "$tmp/kdeglobals"
  printf '%s\n' "[Theme]" "name=default" > "$tmp/plasmarc"
  printf '%s\n' "[Mouse]" "cursorTheme=Nook-Pixel" "cursorSize=16" > "$tmp/kcminputrc"
  for c in kdeglobals plasmarc kcminputrc; do
    sudo install -D -o plasmalogin -g plasmalogin -m644 "$tmp/$c" "$home/.config/$c"
  done
  sudo rm -rf "$home/.cache"   # Plasma caches theme SVGs and colours: start the greeter clean

  # wallpaper at the primary screen's size (rotated screens swapped); Hyprland or KScreen
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
  python3 -I "$HERE/wallpaper.py" "$tmp/login.svg" "${size:-2560x1440}" "$FONT"
  recolor "$tmp/login.svg"
  if have rsvg-convert && rsvg-convert "$tmp/login.svg" -o "$tmp/login.png"; then
    sudo install -D -o plasmalogin -g plasmalogin -m644 "$tmp/login.png" "$home/wallpapers/nook.png"
    sudo kwriteconfig6 --file "$PLM_CONF" --group Greeter --key WallpaperPluginId org.kde.image
    sudo kwriteconfig6 --file "$PLM_CONF" --group Greeter --group Wallpaper --group org.kde.image \
      --group General --key Image "file://$home/wallpapers/nook.png"
    wp=1
  else
    warn "no rsvg-convert: the login screen keeps its wallpaper"; wp=0
  fi
  ok "Plasma Login: $scheme colours, Breeze, $FONT, Nook-Pixel$([ "$wp" = 1 ] && echo ", the nook wallpaper") (shows at the next login)"
fi
