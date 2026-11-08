#!/usr/bin/env python3
"""Bind / unbind the Nook global shortcuts from config/shortcuts.conf.

Each row with a command becomes ~/.local/share/applications/nook-<slug>.desktop
plus a kglobalaccel "_launch" shortcut, registered live over D-Bus (and persisted by
kglobalaccel in kglobalshortcutsrc), so no logout is needed. A command "kwin:Action[,Action…]"
instead rebinds existing KWin actions (Krohnkite's among them); with several actions, the last
part of the keys holds one key per action ("Meta+←↑→↓").

usage: shortcuts.py bind CONF BIN_DIR | unbind CONF | list CONF
"""
import os
import re
import subprocess
import sys
from pathlib import Path

APPS = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "applications"
PREFIX = "nook-"

MODS = {"meta": 0x10000000, "alt": 0x08000000, "ctrl": 0x04000000, "shift": 0x02000000}
KEYS = {
    "return": 0x01000004, "enter": 0x01000005, "space": 0x20, "esc": 0x01000000,
    "escape": 0x01000000, "tab": 0x01000001, "backspace": 0x01000003, "del": 0x01000007,
    "delete": 0x01000007, "print": 0x01000009, "home": 0x01000010, "end": 0x01000011,
    "left": 0x01000012, "up": 0x01000013, "right": 0x01000014, "down": 0x01000015,
    "pgup": 0x01000016, "pgdown": 0x01000017,
}
ARROWS = {"←": "Left", "↑": "Up", "→": "Right", "↓": "Down"}

# KWin actions whose keys the tiling rows take over (or that clash with Plasma defaults:
# Krohnkite's Meta+. / Meta+, / Meta+I / Meta+D), cleared on bind. Meta+Alt+arrows already cross
# screens, so KWin's Meta+Shift+←/→ (window to next/previous screen) make way for resizing. Krohnkite's directional
# actions stay key-less: the nook-tiling script calls them. The KWin ones get their
# defaults back on unbind.
KWIN_FREE = [
    "Window Quick Tile Left", "Window Quick Tile Right",
    "Window Quick Tile Bottom", "Window Quick Tile Top",
    "Switch Window Left", "Switch Window Up", "Switch Window Right", "Switch Window Down",
    "Window to Next Screen", "Window to Previous Screen",
    "Edit Tiles",
    "KrohnkiteFocusNext", "KrohnkiteFocusPrev", "KrohnkiteIncrease", "KrohnkiteDecrease",
    "KrohnkiteFocusLeft", "KrohnkiteFocusUp", "KrohnkiteFocusRight", "KrohnkiteFocusDown",
    "KrohnkiteShiftLeft", "KrohnkiteShiftUp", "KrohnkiteShiftRight", "KrohnkiteShiftDown",
]


def parse(conf):
    rows = []
    for line in Path(conf).read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        parts += [""] * (4 - len(parts))
        group, keys, label, cmd = parts[:4]
        rows.append({"group": group, "keys": keys, "label": label, "cmd": cmd})
    return rows


def qt_key(seq):
    """'Meta+Shift+Return' -> Qt int key code. The key part may itself be '+' or '/'."""
    m = re.fullmatch(r"((?:(?:Meta|Alt|Ctrl|Shift)\+)*)(.+)", seq, re.I)
    mods, key = m.group(1), m.group(2)
    code = 0
    for mod in filter(None, mods.split("+")):
        code |= MODS[mod.lower()]
    k = key.lower()
    if k in KEYS:
        code |= KEYS[k]
    elif re.fullmatch(r"f([1-9]|[12][0-9]|3[0-5])", k):
        code |= 0x01000030 + int(k[1:]) - 1
    elif len(key) == 1:
        code |= ord(key.upper())
    else:
        raise ValueError(f"unknown key '{key}' in '{seq}'")
    return code


def slug(label):
    return re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-")


def accel(method, *args):
    return subprocess.run(
        ["gdbus", "call", "--session", "--dest", "org.kde.kglobalaccel",
         "--object-path", "/kglobalaccel", "--method", f"org.kde.KGlobalAccel.{method}", *args],
        capture_output=True, text=True)


def action_id(desktop, label):
    return f"['{desktop}','_launch','{label}','{label}']"


def kwin_id(action):
    return f"['kwin','{action}','KWin','{action}']"


def kwin_keys(row):
    """'Meta+Alt+←↑→↓' + 'kwin:A,B,C,D' -> [(A, 'Meta+Alt+Left'), (B, 'Meta+Alt+Up'), …]."""
    actions = row["cmd"][len("kwin:"):].split(",")
    if len(actions) == 1:
        return [(actions[0], row["keys"])]
    mods, _, glyphs = row["keys"].rpartition("+")
    glyphs = glyphs.replace(" ", "")
    if len(glyphs) != len(actions):
        raise ValueError(f"'{row['keys']}' has {len(glyphs)} keys for {len(actions)} actions")
    return [(a, f"{mods}+{ARROWS.get(g, g)}") for a, g in zip(actions, glyphs)]


def bind_kwin(rows):
    for action in KWIN_FREE:
        accel("setForeignShortcut", kwin_id(action), "@ai []")
    for row in rows:
        for action, keys in kwin_keys(row):
            r = accel("setForeignShortcut", kwin_id(action), f"[{qt_key(keys)}]")
            status = "bound" if r.returncode == 0 else f"FAILED ({r.stderr.strip()})"
            print(f"  {keys:<18} {action:<16} {status}")


def unbind_kwin(conf):
    for action in KWIN_FREE:
        if action.startswith(("Krohnkite", "Nook")):
            continue
        r = accel("defaultShortcutKeys", kwin_id(action))
        m = re.fullmatch(r"\((\[.*\]),\)", r.stdout.strip())
        if r.returncode == 0 and m:
            accel("setForeignShortcutKeys", kwin_id(action), m.group(1))
    for row in parse(conf):
        if row["cmd"].startswith("kwin:"):
            for action, _ in kwin_keys(row):
                accel("unregister", "kwin", action)


def bind(conf, bin_dir):
    APPS.mkdir(parents=True, exist_ok=True)
    rows = parse(conf)
    # launchers whose row is gone from the conf (an old nook-menu binding, say) are released first
    current = {f"{PREFIX}{slug(r['label'])}.desktop" for r in rows if r["cmd"] and not r["cmd"].startswith("kwin:")}
    for f in sorted(APPS.glob(f"{PREFIX}*.desktop")):
        if f.name not in current:
            accel("unregister", f.name, "_launch")
            f.unlink()
            print(f"  released {f.name}")
    # KWin's rows first: they move Krohnkite off keys the launchers need (Meta+Return).
    bind_kwin([r for r in rows if r["cmd"].startswith("kwin:")])
    for row in rows:
        if not row["cmd"] or row["cmd"].startswith("kwin:"):
            continue
        cmd = re.sub(r"(^|\s)(nook-[\w-]+)", lambda m: m.group(1) + str(Path(bin_dir) / m.group(2)), row["cmd"])
        desktop = f"{PREFIX}{slug(row['label'])}.desktop"
        label = f"Nook: {row['label']}"
        (APPS / desktop).write_text(
            "[Desktop Entry]\nType=Application\n"
            f"Name={label}\nExec={cmd}\nIcon=nook\nNoDisplay=true\n"
            f"X-KDE-Shortcuts={row['keys']}\n")
        aid = action_id(desktop, label)
        accel("doRegister", aid)
        r = accel("setForeignShortcut", aid, f"[{qt_key(row['keys'])}]")
        status = "bound" if r.returncode == 0 else f"FAILED ({r.stderr.strip()})"
        print(f"  {row['keys']:<18} {row['label']:<16} {status}")
    subprocess.run(["kbuildsycoca6"], capture_output=True)


def unbind(conf):
    unbind_kwin(conf)
    for f in sorted(APPS.glob(f"{PREFIX}*.desktop")):
        accel("unregister", f.name, "_launch")
        f.unlink()
        print(f"  removed {f.name}")
    subprocess.run(["kbuildsycoca6"], capture_output=True)


COLORS = {"apps": (166, 230, 191), "session": (226, 181, 240), "windows": (163, 205, 245),
          "desktop": (196, 178, 245), "tools": (249, 196, 154)}


def show(conf):
    """Pretty cheat-sheet for the terminal (nook-keys)."""
    rows = parse(conf)
    muted = "\x1b[38;2;191;174;159m"
    off = "\x1b[0m"
    last = None
    for r in rows:
        rgb = COLORS.get(r["group"], (246, 236, 228))
        hue = "\x1b[38;2;%d;%d;%dm" % rgb
        if r["group"] != last:
            print(f"\n {hue}\x1b[1m{r['group'].upper()} //{off}")
            last = r["group"]
        print(f"   {hue}{r['keys']:<20}{off}{muted}{'.' * 3}{off} {r['label']}")
    print()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "bind":
        bind(sys.argv[2], sys.argv[3])
    elif cmd == "unbind":
        unbind(sys.argv[2])
    elif cmd == "list":
        show(sys.argv[2])
    else:
        sys.exit(__doc__)
