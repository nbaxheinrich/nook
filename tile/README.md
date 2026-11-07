# λ nook-tile — Hyprland + Quickshell, Ramen Sign

The tiling variant of nook. It's a second session next to Plasma, built from the **Nook / Ramen Sign**
design system: neutral black and greys, nine neons with one job each, and cyan for focus.

```bash
tile/install.sh             # packages (sudo), then link the configs
tile/install.sh --no-deps   # links only
```

| system | Hyprland 0.57+ | Quickshell | notes |
| --- | --- | --- | --- |
| **Nobara 44+** | COPR `sdegler/hyprland` | Nobara repo | Qt apps fully themed (KDE-aware qt6ct reads `NookRamen.colors`) |
| **Fedora 44+** | COPR `sdegler/hyprland` | COPR `errornointernet/quickshell` | same as Nobara. Breeze only if KDE is installed, Fusion otherwise |
| **Ubuntu 26.04+** and distros based on it (Mint, Pop!_OS, Kubuntu …) | PPA `cppiber/hyprland` | apt from 26.10 on; on 26.04 **built from source** (tag `v0.3.2`, a few minutes) | plain qt6ct uses the `NookRamen.conf` palette, so KDE apps' own colour logic doesn't follow |
| Ubuntu 24.04, Debian | ✗ | ✗ | Qt 6.4 is too old (needs 6.9+); no Hyprland 0.57 packages |

The config uses Hyprland's **Lua** format, which is why Hyprland has to be 0.57 or newer.
On other distros, install Hyprland ≥ 0.57, Quickshell, kitty, mako and qt6ct yourself and run `--no-deps`.

Log out, pick **Hyprland** on the login screen. `SUPER ⇧ E` takes you back.

All configs are **symlinks into this folder**. Hyprland reloads `nook.lua` when you save it,
and Quickshell reloads its folder when you save it, so editing here changes the live desktop.

| file | goes to | what |
| --- | --- | --- |
| `hypr/nook.lua` | `~/.config/hypr/nook.lua` (link) | Look, rules, autostart and **every keybind**. Hyprland 0.57 is configured in Lua. |
| `hypr/machine.lua` | `~/.config/hypr/machine.lua` (copied once, yours) | Monitors (DP-2 landscape, DP-1 portrait on the right), EurKEY layout, workspaces 1–5 / 6–9 per screen. |
| `hypr/hyprland.lua` | `~/.config/hypr/hyprland.lua` | Just `require("machine")` and `require("nook")`. |
| `hypr/hyprlock.conf`, `hypridle.conf` | `~/.config/hypr/` (links) | VT323 lock screen in orange, cyan input. Locks after 10 min. |
| `quickshell/nook/` | `~/.config/quickshell/nook` (link) | The shell, started with `qs -c nook`. |
| `kitty/nook.conf` | `~/.config/kitty/` (link + `include`) | Ramen palette, 90% opacity. Sets `NOOK_THEME=ramen` for the prompt. |
| `mako/config` | `~/.config/mako/` (link) | Notifications top-right: `[i]` / `[~]` / `[!!]`, critical ones in red. |
| `cursors/pixelcursors.py` | `~/.local/share/icons/Nook-Pixel` (generated) | Old-school pixel cursors (Win95 / Mac classic): white with a black outline, hard-edged, orange sand in the hourglass, red no-entry sign. |
| `systemd/hyprland-session.target` | `~/.config/systemd/user/` (link) | Starts `graphical-session.target` so xdg-desktop-portal runs (screen sharing, file dialogs). |
| `fastfetch/ramen.*` | `~/.config/fastfetch/` (links) | Candy logo, fire to ice. |
| `qt/NookRamen.colors` | `~/.local/share/color-schemes/` (link) + `~/.config/qt6ct/qt6ct.conf` | Qt/KDE apps in Ramen Sign: Breeze style, cyan selection and focus, your Plasma fonts and icons. Only the Hyprland session uses it (`QT_QPA_PLATFORMTHEME=qt6ct`). |
| `../theme/shell/ramen.zsh` | `~/.local/share/nook/` | Same nook prompt in the neons, loaded when `NOOK_THEME=ramen`. |

## The shell (Quickshell)

- **Bar** (`Bar.qml`), floating at the bottom of every screen:
  - `λ nook` in cream opens the menu.
  - Workspaces 1–9 as dots: cyan bar = active, grey = occupied, red = urgent. Click or scroll.
  - The focused window as a `[ app — title ]` tag.
  - A VT323 clock in orange.
  - CPU braille sparkline and RAM.
  - Volume: scroll to change, click to mute.
  - Tray: left click activates, right click opens the menu.
  - `⏻`: menu on left click, lock on right click.
- **Launcher / hack menu** (`Launcher.qml`, `SUPER SPACE` or `λ nook`): the design system's Launcher, live.
  - NOOK banner, `user@host`, kernel and uptime.
  - A `λ ~/ >` prompt with a blinking aqua block.
  - Pinned apps from `config/apps.conf` as `[01] ▢ name ...... binary`, with line icons in the category hue. Typing searches every app.
  - `SYS // LIVE` (cpu, ram, gpu, temp, net, workspaces), a hexdump of what you type, and the cat.
  - `[lock] [sleep] [reboot] [shutdown]`. Reboot and shutdown ask with a second click.
  - Keys: `↑↓`/Tab to move, `⏎` to run, `Alt 1‥9` for direct launch, `Esc` or a click outside to close.
- **Cheatsheet** (`CheatSheet.qml`) sits on the wallpaper, under every window. `SUPER /` toggles it.
  - It reads the binds from `hyprctl binds -j`. Every bind in `nook.lua` with a description
    `"group: label"` shows up there, so `nook.lua` is the only list of keys.
  - Group colours: APPS amber, WINDOWS cyan, WORKSPACES blue, SYSTEM red.
- **Widgets** (`Widgets.qml`), top right:
  - `TIME // LOCAL` with block digits, one hue per row.
  - `SYS // LIVE` with cpu / ram / disk `[████░░]` bars, net as a blue sparkline, and the CPU temperature.
  - `NOW // PLAYING` (MPRIS) with `[◀◀] [ ▮▮ ] [▶▶]`.
- **Wallpaper** (`Wallpaper.qml`), drawn live per screen: dot grid, scanlines, and the glowing `NOOK` banner.
- `Theme.qml` holds the tokens and `Stats.qml` the shared `/proc` numbers.

## Keys

| | |
| --- | --- |
| apps | `SUPER ⏎` kitty · `SUPER SPACE` menu · `SUPER E` dolphin · `SUPER B` browser · `SUPER ⇧ ⏎` btop |
| windows | `SUPER Q` close · `SUPER F` fullscreen · `SUPER V` float · `SUPER P` pseudo · `SUPER J` flip split · `SUPER ←↑→↓` focus · `SUPER ⇧ ←↑→↓` move · `SUPER` + drag |
| workspaces | `SUPER 1‥9` · `SUPER ⇧ 1‥9` send · `SUPER S` scratchpad · `SUPER` + scroll |
| system | `SUPER L` lock · `PRINT` area → clipboard · `SUPER /` cheatsheet · `SUPER ⇧ R` reload shell · `SUPER ⇧ E` exit |

## Known gaps

- The configs **have not run on a real session yet**. The first login is the test. If
  Hyprland shows a config error bar, the error message names the line.
- Screens-off on idle (dpms) is left out because the Lua dispatcher arguments aren't documented yet.
- GTK apps don't have a Ramen theme yet. The recoloured icon set and the cava bars in the
  now-playing widget are still to do too.
