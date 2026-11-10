#!/usr/bin/env python3
"""nook for WLED: the LEDs glow in the nook palettes.

usage: wled.py [--hosts=a,b] [--dry-run] [--skin]
       wled.py --scan                 list WLED devices on the local /24
       wled.py --remove               take nook's presets and palettes off again

Devices come from config/wled.conf (or --hosts). Every palette in palettes/*.json becomes
  a WLED custom palette  /palette<N>.json: four stops, network → comms → files → time
                         (Ramen: blue → cyan → gold → red)
  a preset               "nook · <palette>" (slots 20, 21, …): Noise 3 through that gradient
The device's own presets stay; its presets.json is backed up to ~/.local/state/nook/wled/ first.
Nothing changes on the LEDs until you pick a preset. --skin also writes a web-interface skin
(/skin.css, shown once "Use custom CSS" is on in WLED's UI settings).
Only the standard library is used (urllib).
"""
import concurrent.futures as cf
import datetime
import json
import os
import socket
import sys
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "nook"
SLOTS = range(20, 26)
PREFIX = "nook · "

# WLED effect and palette ids (stable across 0.14 – 16.x)
FX = {"noise3": 72, "solid": 0, "breathe": 2, "palette": 65, "colorwaves": 67, "colortwinkles": 74, "candle": 88, "flow": 110}
PAL_GRADIENT, PAL_COLORS_ONLY = 4, 5        # "* Color Gradient", "* Colors Only" (made of the segment's 3 colours)


# ── palette ─────────────────────────────────────────────────────────────────
def load_palette(name):
    p = json.loads((ROOT / "palettes" / f"{name}.json").read_text())
    r = dict(p["roles"])
    for k, v in p.get("aliases", {}).items():
        r.setdefault(k, r[v])
    return p, r


def rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def rgba(h, a):
    return "rgba({},{},{},{})".format(*rgb(h), a)


# ── presets ─────────────────────────────────────────────────────────────────
# the glow's gradient: network → comms → files → time. In Ramen that is blue → cyan → gold → red,
# the palette Nils built by hand on wled-desk (2026-11-08); other palettes get their own four roles.
GLOW = ["net", "comms", "files", "time"]


def palette_file(r):
    """WLED custom palette: {"palette": [pos, r, g, b, …]} with the glow roles spread over 0–255."""
    flat = []
    for i, h in enumerate(GLOW):
        flat += [round(i * 255 / (len(GLOW) - 1))] + rgb(r[h])
    return {"palette": flat}


def glow_presets(top=255):
    """One preset per palette: Noise 3 through the palette's glow gradient (wled-desk's design).
    Custom palette N is WLED palette id TOP - N (255 up to 0.15, 200 on 16.x: see custom_top)."""
    out = {}
    for n, name in enumerate(palette_names()):
        p, r = load_palette(name)
        out[str(SLOTS[n])] = {
            "n": f"{PREFIX}{name}", "on": True, "bri": 160, "transition": 15, "mainseg": 0,
            "seg": [{"id": 0, "on": True, "fx": FX["noise3"], "sx": 133, "ix": 128, "pal": top - n,
                     "col": [rgb(r["accent"]), rgb(r["focus"]), rgb(r["bg000"])], "rev": False, "mi": False}],
            "ql": name[0].upper()}
    return out


def palette_names():
    return sorted(f.stem for f in (ROOT / "palettes").glob("*.json"))


def presets(name, r):
    """Six scenes, all drawn from the palette's roles. Segment 0 only: every device here has one."""
    def seg(fx, cols, pal=PAL_GRADIENT, sx=128, ix=128, **kw):
        s = {"id": 0, "on": True, "fx": FX[fx], "sx": sx, "ix": ix, "pal": pal,
             "col": [rgb(r[c]) for c in cols], "rev": False, "mi": False}
        s.update(kw)
        return s

    scenes = [
        ("sign",       170, seg("colorwaves",    ["accent", "focus", "files"], sx=60, ix=110)),
        ("glow",       150, seg("breathe",       ["accent", "bg000", "bg000"], pal=0, sx=40)),
        ("fire → ice", 170, seg("palette",       ["time", "files", "focus"], sx=50, ix=90)),
        ("flicker",    140, seg("candle",        ["accent", "focus", "bg000"], pal=0, sx=96, ix=200)),
        ("twinkle",    150, seg("colortwinkles", ["dev", "focus", "session"], pal=PAL_COLORS_ONLY, sx=70, ix=140)),
        ("calm",        70, seg("solid",         ["session", "bg000", "bg000"], pal=0)),
    ]
    out = {}
    for slot, (title, bri, s) in zip(SLOTS, scenes):
        out[str(slot)] = {"n": f"{PREFIX}{title}", "on": True, "bri": bri, "transition": 10,
                          "mainseg": 0, "seg": [s], "ql": str(slot - 19)}
    return out


# ── skin ────────────────────────────────────────────────────────────────────
def skin(name, r):
    v = {
        # WLED's greys, darkest → lightest, mapped onto the palette's grounds and text
        "--c-1": r["bg100"], "--c-2": r["bg200"], "--c-3": r["bg300"], "--c-4": r["line"],
        "--c-5": r["line"], "--c-6": r["faint"], "--c-8": r["faint"], "--c-b": r["muted"],
        "--c-c": r["muted"], "--c-d": r["ink"], "--c-e": r["ink"], "--c-f": r["ink"],
        # signal colours
        "--c-r": r["danger"], "--c-g": r["dev"], "--c-l": r["net"], "--c-y": r["files"],
        "--c-o": rgba(r["bg100"], .9), "--c-tb": rgba(r["bg100"], "var(--t-b)"),
        "--c-tba": rgba(r["bg300"], "var(--t-b)"), "--c-tbh": rgba(r["bg200"], "var(--t-b)"),
    }
    root = ";".join(f"{k}:{val}" for k, val in v.items())
    focus, accent = r["focus"], r["accent"]
    return f"""/* nook for WLED · palette {name} · written by nook's shared/wled/wled.py */
:root{{{root}}}
body,button,input,select,textarea,.btn,.lstIname,.label{{font-family:"JetBrains Mono","JetBrainsMono Nerd Font",ui-monospace,monospace!important;letter-spacing:0}}
body{{background:{r['bg000']}!important;color:{r['ink']}}}
/* barely rounded, like the rest of nook */
.btn,.lstI,.segin,.presin,.filter,.sliderdisplay,input[type=text],input[type=number],select,textarea,.pop-c,#info,#nodes,.modal{{border-radius:4px!important}}
/* focus and selection: the palette's focus colour */
.lstI.selected,.lstI:hover{{background:{rgba(focus, .14)}!important;box-shadow:inset 0 0 0 1px {focus}!important}}
.btn:hover,.tab button:hover{{color:{focus}!important}}
.tab button.active,.tab button.active i{{color:{focus}!important;background:{rgba(focus, .12)}!important}}
input:focus,select:focus,textarea:focus{{outline:1px solid {focus}!important;outline-offset:0}}
/* sliders: the accent */
.sliderdisplay{{background:{r['bg300']}!important}}
input[type=range]::-webkit-slider-thumb{{background:{accent}!important;border:2px solid {r['bg100']}!important;box-shadow:0 0 8px {rgba(accent, .6)}}}
input[type=range]::-moz-range-thumb{{background:{accent}!important;border:2px solid {r['bg100']}!important}}
/* power on: the accent, glowing */
.btn.active,#buttonPower.on,#buttonPower.active{{color:{accent}!important;text-shadow:0 0 8px {rgba(accent, .7)}}}
/* the header name in the palette's session colour */
#namelabel{{color:{r['session']}!important}}
"""


# ── device I/O ──────────────────────────────────────────────────────────────
def get(host, path, timeout=5):
    with urllib.request.urlopen(f"http://{host}{path}", timeout=timeout) as f:
        return f.read()


def upload(host, filename, data):
    """WLED's /upload: multipart form, field "data", the filename is the path on the device."""
    b = uuid.uuid4().hex
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"data\"; filename=\"{filename}\"\r\n"
            f"Content-Type: application/octet-stream\r\n\r\n").encode() + data + f"\r\n--{b}--\r\n".encode()
    req = urllib.request.Request(f"http://{host}/upload", data=body, method="POST",
                                 headers={"Content-Type": f"multipart/form-data; boundary={b}"})
    with urllib.request.urlopen(req, timeout=10) as f:
        return f.status


def hosts_from_conf():
    out = []
    for line in (ROOT / "config" / "wled.conf").read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if "|" in line:
            n, a = (x.strip() for x in line.split("|", 1))
            out.append((n, a))
    return out


def scan():
    ip = socket.gethostbyname(socket.gethostname())
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect(("192.0.2.1", 9)); ip = s.getsockname()[0]; s.close()
    except OSError:
        pass
    net = ip.rsplit(".", 1)[0]

    def probe(i):
        h = f"{net}.{i}"
        try:
            d = json.loads(get(h, "/json/info", timeout=1.5))
            return f"{h}  {d.get('name')}  v{d.get('ver')}  {d.get('leds', {}).get('count')} LEDs"
        except Exception:
            return None
    with cf.ThreadPoolExecutor(64) as ex:
        for line in filter(None, ex.map(probe, range(1, 255))):
            print(line)


def custom_top(addr):
    """The palette id of custom palette 0. WLED counts custom palettes down from it; the number
    changed between versions (255 → 200), so read it off the device: the highest id in /json/palx
    that isn't a built-in one."""
    info = json.loads(get(addr, "/json/info"))
    if not info.get("cpalcount"):
        return 255
    ids = []
    for page in range(0, 20):
        d = json.loads(get(addr, f"/json/palx?page={page}"))
        ids += [int(k) for k in d.get("p", {})]
        if page >= d.get("m", 0):
            break
    builtin = info.get("palcount", 0)
    custom = sorted(i for i in ids if i >= builtin)
    return max(custom) if custom else 255


def apply(name, addr, do_skin, dry, remove):
    msgs = []
    names = palette_names()
    cur = json.loads(get(addr, "/presets.json") or b"{}")
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    bdir = STATE / "wled"; bdir.mkdir(parents=True, exist_ok=True)
    if not dry:
        (bdir / f"{addr}-{stamp}.presets.json").write_text(json.dumps(cur))
    # drop nook's earlier presets (by slot or name), keep everything else
    new = {k: v for k, v in cur.items()
           if not (k.isdigit() and int(k) in SLOTS) and not str(v.get("n", "")).startswith(PREFIX)}
    if not remove and not dry:
        # palettes first, so the device numbers them and we can read where they landed
        for n, pname in enumerate(names):
            _, r = load_palette(pname)
            upload(addr, f"/palette{n}.json", json.dumps(palette_file(r), separators=(",", ":")).encode())
    top = custom_top(addr) if not remove else 255
    if not remove:
        new.update(glow_presets(top))
    theirs = sorted(int(k) for k in new if k.isdigit() and int(k) not in SLOTS and k != "0")
    if not dry:
        if remove:
            for n in range(len(names)):
                upload(addr, f"/palette{n}.json", b"{}")
        upload(addr, "/presets.json", json.dumps(new, separators=(",", ":")).encode())
    if remove:
        msgs.append(f"nook presets and palettes removed (kept {len(theirs)} of yours)")
    else:
        msgs.append("presets " + ", ".join(f"{SLOTS[i]} nook · {p} (pal {top - i})" for i, p in enumerate(names))
                    + f" (kept {len(theirs)} of yours: {theirs})")
    if do_skin:
        _, r = load_palette("ramen")
        css = b"/* nook skin removed */\n" if remove else skin("ramen", r).encode()
        msgs.append("skin.css")
        if not dry:
            upload(addr, "/skin.css", css)
    return msgs


def main(argv):
    hosts = None
    do_skin = dry = remove = False
    for a in argv:
        if a.startswith("--hosts="): hosts = [(h, h) for h in a.split("=", 1)[1].split(",") if h]
        elif a == "--dry-run": dry = True
        elif a == "--skin": do_skin = True
        elif a == "--remove": remove = True
        elif a == "--scan": scan(); return 0
        elif a.startswith("--palette="): pass        # every palette gets a preset; kept for ./nook
        elif a in ("-h", "--help"): print(__doc__); return 0
        else: print(f"unknown option {a}", file=sys.stderr); return 2
    hosts = hosts or hosts_from_conf()
    failed = 0
    with cf.ThreadPoolExecutor(8) as ex:
        futs = {ex.submit(apply, n, a, do_skin, dry, remove): (n, a) for n, a in hosts}
        for f in cf.as_completed(futs):
            n, a = futs[f]
            try:
                print(f"  [OK] {n} ({a}): " + " · ".join(f.result()) + (" [dry run]" if dry else ""))
            except Exception as e:
                failed += 1
                print(f"  [!!] {n} ({a}): {e}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
