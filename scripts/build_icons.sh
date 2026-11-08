#!/usr/bin/env bash
# Build the Nook icon themes for a palette: the rice's icon set (BeautyLine + Breeze symbolic),
# every icon painted in ONE colour chosen by its category.
#   build_icons.sh cocoa  → ~/.local/share/icons/Nook       (+ Nook-Breeze)
#   build_icons.sh ramen  → ~/.local/share/icons/Nook-Ramen (+ Nook-Ramen-Breeze)
# Used by apply.sh (Plasma) and tile/install.sh (Qt apps under Hyprland). No sudo.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
palette=${1:-cocoa}
case "$palette" in
  cocoa) name=Nook ;;
  ramen) name=Nook-Ramen ;;
  *) die "unknown palette $palette (cocoa, ramen)" ;;
esac
step "icons: $name ($palette)"

# BeautyLine (GPL-3) is fetched at a fixed commit and repainted locally; it is not vendored here.
BL_REV=07e3736f8be38f9f48cf015d992f56f06e455002
bl_src="$NOOK_STATE/src/beautyline-$BL_REV"
if [ ! -f "$bl_src/index.theme" ]; then
  mkdir -p "$NOOK_STATE/src"
  tmp=$(mktemp -d "$NOOK_STATE/src/dl.XXXXXX")
  curl -fsSL "https://gitlab.com/garuda-linux/themes-and-settings/artwork/beautyline/-/archive/$BL_REV/beautyline-$BL_REV.tar.gz" \
    | tar -xz -C "$tmp" && mv "$tmp"/beautyline-* "$bl_src" && rmdir "$tmp" || die "could not download BeautyLine"
fi

icons="$XDG_DATA_HOME/icons"
export NOOK_PALETTE=$palette                 # icons.py / appicons.py pick their colours from it
breeze=$(ls -d /usr/share/icons/breeze-dark /usr/share/icons/breeze 2>/dev/null | head -1 || true)
if [ -n "$breeze" ]; then
  python3 "$REPO/scripts/icons.py" "$breeze" "$icons/$name-Breeze" "$name-Breeze" \
    "breeze-dark,hicolor" --keep-semantic --symbolic-only >/dev/null
fi
python3 "$REPO/scripts/icons.py" "$bl_src" "$icons/$name" "$name" "$name-Breeze,breeze-dark,Adwaita,hicolor" >/dev/null

# the rice's own icons (logo, start button, thin line chevrons, a plain office document instead of
# BeautyLine's Microsoft logo), drawn in cocoa and recoloured for other palettes
own() {  # SRC DEST
  rm -f "$2"; install -Dm644 "$1" "$2"
  [ "$palette" = cocoa ] || python3 -I "$REPO/scripts/recolor.py" --from cocoa --to "$palette" "$2" >/dev/null
}
own "$REPO/theme/icons/nook.svg" "$icons/$name/apps/scalable/nook.svg"
own "$REPO/theme/icons/nook-start.svg" "$icons/$name/apps/scalable/nook-start.svg"
for a in "$REPO"/theme/icons/arrows/*.svg; do own "$a" "$icons/$name/actions/scalable/${a##*/}"; done
for n in applications-office applications-office-symbolic; do
  own "$REPO/theme/icons/applications-office.svg" "$icons/$name/apps/scalable/$n.svg"
done

# apps the theme has no icon for, or whose .desktop names an image file (snaps): see appicons.py
python3 "$REPO/scripts/appicons.py" "$icons/$name" "$icons/$name-Breeze" >/dev/null || true
gtk-update-icon-cache -q "$icons/$name" 2>/dev/null || true
ok "$name icons (one colour per category, $palette)"
