#!/usr/bin/env python3
"""Give every installed app an icon from the Nook theme.

Some apps name an icon the theme doesn't have (it then falls back to full-colour artwork), and
some, snaps among them, point Icon= at an image file, which skips the icon theme entirely.
For each of those this:
  1. looks for a theme icon under the app's other names (desktop id, snap app name, the last part
     of a reverse-DNS id, the command) and links it in, or
  2. draws a monogram tile in the app's category colour.
An app whose Icon= is a file gets a copy of its .desktop file in ~/.local/share/applications
(marked X-Nook-Icon, which uninstall.sh removes) that names the theme icon instead.

usage: appicons.py THEME_DIR [INHERITED_THEME_DIR…]   (icons found in those count as present)
"""
import os
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

from icons import CATEGORIES, HUE, by_name

DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
LOCAL = DATA / "applications"
SNAPS = Path("/var/lib/snapd/desktop/applications")
DIRS = [LOCAL, DATA / "flatpak/exports/share/applications", Path("/var/lib/flatpak/exports/share/applications"),
        SNAPS, Path("/usr/local/share/applications"), Path("/usr/share/applications")]
MARK = "X-Nook-Icon=true"

TILE = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
  <!-- Nook: monogram for an app the icon theme has no artwork for -->
  <rect x="14" y="14" width="100" height="100" rx="18" fill="none" stroke="{hue}" stroke-width="9"/>
  <text x="64" y="81" text-anchor="middle" fill="{hue}" font-family="JetBrains Mono, monospace"
        font-weight="700" font-size="{size}">{text}</text>
</svg>
"""


def entry(text):
    """The [Desktop Entry] group only, not the actions after it."""
    m = re.search(r"^\[Desktop Entry\]\s*$(.*?)(?=^\[|\Z)", text, re.M | re.S)
    return m.group(1) if m else ""


def key(group, name):
    m = re.search(rf"^{name}=(.*)$", group, re.M)
    return m.group(1).strip() if m else ""


def hue_of(group, names):
    cats = set(key(group, "Categories").split(";"))
    for hue, wanted in CATEGORIES:
        if cats & wanted:
            return HUE[hue]
    return HUE[next((h for h in map(by_name, names) if h), "lavender")]


def monogram(name):
    words = re.findall(r"[A-Za-z0-9]+", name)
    if len(words) > 1:
        text = words[0][0].upper() + words[1][0].upper()
    else:
        word = words[0] if words else "?"
        text = word[0].upper() + word[1:2].lower()
    return text, 56 if len(text) > 1 else 68


def aliases(path, group, icon):
    stem = path.name.removesuffix(".desktop")
    names = [icon, stem]
    parts = stem.split(".")
    if len(parts) >= 3 and parts[-1].isalpha():  # reverse-DNS: dev.zed.Zed → zed
        names.append(parts[-1])
    if path.parent == SNAPS and "_" in stem:
        names.append(stem.split("_", 1)[1])
    cmd = key(group, "Exec").split()
    while cmd and (cmd[0] == "env" or "=" in cmd[0]):
        cmd = cmd[1:]
    if cmd:
        names.append(Path(cmd[0]).name)
    return [n.lower() for n in names if n]


def main(theme, *inherited):
    theme = Path(theme)
    apps_dir = theme / "apps/scalable"
    for f in LOCAL.glob("*.desktop"):  # last run's overrides: rebuilt from the originals below
        if MARK in f.read_text(errors="ignore"):
            f.unlink()
    have = {}
    for p in theme.rglob("*.svg"):
        if p.exists():
            have.setdefault(p.stem.lower(), p)
    present = set(have)
    for t in inherited:
        present.update(p.stem.lower() for p in Path(t).rglob("*.svg"))
    seen, linked, drawn, overrides = set(), 0, 0, []
    for d in DIRS:
        for path in sorted(d.glob("*.desktop")) if d.is_dir() else []:
            if path.name in seen:
                continue
            seen.add(path.name)
            text = path.read_text(errors="ignore")
            group = entry(text)
            if re.search(r"^(NoDisplay|Hidden)=true", group, re.M) or key(group, "Type") != "Application":
                continue
            raw = key(group, "Icon")
            is_file = raw.startswith("/")
            icon = re.sub(r"\.(svg|png|xpm)$", "", Path(raw).name) if raw else ""
            if icon.lower() in present and not is_file:
                continue
            if is_file and d == LOCAL:
                print(f"  [!!] {path.name}: your own .desktop file uses an image path; left as is", file=sys.stderr)
                continue
            target = icon if icon and not is_file else f"nook-app-{path.name.removesuffix('.desktop')}"
            dest = apps_dir / f"{target}.svg"
            match = next((have[n] for n in aliases(path, group, icon) if n in have), None)
            if match:
                if match != dest:
                    dest.unlink(missing_ok=True)
                    dest.symlink_to(os.path.relpath(match, dest.parent))
                linked += 1
            else:
                text_, size = monogram(key(group, "Name") or target)
                dest.write_text(TILE.format(hue=hue_of(group, [icon, path.name]), size=size, text=escape(text_)))
                drawn += 1
            have[target.lower()] = dest
            present.add(target.lower())
            if is_file:
                LOCAL.mkdir(parents=True, exist_ok=True)
                new = re.sub(r"^Icon=.*$", f"Icon={target}", text, flags=re.M)
                new = new.replace("[Desktop Entry]\n", f"[Desktop Entry]\n{MARK}\n", 1)
                (LOCAL / path.name).write_text(new)
                overrides.append(path.name)
    print(f"  {linked} linked to theme icons, {drawn} monograms, {len(overrides)} .desktop overrides")


if __name__ == "__main__":
    main(*sys.argv[1:])
