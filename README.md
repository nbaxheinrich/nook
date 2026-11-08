# λ nook — a KDE Plasma 6 rice

A cozy pastel desktop: warm espresso-brown surfaces, cream text, nine pastels (one per
category), JetBrains Mono everywhere, and a Windows-style layout dressed as a terminal.
Built from the *Hackmachine* design system (and called that until it was renamed to nook).

One repo, any machine: clone it and run `./install.sh`. Tested on Fedora/Nobara 44 with Plasma 6.6,
Wayland and two monitors (one rotated 90°). The scripts also handle Ubuntu/Kubuntu, Debian, Arch
and openSUSE.

```bash
git clone https://github.com/nookware/nook.git && cd nook
./install.sh                  # everything: packages (sudo), Plasma theme, nook-tile (Hyprland), login screen (sudo)
./install.sh --no-deps        # no sudo: Plasma theme and nook-tile configs, no packages, no login screen
./install.sh --no-tile        # Plasma only        (--no-plasma: nook-tile + login screen only)
./install.sh --ramen          # Plasma in Ramen Sign too (nook-tile's look: colours, style, icons, cursor, wallpaper, terminal)
./install.sh --pastel         # back to the cocoa look for Plasma and the login screen
./scripts/sddm.sh             # just the login screen, e.g. after --no-deps
./scripts/uninstall.sh        # back to how things were before the first install
```

`./install.sh` runs `scripts/deps.sh` → `scripts/apply.sh` → `tile/install.sh` → `scripts/sddm.sh`. Each can also run alone.
Without Plasma installed (Ubuntu with GNOME, say), the Plasma part is skipped and you get nook-tile and the login screen.
nook-tile needs Fedora/Nobara 44+ or Ubuntu 26.04+; elsewhere it reports why and the rest still installs. See [tile/README.md](tile/README.md).

Options: `--no-sddm` leaves the login screen alone, `--no-tile` / `--no-plasma` skip a part. The rest are passed through to `scripts/apply.sh`:
`--no-panel` keeps your panels, `--no-widgets` skips the desktop widgets, `--no-shell` leaves
your shell (and the command-line tools) alone, `--no-shortcuts` skips the key bindings, `--no-icons` keeps
your icon theme, `--no-cursor` keeps your cursor.

## What you get

| piece | details |
| --- | --- |
| **Colours** | `Nook` Plasma colour scheme, used by the Breeze application style. |
| **Plasma style** | `nook`, generated from the design tokens. Flat cocoa taskbar with a hairline on top. Task buttons: a short faint bar while running, a tile plus a lavender bar when focused, a coral bar when asking for attention. Popups are rounded with a lavender ring. Everything else falls back to Breeze. |
| **Icons** | `Nook`: the BeautyLine line-icon theme (fetched at a pinned commit, GPL-3) repainted so each icon is **one pastel chosen by category**. Media is pink, security coral, time and transfers peach, files butter, dev mint, chat teal, web sky, system lavender and session lilac. App icons are categorised from their `.desktop` Categories, others by name. The arrows (the tray's `^` too) are thin line chevrons instead of BeautyLine's filled ones, and the Office category is a plain line document instead of the Microsoft Office logo. Apps BeautyLine has nothing for get a theme icon found under another of their names, or else a monogram tile in their category colour; apps whose `.desktop` file points at an image (snaps, for one) get a copy in `~/.local/share/applications` that names the theme icon instead (`scripts/appicons.py`; uninstall removes them). Underneath it, `Nook-Breeze` repaints Breeze's small symbolic icons (tray, toolbars) the same way. |
| **Cursor** | `Nook-Cursors`: **Posy's Cursor** (Michiel de Boer's design, Linux port by simtrami, CC BY-NC 4.0, fetched at a pinned commit and not vendored) recoloured by `scripts/cursors.py`. The shapes stay exactly Posy's; white becomes cream and black becomes cocoa, and the coloured bits (the spinning wait wheel, the "not allowed" sign) take the nearest pastel. Size 32, with 48–128 for scaled screens. |
| **Fonts** | JetBrains Mono for every UI font, with bold window titles. The Nerd Font build is used if that's the one installed. VT323 is fetched for pixel headings. |
| **Windows** | `Nook` Aurorae decoration (generated SVG). Cocoa title bar with the title on the left and bracketed `[_] [□] [x]` buttons on the right; close turns coral on hover. Square corners; the active window gets a 1px lavender ring and inactive ones a hairline. Blur is on. |
| **Tiling** | **Krohnkite** (MIT, a dynamic tiling KWin script, fetched at a pinned release and checksum-verified): every new window is tiled automatically, master on the left and the stack on the right, with 8px gaps. Each screen and virtual desktop keeps its own layout. Dialogs and plasmashell float. `Meta+F` floats or tiles a single window, and dragging a tile onto another swaps them. Keys below; Krohnkite's own defaults that clash with Plasma's (`Meta+L`, `Meta+I`, `Meta+D`, `Meta+.`) are cleared, and KWin's quick-tile keys go to Krohnkite (`Meta+Shift+←→` resize instead of sending a window to the next screen; `Meta+Alt+arrows` does that). The arrow keys cross screens: at the edge of a screen, focus jumps to the next screen and a moved window is sent there (`theme/kwin/nook-tiling`). On a portrait (90°) screen the split starts top/bottom: the master on top, the others side by side below it (a small patch to Krohnkite's tile layout, `scripts/krohnkite.py`); `Meta+Ctrl+Space` rotates from there. Settings: System Settings → Window Management → KWin Scripts → Krohnkite. |
| **Taskbar** | One floating bar along the bottom of the primary screen that **auto-hides**: push the mouse against the bottom edge anywhere to bring it back. Left: the filled rainbow hexagon-λ start button (set apart from the single-pastel line icons of the apps) and pinned apps. Centre: a colourful clock (a big rainbow `16:34` as tall as the app icons, with `fri 09.10` over `wk41 :47` beside it; click for a calendar). Right: the tray, its icons scaled to the same size as the apps. It's one bar rather than separate islands because Plasma only reveals an auto-hidden panel from the stretch of screen edge right under it. |
| **Desktop widgets** | Three custom Plasma widgets are placed on **every connected screen**, in the space the wallpaper leaves free. Everything sits on Plasma's 16px widget grid, and the wallpaper's cards are snapped to the same grid, so the widget frames line up exactly with the cheat-sheet and whoami cards, with the same 32px gaps. On landscape screens: clock and apps level with the cheat-sheet, the system card below them from the whoami card's top to above the banner. On portrait screens: stacked between the cards and the banner, as wide as the cards. `TIME // LOCAL` is a big clock drawn with `#` in monospace, one pastel per digit, with date, ISO week and day of month. `SYS // LIVE` shows CPU/GPU/RAM/disk as `[████░░]` bars with temperatures, network up/down as sparklines, and uptime. `APPS // PINNED` has numbered app tiles that scale with the card; its footer opens the taskbar's app launcher. |
| **Tray** | Only network, sound, microphone and battery stay visible. Everything else, Plasma's own entries and app icons alike, goes into the `^` popup. `nook-tray` runs at login and hides tray icons from apps that start later. Each entry is hidden only the first time it appears, so anything you set to "Always shown" stays. Edit `SHOW` in `bin/nook-tray` to change the list. |
| **Wallpaper** | Rendered **per screen at its real size**, so rotated or portrait monitors get a stacked layout. It has a dot grid, a faint ASCII skull (only without the desktop widgets), a **key cheat-sheet** (three columns, two when the screen is too narrow), a `whoami` card and the rainbow `NOOK` banner. The lock screen gets it too. |
| **Login screen** | `theme/sddm/nook`, an SDDM theme in plain QtQuick: the wallpaper's dot grid, the desktop's `#` clock, a terminal-style `LOGIN // TTY` card and the rainbow banner. `user ‹ nbax ›`, `pass ▶ ••••` and `session ‹ plasma (wayland) ›` rows (Tab moves between them, ←→ change the user or session, ⏎ logs in), and `[ suspend ] [ reboot ] [ shut down ]` with the taskbar's hover bars. A failed login shakes the card; caps lock gets a warning. Other screens get just the clock and banner. Also uses the Nook cursor. Installed by `scripts/sddm.sh` (sudo) to `/usr/share/sddm/themes/nook`, picked by `/etc/sddm.conf.d/zz-nook.conf`; `scripts/sddm.sh --remove` undoes it. Preview without logging out: `sddm-greeter-qt6 --test-mode --theme theme/sddm/nook`. **Plasma Login** (Plasma 6.6+, the default on Fedora/Nobara now) has a built-in greeter that takes no themes, so `scripts/sddm.sh` gives it Nook's colours, Plasma style, font and cursor (in the `plasmalogin` user's config) and the desktop's wallpaper (in `/etc/plasmalogin.conf`) instead. System Settings → Login Screen → "Apply Plasma Settings" overwrites that; run `scripts/sddm.sh` again to restore it. **One look for both sessions** (Plasma and nook-tile): by default the **Ramen Sign** look (neutral greys and neons, cyan focus, the `NookRamen` colours, Nook-Pixel cursor, a black wallpaper with the glowing `NOOK` banner from `scripts/login_wallpaper.py`; the SDDM theme reads `palette=ramen` from its `theme.conf`). `scripts/sddm.sh --pastel` brings back the cocoa look. |
| **Logout screen** | `theme/look-and-feel/org.nook.desktop`, a global theme with only a logout screen: the login screen's dot grid, `#` clock and banner around a `SESSION // POWER` card of `[ sleep ] [ restart ] [ shut down ] [ log out ] [ cancel ]` (←→ or Tab pick, ⏎ runs, Esc cancels). Shut down or restart from the menu counts down 30 s. Everything else (splash, lock screen) is Breeze. `apply.sh` sets just its name, since `plasma-apply-lookandfeel` would also reset the panel. Preview: `/usr/libexec/ksmserver-logout-greeter --windowed` (the buttons work, so press Esc). |
| **Lock screen** | Plasma's own (since Plasma 6.6 it belongs to the desktop shell, not the global theme) in Nook colours, font and the primary screen's wallpaper. |
| **Terminal** | **Alacritty** is the default terminal (`Meta+Return`, and Plasma's default terminal for Dolphin & co.). It runs **zsh with oh-my-zsh** and the `nook` theme: a two-line prompt (`╭─λ user@host ─ ~/path ─  branch ✓` / `╰─❯`). The right side shows the conda/venv env, how long the last command took, a failed command's exit code, and the time. Autosuggestions and syntax highlighting are in the pastels. Your own `~/.zshrc` is kept; one line is added at its top. Pastel 16-colour palette, 92% opacity with blur (`theme/alacritty/nook.toml`; apply.sh writes `~/.config/alacritty/alacritty.toml` with the font and shell). **Konsole stays as the fallback** on `Ctrl+Alt+T`, with the same look in its `Nook` profile and no toolbars (menus via Ctrl+Shift+M or right-click).
| **fastfetch** | Runs once when a Nook terminal opens (`theme/fastfetch`). A steaming mug with `n o o k` under it, then three cards like the wallpaper's: `SYS //` (os, kernel, packages, uptime), `DESK //` (Plasma, KWin and whether Krohnkite tiles, the colour scheme, icons and Plasma style in use, cursor, font, terminal, shell, each screen) and `HW //` (CPU with temperature, GPUs, and memory, disk and battery as `[████░░]` bars like the desktop widget), ending in the nine pastels. |
| **Brave** | `theme/brave/nook`: a browser theme in the same cocoa and lavender palette. Chromium only installs local themes through its own UI, so run `nook-brave` once: it opens the extensions page, copies the theme's path to the clipboard and tells you the two clicks (Developer mode → Load unpacked). |
| **Zed** | `theme/zed/nook.json`: a Zed theme in the same cocoa and pastel palette (lavender keywords and focus, mint strings, sky functions, butter types). It goes into the native (`~/.config/zed`) and the Flatpak (`~/.var/app/dev.zed.Zed/config/zed`) config, whichever is there. `settings.json` gets `theme` and JetBrains Mono as buffer and UI font; the file's other settings and comments stay as they are. Zed picks it up live. |
| **Shell tools** | Installed by `deps.sh` and set up in `theme/shell/tools.sh` (zsh, and bash in Nook terminals). Each one only kicks in when it's installed. **zoxide** sits behind `cd`: it learns where you go, so `cd proj` jumps to `~/code/proj`, plain paths work as before, and `cdi` picks with fzf. **eza** behind `ls` (`ll`, `la` with git status, `lt` for a tree). **bat** behind `cat`, as the man pager and as the fzf `Ctrl+T` preview. **fd** feeds fzf, and **ripgrep** (`rg`) gets smart-case and pastel matches. **fzf** (`Ctrl+R`, `Ctrl+T`, `Alt+C`) uses the palette everywhere. |
| **git** | `theme/git/gitconfig`, included from `~/.gitconfig` (your own settings stay): pastel status, branch and diff colours, `git lg` (a one-line graph), `git st`, `git last`, zdiff3 conflicts. **delta** is the pager when it's installed (`theme/git/delta.gitconfig`): line numbers, `n`/`N` to jump between files, coral and mint diff backgrounds, and syntax highlighting with the `Nook` bat theme (`theme/bat/Nook.tmTheme`, the same colours as the Zed theme). |
| **Extras** | Themes for btop and cava (rainbow bars). |

## Pinned apps

`config/apps.conf` lists the pinned apps, used by both the taskbar and the desktop card. Each line
has a label, a category colour and the `.desktop` ids to try, so one line covers the native,
Flatpak and Snap builds of an app. If a pinned app isn't installed, its slot goes to the first
installed app from the `[fill]` list below it (Zed, VS Code, Firefox, Zen, Spotify, Signal,
Obsidian, Kate, System Monitor), so the card is always full. Edit it and run `./install.sh --no-deps`.

## Shortcuts

`config/shortcuts.conf` is the **single source** for the key bindings *and* the wallpaper
cheat-sheet. A row with a command gets bound as a global shortcut, live over D-Bus, with no
logout needed. A row without one is a Plasma default and only shows on the wallpaper. Edit it,
then re-run `./install.sh --no-deps`.

| keys | does |
| --- | --- |
| `Meta+Return` | terminal (Alacritty) |
| `Ctrl+Alt+T` | Konsole, the fallback terminal |
| `Meta+/` | show every shortcut in a terminal (`nook-keys`) |
| `Meta+B` | browser |
| `Meta+Shift+Return` | btop |
| `Meta+Alt+V` | cava |
| `Meta+←↑→↓` | focus the tile in that direction, or the next screen at the edge |
| `Meta+Alt+←↑→↓` | swap with the tile on that side, or send the window to the next screen |
| `Meta+Shift+←↑→↓` | shrink (← ↑) or grow (→ ↓) the window, tiled or floating |
| `Meta+Ctrl+Return` | make the window the master |
| `Meta+T` / `Meta+M` | tile / monocle layout (`Meta+Shift+Space` cycles all layouts, `Meta+Ctrl+Space` rotates) |

## Multi-monitor and rotation

Screen sizes come from plasmashell's own `screenGeometry()`. Rotation is already applied there,
so a 90° monitor reports e.g. 1440×2560 and gets a portrait wallpaper. The taskbar goes on the
primary screen. Plug in or rotate a monitor? Run `./install.sh --no-deps` again.

## Layout

```
install.sh              entry point: deps.sh, apply.sh, tile/install.sh, then sddm.sh
scripts/deps.sh         packages per distro (dnf / apt / pacman / zypper) + VT323
scripts/apply.sh        everything per-user; backs up first to ~/.local/state/nook/
scripts/sddm.sh         the login screen (SDDM or Plasma Login) and its cursor, system-wide (sudo); --remove undoes it
scripts/uninstall.sh    restores the oldest backup, removes our files
scripts/wallpaper.py    SVG wallpaper generator (stdlib only), rendered with rsvg-convert/inkscape/magick
scripts/shortcuts.py    binds/unbinds global shortcuts, prints the cheat-sheet
scripts/panel.js        Plasma scripting for the taskbar
scripts/apps.py         resolves config/apps.conf to installed .desktop files
scripts/layout.py       places the desktop widgets on each screen around the wallpaper
scripts/icons.py        repaints an icon theme, one pastel per icon by category
scripts/appicons.py     theme icons or monograms for apps the icon theme misses
scripts/themegen.py     generates the Plasma style and the Aurorae decoration
scripts/zed.py          sets the theme and font in Zed's settings.json (JSONC, edited in place)
scripts/krohnkite.py    makes Krohnkite's tile layout start top/bottom on portrait screens
scripts/cursors.py      recolours Posy's cursors in the palette
config/shortcuts.conf   key bindings + cheat-sheet rows
config/apps.conf        pinned apps (taskbar + desktop card)
bin/nook-keys             the cheat-sheet viewer (installed to ~/.local/bin)
bin/nook-tray             keeps the tray minimal (autostarted)
bin/nook-brave            loads the Brave theme
theme/                  colour schemes, Alacritty, Konsole, fastfetch, btop, cava, Zed, icon, shell, KWin script,
                        SDDM, bat, git, ripgrep
```

## Palette

```
bg-000 #1a1614  bg-100 #221d1a  bg-200 #2a2420  bg-300 #372f2a  line #4a3f38
ink    #f6ece4  muted  #bfae9f  faint  #7d6d62
pink   #f5a8c9  coral  #f7a59a  peach  #f9c49a  butter #f2e29b  mint #a6e6bf
teal   #94dcd6  sky    #a3cdf5  lavender #c4b2f5  lilac #e2b5f0
```
