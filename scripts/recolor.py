#!/usr/bin/env python3
"""Recolour installed Nook files from the cocoa pastels to Ramen Sign, in place.

usage: recolor.py PATH…        (files, or folders: every text file inside is done)

One table, used by apply.sh --ramen for everything that has the palette written into it:
the Plasma widgets, the logout screen, Konsole, btop, cava, bat, git/delta, fzf, Zed, Brave,
the zsh prompt, the rice's own icons. Hex colours (#rrggbb in any case, #rrggbbaa, #aarrggbb)
and "r,g,b" triples (KDE colour files) are both replaced. Role names stay the pastel ones:
  cocoa grounds → neutral greys · ink/muted/faint → the Ramen greys
  pink (media) → rose · peach (time) → red, the accent · coral (danger) → orange
  butter → gold · mint → aqua · teal → cyan · sky → blue
  lavender (focus) → cyan, the focus · lilac (session) → cream
"""
import re
import sys
from pathlib import Path

MAP = {
    # grounds and text
    "1a1614": "060606", "221d1a": "0d0d0d", "2a2420": "141414", "372f2a": "202020",
    "4a3f38": "343434", "f6ece4": "f2f2f2", "bfae9f": "a8a8a8", "7d6d62": "626262",
    # the nine hues
    "f5a8c9": "ff7a5c", "f9c49a": "ff6458", "f7a59a": "ff9a3c", "f2e29b": "ffc247",
    "a6e6bf": "4fd8cf", "94dcd6": "45c8e6", "a3cdf5": "62a5ff", "c4b2f5": "45c8e6",
    "e2b5f0": "ffd98f",
}
_K = "|".join(MAP)
# #rrggbb, #rrggbbaa (alpha last: Zed, CSS) and #aarrggbb (alpha first: Qt, KDE)
HEX = re.compile(r"(?i)(?<=#)(?:(?P<a>" + _K + r")(?=(?:[0-9a-f]{2})?\b)|(?P<p>[0-9a-f]{2})(?P<b>" + _K + r")\b)")


def rgb(h):
    return ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


TRIPLES = {rgb(k): rgb(v) for k, v in MAP.items()}
TRIPLE = re.compile(r"(?<![\d,])(" + "|".join(re.escape(t) for t in TRIPLES) + r")(?![\d,])")


def recolor(text):
    text = HEX.sub(lambda m: MAP[m.group("a").lower()] if m.group("a") else m.group("p") + MAP[m.group("b").lower()], text)
    return TRIPLE.sub(lambda m: TRIPLES[m.group(1)], text)


def files(paths):
    for p in map(Path, paths):
        if p.is_dir():
            yield from (f for f in p.rglob("*") if f.is_file() and not f.is_symlink())
        elif p.is_file():
            yield p


def main():
    changed = 0
    for f in files(sys.argv[1:]):
        try:
            text = f.read_text()
        except (UnicodeDecodeError, OSError):
            continue                      # binary (png, …): nothing to do
        new = recolor(text)
        if new != text:
            f.write_text(new)
            changed += 1
    print(f"recoloured {changed} file(s)")


if __name__ == "__main__":
    main()
