# Clean up after installs from before the rename: this rice used to be called Hackmachine, and
# some of its versions had a hack menu (hm-menu). Sourced by apply.sh before its backup, with the
# DO_* options set; does nothing on a machine that never had the old name.
# Everything here is replaced under the new name later in the same apply.sh run.

old_state="$XDG_STATE_HOME/hackmachine"
old_share="$XDG_DATA_HOME/hackmachine"
if [ -d "$old_state" ] || [ -d "$old_share" ] || [ -e "$XDG_DATA_HOME/color-schemes/Hackmachine.colors" ]; then
  step "renaming an earlier Hackmachine install to Nook"

  # backups (the oldest one holds your setup from before any of this) and downloads move over
  if [ -d "$old_state" ]; then
    if [ ! -e "$NOOK_STATE" ]; then
      mkdir -p "$(dirname "$NOOK_STATE")"; mv "$old_state" "$NOOK_STATE"
    else
      mkdir -p "$NOOK_STATE/src"
      for b in "$old_state"/backup-*; do [ -e "$b" ] && mv "$b" "$NOOK_STATE/"; done
      for d in "$old_state"/src/*; do [ -e "$d" ] && [ ! -e "$NOOK_STATE/src/${d##*/}" ] && mv "$d" "$NOOK_STATE/src/"; done
      [ -f "$old_state/zed-created" ] && cat "$old_state/zed-created" >> "$NOOK_STATE/zed-created"
      [ -f "$old_state/omz-installed-by-hackmachine" ] && touch "$NOOK_STATE/omz-installed-by-nook"
      rm -rf "$old_state"
    fi
    [ -f "$NOOK_STATE/omz-installed-by-hackmachine" ] && mv "$NOOK_STATE/omz-installed-by-hackmachine" "$NOOK_STATE/omz-installed-by-nook"
    rm -rf "$NOOK_STATE/menu-config" "$NOOK_STATE/menu-data" "$NOOK_STATE/tray-seen"
  fi

  # global shortcuts: the old launchers and the old names of the tiling script's actions
  accel_unregister() {
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
      --method org.kde.KGlobalAccel.unregister "$1" "$2" >/dev/null 2>&1 || true
  }
  for f in "$XDG_DATA_HOME"/applications/hackmachine-*.desktop; do
    [ -e "$f" ] || continue
    accel_unregister "${f##*/}" _launch; rm -f "$f"
  done
  for a in FocusLeft FocusUp FocusRight FocusDown MoveLeft MoveUp MoveRight MoveDown; do
    accel_unregister kwin "Hackmachine$a"
  done

  pkill -f "hm-tr[a]y" 2>/dev/null || true
  rm -f "$HOME/.local/bin/hm-menu" "$HOME/.local/bin/hm-keys" "$HOME/.local/bin/hm-tray" "$HOME/.local/bin/hm-brave" \
        "$XDG_CONFIG_HOME/autostart/hackmachine-tray.desktop"

  rm -rf "$XDG_DATA_HOME/kwin/scripts/hackmachine-tiling"
  kwrite --file kwinrc --group Plugins --key hackmachine-tilingEnabled --delete 2>/dev/null || true

  if [ "$DO_PANEL" = 1 ] && [ "$DO_WIDGETS" = 1 ]; then
    # the taskbar is rebuilt and the desktop widgets placed again, so the old ones can go
    plasma_eval 'desktops().concat(panels()).forEach(function (c) { c.widgets().forEach(function (w) {
      if (w.type.indexOf("org.hackmachine.") === 0) w.remove(); }); });' >/dev/null 2>&1 || true
    rm -rf "$XDG_DATA_HOME"/plasma/plasmoids/org.hackmachine.{apps,clock,sys}
  fi
  rm -f "$XDG_DATA_HOME/color-schemes/Hackmachine.colors" \
        "$XDG_DATA_HOME/konsole/Hackmachine.profile" "$XDG_DATA_HOME/konsole/Hackmachine.colorscheme" \
        "$XDG_DATA_HOME/icons/hicolor/scalable/apps/hackmachine.svg" "$XDG_DATA_HOME/icons/hicolor/scalable/apps/hackmachine-start.svg" \
        "${XDG_CACHE_HOME:-$HOME/.cache}"/plasma_theme_hackmachine*
  rm -rf "$XDG_DATA_HOME/aurorae/themes/Hackmachine" "$XDG_DATA_HOME/plasma/desktoptheme/hackmachine"
  if [ "$DO_ICONS" = 1 ]; then
    rm -rf "$XDG_DATA_HOME/icons/Hackmachine" "$XDG_DATA_HOME/icons/Hackmachine-Breeze"
    { grep -lx 'X-Hackmachine-Icon=true' "$XDG_DATA_HOME"/applications/*.desktop 2>/dev/null || true; } | xargs -r rm -f
  fi
  [ "$DO_CURSOR" = 1 ] && rm -rf "$XDG_DATA_HOME/icons/Hackmachine-Cursors"

  if [ "$DO_SHELL" = 1 ]; then
    sed -i '/# hackmachine$/d' "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null || true
    rm -f "$HOME/.oh-my-zsh/custom/themes/hackmachine.zsh-theme"
    for inc in gitconfig delta.gitconfig; do
      git config --global --fixed-value --unset-all include.path "$old_share/$inc" 2>/dev/null || true
    done
  fi
  rm -f "$XDG_CONFIG_HOME/alacritty/hackmachine.toml" "$XDG_CONFIG_HOME/btop/themes/hackmachine.theme" \
        "$XDG_CONFIG_HOME/zed/themes/hackmachine.json" "$HOME/.var/app/dev.zed.Zed/config/zed/themes/hackmachine.json"

  [ -d "$XDG_DATA_HOME/fonts/hackmachine" ] && [ ! -e "$XDG_DATA_HOME/fonts/nook" ] \
    && mv "$XDG_DATA_HOME/fonts/hackmachine" "$XDG_DATA_HOME/fonts/nook"
  [ -d "$old_share/brave-theme" ] && warn "Brave: the theme moved; run nook-brave and load it again (then remove the old one)"
  rm -rf "$old_share"
  ok "old names cleaned up; backups kept in ${NOOK_STATE/#$HOME/\~}"
fi

# the hack menu (removed): its KWin rule and script, and Krohnkite settings made for it
rules=$(kread --file kwinrulesrc --group General --key rules)
if [[ ",$rules," == *",hackmachine-menu,"* ]]; then
  # (grep finds nothing when the menu's rule was the only one)
  rules=$(tr ',' '\n' <<<"$rules" | { grep -vx hackmachine-menu || true; } | paste -sd, -)
  kwrite --file kwinrulesrc --group General --key rules "$rules"
  kwrite --file kwinrulesrc --group General --key count "$(awk -F, '{print NF}' <<<"$rules")"
fi
rm -rf "$XDG_DATA_HOME/kwin/scripts/hackmachine-menu" "$HOME/.local/bin/hm-menu"
kwrite --file kwinrc --group Plugins --key hackmachine-menuEnabled --delete 2>/dev/null || true
if [ "$(kread --file kwinrc --group Script-krohnkite --key floatingTitle)" = hm-menu ]; then
  kwrite --file kwinrc --group Script-krohnkite --key floatingTitle --delete 2>/dev/null || true
  kwrite --file kwinrc --group Script-krohnkite --key floatSkipPagerWindows --delete 2>/dev/null || true
fi
