#!/bin/sh
# platform: macOS-only -- pkgbuild builds the component
#   usage: VERSION=V [STAGE=DIR] [OUT=DIR] sh build/package-pkg.sh
#          Compat-guards each tool's x86_64 and arm64 slices, gives the staged tree its manifest
#          and install scripts, and wraps it with the 10.9.5 floor. Prints the .pkg path.
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
pkgbuild --root "$STAGE" --identifier "$ID" --version "$VERSION" --scripts "$SCR" \
  --install-location / "$comp" >&2

final="$OUT/ed25519-${VERSION}.pkg"
sh "$SCRIPTS/set_install_floor.sh" --identifier "$ID" --title "ed25519 ${VERSION}" \
  --component "$comp" --out "$final" --require-scripts >&2

printf '%s\n' "$final"
