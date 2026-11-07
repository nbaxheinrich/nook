#!/usr/bin/env python3
"""Nook-Pixel: an old-school 1-bit cursor theme (Win95 / Mac classic), drawn as pixel art and
scaled with hard edges. Writes Xcursor files directly (no xcursorgen, no Pillow).

usage: pixelcursors.py [DEST]     default DEST: ~/.local/share/icons/Nook-Pixel

Shapes are drawn as FILL only: 'o' = white (ink), 'y' = orange sand, 'r' = red, '#' = black.
A 1px black outline is added around every filled pixel automatically, so the classic look
(white body, black border) comes for free. '@' marks the hotspot (and is filled white).
"""
import os
import struct
import sys

INK, BLACK, SAND, RED = 0xFFF2F2F2, 0xFF060606, 0xFFFF9A3C, 0xFFFF6458
COLOURS = {"o": INK, "@": INK, "y": SAND, "r": RED, "#": BLACK}

SHAPES = {
    "default": """
@
oo
ooo
oooo
ooooo
oooooo
ooooooo
oooooooo
ooooooooo
oooooooooo
oooooo
ooo.oo
oo..oo
o....oo
.....oo
......oo
......oo
""",
    "pointer": """
....oo
....oo
....oo
....oo
....oo
....oo#oo#oo
....oo#oo#oo#o
.oo.oo#oo#oo#oo
.ooooooooooooooo
..ooooooooooooo
...oooooooooooo
...ooooooooooo
....oooooooooo
....oooooooooo
.....oooooooo
.....oooooooo
""",
    "text": """
ooo.ooo
...o...
...o...
...o...
...o...
...@...
...o...
...o...
...o...
...o...
...o...
ooo.ooo
""",
    "wait": """
ooooooooooo
.ooooooooo.
.oyyyyyyyo.
..oyyyyyo..
...oyyyo...
....o@o....
....oyo....
...ooyoo...
..ooyyyoo..
.oyyyyyyyo.
.ooooooooo.
ooooooooooo
""",
    "crosshair": """
......o......
......o......
......o......
......o......
......o......
.............
oooooo@oooooo
.............
......o......
......o......
......o......
......o......
......o......
""",
    "not-allowed": """
....rrrrr....
..rrrrrrrrr..
.rrr.....rrr.
.rrrr.....rr.
rr.rrr.....rr
rr..rrr....rr
rr...r@r...rr
rr....rrr..rr
rr.....rrr.rr
.rr.....rrrr.
.rrr.....rrr.
..rrrrrrrrr..
....rrrrr....
""",
    "move": """
......o......
.....ooo.....
....ooooo....
......o......
..o...o...o..
.oo...o...oo.
oooooo@oooooo
.oo...o...oo.
..o...o...o..
......o......
....ooooo....
.....ooo.....
......o......
""",
    "ew-resize": """
...o.......o...
..oo.......oo..
.ooooooooooooo.
ooooooo@ooooooo
.ooooooooooooo.
..oo.......oo..
...o.......o...
""",
    "ns-resize": """
...o...
..ooo..
.ooooo.
ooooooo
..ooo..
..ooo..
..ooo..
..o@o..
..ooo..
..ooo..
..ooo..
ooooooo
.ooooo.
..ooo..
...o...
""",
    "nwse-resize": """
oooooo.....
ooooo......
oooo.......
ooooo......
oo.ooo.....
o...o@o...o
.....ooo.oo
......ooooo
.......oooo
......ooooo
.....oooooo
""",
}
SHAPES["nesw-resize"] = "\n".join(r[::-1] for r in SHAPES["nwse-resize"].strip("\n").split("\n"))

# every X / CSS cursor name → shape
NAMES = {
    "default": ["default", "left_ptr", "arrow", "top_left_arrow", "context-menu", "help", "question_arrow",
                "copy", "alias", "dnd-copy", "dnd-link", "dnd-move", "dnd-none", "cell", "vertical-text", "zoom-in", "zoom-out",
                "left_ptr_help", "whats_this", "progress", "left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f",
                "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599", "d9ce0ab605698f320427677b458ad60b"],
    "pointer": ["pointer", "hand1", "hand2", "pointing_hand", "grab", "openhand", "grabbing", "closedhand",
                "e29285e634086352946a0e7090d73106", "9d800788f1b08800ae810202380a0822"],
    "text": ["text", "xterm", "ibeam"],
    "wait": ["wait", "watch"],
    "crosshair": ["crosshair", "cross", "tcross", "cross_reverse", "diamond_cross", "plus", "color-picker"],
    "not-allowed": ["not-allowed", "crossed_circle", "forbidden", "no-drop", "circle", "03b6e0fcb3499374a867c041f52298f0"],
    "move": ["move", "fleur", "all-scroll", "size_all", "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f"],
    "ew-resize": ["ew-resize", "col-resize", "e-resize", "w-resize", "sb_h_double_arrow", "h_double_arrow",
                  "left_side", "right_side", "size_hor", "split_h", "14fef782d02440884392942c11205230", "028006030e0e7ebffc7f7070c0600140"],
    "ns-resize": ["ns-resize", "row-resize", "n-resize", "s-resize", "sb_v_double_arrow", "v_double_arrow",
                  "top_side", "bottom_side", "size_ver", "split_v", "2870a09082c103050810ffdffffe0204", "00008160000006810000408080010102"],
    "nwse-resize": ["nwse-resize", "nw-resize", "se-resize", "top_left_corner", "bottom_right_corner",
                    "size_fdiag", "bd_double_arrow", "c7088f0f3e6c8088236ef8e1e3e70000"],
    "nesw-resize": ["nesw-resize", "ne-resize", "sw-resize", "top_right_corner", "bottom_left_corner",
                    "size_bdiag", "fd_double_arrow", "fcf1c3c7cd4491d801f1e1c78f100000"],
}

# nominal size → integer pixel scale (hard edges)
SIZES = {16: 1, 24: 2, 32: 2, 48: 3, 64: 4, 96: 6}


def parse(art):
    rows = art.strip("\n").split("\n")
    w = max(len(r) for r in rows) + 2           # 1px border each side for the outline
    h = len(rows) + 2
    grid = [[0] * w for _ in range(h)]
    hot = (1, 1)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in COLOURS:
                grid[y + 1][x + 1] = COLOURS[ch]
            if ch == "@":
                hot = (x + 1, y + 1)
    # outline: every empty pixel next to a filled one (8-neighbourhood) turns black
    out = [row[:] for row in grid]
    for y in range(h):
        for x in range(w):
            if grid[y][x]:
                continue
            if any(0 <= y + dy < h and 0 <= x + dx < w and grid[y + dy][x + dx] not in (0, BLACK)
                   for dy in (-1, 0, 1) for dx in (-1, 0, 1)):
                out[y][x] = BLACK
    return out, hot


def scaled(grid, hot, s):
    h, w = len(grid), len(grid[0])
    pix = []
    for y in range(h * s):
        row = grid[y // s]
        for x in range(w * s):
            pix.append(row[x // s])
    return w * s, h * s, hot[0] * s + s // 2, hot[1] * s + s // 2, pix


def xcursor(images):
    """images: list of (nominal, w, h, xhot, yhot, pixels ARGB). Returns Xcursor file bytes."""
    ntoc = len(images)
    header = struct.pack("<4sIII", b"Xcur", 16, 0x10000, ntoc)
    pos = 16 + ntoc * 12
    toc, chunks = b"", b""
    for nominal, w, h, xh, yh, pix in images:
        chunk = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, nominal, 1, w, h, xh, yh, 0)
        chunk += struct.pack("<%dI" % len(pix), *pix)        # opaque/transparent only: no premultiply needed
        toc += struct.pack("<III", 0xFFFD0002, nominal, pos)
        chunks += chunk
        pos += len(chunk)
    return header + toc + chunks


def main():
    dest = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/.local/share/icons/Nook-Pixel")
    cdir = os.path.join(dest, "cursors")
    os.makedirs(cdir, exist_ok=True)
    for shape, art in SHAPES.items():
        grid, hot = parse(art)
        data = xcursor([(n, *scaled(grid, hot, s)) for n, s in SIZES.items()])
        first, *aliases = NAMES[shape]
        with open(os.path.join(cdir, first), "wb") as f:
            f.write(data)
        for a in aliases:
            p = os.path.join(cdir, a)
            if os.path.lexists(p):
                os.remove(p)
            os.symlink(first, p)
    with open(os.path.join(dest, "index.theme"), "w") as f:
        f.write("[Icon Theme]\nName=Nook-Pixel\nComment=Old-school pixel cursors for nook-tile (Ramen Sign)\n")
    print(f"Nook-Pixel → {dest} ({len(SHAPES)} shapes, sizes {', '.join(map(str, SIZES))})")


if __name__ == "__main__":
    main()
