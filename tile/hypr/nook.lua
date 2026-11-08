-- ── nook-tile · Ramen Sign ──────────────────────────────────────────────────
-- Look, rules, autostart and keybinds for Hyprland 0.57+ (Lua config).
-- Loaded from ~/.config/hypr/hyprland.lua with require("nook"); this file is a
-- symlink into the repo, so edit it there. Hyprland reloads on save.
--
-- Every bind gets a description "group: label". The Quickshell cheatsheet reads
-- them from `hyprctl binds -j`, so this file is the only list of key bindings.

local C = {
    bg000 = "060606", bg100 = "0d0d0d", bg200 = "141414", line = "343434",
    cyan  = "45c8e6", red = "ff6458",
}
local function rgba(hex, a) return "rgba(" .. hex .. (a or "ff") .. ")" end

local mod      = "SUPER"
local term     = "kitty"
local files    = "dolphin"
local browser  = [[sh -c 'gtk-launch "$(xdg-settings get default-web-browser)"']]
local menu     = "qs -c nook ipc call launcher toggle"

-------------------------------------------------------------------------------
-- autostart
-------------------------------------------------------------------------------
hl.on("hyprland.start", function()
    -- environment into systemd/dbus, then graphical-session.target (xdg-desktop-portal needs it),
    -- then the shell, so Quickshell finds the portal already running
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP "
        .. "HYPRLAND_INSTANCE_SIGNATURE DISPLAY QT_QPA_PLATFORMTHEME XCURSOR_THEME XCURSOR_SIZE "
        .. "&& systemctl --user start hyprland-session.target hyprpolkitagent "
        .. "; nook-session-look hyprland; qs -c nook")  -- Ramen icons for KDE apps, then the shell
    hl.exec_cmd("mako")                                 -- notifications
    hl.exec_cmd("hypridle")                             -- lock when idle
end)

hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)

hl.env("XCURSOR_THEME", "Nook-Pixel")     -- old-school pixel cursors (tile/cursors/pixelcursors.py)
hl.env("XCURSOR_SIZE", "16")
hl.env("HYPRCURSOR_SIZE", "16")
-- Qt apps: qt6ct (the KDE-aware build) with the NookRamen colour scheme, Breeze style, Nook icons.
-- Only this session reads ~/.config/qt6ct, so Plasma keeps its pastel Nook scheme.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- NVIDIA (proprietary driver): VA-API, GLX vendor and Electron on Wayland
local nv = io.open("/proc/driver/nvidia/version", "r")
if nv then
    nv:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-------------------------------------------------------------------------------
-- look
-------------------------------------------------------------------------------
hl.config({
    general = {
        gaps_in     = 6,                                -- gap-in
        gaps_out    = 12,                               -- space-3
        border_size = 2,
        col = {
            -- the neon sign: cyan → red, slowly rotating (borderangle below)
            active_border   = { colors = { rgba(C.cyan), rgba(C.red) }, angle = 45 },
            inactive_border = rgba(C.line, "cc"),
        },
        layout           = "dwindle",
        resize_on_border = true,
    },

    decoration = {
        rounding         = 4,                           -- radius-md: barely rounded
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.92,
        dim_inactive     = true,
        dim_strength     = 0.08,
        blur = {
            enabled = true,
            size    = 6,
            passes  = 2,
        },
        shadow = {
            enabled        = true,
            range          = 24,
            render_power   = 3,
            color          = rgba(C.cyan, "40"),        -- glow-focus halo
            color_inactive = "rgba(00000066)",
        },
    },

    animations = { enabled = true },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = "rgb(" .. C.bg000 .. ")",
    },

})

hl.curve("snap", { type = "bezier", points = { { 0.2, 0.9 }, { 0.1, 1.0 } } })
hl.animation({ leaf = "windows",     enabled = true, speed = 4,  bezier = "snap",    style = "popin 85%" })
hl.animation({ leaf = "fade",        enabled = true, speed = 4,  bezier = "default" })
hl.animation({ leaf = "layers",      enabled = true, speed = 4,  bezier = "snap",    style = "fade" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4,  bezier = "snap",    style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 80, bezier = "default", style = "loop" })

-------------------------------------------------------------------------------
-- layer surfaces (Quickshell) and window rules
-------------------------------------------------------------------------------
for _, ns in ipairs({ "nook-bar", "nook-cheatsheet", "nook-widgets", "nook-launcher", "nook-control" }) do
    hl.layer_rule({ match = { namespace = "^" .. ns .. "$" }, blur = true, ignore_alpha = 0.05 })
end

-- dialogs and pickers float
hl.window_rule({ match = { class = "^(org.kde.polkit-kde-authentication-agent-1|hyprpolkitagent|pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager)$" }, float = true })
hl.window_rule({ match = { title = "^(Open File|Save File|Open Folder|Choose Files?).*$" }, float = true })
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-------------------------------------------------------------------------------
-- gaming: tearing for games, VRR in fullscreen, direct scanout, no lock mid-game
-------------------------------------------------------------------------------
hl.config({
    general = { allow_tearing = true },   -- only windows with `immediate` tear
    misc    = { vrr = 2 },                -- variable refresh rate for fullscreen windows
    render  = { direct_scanout = 2 },     -- skip compositing for fullscreen games
})
-- Steam/Proton games (steam_app_<id>), gamescope, Wine/Lutris .exe windows
hl.window_rule({
    name             = "games",
    match            = { class = "^(steam_app_[0-9]+|gamescope|.*\\.exe)$" },
    immediate        = true,          -- tearing: lowest latency (needs allow_tearing)
    idle_inhibit     = "fullscreen",  -- hypridle doesn't lock while you play fullscreen
    content          = "game",        -- tells direct scanout / VRR it's a game
    no_blur          = true,
    no_dim           = true,
    render_unfocused = true,          -- keeps rendering on the other screen
})
-- Steam's own small windows float
hl.window_rule({ match = { class = "^steam$", title = "^(Friends List|Steam Settings|Properties.*|.* - Chat|Screenshot Manager)$" }, float = true })

-------------------------------------------------------------------------------
-- keybinds  (description = "group: label" → cheatsheet)
-------------------------------------------------------------------------------
local function bind(keys, dsp, desc, opts)
    opts = opts or {}
    opts.description = desc
    hl.bind(keys, dsp, opts)
end
local function M(k) return mod .. " + " .. k end
local function MS(k) return mod .. " + SHIFT + " .. k end

-- apps
bind(M("RETURN"),  hl.dsp.exec_cmd(term),              "apps: terminal")
bind(M("SPACE"),   hl.dsp.exec_cmd(menu),              "apps: hack menu")
bind(M("A"),       hl.dsp.exec_cmd("qs -c nook ipc call control toggle audio"), "apps: control center (sound, net, bt, background apps)")
bind(M("E"),       hl.dsp.exec_cmd(files),             "apps: files")
bind(M("B"),       hl.dsp.exec_cmd(browser),           "apps: browser")
bind(MS("RETURN"), hl.dsp.exec_cmd(term .. " -e btop"), "apps: btop")

-- windows
bind(M("Q"),       hl.dsp.window.close(),                     "windows: close")
bind(M("F"),       hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }),              "windows: fullscreen")
bind(M("V"),       hl.dsp.window.float({ action = "toggle" }), "windows: float / tile")
bind(M("P"),       hl.dsp.window.pseudo(),                    "windows: pseudotile")
bind(M("J"),       hl.dsp.layout("togglesplit"),              "windows: flip split")
for _, d in ipairs({ "left", "up", "right", "down" }) do
    local arrows = { left = "←", up = "↑", right = "→", down = "↓" }
    bind(M(d),  hl.dsp.focus({ direction = d }),       "windows: focus " .. arrows[d])
    bind(MS(d), hl.dsp.window.move({ direction = d }), "windows: move " .. arrows[d])
end
bind(M("mouse:272"), hl.dsp.window.drag(),   "windows: drag = move",   { mouse = true })
bind(M("mouse:273"), hl.dsp.window.resize(), "windows: drag = resize", { mouse = true })

-- workspaces
for i = 1, 9 do
    bind(M(tostring(i)),  hl.dsp.focus({ workspace = i }),       "workspaces: switch to " .. i)
    bind(MS(tostring(i)), hl.dsp.window.move({ workspace = i }), "workspaces: send window to " .. i)
end
bind(M("S"),          hl.dsp.workspace.toggle_special("scratch"),         "workspaces: scratchpad")
bind(MS("S"),         hl.dsp.window.move({ workspace = "special:scratch" }), "workspaces: to scratchpad")
bind(M("mouse_down"), hl.dsp.focus({ workspace = "e+1" }),                "workspaces: next (scroll)")
bind(M("mouse_up"),   hl.dsp.focus({ workspace = "e-1" }),                "workspaces: previous (scroll)")

-- system
bind(M("L"),     hl.dsp.exec_cmd("loginctl lock-session"),                         "system: lock")
bind(M("K"),     hl.dsp.exec_cmd("hyprctl switchxkblayout all next && qs -c nook ipc call kb refresh"),              "system: keyboard eu ⇄ de")
bind("PRINT",    hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'),               "system: screenshot area")
bind(MS("PRINT"), hl.dsp.exec_cmd("grim - | wl-copy"),                            "system: screenshot")
bind(M("slash"), hl.dsp.exec_cmd("qs -c nook ipc call cheatsheet toggle"),         "system: this cheatsheet")
bind(MS("R"),    hl.dsp.exec_cmd("pkill -x qs; qs -c nook"),                       "system: reload shell")
bind(MS("E"),    hl.dsp.exit(),                                                    "system: exit hyprland")
bind(M("G"),     hl.dsp.exec_cmd("nook-gamemode"),                                 "system: game mode on / off")

-- media keys (no description: not on the cheatsheet)
local L = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), L)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), L)
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), L)
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), L)
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
