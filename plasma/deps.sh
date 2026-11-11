#!/usr/bin/env bash
# Install the packages the Plasma rice uses. Needs sudo. Safe to re-run.
# usage: plasma/deps.sh [--packages=a,b,…]   ids from lib/packages.tsv (default: plasma's usual ones)
# (zsh, the prompt and the command-line tools are the shell part's: shared/shell/install.sh)
set -euo pipefail
source "$(dirname "$0")/../lib/lib.sh"
source "$REPO/lib/pkg.sh"

packages=$(pkg_default plasma | paste -sd' ')
for a in "$@"; do
  case "$a" in
    --packages=*) packages=$(tr ',' ' ' <<<"${a#--packages=}") ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) die "unknown option $a" ;;
  esac
done
[ -n "${packages// /}" ] || { ok "no packages picked"; exit 0; }

step "packages ($(distro_family)): $packages"
[ "$(distro_family)" = debian ] && sudo apt-get update
pkg_install $packages >/dev/null
ok "packages done"
