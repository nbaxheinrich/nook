#!/usr/bin/env python3
"""Recolour files from one Nook palette to another, in place.

usage: recolor.py [--from cocoa] [--to ramen] PATH…   (files, or folders: every text file inside)

The palettes live in palettes/*.json. Each names the same roles (grounds bg000…bg300, line,
ink/muted/faint, one hue per category: media danger time files dev comms net system session,
plus focus and accent) and its 16 terminal colours. A colour is mapped through its role: the
SOURCE palette's colour for a role becomes the TARGET palette's colour for that role. Where a
palette folds two roles into one colour (cocoa's lavender is both focus and system; Ramen's red
is time and the accent), the role listed in "roles" wins and "aliases" point the others at it.
Terminal colours that no role covers (the brights) map by position.

Hex colours (#rrggbb in any case, #rrggbbaa, #aarrggbb) and "r,g,b" triples (KDE colour files)
are both replaced. Default: --from cocoa --to ramen (what apply.sh --ramen has always done).
"""
import json
import re
import sys
from pathlib import Path

PALETTES = Path(__file__).resolve().parent.parent / "palettes"


def load(name):
    return json.loads((PALETTES / f"{name}.json").read_text())


def colour(p, role):
    return p["roles"].get(role) or p["roles"].get(p.get("aliases", {}).get(role, ""), None)


def table(src, dst):
    a, b = load(src), load(dst)
    m = {}
    for role, hexa in a["roles"].items():
        target = colour(b, role)
        if target:
            m.setdefault(hexa.lower().lstrip("#"), target.lower().lstrip("#"))
    for x, y in zip(a.get("ansi", []), b.get("ansi", [])):
        m.setdefault(x.lower().lstrip("#"), y.lower().lstrip("#"))
    return {k: v for k, v in m.items() if k != v}


def rgb(h):
    return ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


class Recolor:
    def __init__(self, src, dst):
        self.map = table(src, dst)
        keys = "|".join(sorted(self.map, key=len, reverse=True)) or "(?!)"
        # #rrggbb, #rrggbbaa (alpha last: Zed, CSS) and #aarrggbb (alpha first: Qt, KDE)
        # after "#", or bare inside hyprlang's rgb(…) / rgba(…)
        self.hex = re.compile(r"(?i)(?:(?<=#)|(?<=rgb\()|(?<=rgba\())(?:(?P<a>" + keys + r")(?=(?:[0-9a-f]{2})?\b)"
                              r"|(?P<p>[0-9a-f]{2})(?P<b>" + keys + r")\b)")
        self.triples = {rgb(k): rgb(v) for k, v in self.map.items()}
        tk = "|".join(re.escape(t) for t in self.triples) or "(?!)"
        self.triple = re.compile(r"(?<![\d,])(" + tk + r")(?![\d,])")

    def __call__(self, text):
        text = self.hex.sub(lambda m: self.map[m.group("a").lower()] if m.group("a")
                            else m.group("p") + self.map[m.group("b").lower()], text)
        return self.triple.sub(lambda m: self.triples[m.group(1)], text)


def files(paths):
    for p in map(Path, paths):
        if p.is_dir():
            yield from (f for f in p.rglob("*") if f.is_file() and not f.is_symlink())
        elif p.is_file():
            yield p


def main(argv):
    src, dst, paths = "cocoa", "ramen", []
    it = iter(argv)
    for a in it:
        if a == "--from": src = next(it)
        elif a == "--to": dst = next(it)
        else: paths.append(a)
    if src == dst:
        print("same palette, nothing to do"); return
    rc, changed = Recolor(src, dst), 0
    for f in files(paths):
        try:
            text = f.read_text()
        except (UnicodeDecodeError, OSError):
            continue                      # binary (png, …): nothing to do
        new = rc(text)
        if new != text:
            f.write_text(new)
            changed += 1
    print(f"recoloured {changed} file(s) {src} → {dst}")


if __name__ == "__main__":
    main(sys.argv[1:])
