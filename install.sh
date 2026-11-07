#!/usr/bin/env bash
# Nook, everything in one go:
#   1. Plasma rice   packages (scripts/deps.sh, sudo) + theme for the current user (scripts/apply.sh)
#   2. nook-tile     Hyprland + Quickshell session in Ramen Sign (tile/install.sh, packages need sudo)
#   3. login screen  SDDM or Plasma Login, Ramen Sign for both sessions (scripts/sddm.sh, sudo)
#
# usage: ./install.sh [options] [apply.sh options: --no-panel --no-widgets --no-shell
#                                --no-shortcuts --no-icons --no-cursor]
#   --no-deps     nothing that needs sudo: no packages, no login screen; configs and themes only
#   --no-plasma   skip the Plasma rice (skipped by itself when Plasma isn't installed)
#   --no-tile     skip nook-tile (Hyprland)
#   --no-sddm     leave the login screen alone (also: --no-login)
#   --pastel      login screen in the cocoa Plasma look instead of Ramen Sign
#
# Each part can also run alone: scripts/deps.sh, scripts/apply.sh, tile/install.sh, scripts/sddm.sh.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/scripts/lib.sh"

deps=1 plasma=1 tile=1 sddm=1 login_style="" args=()
for a in "$@"; do
  case "$a" in
    --no-deps)            deps=0 ;;
    --no-plasma)          plasma=0 ;;
    --no-tile)            tile=0 ;;
    --no-sddm|--no-login) sddm=0 ;;
    --pastel)             login_style=--pastel ;;
    -h|--help)            sed -n '2,15p' "$0"; exit 0 ;;
    *)                    args+=("$a") ;;
  esac
done

if [ "$plasma" = 1 ] && ! have plasmashell; then
  warn "Plasma is not installed: skipping the Plasma rice (nook-tile and the login screen still go in)"
  plasma=0
fi
if [ "$login_style" = --pastel ] && [ "$plasma" = 0 ]; then
  die "--pastel takes the Plasma rice's colours and wallpaper; drop --no-plasma or --pastel"
fi

failed=()

# ── 1. Plasma rice ──
if [ "$plasma" = 1 ]; then
  [ "$deps" = 1 ] && "$here/scripts/deps.sh"
  "$here/scripts/apply.sh" "${args[@]}"
fi

# ── 2. nook-tile: its own distro checks (Fedora/Nobara 44+, Ubuntu 26.04+); a failure here
#      doesn't undo the Plasma part, it's reported at the end ──
if [ "$tile" = 1 ]; then
  tile_args=(--no-login)                      # the login screen comes last, below
  [ "$deps" = 0 ] && tile_args+=(--no-deps)
  "$here/tile/install.sh" "${tile_args[@]}" || failed+=("nook-tile (tile/install.sh)")
fi

# ── 3. login screen, last: Ramen needs nothing else, pastel needs the Plasma rice ──
if [ "$deps" = 1 ] && [ "$sddm" = 1 ]; then
  "$here/scripts/sddm.sh" ${login_style:+"$login_style"} || failed+=("login screen (scripts/sddm.sh)")
fi

echo
if [ ${#failed[@]} -gt 0 ]; then
  for f in "${failed[@]}"; do warn "did not finish: $f; its messages are above, rerun it alone"; done
  exit 1
fi
step "nook is in. Log out; on the login screen pick Plasma or Hyprland (it remembers your choice)."
