#!/usr/bin/env python3
"""Resolve config/apps.conf against the installed .desktop files.

A pinned app that is not installed hands its slot to the first [fill] app that is installed and
not pinned yet, so the taskbar and the desktop card keep their size on any machine.

usage: apps.py CONF json       → [{"name","hue","id","icon","path","wmclass"}] for the desktop card
       apps.py CONF launchers  → "applications:x.desktop,…" for the taskbar
       apps.py CONF wmclass    → "wmclass<TAB>id" per app whose windows name a different app id
                                 (Discord's flatpak says "discord"), for the KWin rules
"""
import json
import os
import re
import sys
from pathlib import Path

HUE = {"pink": "#f5a8c9", "coral": "#f7a59a", "peach": "#f9c49a", "butter": "#f2e29b", "mint": "#a6e6bf",
       "teal": "#94dcd6", "sky": "#a3cdf5", "lavender": "#c4b2f5", "lilac": "#e2b5f0"}
if os.environ.get("NOOK_PALETTE") == "ramen":   # Ramen Sign (apply.sh --ramen)
    HUE = {"pink": "#ff7a5c", "coral": "#ff9a3c", "peach": "#ff6458", "butter": "#ffc247", "mint": "#4fd8cf",
           "teal": "#45c8e6", "sky": "#62a5ff", "lavender": "#ffb14a", "lilac": "#ffd98f"}
DATA = os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))
DIRS = [Path(DATA) / "applications", Path(DATA) / "flatpak/exports/share/applications",
        Path("/var/lib/flatpak/exports/share/applications"), Path("/var/lib/snapd/desktop/applications"),
        Path("/usr/local/share/applications"), Path("/usr/share/applications")]


def find(desktop_id):
    for d in DIRS:
        f = d / f"{desktop_id}.desktop"
        if f.is_file():
            return f
    return None


def entry_key(path, key):
    # inside [Desktop Entry], not one of the actions below it
    text = path.read_text(errors="ignore").split("\n[Desktop Action", 1)[0]
    m = re.search(rf"^{key}=(.+)$", text, re.M)
    return m.group(1).strip() if m else None


def first_installed(name, hue, ids):
    for i in ids.split():
        path = find(i)
        if path:
            return {"name": name, "hue": HUE.get(hue, hue), "id": i, "path": str(path),
                    "icon": entry_key(path, "Icon") or "application-x-executable",
                    "wmclass": entry_key(path, "StartupWMClass")}
    return None


def resolve(conf):
    pinned, fill = [], []
    section = pinned
    for line in Path(conf).read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.strip() == "[fill]":
            section = fill
            continue
        section.append(tuple(p.strip() for p in line.split("|", 2)))
    apps = [first_installed(*row) for row in pinned]
    used = {a["path"] for a in apps if a}
    spare = (a for a in (first_installed(*row) for row in fill) if a)
    for n, (row, app) in enumerate(zip(pinned, apps)):
        if app:
            continue
        sub = next((a for a in spare if a["path"] not in used), None)
        if sub:
            used.add(sub["path"])
            apps[n] = sub
        print(f"  [!!] {row[0]}: none of {row[2]} is installed, "
              + (f"{sub['name']} takes its place" if sub else "skipped"), file=sys.stderr)
    return [a for a in apps if a]


if __name__ == "__main__":
    apps = resolve(sys.argv[1])
    if sys.argv[2] == "json":
        print(json.dumps(apps))
    elif sys.argv[2] == "wmclass":
        for a in apps:
            if a["wmclass"] and a["wmclass"] != a["id"]:
                print(f"{a['wmclass']}\t{a['id']}")
    else:
        print(",".join(f"applications:{a['id']}.desktop" for a in apps))
