#!/bin/sh
# platform: host-agnostic
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
: "${MAVERICKS_SCRIPTS:=${SHIPYARD_SCRIPTS:-$R/../mavergreen-shipyard/scripts}}"
[ -d "$MAVERICKS_SCRIPTS" ] || { echo "shipyard scripts not found at $MAVERICKS_SCRIPTS -- skipping" >&2; exit 77; }
SHIPYARD_SCRIPTS="$MAVERICKS_SCRIPTS"; export SHIPYARD_SCRIPTS MAVERICKS_SCRIPTS
[ "$(sh "$MAVERICKS_SCRIPTS/mavericks_mode.sh")" = cross ] || {
  echo "native 10.9 host: clang22-cross, which builds the arm64 slice, runs on macOS 11 and later -- skipping" >&2
  exit 77
}
X="$(mktemp -d "${TMPDIR:-/tmp}/package-pkg.XXXXXX")"; trap 'rm -rf "$X"' EXIT
STAGE="$(ED_ROOT="$R" sh "$R/build/build-tools.sh" "$X/stage")"
pkg="$(VERSION=20190301-mavericks.1 STAGE="$STAGE" OUT="$X/out" ED_ROOT="$R" sh "$R/build/package-pkg.sh")"
[ -f "$pkg" ] || { echo "no pkg at $pkg" >&2; exit 1; }
grep -qF 'pkgbuild' "$R/build/package-pkg.sh" && { echo "package-pkg.sh builds with shipyard's seams, never pkgbuild" >&2; exit 1; }
SD="$(sh "$MAVERICKS_SCRIPTS/fetch_stevedore.sh")"
"$SD" expand "$pkg" "$X/x" >/dev/null
grep -q 'os-version min="10.9.5"' "$X/x/Distribution" || { echo "floor missing" >&2; exit 1; }
grep -q 'hostArchitectures="x86_64,arm64"' "$X/x/Distribution" \
  || { echo "the pkg must declare both host architectures, or Installer on Apple Silicon runs its scripts under Rosetta" >&2; exit 1; }
first="$(sed -n 's/.*<line choice="\([^"]*\)".*/\1/p' "$X/x/Distribution" | grep -v '^default$' | head -1)"
[ "$first" = dev.mavergreen.base ] || { echo "the base component must come first, got $first" >&2; exit 1; }
comp="$(dirname "$(grep -l 'identifier="dev.mavergreen.ed25519"' "$X"/x/*/PackageInfo)")"
mkdir "$X/full"
( cd "$X/full" && gzip -dc "$comp/Payload" | cpio -id --quiet 2>/dev/null )
T="$X/full/usr/local/mavergreen/ed25519"
for t in ed25519-keygen ed25519-sign ed25519-verify; do
  [ -f "$T/bin/$t" ] || { echo "pkg payload missing $t" >&2; exit 1; }
done
[ "$("$SD" plist get "$T/mavergreen.plist" product)" = ed25519 ] \
  || { echo "the pkg must carry the ed25519 manifest at its tree root" >&2; exit 1; }
[ "$(find "$X/full" -type f -name ed25519-sign | wc -l | tr -d ' ')" = 1 ] \
  || { echo "exactly one ed25519-sign in the payload: sign_and_appcast.sh signs every family release with the first it finds" >&2; exit 1; }
cmp "$R/THIRD-PARTY-NOTICES.txt" "$T/share/doc/THIRD-PARTY-NOTICES.txt"
find "$X/full" -path '*/usr/local/bin/*' | grep -q . && { echo "nothing installs into /usr/local/bin" >&2; exit 1; }
echo "package-pkg OK"
