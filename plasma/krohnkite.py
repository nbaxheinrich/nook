#!/usr/bin/env python3
"""Patch Krohnkite's tile layout to start top/bottom on portrait screens.

Krohnkite only has one global rotation for its tile layout. This gives the layout an extra
quarter turn wherever the tiling area is taller than wide: the master goes on top and the
stack below it, side by side. Meta+Ctrl+Space still rotates from there. Safe to re-run.

usage: krohnkite.py SCRIPT_JS
"""
import sys
from pathlib import Path

MARKER = "// nook: portrait"

OLD = """    adjust(area, tiles, basis, delta, gap) {
        this.parts.adjust(area, tiles, basis, delta, gap);
    }
    apply(ctx, tileables, area, gap) {
        tileables.forEach((tileable) => (tileable.state = WindowState.Tiled));
        this.parts.apply(area, tileables, gap).forEach((geometry, i) => {
            tileables[i].geometry = geometry;
        });
    }
"""

NEW = """    adjust(area, tiles, basis, delta, gap) {
        this.portrait(area, () => this.parts.adjust(area, tiles, basis, delta, gap));
    }
    apply(ctx, tileables, area, gap) {
        tileables.forEach((tileable) => (tileable.state = WindowState.Tiled));
        this.portrait(area, () => this.parts.apply(area, tileables, gap)).forEach((geometry, i) => {
            tileables[i].geometry = geometry;
        });
    }
    // nook: portrait areas get a quarter turn on top of the layout's own rotation
    portrait(area, fn) {
        const angle = this.parts.angle;
        if (area.height > area.width) this.parts.angle = (angle + 90) % 360;
        try { return fn(); } finally { this.parts.angle = angle; }
    }
"""


def main(path):
    script = Path(path)
    text = script.read_text()
    if MARKER in text:
        return
    start = text.index("class TileLayout {")
    at = text.find(OLD, start)
    end = text.find("\nclass ", start + 1)
    if at == -1 or at > end:
        sys.exit("Krohnkite's TileLayout changed; portrait patch not applied")
    script.write_text(text[:at] + NEW + text[at + len(OLD):])


if __name__ == "__main__":
    main(sys.argv[1])
