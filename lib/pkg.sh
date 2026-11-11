# Package helpers over lib/packages.tsv. Source after lib.sh, don't execute.
#   pkg_rows PART…        id, on, description of the packages those parts want (tab separated)
#   pkg_default PART…     the ids picked by default for those parts
#   pkg_names ID…         this distro's package names for them (@specials included)
#   pkg_installed ID      true when all of its packages are there
#   pkg_install ID…       installs them (sudo); @vt323 is downloaded, other @… are left to the caller
# A PART is plasma, tile.<part> or tile (= every tile part).

PKG_TSV="$REPO/lib/packages.tsv"

pkg_family() {
  case "$(distro_family)" in fedora) echo 5 ;; debian) echo 6 ;; arch) echo 7 ;; suse) echo 8 ;; *) echo 0 ;; esac
}

pkg_rows() {
  awk -F'\t' -v want=" $* " '
    /^#/ || NF < 8 { next }
    { n = split($2, ps, ","); hit = 0
      for (i = 1; i <= n; i++) {
        p = ps[i]; split(p, top, ".")
        if (index(want, " " p " ") || index(want, " " top[1] " ")) hit = 1
      }
      if (hit && !seen[$1]++) print $1 "\t" $3 "\t" $4 }' "$PKG_TSV"
}

pkg_default() { pkg_rows "$@" | awk -F'\t' '$2 == 1 { print $1 }'; }

pkg_names() {
  local col; col=$(pkg_family)
  [ "$col" != 0 ] || return 0
  awk -F'\t' -v col="$col" -v ids=" $* " '
    /^#/ || NF < 8 { next }
    index(ids, " " $1 " ") && $col != "-" { print $col }' "$PKG_TSV" | tr ' ' '\n' | sed '/^$/d'
}

pkg_has_name() {  # one distro package name, or @vt323
  case "$1" in
    @vt323) fc-list 2>/dev/null | grep VT323 >/dev/null ;;
    @quickshell) have qs ;;
    @*) return 1 ;;
    *) case "$(distro_family)" in
         fedora|suse) rpm -q --whatprovides "$1" >/dev/null 2>&1 ;;
         debian) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed' ;;
         arch) pacman -Q "$1" >/dev/null 2>&1 ;;
         *) return 1 ;;
       esac ;;
  esac
}

pkg_installed() {
  local n names; names=$(pkg_names "$1")
  [ -n "$names" ] || return 1
  for n in $names; do pkg_has_name "$n" || return 1; done
}

# Installs the distro packages and VT323; prints the other @specials for the caller to handle.
pkg_install() {
  local names=() n special=()
  while read -r n; do
    case "$n" in @vt323) special+=(vt323) ;; @*) echo "${n#@}" ;; *) names+=("$n") ;; esac
  done < <(pkg_names "$@")
  if [ ${#names[@]} -gt 0 ]; then
    case "$(distro_family)" in
      fedora) sudo dnf install -y --skip-unavailable "${names[@]}" >&2 ;;
      debian) sudo apt-get install -y "${names[@]}" >&2 ;;
      arch)   sudo pacman -S --needed --noconfirm "${names[@]}" >&2 ;;
      suse)   sudo zypper install -y "${names[@]}" >&2 ;;
      *)      warn "unknown distro; install by hand: ${names[*]}" ;;
    esac
  fi
  if [ ${#special[@]} -gt 0 ] && ! fc-list 2>/dev/null | grep VT323 >/dev/null; then
    local fontdir="$XDG_DATA_HOME/fonts/nook"
    mkdir -p "$fontdir"
    curl -fsSL -o "$fontdir/VT323-Regular.ttf" \
      https://raw.githubusercontent.com/google/fonts/main/ofl/vt323/VT323-Regular.ttf \
      && fc-cache -f "$fontdir" >/dev/null && ok "VT323" >&2 || warn "could not fetch VT323; headings fall back to JetBrains Mono"
  fi
}
