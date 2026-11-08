#!/usr/bin/env python3
"""Render the Nook wallpaper: dot grid, faint skull, a key cheat-sheet built from
config/shortcuts.conf, a system card and the rainbow NOOK banner.

usage: wallpaper.py CONF OUT.svg WIDTHxHEIGHT "Font Family" [panel_height] [--no-skull]

Also writes OUT.json with the boxes of the cards and the banner.
"""
import itertools
import json
import math
import os
import platform
import socket
import sys
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, str(Path(__file__).parent))
from shortcuts import parse  # noqa: E402

BG000, BG100, BG200, BG300 = "#1a1614", "#221d1a", "#2a2420", "#372f2a"
LINE, INK, MUTED, FAINT = "#4a3f38", "#f6ece4", "#bfae9f", "#7d6d62"
HUES = ["#f5a8c9", "#f7a59a", "#f9c49a", "#f2e29b", "#a6e6bf", "#94dcd6", "#a3cdf5", "#c4b2f5", "#e2b5f0"]
PINK, CORAL, PEACH, BUTTER, MINT, TEAL, SKY, LAVENDER, LILAC = HUES

# NOOK_PALETTE=ramen: Ramen Sign — neutral greys and the neons (role names stay the pastel ones)
if os.environ.get("NOOK_PALETTE") == "ramen":
    BG000, BG100, BG200, BG300 = "#060606", "#0d0d0d", "#141414", "#202020"
    LINE, INK, MUTED, FAINT = "#343434", "#f2f2f2", "#a8a8a8", "#626262"
    HUES = ["#ff7a5c", "#ff6458", "#ff9a3c", "#ffc247", "#4fd8cf", "#45c8e6", "#62a5ff", "#ffb14a", "#ffd98f"]
    PINK, CORAL, PEACH, BUTTER, MINT, TEAL, SKY, LAVENDER, LILAC = HUES
GROUP_HUE = {"apps": MINT, "session": LILAC, "windows": SKY, "desktop": LAVENDER, "tools": PEACH}

BANNER = """\
███╗   ██╗ ██████╗  ██████╗ ██╗  ██╗
████╗  ██║██╔═══██╗██╔═══██╗██║ ██╔╝
██╔██╗ ██║██║   ██║██║   ██║█████╔╝ 
██║╚██╗██║██║   ██║██║   ██║██╔═██╗ 
██║ ╚████║╚██████╔╝╚██████╔╝██║  ██╗
╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝""".splitlines()

SKULL = """\
    _______
   /       \\
  |  ▄   ▄  |
  |  ▀   ▀  |
   \\   ▲   /
    |╻╻╻╻╻|
    ╰┴┴┴┴┴╯""".splitlines()

CAT = """\
 /\\_/\\
( o.o )
 > ^ <
/  λ  \\""".splitlines()

ADV = 0.6  # JetBrains Mono advance width, in em


def osrel():
    try:
        d = dict(l.split("=", 1) for l in Path("/etc/os-release").read_text().splitlines() if "=" in l)
        return d.get("PRETTY_NAME", "linux").strip('"')
    except OSError:
        return "linux"


class Svg:
    def __init__(self, w, h, font):
        self.w, self.h, self.font = w, h, font
        self.out = []

    def add(self, s):
        self.out.append(s)

    def text(self, x, y, s, size, fill, weight=400, anchor="start", spacing=0, opacity=1, family=None):
        fam = family or self.font
        self.add(f'<text x="{x:.1f}" y="{y:.1f}" font-family="{fam}" font-size="{size:.1f}" '
                 f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" '
                 f'letter-spacing="{spacing:.2f}" opacity="{opacity}" xml:space="preserve">{escape(s)}</text>')

    def rect(self, x, y, w, h, fill="none", stroke="none", r=0, sw=1, opacity=1):
        self.add(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r}" fill="{fill}" '
                 f'stroke="{stroke}" stroke-width="{sw}" opacity="{opacity}"/>')

    def render(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
                f'viewBox="0 0 {self.w} {self.h}">\n' + "\n".join(self.out) + "\n</svg>\n")


def split_columns(groups, n):
    """Split ordered groups into n columns (order kept) so the tallest column is as short as possible."""
    sizes = [len(g[1]) + 1.6 for g in groups]
    best = None
    for cuts in itertools.combinations(range(1, len(groups)), n - 1):
        bounds = (0, *cuts, len(groups))
        tallest = max(sum(sizes[a:b]) for a, b in zip(bounds, bounds[1:]))
        if best is None or tallest < best[0]:
            best = (tallest, [groups[a:b] for a, b in zip(bounds, bounds[1:])])
    return best[1]


# Plasma snaps desktop widgets to a 16px grid, so the cards sit on it too and widgets can line up with them.
GRID = 16


def snap(v):
    return round(v / GRID) * GRID


def grow(v):
    return math.ceil(v / GRID) * GRID


def main():
    conf, out, size, font = sys.argv[1:5]
    panel = int(sys.argv[5]) if len(sys.argv) > 5 else 44
    no_skull = "--no-skull" in sys.argv
    W, H = map(int, size.lower().split("x"))
    portrait = H > W  # rotated monitors get a centred, stacked layout
    s = min(W, H) / 1440  # design is drawn at 1440p and scaled
    family = f"'{font}', 'JetBrains Mono', monospace"
    pixel = "'VT323', " + family
    svg = Svg(W, H, family)

    # ground + dot grid
    pitch = 24 * s
    svg.add(f'<defs><pattern id="dots" width="{pitch:.2f}" height="{pitch:.2f}" patternUnits="userSpaceOnUse">'
            f'<circle cx="{pitch/2:.2f}" cy="{pitch/2:.2f}" r="{1.3*s:.2f}" fill="{LINE}"/></pattern></defs>')
    svg.rect(0, 0, W, H, fill=BG000)
    svg.rect(0, 0, W, H, fill="url(#dots)")


    # ── cheat-sheet card (top right) ─────────────────────────────────────────
    rows = parse(conf)
    groups = []
    for r in rows:
        if not groups or groups[-1][0] != r["group"]:
            groups.append((r["group"], []))
        groups[-1][1].append(r)

    body = 15 * s
    row_h = 27 * s
    pad = 24 * s
    key_w = max(len(r["keys"]) for r in rows) * body * ADV + 18 * s
    label_w = max(len(r["label"]) for r in rows) * body * ADV
    col_w = key_w + 14 * s + label_w + 24 * s
    col_gap = 36 * s
    header_h = 54 * s
    # three columns keep the card short, so the widgets beside it are not stretched;
    # two when three would take more than about half of the screen's width
    for n in (3, 2):
        cols = split_columns(groups, min(n, len(groups)))
        card_w = grow(pad * 2 + col_w * len(cols) + col_gap * (len(cols) - 1))
        if card_w <= W * (0.9 if portrait else 0.55):
            break
    card_h = grow(header_h + max(sum(len(g[1]) + 1.6 for g in col) for col in cols) * row_h + pad)
    if portrait:
        cx, cy = snap((W - card_w) / 2), snap(H * 0.10)
    else:
        cx, cy = W - card_w - snap(48 * s), snap(48 * s)

    svg.rect(cx, cy, card_w, card_h, fill=BG100, stroke=LINE, r=6 * s, sw=max(1, s), opacity=0.94)
    svg.rect(cx, cy, 3 * s, card_h, fill=LAVENDER)
    svg.text(cx + pad, cy + 34 * s, "KEYS // CHEATSHEET", 12 * s, LAVENDER, 700, spacing=1.6 * s)
    svg.text(cx + card_w - pad, cy + 34 * s, "λ nook-keys  ·  meta+/", 12 * s, MUTED, anchor="end")
    svg.add(f'<line x1="{cx+pad:.1f}" y1="{cy+header_h-8*s:.1f}" x2="{cx+card_w-pad:.1f}" '
            f'y2="{cy+header_h-8*s:.1f}" stroke="{LINE}" stroke-width="{max(1, s):.1f}" stroke-dasharray="{4*s:.1f} {4*s:.1f}"/>')

    for ci, col in enumerate(cols):
        x = cx + pad + ci * (col_w + col_gap)
        y = cy + header_h + row_h * 0.6
        for name, items in col:
            hue = GROUP_HUE.get(name, INK)
            svg.text(x, y, f"{name.upper()} //", 11 * s, hue, 700, spacing=1.4 * s)
            y += row_h * 0.9
            for r in items:
                chip_w = len(r["keys"]) * body * ADV + 14 * s
                svg.rect(x, y - body * 1.05, chip_w, body * 1.45, fill=hue, r=3 * s, opacity=0.16)
                svg.text(x + 7 * s, y, r["keys"], body, hue, 700)
                lead_x = x + chip_w + 6 * s
                lx = x + key_w + 14 * s
                dots = max(0, int((lx - lead_x - 6 * s) / (body * ADV)))
                svg.text(lead_x, y, "." * dots, body, FAINT)
                svg.text(lx, y, r["label"], body, INK if r["cmd"] else MUTED)
                y += row_h
            y += row_h * 0.7

    # ── system card (below the cheat-sheet) ──────────────────────────────────
    host = socket.gethostname().split(".")[0]
    user = os.environ.get("USER", "root")
    sys_lines = [
        (LILAC, f"{user}@{host}"),
        (SKY, osrel().lower()),
        (LAVENDER, f"kernel {platform.release()}"),
        (MINT, "λ ~/ > make yourself at home"),
    ]
    sy0 = cy + card_h + 2 * GRID
    sc_h = grow(54 * s + len(sys_lines) * 26 * s + 40 * s)
    svg.rect(cx, sy0, card_w, sc_h, fill=BG100, stroke=LINE, r=6 * s, sw=max(1, s), opacity=0.94)
    svg.rect(cx, sy0, 3 * s, sc_h, fill=LILAC)
    svg.text(cx + pad, sy0 + 34 * s, "SYS // WHOAMI", 12 * s, LILAC, 700, spacing=1.6 * s)
    for i, (hue, line) in enumerate(sys_lines):
        svg.text(cx + pad, sy0 + 70 * s + i * 26 * s, line, (24 if i == 0 else 15) * s,
                 hue, 400 if i == 0 else 400, family=pixel if i == 0 else None)
    # palette swatches
    sw_y = sy0 + sc_h - 30 * s
    for i, h in enumerate(HUES):
        svg.rect(cx + pad + i * 22 * s, sw_y, 16 * s, 12 * s, fill=h, r=2 * s)
    # cat, bottom-right of the system card
    for i, line in enumerate(CAT):
        svg.text(cx + card_w - pad - 7 * 13 * s * ADV, sy0 + 62 * s + i * 15 * s, line, 13 * s, FAINT)

    # ── rainbow banner (lower right, above the taskbar) ──────────────────────
    # faint skull: centre-left of the free area, or under the cards on a portrait screen
    fs = 30 * s
    if portrait:
        sx, sy = W / 2 - 7 * fs * ADV, sy0 + sc_h + (H - sy0 - sc_h) * 0.30
    else:
        sx, sy = W * 0.36, H * 0.30
    if not no_skull:
        for i, line in enumerate(SKULL):
            svg.text(sx, sy + i * fs * 1.25, line, fs, FAINT, opacity=0.55)

    bf = min(32 * s, (W * (0.9 if portrait else 0.55)) / (len(BANNER[0]) * ADV))
    bw = len(BANNER[0]) * bf * ADV
    lh = bf * 1.18
    bx = (W - bw) / 2 if portrait else W - bw - 48 * s
    by = H - panel * s - 64 * s - lh * (len(BANNER) - 1)
    # lolcat-style: one diagonal sweep through the nine hues across the whole banner
    svg.add(f'<defs><linearGradient id="banner" gradientUnits="userSpaceOnUse" x1="{bx:.1f}" y1="{by - bf:.1f}" '
            f'x2="{bx + bw:.1f}" y2="{by + lh * len(BANNER) + bw * 0.25:.1f}">'
            + "".join(f'<stop offset="{i/8:.3f}" stop-color="{c}"/>' for i, c in enumerate(HUES))
            + '</linearGradient></defs>')
    svg.add('<g fill="url(#banner)">')
    for i, line in enumerate(BANNER):
        svg.add(f'<text x="{bx:.1f}" y="{by + i*lh:.1f}" font-family="{family}" font-size="{bf:.1f}" '
                f'xml:space="preserve">{escape(line)}</text>')
    svg.add("</g>")
    Path(out).write_text(svg.render())
    # Where the cards and the banner landed, so apply.sh can place desktop widgets around them.
    Path(out).with_suffix(".json").write_text(json.dumps({
        "size": [W, H], "scale": s, "portrait": portrait,
        "cards": [round(cx), round(cy), round(card_w), round(sy0 + sc_h - cy)],
        "cheat": [cx, cy, card_w, card_h],
        "whoami": [cx, sy0, card_w, sc_h],
        "banner": [round(bx), round(by - bf), round(bw), round(lh * len(BANNER) + bf)],
    }))


if __name__ == "__main__":
    main()
