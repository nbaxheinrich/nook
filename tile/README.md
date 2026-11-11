# λ nook-tile — Hyprland + Quickshell

The tiling half of nook v2. It's a second session next to Plasma, drawn in the **Ramen Sign** design
system (neutral black and greys, nine neons with one job each, cyan for focus), and it takes any palette.

```bash
./nook                                  # from the repo root: the TUI (pick "tile")
tile/install.sh --palette=ramen         # nook-tile alone: packages (sudo), then link the configs
tile/install.sh --palette=cocoa --no-deps
```

With **ramen**, the configs are symlinks into this folder (edits show up live). With any other palette,
they link to a recoloured copy in `~/.local/share/nook/tile-build`. Re-run the installer after editing.

| system | Hyprland 0.57+ | Quickshell | notes |
| --- | --- | --- | --- |
| **Nobara 44+** | COPR `sdegler/hyprland` | Nobara repo | Qt apps fully themed (KDE-aware qt6ct reads `NookRamen.colors`) |
| **Fedora 44+** | COPR `sdegler/hyprland` | COPR `errornointernet/quickshell` | same as Nobara. Breeze only if KDE is installed, Fusion otherwise |
| **Ubuntu 26.04+** and distros based on it (Mint, Pop!_OS, Kubuntu …) | PPA `cppiber/hyprland` | apt from 26.10 on; on 26.04 **built from source** (tag `v0.3.2`, a few minutes) | plain qt6ct uses the `NookRamen.conf` palette, so KDE apps' own colour logic doesn't follow |
| Ubuntu 24.04, Debian | ✗ | ✗ | Qt 6.4 is too old (needs 6.9+); no Hyprland 0.57 packages |

The config uses Hyprland's **Lua** format, which is why Hyprland has to be 0.57 or newer.
On other distros, install Hyprland ≥ 0.57, Quickshell, kitty, mako and qt6ct yourself and run `--no-deps`.

Log out, pick **Hyprland** on the login screen. `SUPER ⇧ E` takes you back.

Hyprland reloads `nook.lua` and Quickshell reloads its folder when a file changes.
The shell, prompt and command-line tools are the shell part's (`./nook` → shell), and the login screen is the login part's.

| file | goes to | what |
| --- | --- | --- |
| `hypr/nook.lua` | `~/.config/hypr/nook.lua` (link) | Look, rules, autostart and **every keybind**. Hyprland 0.57 is configured in Lua. |
| `hypr/machine.lua` | `~/.config/hypr/machine.lua` (copied once, yours) | Monitors (DP-2 landscape, DP-1 portrait on the right), EurKEY layout. |
| `hypr/hyprland.lua` | `~/.config/hypr/hyprland.lua` | Just `require("machine")` and `require("nook")`. |
| `hypr/hyprlock.conf`, `hypridle.conf` | `~/.config/hypr/` (links) | Lock screen with the `NOOK` banner's shadow-block clock (`bin/nook-lockclock`, one fire → ice hue per row), cyan input. Locks after 10 min. |
| `quickshell/nook/` | `~/.config/quickshell/nook` (link) | The shell, started with `qs -c nook`. |
| `kitty/nook.conf` | `~/.config/kitty/` (link + `include`) | The palette, 90% opacity; `NOOK=1` and the axolotl fastfetch for the shell part. |
| `ssh/nook.conf` | `~/.ssh/nook.conf` (copy, mode 600, + `Include` at the end of `~/.ssh/config`) | `TERM=xterm-256color` for ssh, so `nano` & co. work on machines without kitty's terminfo (`Error opening terminal: xterm-kitty`). A `Host` block of your own above it wins. |
| `mako/config` | `~/.config/mako/` (link) | Notifications top-right: `[i]` / `[~]` / `[!!]`, critical ones in red. |
| `../shared/cursors/pixelcursors.py` | `~/.local/share/icons/Nook-Pixel` (generated) | Old-school pixel cursors (Win95 / Mac classic): white with a black outline, hard-edged, orange sand in the hourglass, red no-entry sign. |
| `systemd/hyprland-session.target` | `~/.config/systemd/user/` (link) | Starts `graphical-session.target` so xdg-desktop-portal runs (screen sharing, file dialogs). |
| `../shared/icons/build.sh <palette>` | `~/.local/share/icons/Nook-Ramen` or `Nook` (generated) | The rice's icon set (BeautyLine + Breeze symbolic) with one neon per category: files gold, dev aqua, comms cyan, network blue, system amber, media rose, time red, security orange, session cream. KDE apps read the icon theme from the shared `kdeglobals`, so `bin/nook-session-look` sets `Nook-Ramen` when Hyprland starts and puts Plasma's back when Plasma starts (a Plasma-only autostart entry). |
| `qt/qt6ct.conf` + `../palettes/kde/*.colors` | `~/.config/qt6ct/` | Qt/KDE apps in the palette: Breeze style, cyan selection and focus, your Plasma fonts and icons. Only the Hyprland session uses it (`QT_QPA_PLATFORMTHEME=qt6ct`). |

**Red is the accent** (start button, clock, the cyan → red window border, glows, hover in Qt apps). Orange takes over danger: urgent workspaces, errors, critical notifications, the lock button. The login screen (`shared/login/login.sh`) takes any palette, for SDDM and Plasma Login.

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
- **Keyboard pill** `kb eu` / `kb de` in the bar: shows the active layout (EurKEY / German, `kb_layout = "eu,de"` in `machine.lua`). Click it or press `SUPER K` to switch.
- **Control center** (`ControlCenter.qml`, `SUPER A`, or click `vol` / `net · bt` / `bg N` in the bar), four tabs in the launcher's look:
  - `audio`: output and input device to pick, volume and mic bars (click, drag or scroll), mute, and a mixer per app.
  - `net`: wifi on/off and networks by signal; it scans while the tab is open. Click to connect or disconnect. A new secured network asks for its password right in the row (`⏎` joins, `show` reveals it); a wrong one shows why and asks again. Known networks have `[forget]` (click twice). Wired links (from `nmcli`, without container veths) connect and disconnect with a click. `settings` opens `nm-connection-editor`, or `nmtui` without it.
  - `bt`: bluetooth on/off, scan, devices with connect/disconnect and battery. A new device pairs, gets trusted and connects with one click; `[cancel]` stops pairing, `[forget]` (click twice) removes a paired one.
  - `apps`: the background apps (the tray) as a list. Click opens, right-click opens their menu. Also what's playing.
- **Cheatsheet** (`CheatSheet.qml`) sits on the wallpaper, under every window. `SUPER /` toggles it.
  - It reads the binds from `hyprctl binds -j`. Every bind in `nook.lua` with a description
    `"group: label"` shows up there, so `nook.lua` is the only list of keys.
  - Group colours: APPS amber, WINDOWS cyan, WORKSPACES blue, SYSTEM red.
- **Widgets** (`Widgets.qml`), top right. Landscape screens get two columns, portrait screens one:
  - `TIME // LOCAL` in the `NOOK` banner's shadow-block font (`███╗`), one fire → ice hue per row, and the ISO week.
  - `SYS // LIVE` with cpu / ram / disk `[████░░]` bars, net as a blue sparkline, and the CPU temperature. With an NVIDIA card also gpu and vram bars, a load sparkline, temperature, watts and fan (`nvidia-smi`).
  - `NOW // PLAYING` (MPRIS) with `[◀◀] [ ▮▮ ] [▶▶]`.
  - `WX // OUTSIDE`: weather now (symbol, temperature, feels-like, min/max, humidity, wind) and the next five 3-hour slots with rain chance, from wttr.in.
  - `SRV // HOMELAB`: your hosts with an up/down dot, a latency sparkline and the last ping. `host:port` checks a TCP port instead, for hosts that drop pings.
  - `CAL // NEXT`: the next events from a CalDAV server (Nextcloud works), with a countdown to the first one. The password sits in the keyring, not in a file: `nook-feed cal --setup`.
  - `PROC // TOP`: the five busiest processes (idle ones by ram). Click a row, then click again within 3 s to end it; the session's own processes can't be ended.
  - Weather place, hosts and calendar are personal, so they live in `~/.config/nook/widgets.conf` (installed once from `config/widgets.example.conf`). A widget with nothing configured hides. `Feeds.qml` polls `bin/nook-feed`.
- **Wallpaper** (`Wallpaper.qml`), drawn live per screen: dot grid, scanlines, and the glowing `NOOK` banner.
- `Theme.qml` holds the tokens and `Stats.qml` the shared `/proc` numbers.

## Screen sharing

It goes through `xdg-desktop-portal-hyprland` (the picker appears when an app asks). Two things keep it working:
- KDE's `xwaylandvideobridge` is kept to Plasma (`NotShowIn=Hyprland`). Under Hyprland it opened shares by itself and looped on formats.
- Electron apps from Flatpak (Discord, Vesktop) run natively on Wayland (`ELECTRON_OZONE_PLATFORM_HINT=auto`), so they share through the portal instead of needing the bridge.

## Gaming

- **Global:** tearing allowed, VRR for fullscreen windows (`misc.vrr = 2`), direct scanout for fullscreen games.
- **Games** (`steam_app_<id>`, `gamescope`, `*.exe`) get a rule:
  - tearing (`immediate`) for the lowest latency
  - no idle lock while fullscreen
  - `content = "game"`
  - no blur or dimming
  - they keep rendering when the other screen has focus
- **NVIDIA:** `LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME` and `NVD_BACKEND` are set when the proprietary driver is loaded.
- **`SUPER G` game mode** (`bin/nook-gamemode`) turns animations, blur, shadows, dimming and gaps off. Press it again to reload the normal look.
- **`SUPER ⇧ P` screens** (`bin/nook-display`) toggles extend ⇄ duplicate: every other screen mirrors the focused one, upright in its own rotation (letterboxed between portrait and landscape), and all screens switch to the biggest resolution they share (a small beamer gets a native, readable picture; `nook-display duplicate 1280x720` picks one yourself). Extend is a config reload, so the layout stays in `machine.lua`. `nook-display only` keeps just the focused screen.
- **Steam launch options** worth using: `gamemoderun %command%` (CPU governor and priority), `mangohud %command%` (FPS overlay), or `gamescope -f -W 2560 -H 1440 -r 144 -- %command%` for games that misbehave with XWayland.

## Keys

| | |
| --- | --- |
| apps | `SUPER ⏎` kitty · `SUPER SPACE` menu · `SUPER E` dolphin · `SUPER B` browser · `SUPER ⇧ ⏎` btop |
| windows | `SUPER Q` close · `SUPER F` fullscreen · `SUPER V` float · `SUPER P` pseudo · `SUPER J` flip split · `SUPER ←↑→↓` focus · `SUPER ⇧ ←↑→↓` move · `SUPER` + drag |
| workspaces | `SUPER 1‥9` · `SUPER ⇧ 1‥9` send (also off a workspace the bar doesn't show) · `SUPER S` scratchpad · `SUPER ALT S` to scratchpad · `SUPER` + scroll. Every screen has a home workspace, counted from the left: 1, 2, 3 …; the rest open on the focused screen |
| system | `SUPER G` game mode · `SUPER ⇧ P` screens extend ⇄ duplicate · `SUPER K` keyboard EurKEY ⇄ German · `SUPER L` lock · `SUPER ⇧ S` / `W` / `A` screenshot area / window / screen (also `PRINT`), saved to ~/Pictures/Screenshots + clipboard · `SUPER /` cheatsheet · `SUPER ⇧ R` reload shell · `SUPER ⇧ E` exit |

## Known gaps

- The configs **have not run on a real session yet**. The first login is the test. If
  Hyprland shows a config error bar, the error message names the line.
- Screens-off on idle (dpms) is left out because the Lua dispatcher arguments aren't documented yet.
- GTK apps don't have a Ramen theme yet. The recoloured icon set and the cava bars in the
  now-playing widget are still to do too.
