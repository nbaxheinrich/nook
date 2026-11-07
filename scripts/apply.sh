#!/usr/bin/env bash
# Apply Nook to the current user's Plasma 6 session. No sudo needed.
# Everything it overwrites is copied to ~/.local/state/nook/backup-<time>/ first;
# uninstall.sh puts the oldest backup (your pre-Nook setup) back.
#
# usage: apply.sh [--no-panel] [--no-shell] [--no-shortcuts] [--no-icons] [--no-cursor] [--no-widgets]
set -euo pipefail
source "$(dirname "$0")/lib.sh"

DO_PANEL=1 DO_SHELL=1 DO_KEYS=1 DO_ICONS=1 DO_CURSOR=1 DO_WIDGETS=1
for a in "$@"; do
  case "$a" in
    --no-panel) DO_PANEL=0 ;; --no-shell) DO_SHELL=0 ;;
    --no-shortcuts) DO_KEYS=0 ;; --no-icons) DO_ICONS=0 ;; --no-cursor) DO_CURSOR=0 ;;
    --no-widgets) DO_WIDGETS=0 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) die "unknown option $a" ;;
  esac
done

have kwriteconfig6 || die "this needs KDE Plasma 6 (kwriteconfig6 not found)"
pgrep -x plasmashell >/dev/null || die "plasmashell is not running; log into a Plasma session first"

CFG=$XDG_CONFIG_HOME
BIN="$HOME/.local/bin"
FONT=$(mono_font)
ZSHBIN=$(command -v zsh || true)
SCREENS=$(screens)
[ -n "$SCREENS" ] || die "could not read the screen layout from plasmashell"
# installs from before the rename (Hackmachine) and the old hack menu get cleaned up first
source "$REPO/scripts/migrate.sh"
BACKUP_DIR="$NOOK_STATE/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR" "$NOOK_SHARE" "$BIN"

# ── 0 · backup ──────────────────────────────────────────────────────────────
step "backing up current settings → ${BACKUP_DIR/#$HOME/\~}"
backup "$CFG/kdeglobals" "$CFG/kwinrc" "$CFG/kwinrulesrc" "$CFG/plasmarc" \
       "$CFG/konsolerc" "$CFG/kscreenlockerrc" "$CFG/plasma-org.kde.plasma.desktop-appletsrc" \
       "$CFG/plasmashellrc" "$CFG/kglobalshortcutsrc" "$CFG/fastfetch/config.jsonc" \
       "$CFG/cava/config" "$CFG/btop/btop.conf" "$CFG/alacritty/alacritty.toml" "$HOME/.bashrc" \
       "$CFG/kcminputrc" "$CFG/bat/config" "$CFG/ripgrep/config"
# Names the uninstaller re-applies through Plasma's own tools.
{
  printf 'colorscheme=%q\n' "$(kread --file kdeglobals --group General --key ColorScheme)"
  printf 'icons=%q\n' "$(kread --file kdeglobals --group Icons --key Theme)"
  printf 'desktoptheme=%q\n' "$(kread --file plasmarc --group Theme --key name)"
  printf 'cursor=%q\n' "$(kread --file kcminputrc --group Mouse --key cursorTheme)"
  printf 'cursorsize=%q\n' "$(kread --file kcminputrc --group Mouse --key cursorSize)"
  printf 'lookandfeel=%q\n' "$(kread --file kdeglobals --group KDE --key LookAndFeelPackage)"
} > "$BACKUP_DIR/previous.env"
ok "backup done"

# ── 1 · files ───────────────────────────────────────────────────────────────
step "installing theme files"
install -Dm644 "$REPO/theme/color-schemes/Nook.colors" "$XDG_DATA_HOME/color-schemes/Nook.colors"
install -Dm644 "$REPO/theme/konsole/Nook.colorscheme" "$XDG_DATA_HOME/konsole/Nook.colorscheme"
install -Dm644 "$REPO/theme/icons/nook.svg" "$XDG_DATA_HOME/icons/hicolor/scalable/apps/nook.svg"
install -Dm644 "$REPO/theme/icons/nook-start.svg" "$XDG_DATA_HOME/icons/hicolor/scalable/apps/nook-start.svg"
install -Dm755 "$REPO/bin/nook-keys" "$BIN/nook-keys"
install -Dm755 "$REPO/bin/nook-tray" "$BIN/nook-tray"
install -Dm755 "$REPO/bin/nook-brave" "$BIN/nook-brave"
rm -rf "$NOOK_SHARE/brave-theme"; cp -r "$REPO/theme/brave/nook" "$NOOK_SHARE/brave-theme"
install -Dm644 "$REPO/scripts/shortcuts.py" "$NOOK_SHARE/shortcuts.py"
install -Dm644 "$REPO/config/shortcuts.conf" "$NOOK_SHARE/shortcuts.conf"
install -Dm644 "$REPO/theme/shell/bashrc" "$NOOK_SHARE/bashrc"
install -Dm644 "$REPO/theme/fastfetch/config.jsonc" "$CFG/fastfetch/config.jsonc"
install -Dm644 "$REPO/theme/fastfetch/nook-logo.txt" "$CFG/fastfetch/nook-logo.txt"
rm -f "$CFG/fastfetch/candy-logo.txt"   # the logo before the mug
install -Dm644 "$REPO/theme/cava/config" "$CFG/cava/config"
install -Dm644 "$REPO/theme/btop/nook.theme" "$CFG/btop/themes/nook.theme"
if [ -f "$CFG/btop/btop.conf" ]; then
  sed -i -E 's|^color_theme *=.*|color_theme = "nook"|' "$CFG/btop/btop.conf"
else
  printf 'color_theme = "nook"\ntheme_background = True\n' > "$CFG/btop/btop.conf"
fi
gtk-update-icon-cache -q "$XDG_DATA_HOME/icons/hicolor" 2>/dev/null || true
# Nook widgets (the panel clock needs them before the taskbar is built)
for pl in apps clock sys; do
  dst="$XDG_DATA_HOME/plasma/plasmoids/org.nook.$pl"
  rm -rf "$dst"; mkdir -p "$(dirname "$dst")"
  cp -r "$REPO/theme/plasmoids/org.nook.$pl" "$dst"
done

cat > "$XDG_DATA_HOME/konsole/Nook.profile" <<EOF
[Appearance]
ColorScheme=Nook
Font=$FONT,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1

[Cursor Options]
CursorShape=0

[General]
${ZSHBIN:+Command=$ZSHBIN}
Environment=TERM=xterm-256color,COLORTERM=truecolor,NOOK=1
Name=Nook
Parent=FALLBACK/
TerminalCenter=true
TerminalMargin=12

[Scrolling]
ScrollBarPosition=2
EOF
kwrite --file konsolerc --group "Desktop Entry" --key DefaultProfile Nook.profile
# No toolbars in Konsole: just the window decoration and the terminal. The layout files are compiled
# into Konsole, so fetch the ones for the installed version from KDE and drop their <ToolBar>s.
# (Menus stay reachable: Ctrl+Shift+M or right-click.)
kver=$(konsole --version 2>/dev/null | awk '{print $2}')
if [ -n "$kver" ]; then
  kui="$XDG_DATA_HOME/kxmlgui5/konsole"; mkdir -p "$kui"
  for rc in konsoleui.rc sessionui.rc; do
    if curl -fsSL "https://invent.kde.org/utilities/konsole/-/raw/v$kver/desktop/$rc" -o "$kui/$rc.tmp"; then
      python3 - "$kui/$rc.tmp" <<'NOTOOLBAR'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"\s*<ToolBar\b.*?</ToolBar>", "", s, flags=re.S)
open(p, "w").write(s)
NOTOOLBAR
      mv "$kui/$rc.tmp" "$kui/$rc"
    else
      rm -f "$kui/$rc.tmp"; warn "could not fetch Konsole $kver's $rc; its toolbar stays"
    fi
  done
fi
kwrite --file konsolerc --group KonsoleWindow --key ShowMenuBarByDefault false
ok "konsole profile (the fallback terminal), fastfetch, btop, cava, nook-keys"

# Alacritty is the default terminal; Konsole stays on Ctrl+Alt+T for when something breaks.
install -Dm644 "$REPO/theme/alacritty/nook.toml" "$CFG/alacritty/nook.toml"
cat > "$CFG/alacritty/alacritty.toml" <<EOF
# Written by Nook's apply.sh (re-running it overwrites this file).
[general]
import = ["$CFG/alacritty/nook.toml"]

[font]
normal = { family = "$FONT" }
size = 11
EOF
[ -n "$ZSHBIN" ] && printf '\n[terminal.shell]\nprogram = "%s"\n' "$ZSHBIN" >> "$CFG/alacritty/alacritty.toml"
kwrite --file kdeglobals --group General --key TerminalApplication alacritty
# its .desktop id depends on how it was installed (distro package, upstream, snap)
for id in Alacritty com.alacritty.Alacritty alacritty_alacritty; do
  for d in "$XDG_DATA_HOME/applications" /var/lib/snapd/desktop/applications /usr/local/share/applications /usr/share/applications; do
    [ -f "$d/$id.desktop" ] && { kwrite --file kdeglobals --group General --key TerminalService "$id.desktop"; break 2; }
  done
done
ok "alacritty is the default terminal (Konsole still on Ctrl+Alt+T)"

# Zed: native (~/.config/zed) and Flatpak (its own config dir) each get the theme + font.
zed_dirs=()
{ [ -d "$CFG/zed" ] || have zed || have zeditor; } && zed_dirs+=("$CFG/zed")
zflat="$HOME/.var/app/dev.zed.Zed/config/zed"
{ [ -d "$zflat" ] || flatpak info dev.zed.Zed >/dev/null 2>&1; } && zed_dirs+=("$zflat")
for zd in "${zed_dirs[@]}"; do
  backup "$zd/settings.json"
  # remember settings files we create, so uninstall deletes them instead of restoring ours
  [ -e "$zd/settings.json" ] || echo "$zd/settings.json" >> "$NOOK_STATE/zed-created"
  install -Dm644 "$REPO/theme/zed/nook.json" "$zd/themes/nook.json"
  python3 "$REPO/scripts/zed.py" "$zd/settings.json" "$FONT"
  ok "zed theme Nook + $FONT → ${zd/#$HOME/\~}"
done

if [ "$DO_SHELL" = 1 ]; then
  hook='[ -f "$HOME/.local/share/nook/bashrc" ] && . "$HOME/.local/share/nook/bashrc"  # nook'
  grep -qF '# nook' "$HOME/.bashrc" 2>/dev/null || printf '\n%s\n' "$hook" >> "$HOME/.bashrc"
  ok "bash prompt + fastfetch (only inside Alacritty and the Nook Konsole)"
fi

# ── zsh: oh-my-zsh + nook theme (Konsole's Nook profile runs zsh) ──
if [ "$DO_SHELL" = 1 ]; then
  if [ -n "$ZSHBIN" ]; then
    omz="$HOME/.oh-my-zsh"
    if [ ! -d "$omz" ]; then
      git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$omz" && touch "$NOOK_STATE/omz-installed-by-nook"
    fi
    for repo in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting; do
      dst="$omz/custom/plugins/${repo#*/}"
      [ -d "$dst" ] || git clone -q --depth 1 "https://github.com/$repo.git" "$dst"
    done
    install -Dm644 "$REPO/theme/shell/nook.zsh-theme" "$omz/custom/themes/nook.zsh-theme"
    install -Dm644 "$REPO/theme/shell/zshrc" "$NOOK_SHARE/zshrc"
    backup "$HOME/.zshrc"
    touch "$HOME/.zshrc"
    hook='[ -f "$HOME/.local/share/nook/zshrc" ] && . "$HOME/.local/share/nook/zshrc"  # nook'
    if grep -v '# nook$' "$HOME/.zshrc" | grep -q 'oh-my-zsh.sh'; then
      # you already load oh-my-zsh yourself: switch its theme, and add the rest (colours, tools,
      # fastfetch) after it
      sed -i -E 's/^ZSH_THEME=.*/ZSH_THEME="nook"/' "$HOME/.zshrc"
      grep -qF '# nook' "$HOME/.zshrc" || printf '\n%s\n' "$hook" >> "$HOME/.zshrc"
    elif ! grep -qF '# nook' "$HOME/.zshrc"; then
      printf '%s\n\n%s' "$hook" \
        "$(cat "$HOME/.zshrc")" > "$HOME/.zshrc.hm" && mv "$HOME/.zshrc.hm" "$HOME/.zshrc"
    fi
    ok "oh-my-zsh + nook theme; Alacritty and Konsole's Nook profile start zsh"
  else
    warn "zsh is not installed yet: run ./install.sh (with packages) for the oh-my-zsh setup"
  fi
fi

# ── command-line tools: zoxide, eza, bat, delta, fd, ripgrep in the palette ──
if [ "$DO_SHELL" = 1 ]; then
  install -Dm644 "$REPO/theme/shell/tools.sh" "$NOOK_SHARE/tools.sh"
  install -Dm644 "$REPO/theme/ripgrep/config" "$CFG/ripgrep/config"
  # bat (and delta, which reads bat's themes) gets the Nook syntax theme
  install -Dm644 "$REPO/theme/bat/Nook.tmTheme" "$CFG/bat/themes/Nook.tmTheme"
  printf '%s\n' '# Written by Nook'"'"'s apply.sh' '--theme="Nook"' '--style="numbers,changes,header"' \
    '--italic-text=always' > "$CFG/bat/config"
  batbin=$(command -v bat || command -v batcat || true)
  [ -n "$batbin" ] && "$batbin" cache --build >/dev/null
  # git: colours and aliases always, delta as the pager only when it is installed
  install -Dm644 "$REPO/theme/git/gitconfig" "$NOOK_SHARE/gitconfig"
  install -Dm644 "$REPO/theme/git/delta.gitconfig" "$NOOK_SHARE/delta.gitconfig"
  for inc in gitconfig delta.gitconfig; do
    git config --global --fixed-value --unset-all include.path "$NOOK_SHARE/$inc" 2>/dev/null || true
  done
  git config --global --add include.path "$NOOK_SHARE/gitconfig"
  have delta && git config --global --add include.path "$NOOK_SHARE/delta.gitconfig"
  tools=""
  for t in zoxide eza bat delta fd rg; do
    have "$t" || { [ $t = bat ] && have batcat; } || { [ $t = fd ] && have fdfind; } || tools+=" $t"
  done
  ok "cd → zoxide, ls → eza, cat → bat, git → delta, fzf/rg colours${tools:+ (not installed:$tools; run ./install.sh)}"
fi

# ── 2 · colours, plasma style, icons ─────────────────────────────────────────
step "colours + plasma style"
plasma-apply-colorscheme Nook >/dev/null 2>&1 || plasma-apply-colorscheme Nook
kwrite --file kdeglobals --group KDE --key widgetStyle Breeze
pstyle="$XDG_DATA_HOME/plasma/desktoptheme/nook"
rm -rf "$pstyle"
python3 "$REPO/scripts/themegen.py" plasma "$pstyle"
# Plasma caches theme SVGs; drop the cache so a regenerated style shows up at once.
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/plasma-svgelements* "${XDG_CACHE_HOME:-$HOME/.cache}"/plasma_theme_nook*
plasma-apply-desktoptheme nook >/dev/null 2>&1 || plasma-apply-desktoptheme nook
ok "Nook colours + Plasma style (cocoa panel, lavender focus bars, rounded popups)"

# The global theme holds the logout / restart / shut-down screen; what it leaves out (splash,
# lock screen) comes from Breeze. Only its name is set: plasma-apply-lookandfeel would also
# reset the panel layout.
lnf="$XDG_DATA_HOME/plasma/look-and-feel/org.nook.desktop"
rm -rf "$lnf"; mkdir -p "$(dirname "$lnf")"
cp -r "$REPO/theme/look-and-feel/org.nook.desktop" "$lnf"
kwrite --file kdeglobals --group KDE --key LookAndFeelPackage org.nook.desktop
ok "global theme Nook (logout screen; preview: /usr/libexec/ksmserver-logout-greeter --windowed)"

if [ "$DO_ICONS" = 1 ]; then
  step "icons: BeautyLine + Breeze symbolic, one pastel per category"
  # BeautyLine (GPL-3) is fetched at a fixed commit and repainted locally; it is not vendored here.
  BL_REV=07e3736f8be38f9f48cf015d992f56f06e455002
  bl_src="$NOOK_STATE/src/beautyline-$BL_REV"
  if [ ! -f "$bl_src/index.theme" ]; then
    mkdir -p "$NOOK_STATE/src"
    tmp=$(mktemp -d "$NOOK_STATE/src/dl.XXXXXX")
    curl -fsSL "https://gitlab.com/garuda-linux/themes-and-settings/artwork/beautyline/-/archive/$BL_REV/beautyline-$BL_REV.tar.gz" \
      | tar -xz -C "$tmp" || die "could not download BeautyLine"
    mv "$tmp"/beautyline-* "$bl_src" && rmdir "$tmp"
  fi
  breeze=$(ls -d /usr/share/icons/breeze-dark /usr/share/icons/breeze 2>/dev/null | head -1)
  icons="$XDG_DATA_HOME/icons"
  if [ -n "$breeze" ]; then
    python3 "$REPO/scripts/icons.py" "$breeze" "$icons/Nook-Breeze" "Nook-Breeze" \
      "breeze-dark,hicolor" --keep-semantic --symbolic-only
  fi
  python3 "$REPO/scripts/icons.py" "$bl_src" "$icons/Nook" "Nook" \
    "Nook-Breeze,breeze-dark,hicolor"
  install -Dm644 "$REPO/theme/icons/nook.svg" "$icons/Nook/apps/scalable/nook.svg"
  install -Dm644 "$REPO/theme/icons/nook-start.svg" "$icons/Nook/apps/scalable/nook-start.svg"
  # thin line chevrons instead of BeautyLine's filled ones (the tray's ^ among them)
  for a in "$REPO"/theme/icons/arrows/*.svg; do install -Dm644 "$a" "$icons/Nook/actions/scalable/${a##*/}"; done
  # a plain document for the Office category instead of BeautyLine's Microsoft Office logo
  # (these are symlinks into other icons, so unlink before writing)
  for n in applications-office applications-office-symbolic; do
    rm -f "$icons/Nook/apps/scalable/$n.svg"
    install -m644 "$REPO/theme/icons/applications-office.svg" "$icons/Nook/apps/scalable/$n.svg"
  done
  # apps the theme has no icon for, or whose .desktop names an image file (snaps): see appicons.py
  python3 "$REPO/scripts/appicons.py" "$icons/Nook" "$icons/Nook-Breeze"
  kbuildsycoca6 >/dev/null 2>&1 || true
  changeicons=$(ls /usr/libexec/plasma-changeicons /usr/lib/*/libexec/plasma-changeicons \
                   /usr/lib/libexec/plasma-changeicons 2>/dev/null | head -1 || true)
  if [ -n "$changeicons" ]; then "$changeicons" Nook >/dev/null 2>&1 || true
  else kwrite --file kdeglobals --group Icons --key Theme Nook; fi
  # tell running apps (KWin's title bars too) to reload icons now instead of at the next login
  for g in 0 1 2 3 4 5; do
    dbus-send --session --type=signal /KIconLoader org.kde.KIconLoader.iconChanged int32:$g 2>/dev/null || true
  done
  ok "icon theme Nook"
fi

if [ "$DO_CURSOR" = 1 ]; then
  step "cursor: Posy's cursors in cocoa and cream"
  # Posy's Cursor (Michiel de Boer; Linux port by simtrami, CC BY-NC 4.0) is fetched at a fixed
  # commit and recoloured locally; it is not vendored here.
  POSY_REV=ffef15950490af620fd0f70cc98847880f63d96e
  posy_src="$NOOK_STATE/src/posy-$POSY_REV"
  if [ ! -d "$posy_src/Posy_Cursor/cursors" ]; then
    mkdir -p "$NOOK_STATE/src"
    tmp=$(mktemp -d "$NOOK_STATE/src/dl.XXXXXX")
    curl -fsSL "https://codeload.github.com/simtrami/posy-improved-cursor-linux/tar.gz/$POSY_REV" \
      | tar -xz -C "$tmp" || die "could not download Posy's cursors"
    rm -rf "$posy_src"; mv "$tmp"/posy-improved-cursor-linux-* "$posy_src" && rmdir "$tmp"
  fi
  python3 "$REPO/scripts/cursors.py" "$posy_src/Posy_Cursor" "$XDG_DATA_HOME/icons/Nook-Cursors" "Nook-Cursors" >/dev/null
  # 32 is Posy's own base size; the theme also carries 48, 64, 96 and 128 for scaled screens
  plasma-apply-cursortheme --size 32 Nook-Cursors >/dev/null 2>&1 || {
    kwrite --file kcminputrc --group Mouse --key cursorTheme Nook-Cursors
    kwrite --file kcminputrc --group Mouse --key cursorSize 32
  }
  ok "cursor theme Nook-Cursors (the login screen gets it from scripts/sddm.sh)"
fi

# ── 3 · fonts: monospace everywhere ──────────────────────────────────────────
step "fonts → $FONT"
f() { echo "$FONT,$1,-1,5,$2,0,0,0,0,0,0,0,0,0,0,1"; }
kwrite --file kdeglobals --group General --key font "$(f 10 400)"
kwrite --file kdeglobals --group General --key fixed "$(f 10 400)"
kwrite --file kdeglobals --group General --key menuFont "$(f 10 400)"
kwrite --file kdeglobals --group General --key toolBarFont "$(f 10 400)"
kwrite --file kdeglobals --group General --key smallestReadableFont "$(f 8 400)"
kwriteconfig6 --notify --file kdeglobals --group WM --key activeFont "$(f 10 700)" 2>/dev/null \
  || kwrite --file kdeglobals --group WM --key activeFont "$(f 10 700)"
ok "fonts set"

# ── 4 · windows ─────────────────────────────────────────────────────────────
step "window decoration + rules"
deco="$XDG_DATA_HOME/aurorae/themes/Nook"
rm -rf "$deco"
python3 "$REPO/scripts/themegen.py" aurorae "$deco"
kwrite --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
kwrite --file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__Nook
kwrite --file kwinrc --group org.kde.kdecoration2 --key BorderSize Normal
kwrite --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft "M"
kwrite --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight "IAX"
kwrite --file kwinrc --group Plugins --key blurEnabled true

# Tiling: Krohnkite (MIT), a dynamic tiler as a KWin script, fetched at a fixed release.
# Every new window is tiled; dialogs and plasmashell float. Keys: section 7.
KK_REV=0.9.9.2 KK_SHA=42f7f66531d366c74b5fc860381da3517ccb4cdccd1f80c122fcab6e9a8fcf7e
kk_dir="$XDG_DATA_HOME/kwin/scripts/krohnkite"
if ! grep -q "\"Version\": \"$KK_REV\"" "$kk_dir/metadata.json" 2>/dev/null; then
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/krohnkite.kwinscript" \
    "https://github.com/anametologin/krohnkite/releases/download/$KK_REV/krohnkite-${KK_REV}_1d7fd74.kwinscript" \
    || die "could not download Krohnkite"
  echo "$KK_SHA  $tmp/krohnkite.kwinscript" | sha256sum -c --quiet - || die "Krohnkite checksum mismatch"
  python3 -I -m zipfile -e "$tmp/krohnkite.kwinscript" "$tmp/x"
  rm -rf "$kk_dir"; mv "$tmp/x" "$kk_dir"; rm -rf "$tmp"
fi
# portrait screens start with a top/bottom split instead of side by side
python3 "$REPO/scripts/krohnkite.py" "$kk_dir/contents/code/script.js" || warn "portrait screens keep the side-by-side split"
K=Script-krohnkite
for side in Left Right Top Bottom Between; do
  kwrite --file kwinrc --group $K --key screenGap$side 8
done
kwrite --file kwinrc --group $K --key notificationDuration 600
kwrite --file kwinrc --group Plugins --key krohnkiteEnabled true
# arrow keys that cross to the next screen at the edge, see theme/kwin/nook-tiling
script_dir="$XDG_DATA_HOME/kwin/scripts/nook-tiling"
rm -rf "$script_dir"; mkdir -p "$(dirname "$script_dir")"
cp -r "$REPO/theme/kwin/nook-tiling" "$script_dir"
kwrite --file kwinrc --group Plugins --key nook-tilingEnabled true
# Some apps' windows name another app id than their .desktop file (the Discord flatpak says
# "discord"), so the taskbar can't match them to their pin and starts a second copy on click.
# One rule per pinned app gives its windows the right .desktop file; other rules are kept.
rules=$(kread --file kwinrulesrc --group General --key rules | tr ',' '\n' | { grep -v '^nook-app-' || true; })
if [ -f "$CFG/kwinrulesrc" ]; then
  awk '/^\[/ { skip = /^\[nook-app-/ } !skip' "$CFG/kwinrulesrc" > "$CFG/kwinrulesrc.tmp"
  mv "$CFG/kwinrulesrc.tmp" "$CFG/kwinrulesrc"
fi
while IFS=$'\t' read -r wmclass id; do
  [ -n "$id" ] || continue
  g="nook-app-$id"
  kwrite --file kwinrulesrc --group "$g" --key Description "Nook: $wmclass windows belong to $id"
  kwrite --file kwinrulesrc --group "$g" --key wmclass "$wmclass"
  kwrite --file kwinrulesrc --group "$g" --key wmclassmatch 1
  kwrite --file kwinrulesrc --group "$g" --key desktopfile "$id"
  kwrite --file kwinrulesrc --group "$g" --key desktopfilerule 2
  rules+=$'\n'"$g"
done < <(python3 "$REPO/scripts/apps.py" "$REPO/config/apps.conf" wmclass 2>/dev/null)
rules=$(grep . <<<"$rules" | paste -sd, - || true)
kwrite --file kwinrulesrc --group General --key rules "$rules"
kwrite --file kwinrulesrc --group General --key count "$(awk -F, '{print NF}' <<<"$rules")"
qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1 \
  || gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure >/dev/null
ok "Nook decoration: lavender focus ring, [_] [□] [x], Krohnkite tiling"

# plasmashell only reads fonts and the icon theme at start-up, so restart it once, before the
# wallpaper, taskbar and widgets go in: it saves widget positions with a delay, and a restart
# right after placing them can lose them.
step "restarting plasmashell"
if systemctl --user is-active -q plasma-plasmashell.service 2>/dev/null; then
  systemctl --user restart plasma-plasmashell.service
else
  kquitapp6 plasmashell >/dev/null 2>&1 || true; sleep 1; (setsid -f plasmashell >/dev/null 2>&1 &)
fi
for _ in $(seq 30); do [ -n "$(screens 2>/dev/null)" ] && break; sleep 1; done
SCREENS=$(screens)
[ -n "$SCREENS" ] || die "plasmashell did not come back after the restart"
ok "plasmashell restarted"

# ── 5 · wallpaper with the key cheat-sheet, one per screen ──────────────────
step "wallpapers"
render() {  # svg png
  if have rsvg-convert; then rsvg-convert -o "$2" "$1"
  elif have inkscape; then inkscape "$1" --export-type=png --export-filename="$2" >/dev/null 2>&1
  elif have magick; then magick -background none "$1" "$2"
  else die "need rsvg-convert, inkscape or imagemagick to render the wallpaper (run ./install.sh)"; fi
}
js="" layout_in=""
while read -r id screen x y w h; do
  # the primary screen holds the taskbar, so the banner moves up there
  panel=0; [ "$screen" = 0 ] && panel=44
  png="$NOOK_SHARE/wallpaper-${w}x${h}-p$panel.png"
  # the desktop widgets take the free area, so the skull goes
  skull=""; [ "$DO_WIDGETS" = 1 ] && skull=--no-skull
  python3 "$REPO/scripts/wallpaper.py" "$REPO/config/shortcuts.conf" "${png%.png}.svg" "${w}x$h" "$FONT" "$panel" $skull
  layout_in+="$id $screen $w $h ${png%.png}.json"$'\n'
  render "${png%.png}.svg" "$png"
  js+="d = desktopById($id); d.wallpaperPlugin = 'org.kde.image';
       d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
       d.writeConfig('Image', 'file://$png'); d.writeConfig('FillMode', 2);"
  [ "$screen" = 0 ] && lock_png=$png
  ok "screen $screen: ${w}x$h$([ "$h" -gt "$w" ] && echo ' (portrait)')"
done <<<"$SCREENS"
plasma_eval "var d; $js" >/dev/null
kwrite --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$lock_png"
ok "lock screen uses the primary screen's wallpaper"

# ── 6 · taskbar ─────────────────────────────────────────────────────────────
if [ "$DO_PANEL" = 1 ]; then
  step "taskbar"
  launchers=$(python3 "$REPO/scripts/apps.py" "$REPO/config/apps.conf" launchers)
  plasma_eval "$(sed "s|__LAUNCHERS__|$launchers|" "$REPO/scripts/panel.js")" >/dev/null
  rm -f "$NOOK_STATE/tray-seen"   # new tray: hide everything again
  ok "one auto-hiding bar: launcher + apps · colourful clock · tray"
fi

# ── 6a · desktop widgets on every screen ────────────────────────────────────
if [ "$DO_WIDGETS" = 1 ]; then
  step "desktop widgets: clock, system, apps on every screen"
  apps_json=$(python3 "$REPO/scripts/apps.py" "$REPO/config/apps.conf" json)
  # the apps card's footer opens the taskbar's app launcher
  launcher_cmd="dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.activateLauncherMenu"
  # 44px bar + its float margin
  for mode in remove add; do
    plasma_eval "$(printf '%s' "$layout_in" | python3 "$REPO/scripts/layout.py" "$apps_json" "$launcher_cmd" 64 $mode)" >/dev/null
    [ $mode = remove ] && sleep 2
  done
  ok "$(printf '%s' "$layout_in" | grep -c .) screen(s) filled; apps from config/apps.conf"
fi

# ── 6b · minimal tray ───────────────────────────────────────────────────────
step "tray: network, sound, microphone, battery; the rest in the ^ popup"
mkdir -p "$CFG/autostart"
cat > "$CFG/autostart/nook-tray.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Nook tray
Comment=Keeps the system tray down to network, sound, microphone and battery
Exec=$BIN/nook-tray
NoDisplay=true
X-KDE-autostart-phase=2
DESKTOP
ok "nook-tray runs at login and hides new tray icons as apps start (started below)"

# ── 7 · shortcuts ───────────────────────────────────────────────────────────
if [ "$DO_KEYS" = 1 ]; then
  step "global shortcuts"
  python3 "$REPO/scripts/shortcuts.py" bind "$REPO/config/shortcuts.conf" "$BIN"
fi


# The tray watcher starts only now, once the restarted plasmashell is there to talk to.
pkill -f "$BIN/nook-tr[a]y" 2>/dev/null || true
(setsid -f "$BIN/nook-tray" >/dev/null 2>&1 &)

printf '\n%sλ nook applied.%s  %sMeta+/ shows every key · Meta opens the app launcher%s\n' \
  "$c_lav" "$c_off" "$c_muted" "$c_off"
printf '%s  Log out and back in once so window title bars (KWin) pick up the new icons and fonts.%s\n' "$c_muted" "$c_off"
printf '%s  Brave: run nook-brave once to load the Nook browser theme.%s\n' "$c_muted" "$c_off"
