#!/usr/bin/env python3
"""Repaint Posy's cursors (Michiel de Boer's design, Linux port by simtrami, CC BY-NC 4.0) in the
Nook palette, keeping every shape as it is.

Greys run from cocoa to cream instead of black to white: the arrow is cocoa with a cream outline.
Coloured pixels (the spinning wait wheel, the red "not allowed" sign) take the pastel nearest to
their hue, shaded by how bright they were.

usage: cursors.py SRC_THEME_DIR OUT_THEME_DIR NAME
"""
import colorsys
import os
import shutil
import struct
import sys
from pathlib import Path

DARK, LIGHT = (0x1A, 0x16, 0x14), (0xF6, 0xEC, 0xE4)
HUES = ["#f5a8c9", "#f7a59a", "#f9c49a", "#f2e29b", "#a6e6bf", "#94dcd6", "#a3cdf5", "#c4b2f5", "#e2b5f0"]
PASTELS = [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in HUES]
IMAGE = 0xFFFD0002


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def nearest_pastel(hue):
    def dist(c):
        h = colorsys.rgb_to_hsv(*(v / 255 for v in c))[0]
        d = abs(h - hue)
        return min(d, 1 - d)
    return min(PASTELS, key=dist)


def paint(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if s < 0.2:
        return lerp(DARK, LIGHT, (r + g + b) / 765)
    return lerp(DARK, nearest_pastel(h), min(1, v * 1.15))


def recolour(data):
    """Rewrite the ARGB pixels of every image chunk in an Xcursor file."""
    buf = bytearray(data)
    if buf[:4] != b"Xcur":
        return data
    (count,) = struct.unpack_from("<I", buf, 12)
    cache = {}
    for i in range(count):
        kind, _, pos = struct.unpack_from("<III", buf, 16 + 12 * i)
        if kind != IMAGE:
            continue
        width, height = struct.unpack_from("<II", buf, pos + 16)
        start = pos + 36
        for p in range(start, start + 4 * width * height, 4):
            b, g, r, a = buf[p:p + 4]
            if not a:
                continue
            key = (r, g, b, a)
            if key not in cache:
                # pixels are premultiplied: unpremultiply, repaint, premultiply again
                rgb = paint(*(min(255, round(c * 255 / a)) for c in (r, g, b)))
                nr, ng, nb = (round(c * a / 255) for c in rgb)
                cache[key] = bytes((nb, ng, nr, a))
            buf[p:p + 4] = cache[key]
    return bytes(buf)


def main():
    src, out, name = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    shutil.rmtree(out, ignore_errors=True)
    (out / "cursors").mkdir(parents=True)
    for f in sorted((src / "cursors").iterdir()):
        dst = out / "cursors" / f.name
        if f.is_symlink():
            os.symlink(os.readlink(f), dst)
        else:
            dst.write_bytes(recolour(f.read_bytes()))
    (out / "index.theme").write_text(
        f"[Icon Theme]\nName={name}\nComment=Posy's improved cursors in the Nook palette\n"
        "Example=left_ptr\n")
    (out / "README").write_text(
        "Posy's Cursor by Michiel de Boer (http://www.michieldb.nl/other/cursors/), ported to Linux by\n"
        "simtrami (https://github.com/simtrami/posy-improved-cursor-linux), licensed CC BY-NC 4.0\n"
        "(https://creativecommons.org/licenses/by-nc/4.0/). Recoloured by Nook's cursors.py.\n")
    print(f"{name}: {sum(1 for _ in (out / 'cursors').iterdir())} cursors")


if __name__ == "__main__":
    main()
