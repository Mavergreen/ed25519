#!/bin/sh
# platform: host-agnostic
#   usage: sh build/fetch-clang22.sh
#          Prints the prefix of the clang22 release components/clang22/version names, for this host. On
#          Linux: that release's linux-x86_64 archive, verified against components/clang22/sha256
#          (build/pin-clang22.sh writes it). On a Mac: the installed /usr/local/mavergreen/clang22-cross
#          (CLANG22_INSTALLED moves it) when its manifest names that release, else that release's
#          clang22-cross pkg. Either holds both the x86_64 and the arm64 backends. Both are unpacked
#          once into the build root.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ED_ROOT="$(cd "$SELF/.." && pwd)"; export ED_ROOT
. "$SELF/lib.sh"
V="$(tr -d ' \t\n' < "$ED_ROOT/components/clang22/version")"
case "$V" in ''|.|..|*[!a-zA-Z0-9._-]*) echo "fetch-clang22: components/clang22/version holds '$V', not a release tag" >&2; exit 2 ;; esac
W="$MAVERICKS_BUILD_ROOT/clang22/$V"
has_tools() {
  for t in clang ld64.lld llvm-lipo llvm-otool llvm-nm llvm-strings; do [ -x "$1/bin/$t" ] || return 1; done
}
case "$(uname -s)" in
  Linux)
    [ "$(uname -m)" = x86_64 ] || { echo "fetch-clang22: clang22 publishes a Linux archive for x86_64 hosts only, not $(uname -m)" >&2; exit 2; }
    sha=""
    [ ! -f "$ED_ROOT/components/clang22/sha256" ] || sha="$(tr -d ' \t\n' < "$ED_ROOT/components/clang22/sha256")"
    case "$sha" in ''|*[!0-9a-f]*) echo "fetch-clang22: components/clang22/sha256 holds no SHA-256 for clang22 $V's Linux archive -- write it with sh build/pin-clang22.sh" >&2; exit 1 ;; esac
    [ "${#sha}" -eq 64 ] || { echo "fetch-clang22: components/clang22/sha256 holds no SHA-256 for clang22 $V's Linux archive -- write it with sh build/pin-clang22.sh" >&2; exit 1; }
    d="$W/linux"
    sh "$SHIPYARD_SCRIPTS/fetch_product_tar.sh" clang22 "$V" "$sha" "$d" >/dev/null ;;
  Darwin)
    inst="${CLANG22_INSTALLED:-/usr/local/mavergreen/clang22-cross}"
    if has_tools "$inst" && [ -f "$inst/mavergreen.plist" ] \
       && [ "$("$(sh "$SHIPYARD_SCRIPTS/fetch_stevedore.sh")" plist get "$inst/mavergreen.plist" version 2>/dev/null)" = "$V" ]; then
      printf '%s\n' "$inst"; exit 0
    fi
    d="$W/cross"
    sh "$SHIPYARD_SCRIPTS/fetch_product_pkg.sh" --asset "mavericks-clang-22-cross-$V.pkg" clang22-cross "$V" "$d" >/dev/null ;;
  *) echo "fetch-clang22: clang22 builds ed25519 on Linux and on a Mac, not on $(uname -s)" >&2; exit 2 ;;
esac
has_tools "$d" || { echo "fetch-clang22: $d lacks clang, ld64.lld or one of llvm-{lipo,otool,nm,strings}" >&2; exit 1; }
printf '%s\n' "$d"
