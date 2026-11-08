#!/usr/bin/env python3
"""Build a monochrome-per-icon, colourful-as-a-set icon theme.

Every SVG in SRC is repainted in ONE pastel, chosen by what the icon is about (the Nook
rule "one hue per category, everywhere"): media pink, security coral, time/transfer peach,
files butter, dev mint, comms teal, network sky, system lavender, session lilac.

The category comes from, in order:
  1. for app icons: the Categories= of the installed .desktop file that uses that icon,
  2. keywords in the icon name (RULES below),
  3. the icon's context folder (DEFAULTS below).

usage: icons.py SRC DEST "Theme Name" "Inherits,list" [--keep-semantic] [--symbolic-only]
       NOOK_PALETTE=ramen icons.py …   the same in Ramen Sign's neons (nook-tile)

--symbolic-only keeps just the small single-colour icons (16/22/24 px folders and *-symbolic);
full-colour artwork would turn into solid blobs when painted in one hue.
"""
import os
import re
import shutil
import sys
from pathlib import Path

HUE = {
    "pink": "#f5a8c9", "coral": "#f7a59a", "peach": "#f9c49a", "butter": "#f2e29b", "mint": "#a6e6bf",
    "teal": "#94dcd6", "sky": "#a3cdf5", "lavender": "#c4b2f5", "lilac": "#e2b5f0", "ink": "#f6ece4",
}
BG = "#221d1a"

# NOOK_PALETTE=ramen: the same categories in Ramen Sign's neons (nook-tile). The role names stay
# the pastel ones: media rose, security orange, time red, files gold, dev aqua, comms cyan,
# network blue, system amber, session cream.
if os.environ.get("NOOK_PALETTE") == "ramen":
    HUE = {
        "pink": "#ff7a5c", "coral": "#ff9a3c", "peach": "#ff6458", "butter": "#ffc247", "mint": "#4fd8cf",
        "teal": "#45c8e6", "sky": "#62a5ff", "lavender": "#ffb14a", "lilac": "#ffd98f", "ink": "#f2f2f2",
    }
    BG = "#0d0d0d"

# First match wins. Each word matches the start of a name token (tokens split on - . _ and digits).
RULES = [
    ("butter",   "folder directory inode user-trash trash bookmark"),
    ("coral",    "lock security shield password keepass keepassxc bitwarden keyring firewall encrypt "
                 "gpg kleopatra seahorse auth dialog-error error edit-delete delete process-stop "
                 "emblem-important kill window-close close"),
    ("lilac",    "user avatar account system-log-out system-shutdown system-reboot system-suspend "
                 "system-hibernate system-switch-user log-out logout shutdown reboot power session "
                 "start-here nook"),
    ("mint",     "battery text-x application-x-shellscript application-x-executable application-x-python "
                 "code vscode vscodium visual-studio ide git github gitlab python java rust cargo nodejs "
                 "npm javascript debug develop qtcreator kdevelop jetbrains idea pycharm clion webstorm "
                 "android-studio sublime vim nvim neovim emacs docker podman virt qemu virtualbox "
                 "gnome-boxes winboat database sql dialog-ok checkmark emblem-ok success"),
    ("pink",     "input-gaming gaming game steam lutris heroic bottles wine retroarch minecraft prism "
                 "controller gamepad joystick music audio sound volume speaker headphone microphone mic "
                 "spotify elisa amarok rhythmbox strawberry player vlc mpv video movie film camera webcam "
                 "obs kdenlive shotcut blender image photo picture gimp krita inkscape gwenview digikam "
                 "darktable paint draw media multimedia playlist cava ledfx emblem-favorite"),
    ("teal",     "mail thunderbird evolution kmail chat message discord vesktop telegram signal whatsapp "
                 "slack element matrix irc konversation teams zoom skype mumble teamspeak notification "
                 "notifications bell kdeconnect phone contact people im- mail-"),
    ("sky",      "browser firefox chrom chromium google-chrome brave vivaldi opera microsoft-edge web "
                 "internet network nm- wifi wireless wired bluetooth ethernet globe world cloud nextcloud "
                 "dropbox sync share remote ssh server vpn proxy rss feed dialog-information info help "
                 "emblem-shared"),
    ("peach",    "clock time calendar date alarm timer download upload transfer torrent qbittorrent "
                 "ktorrent transmission deluge backup archive zip tar compress package ark update "
                 "software discover plasmadiscover install flatpak appimage application-x-rpm "
                 "application-x-deb"),
    ("butter",   "document file text office libreoffice okular pdf dolphin nautilus nemo thunar places "
                 "note kate kwrite gedit editor x-office spreadsheet presentation calc writer warning "
                 "dialog-warning"),
    ("lavender", "video-display display settings preferences configure system kcm konsole terminal "
                 "xterm utilities-terminal cpu memory ram hardware monitor ksysguard htop btop computer "
                 "drive disk partition usb device keyboard mouse input printer scanner applications-system "
                 "utilities"),
]

# Desktop-file Categories → hue, for app icons.
CATEGORIES = [
    ("coral",    {"Security"}),
    ("mint",     {"Development", "IDE", "Debugger", "RevisionControl", "WebDevelopment", "Emulator"}),
    ("pink",     {"AudioVideo", "Audio", "Video", "Player", "Recorder", "Graphics", "Photography",
                  "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Game"}),
    ("teal",     {"Email", "Chat", "InstantMessaging", "IRCClient", "Telephony", "VideoConference"}),
    ("sky",      {"WebBrowser", "Network", "RemoteAccess"}),
    ("peach",    {"FileTransfer", "Archiving", "Compression", "PackageManager", "Clock", "Calendar"}),
    ("butter",   {"Office", "TextEditor", "WordProcessor", "Spreadsheet", "FileManager", "Viewer"}),
    ("lavender", {"Settings", "System", "Monitor", "HardwareSettings", "TerminalEmulator"}),
    ("peach",    {"Utility"}),
]

DEFAULTS = {
    "apps": "lavender", "places": "butter", "devices": "lavender", "mimetypes": "butter",
    "actions": "ink", "status": "lavender", "emblems": "lilac", "categories": "teal",
    "preferences": "lavender", "applets": "lavender", "panel": "ink",
}

TOKEN = re.compile(r"[-._\d]+")
SMALL = re.compile(r"(^|/)(16|22|24)(@\dx)?/")


def build_rules():
    out = []
    for hue, words in RULES:
        for w in words.split():
            out.append((hue, w))
    return out


RULE_LIST = build_rules()


def by_name(name):
    n = name.lower()
    tokens = [t for t in TOKEN.split(n) if t]
    for hue, w in RULE_LIST:
        if "-" in w:  # multi-token rule: match as a prefix of the whole name or after a separator
            if n.startswith(w) or f"-{w}" in n or f".{w}" in n:
                return hue
        elif any(t.startswith(w) for t in tokens):
            return hue
    return None


def desktop_categories():
    dirs = [Path("/usr/share/applications"), Path.home() / ".local/share/applications",
            Path("/var/lib/flatpak/exports/share/applications"),
            Path.home() / ".local/share/flatpak/exports/share/applications",
            Path("/var/lib/snapd/desktop/applications")]
    icon_hue = {}
    for d in dirs:
        if not d.is_dir():
            continue
        for f in d.glob("*.desktop"):
            try:
                text = f.read_text(errors="ignore")
            except OSError:
                continue
            icon = re.search(r"^Icon=(.+)$", text, re.M)
            cats = re.search(r"^Categories=(.+)$", text, re.M)
            if not icon or not cats:
                continue
            cs = set(cats.group(1).strip().split(";"))
            for hue, wanted in CATEGORIES:
                if cs & wanted:
                    # .name + suffix strip, not .stem: "dev.zed.Zed" has no extension to drop
                    name = re.sub(r"\.(svg|png|xpm)$", "", Path(icon.group(1).strip()).name.lower())
                    icon_hue.setdefault(name, hue)
                    break
    return icon_hue


def context_of(rel):
    for part in rel.parts:
        if part in DEFAULTS:
            return part
    return None


STYLE_CLASS = re.compile(r"(\.ColorScheme-(\w+)\s*\{\s*color\s*:\s*)(#[0-9a-fA-F]{3,8}|[a-z]+)")
HEX = re.compile(r"(?<=[\s\"':;,=])#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-zA-Z_-])")
RGB = re.compile(r"rgba?\([^)]*\)")
NAMED = re.compile(r"((?:fill|stroke|stop-color|color)\s*[:=]\s*[\"']?)(black|white|red|blue|green|gray|grey)\b")


def repaint(svg, hue, keep_semantic):
    def cls(m):
        name = m.group(2)
        if name in ("Background", "ViewBackground"):
            return m.group(1) + BG
        if keep_semantic and name == "NegativeText":
            return m.group(1) + HUE["coral"]
        if keep_semantic and name == "NeutralText":
            return m.group(1) + HUE["butter"]
        if keep_semantic and name == "PositiveText":
            return m.group(1) + HUE["mint"]
        return m.group(1) + hue

    # Keep Plasma from re-tinting the icon with the colour scheme: rename the magic stylesheet id.
    svg = svg.replace('id="current-color-scheme"', 'id="nook-scheme"')
    # Repaint the stylesheet classes first, then protect them from the generic pass.
    styles = []

    def stash(m):
        styles.append(STYLE_CLASS.sub(cls, m.group(0)))
        return f"\x00{len(styles) - 1}\x00"

    svg = re.sub(r"<style[^>]*>.*?</style>", stash, svg, flags=re.S)
    svg = HEX.sub(hue, svg)
    svg = RGB.sub(hue, svg)
    svg = NAMED.sub(lambda m: m.group(1) + hue, svg)
    svg = re.sub("\x00(\\d+)\x00", lambda m: HEX.sub(hue, styles[int(m.group(1))])
                 if "ColorScheme-" not in styles[int(m.group(1))] else styles[int(m.group(1))], svg)
    return svg


def main():
    src, dest, name, inherits = sys.argv[1:5]
    keep_semantic = "--keep-semantic" in sys.argv
    symbolic_only = "--symbolic-only" in sys.argv
    src, dest = Path(src), Path(dest)
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(src, dest, symlinks=True,
                    ignore=shutil.ignore_patterns(".git", "*.png", "icon-theme.cache", "README*"))
    app_hue = desktop_categories()
    # .desktop files often name an alias (dev.zed.Zed.svg → zed.svg), so look the hue up by those too
    aliases = {}
    for path in dest.rglob("*.svg"):
        if path.is_symlink() and path.exists():
            aliases.setdefault(path.resolve(), []).append(path.stem.lower().removesuffix("-symbolic"))
    counts = {}
    for path in dest.rglob("*.svg"):
        if path.is_symlink() or not path.is_file():
            continue
        rel = path.relative_to(dest)
        ctx = context_of(rel)
        if symbolic_only and not path.stem.endswith("-symbolic") and (
                not SMALL.search(str(rel)) or ctx in ("apps", "mimetypes", "categories")):
            path.unlink()
            continue
        stem = path.stem.lower().removesuffix("-symbolic")
        names = [stem, *aliases.get(path.resolve(), [])]
        hue = (next((app_hue[n] for n in names if n in app_hue), None) if ctx == "apps" else None) \
            or by_name(stem) \
            or DEFAULTS.get(ctx or "", "lavender")
        counts[hue] = counts.get(hue, 0) + 1
        try:
            text = path.read_text(errors="ignore")
        except OSError:
            continue
        path.write_text(repaint(text, HUE[hue], keep_semantic))
    # Broken links (targets we skipped) would make the theme lookup fall through oddly.
    for path in dest.rglob("*"):
        if path.is_symlink() and not path.exists():
            path.unlink()

    idx = dest / "index.theme"
    text = idx.read_text()
    text = re.sub(r"^Name=.*$", f"Name={name}", text, count=1, flags=re.M)
    text = re.sub(r"^Comment=.*$", "", text, flags=re.M)
    text = re.sub(r"^Inherits=.*$", f"Inherits={inherits}", text, count=1, flags=re.M)
    text = re.sub(r"^FollowsColorScheme=.*$", "FollowsColorScheme=false", text, flags=re.M)
    text = text.replace("[Icon Theme]", f"[Icon Theme]\nComment=Nook pastel icons (generated)", 1)
    idx.write_text(text)
    print("  " + "  ".join(f"{h}:{n}" for h, n in sorted(counts.items(), key=lambda x: -x[1])))


if __name__ == "__main__":
    main()
