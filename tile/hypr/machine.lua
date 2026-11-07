-- ── this machine ────────────────────────────────────────────────────────────
-- Monitors and keyboard. install.sh copies this ONCE to ~/.config/hypr/machine.lua
-- and never overwrites it, so change it there. `hyprctl monitors` lists outputs.

-- DP-2: 2560x1440 landscape, primary, on the left
hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- DP-1: rotated to portrait (KDE "Right" = transform 3, i.e. 270°), on the right.
-- If it comes up upside down, use transform = 1.
hl.monitor({ output = "DP-1", mode = "2560x1440@200", position = "2560x0", scale = 1, transform = 3 })

-- anything else that gets plugged in
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.config({
    input = {
        kb_layout    = "eu,de",         -- EurKEY and German; SUPER K or the bar's kb pill switches
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad     = { natural_scroll = true },
    },
})

-- workspaces 1–5 on the main screen, 6–9 on the portrait one
for i = 1, 9 do
    hl.workspace_rule({ workspace = tostring(i), monitor = i <= 5 and "DP-2" or "DP-1", default = (i == 1 or i == 6) })
end
