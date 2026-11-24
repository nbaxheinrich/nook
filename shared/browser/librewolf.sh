#!/usr/bin/env bash
# Dress LibreWolf in the nook look: shared/browser/librewolf/ (drawn in haver) recoloured to a palette
# and put into LibreWolf's default profile (Flatpak or native).
# usage: shared/browser/librewolf.sh [--palette=NAME] [--remove]
#
#   chrome/userChrome.css, userContent.css   the window and the internal pages (new tab, settings)
#   chrome/nook-keys.html                    the keys cheatsheet, the start page (Alt+Home)
#   user.js                                  the prefs, between "// >>> nook" and "// <<< nook";
#                                            the rest of your user.js stays
# LibreWolf reads all of it at startup, so restart it afterwards. --remove takes both out again;
# prefs it already copied into prefs.js stay until you change them in about:config.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/lib.sh"

SRC="$REPO/shared/browser/librewolf"
FROM=haver
palette=$FROM remove=0
for a in "$@"; do
  case "$a" in
    --palette=*) palette=${a#*=} ;;
    --remove) remove=1 ;;
    *) die "unknown option $a" ;;
  esac
done
[ -f "$REPO/palettes/$palette.json" ] || die "unknown palette $palette"

# the profile LibreWolf starts with: its install's Default=, else the first one listed
profile=""
for base in "$HOME/.var/app/io.gitlab.librewolf-community/config/librewolf/librewolf" \
            "$HOME/.var/app/io.gitlab.librewolf-community/.librewolf" \
            "$XDG_CONFIG_HOME/librewolf/librewolf" "$HOME/.librewolf"; do
  [ -f "$base/profiles.ini" ] || continue
  rel=$(awk -F= '/^\[Install/{f=1} f&&/^Default=/{print $2; exit}' "$base/profiles.ini")
  [ -n "$rel" ] || rel=$(awk -F= '/^Path=/{print $2; exit}' "$base/profiles.ini")
  [ -n "$rel" ] && profile="$base/$rel" && break
done
[ -n "$profile" ] || die "no LibreWolf profile yet: start LibreWolf once, close it, run this again"

# user.js without nook's block
strip_block() { [ -f "$1" ] && sed '/^\/\/ >>> nook/,/^\/\/ <<< nook/d' "$1" || true; }

if [ "$remove" = 1 ]; then
  step "LibreWolf · nook look off"
  for f in userChrome.css userContent.css; do
    grep -qs '^/\* nook' "$profile/chrome/$f" && rm "$profile/chrome/$f"
  done
  rm -f "$profile/chrome/nook-keys.html"
  warn "the start page pref stays in prefs.js: Settings → Home → Homepage to pick another"
  rest=$(strip_block "$profile/user.js")
  if [ -n "${rest//[$'\n ']/}" ]; then printf '%s\n' "$rest" > "$profile/user.js"; else rm -f "$profile/user.js"; fi
  rm -f "$NOOK_STATE/librewolf-palette"
  ok "removed from ${profile/#$HOME/\~}; restart LibreWolf"
  exit 0
fi

step "LibreWolf · nook look in $palette"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r "$SRC/." "$tmp/"
[ "$palette" = "$FROM" ] || python3 -I "$REPO/lib/recolor.py" --from "$FROM" --to "$palette" "$tmp" >/dev/null

mkdir -p "$profile/chrome"
for f in userChrome.css userContent.css; do
  if [ -f "$profile/chrome/$f" ] && ! grep -qs '^/\* nook' "$profile/chrome/$f"; then
    cp "$profile/chrome/$f" "$profile/chrome/$f.before-nook"
    warn "your own $f is kept as $f.before-nook"
  fi
  cp "$tmp/chrome/$f" "$profile/chrome/$f"
done
cp "$tmp/keys.html" "$profile/chrome/nook-keys.html"
{
  strip_block "$profile/user.js"
  echo "// >>> nook"
  command cat "$tmp/user.js"
  echo "// the keys cheatsheet is the start page (new windows, Alt+Home)"
  echo "user_pref(\"browser.startup.homepage\", \"file://$profile/chrome/nook-keys.html\");"
  echo 'user_pref("browser.startup.page", 1);'
  echo "// <<< nook"
} > "$tmp/user.new"
mv "$tmp/user.new" "$profile/user.js"

mkdir -p "$NOOK_STATE"
echo "$palette" > "$NOOK_STATE/librewolf-palette"
ok "in ${profile/#$HOME/\~}; restart LibreWolf to see it"
