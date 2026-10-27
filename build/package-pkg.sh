#!/bin/sh
# platform: host-agnostic
#   usage: VERSION=V [STAGE=DIR] [OUT=DIR] sh build/package-pkg.sh
#          Compat-guards each tool's x86_64 and arm64 slices, gives the staged tree its manifest
#          and install scripts, and wraps it with the 10.9.5 floor, through shipyard's packaging
#          seams. Every mtime is the commit's time (SOURCE_DATE_EPOCH wins). Prints the .pkg path.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ED_ROOT="$(cd "$SELF/.." && pwd)"; export ED_ROOT
. "$SELF/lib.sh"

: "${VERSION:?package-pkg: VERSION required}"
STAGE="${STAGE:-$ED_BUILD/stage}"
OUT="${OUT:-$ED_BUILD/out}"
SCRIPTS="$(msc_scripts)"
ID="dev.mavergreen.ed25519"
TREE="$STAGE/$ED_TREE"
mkdir -p "$OUT"
SOURCE_DATE_EPOCH="$(cd "$ED_ROOT" && sh "$SCRIPTS/source-date-epoch.sh")"; export SOURCE_DATE_EPOCH

if [ -z "${OTOOL:-}" ] || [ -z "${LIPO:-}" ] || [ -z "${NM:-}" ] || [ -z "${STRINGS:-}" ]; then
  CL="$(sh "$SELF/fetch-clang22.sh")"
  : "${OTOOL:=$CL/bin/llvm-otool}" "${LIPO:=$CL/bin/llvm-lipo}" "${NM:=$CL/bin/llvm-nm}" "${STRINGS:=$CL/bin/llvm-strings}"
fi
export OTOOL LIPO NM STRINGS
BIN=""
for t in $ED_TOOLS; do
  BIN="$BIN $TREE/bin/$t"
done
MAVERICKS_ALLOW_ARCHS="x86_64 arm64" sh "$SCRIPTS/assert_binary_compatible.sh" $BIN >&2

mkdir -p "$TREE/share/doc"
cp "$ED_ROOT/THIRD-PARTY-NOTICES.txt" "$TREE/share/doc/THIRD-PARTY-NOTICES.txt"

SCR="$OUT/pkg-scripts"; rm -rf "$SCR"
sh "$SCRIPTS/stage_product.sh" --stage "$STAGE" --product ed25519 --name ed25519 \
  --version "$VERSION" --scripts-out "$SCR" >&2

mkdir -p "$OUT/component"
comp="$OUT/component/ed25519-component.pkg"
sh "$SCRIPTS/build_component_pkg.sh" --root "$STAGE" --identifier "$ID" --version "$VERSION" \
  --scripts "$SCR" --install-location / --out "$comp" >&2

final="$OUT/ed25519-${VERSION}.pkg"
sh "$SCRIPTS/set_install_floor.sh" --identifier "$ID" --title "ed25519 ${VERSION}" \
  --component "$comp" --out "$final" --require-scripts --host-arch x86_64,arm64 >&2

printf '%s\n' "$final"
