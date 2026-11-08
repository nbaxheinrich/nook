#!/usr/bin/env bash
# Build the Nook-Ramen icon themes: the Plasma rice's icon set (BeautyLine + Breeze symbolic,
# one colour per category) in Ramen Sign's neons. Used by tile/install.sh (Qt apps in Hyprland)
# and by apply.sh --ramen (Plasma itself). No sudo. Writes ~/.local/share/icons/Nook-Ramen{,-Breeze}.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
step "icons: Nook-Ramen"
BL_REV=$(sed -n 's/^ *BL_REV=//p' "$REPO/scripts/apply.sh" | head -1)
bl_src="$NOOK_STATE/src/beautyline-$BL_REV"
if [ ! -f "$bl_src/index.theme" ]; then
  mkdir -p "$NOOK_STATE/src"
  tmp=$(mktemp -d "$NOOK_STATE/src/dl.XXXXXX")
  curl -fsSL "https://gitlab.com/garuda-linux/themes-and-settings/artwork/beautyline/-/archive/$BL_REV/beautyline-$BL_REV.tar.gz" \
    | tar -xz -C "$tmp" && mv "$tmp"/beautyline-* "$bl_src" && rmdir "$tmp" || warn "could not download BeautyLine"
fi
icons="$XDG_DATA_HOME/icons"
if [ -f "$bl_src/index.theme" ]; then
  breeze=$(ls -d /usr/share/icons/breeze-dark /usr/share/icons/breeze 2>/dev/null | head -1 || true)
  if [ -n "$breeze" ]; then
    NOOK_PALETTE=ramen python3 "$REPO/scripts/icons.py" "$breeze" "$icons/Nook-Ramen-Breeze" "Nook-Ramen-Breeze" \
      "breeze-dark,hicolor" --keep-semantic --symbolic-only >/dev/null
  fi
  NOOK_PALETTE=ramen python3 "$REPO/scripts/icons.py" "$bl_src" "$icons/Nook-Ramen" "Nook-Ramen" \
    "Nook-Ramen-Breeze,breeze-dark,Adwaita,hicolor" >/dev/null
  # the rice's own icons (logo, start button, line chevrons, office), pastels → neons
  neon() {
    sed -e 's/#f5a8c9/#ff7a5c/gI; s/#f7a59a/#ff9a3c/gI; s/#f9c49a/#ff6458/gI; s/#f2e29b/#ffc247/gI' \
        -e 's/#a6e6bf/#4fd8cf/gI; s/#94dcd6/#45c8e6/gI; s/#a3cdf5/#62a5ff/gI; s/#c4b2f5/#ffb14a/gI' \
        -e 's/#e2b5f0/#ffd98f/gI; s/#f6ece4/#f2f2f2/gI; s/#221d1a/#0d0d0d/gI' "$1" > "$2"
  }
  mkdir -p "$icons/Nook-Ramen/apps/scalable" "$icons/Nook-Ramen/actions/scalable"
  for n in nook nook-start; do neon "$REPO/theme/icons/$n.svg" "$icons/Nook-Ramen/apps/scalable/$n.svg"; done
  for a in "$REPO"/theme/icons/arrows/*.svg; do rm -f "$icons/Nook-Ramen/actions/scalable/${a##*/}"; neon "$a" "$icons/Nook-Ramen/actions/scalable/${a##*/}"; done
  for n in applications-office applications-office-symbolic; do
    rm -f "$icons/Nook-Ramen/apps/scalable/$n.svg"
    neon "$REPO/theme/icons/applications-office.svg" "$icons/Nook-Ramen/apps/scalable/$n.svg"
  done
  NOOK_PALETTE=ramen python3 "$REPO/scripts/appicons.py" "$icons/Nook-Ramen" "$icons/Nook-Ramen-Breeze" >/dev/null || true
  gtk-update-icon-cache -q "$icons/Nook-Ramen" 2>/dev/null || true
  ok "Nook-Ramen icons (one neon per category)"
else
  warn "no BeautyLine source: no Nook-Ramen icons"; exit 1
fi
