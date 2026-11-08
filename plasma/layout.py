#!/usr/bin/env python3
"""Lay out the Nook desktop widgets on every screen, around what the wallpaper draws.

Reads one line per screen on stdin:  <containment id> <screen> <width> <height> <wallpaper.json>
and prints a Plasma script that (re)places the clock, system and apps cards on each desktop.

Everything sits on Plasma's 16px widget grid, the same grid the wallpaper cards are snapped to,
so widget frames land exactly where they are asked to and line up with the cards.

Landscape: the wallpaper owns the right-hand column (cheat-sheet, whoami) and the banner bottom-right.
           The widgets fill the left in two rows lined up with that column: clock + apps level with
           the cheat-sheet, then the system card from the whoami card's top down to above the banner.
Portrait:  the wallpaper owns the top (cheat-sheet, whoami) and the bottom (banner), so the widgets
           stack in the band between them, as wide as the cards: clock, apps, system.

usage: layout.py APPS_JSON MENU_COMMAND PANEL_RESERVE remove|add < screens

Run "remove" first and "add" a moment later: widgets removed in the same script still hold their
spot while they fade out, and Plasma would shove the new ones aside.
"""
import json
import sys

WIDGETS = ("org.nook.clock", "org.nook.sys", "org.nook.apps")


GRID = 16
GAP = 2 * GRID  # the wallpaper's gap between its cards


def down(v):
    return v // GRID * GRID


def landscape(w, h, box, reserve):
    cx, cy, _, ch = box["cheat"]
    wy = box["whoami"][1]
    bx, by = box["banner"][:2]
    left, right = cy, cx - GAP  # same margin as the cheat-sheet has from the top edge
    apps_w = min(down(ch), down((right - left - GAP) * 0.45))
    clock_w = right - left - GAP - apps_w
    # the system card stops above the banner if the banner reaches under it
    bottom = down(by - GAP) if bx < right else down(h - reserve - left)
    return [
        ("org.nook.clock", left, cy, clock_w, ch),
        ("org.nook.apps", left + clock_w + GAP, cy, apps_w, ch),
        ("org.nook.sys", left, wy, right - left, max(10 * GRID, bottom - wy)),
    ]


def portrait(w, h, box, reserve):
    x, _, cw, _ = box["cheat"]
    _, wy, _, wh = box["whoami"]
    top = wy + wh + GAP
    bottom = down(min(box["banner"][1], h - reserve) - GAP)
    avail = bottom - top - 2 * GAP
    clock_h, apps_h = down(avail * 0.27), down(avail * 0.40)
    sizes = {"clock": clock_h, "apps": apps_h, "sys": avail - clock_h - apps_h}
    y, out = top, []
    for name in ("clock", "apps", "sys"):
        out.append((f"org.nook.{name}", x, y, cw, sizes[name]))
        y += sizes[name] + GAP
    return out


def main():
    apps_json, menu_cmd, reserve, mode = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
    js = ["var d, w;"]
    for line in sys.stdin:
        if not line.strip():
            continue
        cid, screen, w, h, box_file = line.split(maxsplit=4)
        w, h = int(w), int(h)
        box = json.load(open(box_file.strip()))
        res = reserve * box["scale"] if screen == "0" else 0
        place = portrait(w, h, box, res) if box["portrait"] else landscape(w, h, box, res)
        js.append(f"d = desktopById({cid});")
        if mode == "remove":
            js.append("d.widgets().forEach(function (x) { if (%s.indexOf(x.type) >= 0) x.remove(); });"
                      % json.dumps(list(WIDGETS)))
            continue
        for plugin, x, y, ww, hh in place:
            js.append(f"w = d.addWidget('{plugin}', {round(x)}, {round(y)}, {round(ww)}, {round(hh)});")
            if plugin.endswith(".apps"):
                js.append("w.currentConfigGroup = ['General'];")
                js.append(f"w.writeConfig('apps', {json.dumps(apps_json)});")
                js.append(f"w.writeConfig('menuCommand', {json.dumps(menu_cmd)});")
    print("\n".join(js))


if __name__ == "__main__":
    main()
