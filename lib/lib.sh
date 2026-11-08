# Shared helpers for the Nook scripts. Source, don't execute.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
NOOK_STATE="$XDG_STATE_HOME/nook"
NOOK_SHARE="$XDG_DATA_HOME/nook"

c_lav=$'\e[38;2;196;178;245m' c_mint=$'\e[38;2;166;230;191m'
c_coral=$'\e[38;2;247;165;154m' c_butter=$'\e[38;2;242;226;155m'
c_muted=$'\e[38;2;191;174;159m' c_off=$'\e[0m'

step() { printf '%sλ%s %s\n' "$c_mint" "$c_off" "$*"; }
ok()   { printf '  %s[OK]%s %s\n' "$c_mint" "$c_off" "$*"; }
warn() { printf '  %s[!!]%s %s\n' "$c_butter" "$c_off" "$*" >&2; }
die()  { printf '  %s[xx]%s %s\n' "$c_coral" "$c_off" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Distro family: fedora | debian | arch | suse | unknown
distro_family() {
  local id like
  id=$(. /etc/os-release; echo "${ID:-}")
  like=$(. /etc/os-release; echo "${ID_LIKE:-}")
  case " $id $like " in
    *" fedora "*|*" rhel "*|*" nobara "*) echo fedora ;;
    *" debian "*|*" ubuntu "*)            echo debian ;;
    *" arch "*)                           echo arch ;;
    *" suse "*|*" opensuse "*)            echo suse ;;
    *)                                    echo unknown ;;
  esac
}

kwrite() { kwriteconfig6 "$@" 2>/dev/null || kwriteconfig5 "$@"; }
kread()  { kreadconfig6 "$@" 2>/dev/null || kreadconfig5 "$@"; }

plasma_eval() {
  local js=$1
  if have qdbus6; then qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$js"
  elif have qdbus; then qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$js"
  else
    # gdbus parses each argument as GVariant text, which mangles JavaScript, so hand it a quoted
    # string literal. It prints a GVariant tuple, ('…',), and nothing when plasmashell isn't
    # answering (e.g. mid-restart), so fail like qdbus would instead of handing Python "".
    local out
    out=$(gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell \
            --method org.kde.PlasmaShell.evaluateScript \
            "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1], ensure_ascii=False))' "$js")") || return 1
    [ -n "$out" ] || return 1
    python3 -c 'import ast,sys; print(ast.literal_eval(sys.argv[1])[0], end="")' "$out"
  fi
}

# Best installed monospace family: plain JetBrains Mono, then the Nerd Font build.
mono_font() {
  local fams
  fams=$(fc-list : family | tr ',' '\n')
  if grep -qx 'JetBrains Mono' <<<"$fams"; then echo 'JetBrains Mono'
  elif grep -qx 'JetBrainsMono Nerd Font' <<<"$fams"; then echo 'JetBrainsMono Nerd Font'
  elif grep -qx 'JetBrainsMono Nerd Font Mono' <<<"$fams"; then echo 'JetBrainsMono Nerd Font Mono'
  else echo 'Monospace'; fi
}

# One line per Plasma desktop: "<containment id> <screen> <x> <y> <width> <height>".
# Plasma reports logical geometry with rotation applied, so a 90° monitor comes out as 1440x2560.
# Screen 0 is the primary one (it gets the taskbar).
screens() {
  plasma_eval 'desktops().forEach(function (d) { var g = screenGeometry(d.screen);
    print(d.id + " " + d.screen + " " + g.x + " " + g.y + " " + g.width + " " + g.height + "\n"); });' |
    awk 'NF == 6 && $2 >= 0' | sort -k2,2n
}

# Copy a file into the current backup dir (once per run), keeping its path under $HOME.
backup() {
  local f
  for f in "$@"; do
    [ -e "$f" ] || continue
    local rel=${f#"$HOME"/}
    [ -e "$BACKUP_DIR/$rel" ] && continue
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$f" "$BACKUP_DIR/$rel"
  done
}
