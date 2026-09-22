#!/bin/sh
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
# shipyard's scripts: $SHIPYARD_SCRIPTS in CI (exported by install@v1), else a sibling checkout.
# This used to hardcode one developer's absolute path, so the test only ever passed on that machine --
# invisible until CI started running it. With neither available there is nothing to build against, so
# exit 77 = SKIP (the family convention) rather than fail.
: "${MAVERICKS_SCRIPTS:=${SHIPYARD_SCRIPTS:-$R/../mavergreen-shipyard/scripts}}"
[ -d "$MAVERICKS_SCRIPTS" ] || { echo "shipyard scripts not found at $MAVERICKS_SCRIPTS -- skipping" >&2; exit 77; }
export MAVERICKS_SCRIPTS
# CROSS-ONLY by design, so ask the family's mode helper rather than inventing a local probe. The
# Universal build compiles its arm64 slice at -mmacosx-version-min=11.0, a version 10.9's clang
# rejects outright ("invalid version number in '-mmacosx-version-min=11.0'"). A Mavericks box cannot
# produce this artifact and is not supposed to -- that is a host limitation, not a failure, so it
# SKIPs (77) the same way every other host-impossible test in the family does.
[ "$(sh "$MAVERICKS_SCRIPTS/mavericks_mode.sh")" = cross ] || {
  echo "native 10.9 host: the Universal build needs a modern toolchain for the arm64 slice -- skipping" >&2
  exit 77
}
STAGE="$(ED_ROOT="$R" sh "$R/build/build-tools.sh")"
pkg="$(VERSION=20190301-mavericks.1 STAGE="$STAGE" ED_ROOT="$R" sh "$R/build/package-pkg.sh")"
[ -f "$pkg" ] || { echo "no pkg at $pkg" >&2; exit 1; }
# Floor + install-location present in the built product.
X="$(mktemp -d "${TMPDIR:-/tmp}/package-pkg.XXXXXX")"; trap 'rm -rf "$X"' EXIT   # template: 10.9 BSD mktemp requires one
pkgutil --expand "$pkg" "$X/x"
grep -q 'os-version min="10.9.5"' "$X/x/Distribution" || { echo "floor missing" >&2; exit 1; }
# The tools ship inside the pkg payload -- verify, exactly as CI extracts ed25519-sign.
pkgutil --expand-full "$pkg" "$X/full"
find "$X/full" -type f -name ed25519-sign  | grep -q . || { echo "pkg payload missing ed25519-sign"  >&2; exit 1; }
find "$X/full" -type f -name ed25519-keygen | grep -q . || { echo "pkg payload missing ed25519-keygen" >&2; exit 1; }
find "$X/full" -type f -name ed25519-verify | grep -q . || { echo "pkg payload missing ed25519-verify" >&2; exit 1; }
echo "package-pkg OK"
