#!/usr/bin/env python3
"""Generate the Nook Plasma style and Aurorae window decoration from the design tokens.

usage: themegen.py plasma DEST_DIR      → a Plasma/Theme package (panel, tasks, popups, tooltips)
       themegen.py aurorae DEST_DIR     → a KWin/Aurorae package ([_] [□] [x] window frame)

Both are 9-slice SVGs: each frame is nine elements (topleft … center) plus margin hints.
Anything the Plasma style does not draw falls back to Breeze, which follows the colour scheme.
"""
import json
import os
import sys
from pathlib import Path

BG000, BG100, BG200, BG300 = "#1a1614", "#221d1a", "#2a2420", "#372f2a"
LINE, INK, MUTED, FAINT = "#4a3f38", "#f6ece4", "#bfae9f", "#7d6d62"
CORAL, LAVENDER, LILAC, ON_ACCENT = "#f7a59a", "#c4b2f5", "#e2b5f0", "#221d1a"

# NOOK_PALETTE=ramen: Ramen Sign (nook-tile's look) — neutral greys, cyan focus, red accent
if os.environ.get("NOOK_PALETTE") == "ramen":
    BG000, BG100, BG200, BG300 = "#060606", "#0d0d0d", "#141414", "#202020"
    LINE, INK, MUTED, FAINT = "#343434", "#f2f2f2", "#a8a8a8", "#626262"
    CORAL, LAVENDER, LILAC, ON_ACCENT = "#ff6458", "#45c8e6", "#ff6458", "#0d0d0d"


class Doc:
    """An SVG canvas that hands out non-overlapping cells, one per frame."""

    def __init__(self):
        self.parts, self.y = [], 0

    def cell(self, h):
        y = self.y
        self.y += h + 10
        return y

    def add(self, s):
        self.parts.append(s)

    def svg(self, w=400):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{self.y + 10}" '
                f'viewBox="0 0 {w} {self.y + 10}">\n' + "\n".join(self.parts) + "\n</svg>\n")


def frame(doc, prefix, c, fill, fill_opacity=1.0, border=None, radius=0, round_corners="tl tr bl br",
          bar=None, inset_bar=None, margins=None, sides="top right bottom left"):
    """Draw one 9-slice frame.

    c          corner size (also edge thickness) in px
    border     (colour, width, opacity) drawn on all four sides
    radius     corner radius, applied to the corners named in round_corners
    bar        (colour, height) along the whole bottom edge (corners included)
    inset_bar  (colour, height) along the bottom edge only, so it stays clear of the corners
    margins    (top, right, bottom, left) content margins as hint elements
    sides      which sides get the border (square corners only)
    """
    p = f"{prefix}-" if prefix else ""
    s = 3 * c
    y0 = doc.cell(s)
    x0 = 0
    fo = f' fill-opacity="{fill_opacity}"' if fill_opacity < 1 else ""
    bc, bw, bo = border if border else (None, 0, 1)

    def rect(x, y, w, h, color, op=1.0):
        o = f' fill-opacity="{op}"' if op < 1 else ""
        return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"{o}/>'

    # edges
    edges = {
        "top": (x0 + c, y0, c, c), "bottom": (x0 + c, y0 + 2 * c, c, c),
        "left": (x0, y0 + c, c, c), "right": (x0 + 2 * c, y0 + c, c, c),
        "center": (x0 + c, y0 + c, c, c),
    }
    for name, (x, y, w, h) in edges.items():
        g = [rect(x, y, w, h, fill, fill_opacity)]
        if bc and name != "center" and name in sides:
            if name == "top":
                g.append(rect(x, y, w, bw, bc, bo))
            elif name == "bottom":
                g.append(rect(x, y + h - bw, w, bw, bc, bo))
            elif name == "left":
                g.append(rect(x, y, bw, h, bc, bo))
            else:
                g.append(rect(x + w - bw, y, bw, h, bc, bo))
        if name == "bottom" and bar:
            g.append(rect(x, y + h - bar[1], w, bar[1], bar[0]))
        if name == "bottom" and inset_bar:
            g.append(rect(x, y + h - inset_bar[1], w, inset_bar[1], inset_bar[0]))
        doc.add(f'<g id="{p}{name}">{"".join(g)}</g>')

    # corners, drawn as top-left and mirrored
    corners = {"topleft": (0, 0, "tl"), "topright": (1, 0, "tr"),
               "bottomleft": (0, 1, "bl"), "bottomright": (1, 1, "br")}
    pos = {"topleft": (x0, y0), "topright": (x0 + 2 * c, y0),
           "bottomleft": (x0, y0 + 2 * c), "bottomright": (x0 + 2 * c, y0 + 2 * c)}
    for name, (fx, fy, key) in corners.items():
        cx, cy = pos[name]
        r = radius if key in round_corners.split() else 0

        def P(px, py):
            return (cx + (c - px if fx else px), cy + (c - py if fy else py))

        sweep = 1 if fx == fy else 0
        g = []
        if r:
            a, b, d, e = P(0, c), P(0, r), P(r, 0), P(c, 0)
            f2 = P(c, c)
            g.append(f'<path d="M{a[0]},{a[1]} L{b[0]},{b[1]} A{r},{r} 0 0 {sweep} {d[0]},{d[1]} '
                     f'L{e[0]},{e[1]} L{f2[0]},{f2[1]} Z" fill="{fill}"{fo}/>')
            if bc:
                h = bw / 2
                a, b, d, e = P(h, c), P(h, r), P(r, h), P(c, h)
                g.append(f'<path d="M{a[0]},{a[1]} L{b[0]},{b[1]} A{r - h},{r - h} 0 0 {sweep} {d[0]},{d[1]} '
                         f'L{e[0]},{e[1]}" fill="none" stroke="{bc}" stroke-width="{bw}" stroke-opacity="{bo}"/>')
        else:
            g.append(rect(cx, cy, c, c, fill, fill_opacity))
            if bc:
                if ("bottom" if fy else "top") in sides:
                    g.append(rect(cx, cy + (c - bw if fy else 0), c, bw, bc, bo))
                if ("right" if fx else "left") in sides:
                    g.append(rect(cx + (c - bw if fx else 0), cy, bw, c, bc, bo))
        if bar and fy:
            g.append(rect(cx, cy + c - bar[1], c, bar[1], bar[0]))
        doc.add(f'<g id="{p}{name}">{"".join(g)}</g>')

    if margins:
        t, rt, b, lf = margins
        hy = doc.cell(max(margins) + 2)
        for name, size in (("top", t), ("right", rt), ("bottom", b), ("left", lf)):
            w, h = (size, 1) if name in ("left", "right") else (1, size)
            x = {"top": 0, "right": 10, "bottom": 20, "left": 30}[name]
            doc.add(f'<rect id="{p}hint-{name}-margin" x="{x}" y="{hy}" width="{max(w, 1)}" '
                    f'height="{max(h, 1)}" fill="none"/>')


# ── Plasma style ───────────────────────────────────────────────────────────────────

def plasma(dest):
    dest = Path(dest)
    (dest / "widgets").mkdir(parents=True, exist_ok=True)
    (dest / "dialogs").mkdir(parents=True, exist_ok=True)

    # Taskbar: a rounded cocoa pill with a hairline (FrameSvg drops the edge that touches
    # the screen when a maximised window un-floats the panel).
    d = Doc()
    frame(d, "", 8, BG100, 0.97, border=(LINE, 1, 1), radius=8, margins=(4, 6, 4, 6))
    frame(d, "mask", 8, "#000000", radius=8)
    (dest / "widgets/panel-background.svg").write_text(d.svg())

    # Task buttons: hover = bg-300 tile, running = short faint bar, focused = tile + lavender bar,
    # attention = coral bar, minimised = dim bar. Corners are 10px so the bar stays short.
    d = Doc()
    m = (4, 4, 4, 4)
    frame(d, "normal", 10, BG100, 0.0, radius=3, round_corners="tl tr", inset_bar=(FAINT, 2), margins=m)
    frame(d, "minimized", 10, BG100, 0.0, radius=3, round_corners="tl tr", inset_bar=(LINE, 2), margins=m)
    frame(d, "hover", 10, BG300, 0.9, radius=3, round_corners="tl tr", inset_bar=(MUTED, 2), margins=m)
    frame(d, "focus", 10, BG300, 1.0, radius=3, round_corners="tl tr", inset_bar=(LAVENDER, 3), margins=m)
    frame(d, "attention", 10, CORAL, 0.16, radius=3, round_corners="tl tr", inset_bar=(CORAL, 3), margins=m)
    frame(d, "progress", 10, "#a6e6bf", 0.16, radius=3, round_corners="tl tr", margins=m)
    (dest / "widgets/tasks.svg").write_text(d.svg())

    # Popups (launcher, tray, calendar): radius-md, lavender ring = glow-focus.
    d = Doc()
    frame(d, "", 8, BG100, 0.98, border=(LAVENDER, 1, 0.75), radius=6, margins=(10, 10, 10, 10))
    frame(d, "mask", 8, "#000000", radius=6)
    (dest / "dialogs/background.svg").write_text(d.svg())

    # Tooltips and desktop widgets: hairline border.
    for name in ("widgets/tooltip.svg", "widgets/background.svg"):
        d = Doc()
        frame(d, "", 8, BG100, 0.96, border=(LINE, 1, 1), radius=6, margins=(10, 12, 10, 12))
        frame(d, "mask", 8, "#000000", radius=6)
        (dest / name).write_text(d.svg())

    # Highlight behind list items (launcher rows, tray entries): lavender-soft + 1px lavender ring.
    d = Doc()
    for state in ("normal", "hover", "selected", "selected+hover", "pressed"):
        op = {"normal": 0.0, "hover": 0.16, "selected": 0.2, "selected+hover": 0.26, "pressed": 0.3}[state]
        frame(d, state, 4, LAVENDER, op, border=(LAVENDER, 1, 0.0 if state == "normal" else 0.8),
              radius=3, margins=(4, 6, 4, 6))
    (dest / "widgets/viewitem.svg").write_text(d.svg())

    meta = {
        "KPackageStructure": "Plasma/Theme",
        "KPlugin": {
            "Authors": [{"Name": "Nook"}],
            "Category": "Plasma Theme",
            "Description": "Cozy pastel style: cocoa panel, lavender focus, pastel accents",
            "EnabledByDefault": True,
            "Id": "nook",
            "License": "GPL-3.0-or-later",
            "Name": "Nook",
            "Version": "1.0",
        },
        "X-Plasma-API-Minimum-Version": "6.0",
    }
    (dest / "metadata.json").write_text(json.dumps(meta, indent=4) + "\n")
    # No "colors" file: Plasma then takes every colour from the Nook colour scheme.
    (dest / "plasmarc").write_text("[Settings]\nFallbackTheme=default\n\n[ContrastEffect]\nenabled=false\n")


# ── Aurorae window decoration ──────────────────────────────────────────────────────

BTN_W, BTN_H = 40, 30


def glyph(kind, color):
    """Bracketed glyphs: [_] [□] [x] … drawn as strokes so no font is needed."""
    sw = 1.6
    cx, cy = BTN_W / 2, BTN_H / 2
    br = (f'<path d="M{cx-11},{cy-6} h-3 v12 h3 M{cx+11},{cy-6} h3 v12 h-3" fill="none" '
          f'stroke="{color}" stroke-width="{sw}" stroke-opacity="0.55"/>')
    k = {
        "minimize": f'<path d="M{cx-5},{cy+5} h10" stroke="{color}" stroke-width="{sw+0.4}"/>',
        "maximize": f'<rect x="{cx-5}" y="{cy-5}" width="10" height="10" fill="none" stroke="{color}" stroke-width="{sw}"/>',
        "restore": (f'<rect x="{cx-6}" y="{cy-3}" width="8" height="8" fill="none" stroke="{color}" stroke-width="{sw}"/>'
                    f'<path d="M{cx-3},{cy-3} v-3 h8 v8 h-3" fill="none" stroke="{color}" stroke-width="{sw}"/>'),
        "close": f'<path d="M{cx-5},{cy-5} L{cx+5},{cy+5} M{cx+5},{cy-5} L{cx-5},{cy+5}" stroke="{color}" stroke-width="{sw+0.2}"/>',
        "alldesktops": f'<circle cx="{cx}" cy="{cy}" r="3.5" fill="{color}"/>',
        "keepabove": f'<path d="M{cx-5},{cy+3} L{cx},{cy-3} L{cx+5},{cy+3}" fill="none" stroke="{color}" stroke-width="{sw}"/>',
        "keepbelow": f'<path d="M{cx-5},{cy-3} L{cx},{cy+3} L{cx+5},{cy-3}" fill="none" stroke="{color}" stroke-width="{sw}"/>',
        "shade": f'<path d="M{cx-5},{cy-4} h10 M{cx-5},{cy} h10" stroke="{color}" stroke-width="{sw}"/>',
        "help": f'<path d="M{cx-3},{cy-3} a3,3 0 1 1 3,3 v2 M{cx},{cy+5} v0.5" fill="none" stroke="{color}" stroke-width="{sw}"/>',
    }[kind]
    return br + k


def button(kind):
    states = {
        "active": (None, MUTED),
        "hover": (CORAL if kind == "close" else BG300, ON_ACCENT if kind == "close" else INK),
        "pressed": (CORAL if kind == "close" else LAVENDER, ON_ACCENT),
        "inactive": (None, FAINT),
        "deactivated": (None, LINE),
    }
    parts, y = [], 0
    for state, (bg, fg) in states.items():
        inner = f'<rect width="{BTN_W}" height="{BTN_H}" fill="{bg or "#000000"}" fill-opacity="{1 if bg else 0}"' \
                f'{" rx=\"3\"" if bg else ""}/>' + glyph(kind, fg)
        parts.append(f'<g id="{state}-center" transform="translate(0,{y})">{inner}</g>')
        y += BTN_H + 10
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{BTN_W}" height="{y}" viewBox="0 0 {BTN_W} {y}">\n'
            + "\n".join(parts) + "\n</svg>\n")


def aurorae(dest):
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    d = Doc()
    # active: lavender ring (focus); inactive: hairline. Square corners: KWin draws the frame edges
    # through the corner cells, so a rounded corner shows a stray square outline behind it.
    frame(d, "decoration", 6, BG100, border=(LAVENDER, 1, 1))
    frame(d, "decoration-inactive", 6, BG100, border=(LINE, 1, 1))
    frame(d, "decoration-maximized", 6, BG100)
    frame(d, "decoration-maximized-inactive", 6, BG000)
    (dest / "decoration.svg").write_text(d.svg())
    for kind in ("minimize", "maximize", "restore", "close", "alldesktops", "keepabove", "keepbelow",
                 "shade", "help"):
        (dest / f"{kind}.svg").write_text(button(kind))
    rgb = lambda h: ",".join(str(int(h[i:i + 2], 16)) for i in (1, 3, 5))  # noqa: E731
    (dest / "Nookrc").write_text(f"""[General]
ActiveTextColor={rgb(INK)}
InactiveTextColor={rgb(MUTED)}
TitleAlignment=Left
TitleVerticalAlignment=Center
UseTextShadow=false
Shadow=true
Animation=120
LeftButtons=M
RightButtons=IAX

[Layout]
BorderLeft=1
BorderRight=1
BorderBottom=1
TitleEdgeTop=1
TitleEdgeBottom=1
TitleEdgeLeft=8
TitleEdgeRight=2
TitleEdgeTopMaximized=0
TitleEdgeBottomMaximized=0
TitleEdgeLeftMaximized=8
TitleEdgeRightMaximized=0
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={BTN_H}
ButtonWidth={BTN_W}
ButtonHeight={BTN_H}
ButtonSpacing=2
ButtonMarginTop=0
ExplicitButtonSpacer=8
PaddingTop=0
PaddingBottom=0
PaddingLeft=0
PaddingRight=0
""")
    meta = {
        "KPackageStructure": "KWin/Aurorae",
        "KPlugin": {
            "Authors": [{"Name": "Nook"}],
            "Category": "Plasma Window Decorations",
            "Description": "Cocoa title bar, lavender focus ring, [_] [□] [x] buttons",
            "EnabledByDefault": True,
            "Id": "Nook",
            "License": "GPL-3.0-or-later",
            "Name": "Nook",
            "Version": "1.0",
        },
    }
    (dest / "metadata.json").write_text(json.dumps(meta, indent=4) + "\n")
    (dest / "metadata.desktop").write_text(
        "[Desktop Entry]\nName=Nook\nX-KDE-PluginInfo-Name=Nook\n"
        "X-KDE-PluginInfo-Version=1.0\nX-KDE-PluginInfo-License=GPL\n"
        "X-KDE-PluginInfo-EnabledByDefault=true\nX-Plasma-API=javascript\n"
        "X-KDE-ServiceTypes=KWin/Aurorae\n")


if __name__ == "__main__":
    {"plasma": plasma, "aurorae": aurorae}[sys.argv[1]](sys.argv[2])
