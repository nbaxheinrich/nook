#!/usr/bin/env bash
# Make Hyprland (or Plasma again) the session the login screen preselects.
# usage: shared/login/default-session.sh [hyprland|plasma|<name of a .desktop in /usr/share/wayland-sessions>]
#
# Handles the common display managers (needs sudo):
#   Plasma Login, SDDM  → [Last] Session in their state.conf (+ SDDM's DefaultSession)
#   GDM, LightDM        → AccountsService: the per-user session
# The session list stays as it is; this only changes what is selected by default.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/lib.sh"

name=${1:-hyprland}
desktop=""
for d in /usr/share/wayland-sessions /usr/share/xsessions; do
  [ -f "$d/$name.desktop" ] && { desktop="$d/$name.desktop"; break; }
done
[ -n "$desktop" ] || die "no session '$name' (have: $(ls /usr/share/wayland-sessions | sed 's/\.desktop//' | tr '\n' ' '))"

dm=$(systemctl show -p Id --value display-manager.service 2>/dev/null || true)
user=$(id -un)
step "default session → $name ($dm)"

# set KEY=VALUE in [GROUP] of an ini file as root, creating file/group/key as needed
ini_set() {
  local file=$1 group=$2 key=$3 value=$4
  sudo python3 -I - "$file" "$group" "$key" "$value" <<'EOF'
import os, sys
path, group, key, value = sys.argv[1:]
lines = open(path).read().splitlines() if os.path.exists(path) else []
out, in_group, done, seen = [], False, False, False
for l in lines:
    s = l.strip()
    if s.startswith("[") and s.endswith("]"):
        if in_group and not done:
            out.append(f"{key}={value}"); done = True
        in_group = s == f"[{group}]"; seen = seen or in_group
    elif in_group and s.split("=", 1)[0].strip() == key:
        if not done: out.append(f"{key}={value}"); done = True
        continue
    out.append(l)
if not done:
    if not seen: out += ([""] if out else []) + [f"[{group}]"]
    out.append(f"{key}={value}")
open(path, "w").write("\n".join(out) + "\n")
EOF
}

# keep the state file's owner (the greeter user) when it exists
ini_set_owned() {
  local file=$1 owner
  owner=$(sudo stat -c '%U:%G' "$file" 2>/dev/null || true)
  ini_set "$@"
  [ -n "$owner" ] && sudo chown "$owner" "$file"
  return 0
}

case "$dm" in
  plasmalogin.service)
    ini_set_owned /var/lib/plasmalogin/state.conf Last Session "$desktop"
    ini_set_owned /var/lib/plasmalogin/state.conf Last User "$user"
    ok "Plasma Login: preselects $name for $user"
    ;;
  sddm.service)
    ini_set_owned /var/lib/sddm/state.conf Last Session "$desktop"
    ini_set_owned /var/lib/sddm/state.conf Last User "$user"
    sudo mkdir -p /etc/sddm.conf.d
    ini_set /etc/sddm.conf.d/zz-nook-session.conf General DefaultSession "$name.desktop"
    ok "SDDM: preselects $name (also its DefaultSession for new users)"
    ;;
  gdm.service|gdm3.service|lightdm.service)
    f=/var/lib/AccountsService/users/$user
    ini_set "$f" User Session "$name"
    ini_set "$f" User XSession "$name"
    ok "${dm%.service}: $user's session is $name (AccountsService)"
    ;;
  *)
    die "unknown display manager '${dm:-none}': pick '$name' on the login screen once, most remember it"
    ;;
esac
printf '  back to Plasma: %s plasma\n' "$0"
