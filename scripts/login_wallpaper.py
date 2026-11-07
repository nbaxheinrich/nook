#!/usr/bin/env python3
"""Render the Ramen Sign login wallpaper (Plasma Login): bg-000 ground, dot grid, scanlines,
the NOOK banner glowing through the nine neons (fire → ice), and a shell line under it.

usage: login_wallpaper.py OUT.svg WIDTHxHEIGHT "Font Family"
Render with: rsvg-convert OUT.svg -o OUT.png
"""
import sys
from xml.sax.saxutils import escape

BG000, LINE, FAINT, MUTED = "#060606", "#343434", "#626262", "#a8a8a8"
NEONS = ["#ff7a5c", "#ff6458", "#ff9a3c", "#ffc247", "#4fd8cf", "#45c8e6", "#62a5ff", "#ffb14a", "#ffd98f"]
AQUA, CYAN = "#4fd8cf", "#45c8e6"

BANNER = """\
███╗   ██╗ ██████╗  ██████╗ ██╗  ██╗
████╗  ██║██╔═══██╗██╔═══██╗██║ ██╔╝
██╔██╗ ██║██║   ██║██║   ██║█████╔╝
██║╚██╗██║██║   ██║██║   ██║██╔═██╗
██║ ╚████║╚██████╔╝╚██████╔╝██║  ██╗
╚═╝  ╚═══╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝""".splitlines()


def main():
    out, size, font = sys.argv[1], sys.argv[2], sys.argv[3]
    w, h = map(int, size.split("x"))
    s = min(w / 2560, h / 1440)                     # scale from the 2560×1440 layout
    fam = escape(f"'{font}', 'JetBrains Mono', monospace")
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
        "<defs>",
        f'<pattern id="dots" width="24" height="24" patternUnits="userSpaceOnUse">'
        f'<rect x="12" y="12" width="2" height="2" fill="#1e1e1e"/></pattern>',
        '<pattern id="scan" width="3" height="3" patternUnits="userSpaceOnUse">'
        '<rect width="3" height="1" fill="#ffffff" fill-opacity="0.018"/></pattern>',
        '<filter id="glow" x="-20%" y="-40%" width="140%" height="180%">'
        f'<feGaussianBlur in="SourceGraphic" stdDeviation="{10 * s:.1f}" result="b"/>'
        '<feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>',
        # a faint cyan neon haze behind the sign
        f'<radialGradient id="haze" cx="50%" cy="50%" r="50%">'
        f'<stop offset="0" stop-color="{CYAN}" stop-opacity="0.10"/><stop offset="1" stop-color="{CYAN}" stop-opacity="0"/></radialGradient>',
        "</defs>",
        f'<rect width="{w}" height="{h}" fill="{BG000}"/>',
        f'<rect width="{w}" height="{h}" fill="url(#dots)"/>',
    ]

    # banner: bottom-right like the desktop, rows fire → ice, 5-column bands shifting per row
    px = 30 * s
    cw, lh = px * 0.6, px * 1.0
    bw, bh = len(BANNER[0]) * cw, len(BANNER) * lh
    x0, y0 = w - 120 * s - bw, h - 150 * s - bh
    parts.append(f'<ellipse cx="{x0 + bw / 2:.0f}" cy="{y0 + bh / 2:.0f}" rx="{bw * 0.9:.0f}" ry="{bh * 1.6:.0f}" fill="url(#haze)"/>')
    parts.append(f'<g filter="url(#glow)" font-family="{fam}" font-size="{px:.1f}" xml:space="preserve">')
    for r, row in enumerate(BANNER):
        y = y0 + (r + 0.8) * lh
        band, start = None, 0
        for c in range(len(row) + 1):
            k = None if c == len(row) else ((c + 2 * r) // 5) % 9
            if k != band:
                if band is not None and row[start:c].strip():
                    parts.append(f'<text x="{x0 + start * cw:.1f}" y="{y:.1f}" fill="{NEONS[band]}" '
                                 f'textLength="{(c - start) * cw:.1f}" lengthAdjust="spacingAndGlyphs">{escape(row[start:c])}</text>')
                band, start = k, c
    parts.append("</g>")

    # the shell line under it
    fs = 18 * s
    ty = y0 + bh + 48 * s
    parts.append(
        f'<text x="{x0:.1f}" y="{ty:.1f}" font-family="{fam}" font-size="{fs:.1f}" xml:space="preserve">'
        f'<tspan fill="{AQUA}" font-weight="700">λ ~/</tspan><tspan fill="{FAINT}"> &gt; </tspan>'
        f'<tspan fill="{MUTED}">login</tspan><tspan fill="{FAINT}">      # cozy, colourful, slightly dangerous-looking</tspan></text>')
    parts.append(f'<rect x="{x0 + 12.4 * fs * 0.6:.1f}" y="{ty - fs * 0.85:.1f}" width="{fs * 0.6:.1f}" height="{fs:.1f}" fill="{AQUA}"/>')

    parts.append(f'<rect width="{w}" height="{h}" fill="url(#scan)"/>')
    parts.append("</svg>")
    with open(out, "w") as f:
        f.write("\n".join(parts))


if __name__ == "__main__":
    main()
