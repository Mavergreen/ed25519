#!/bin/sh
# Compat-guard the x86_64 slice of each Universal tool, pkgbuild a component installing to
# /usr/local/bin, productbuild it with a 10.9.5 floor (no host-arch restriction -- Universal),
# and tar the binaries for scriptable CI use. Double-clickable .pkg + plain tarball.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ED_ROOT="$(cd "$SELF/.." && pwd)"; export ED_ROOT
. "$SELF/lib.sh"

: "${VERSION:?package-pkg: VERSION required}"
STAGE="${STAGE:-$ED_BUILD/stage}"
OUT="${OUT:-$ED_BUILD/out}"
SCRIPTS="$(msc_scripts)"
ID="dev.modernmavericks.ed25519"
mkdir -p "$OUT"

# 1) prove each shipped tool's x86_64 slice is 10.9-safe (thin it out, guard it).
THIN="$OUT/thin"; rm -rf "$THIN"; mkdir -p "$THIN"
for t in $ED_TOOLS; do
  lipo -thin x86_64 "$STAGE/usr/local/bin/$t" -output "$THIN/$t"
done
sh "$SCRIPTS/assert_binary_compatible.sh" "$THIN"/* >&2

# bundle the orlp/ed25519 (zlib) third-party notice into the installed payload.
mkdir -p "$STAGE/usr/local/share/doc/mavericks-ed25519"
cp "$ED_ROOT/THIRD-PARTY-NOTICES.txt" "$STAGE/usr/local/share/doc/mavericks-ed25519/THIRD-PARTY-NOTICES.txt"

# 2) flat component pkg from the staging root (absolute layout -> install-location /).
mkdir -p "$OUT/component"
comp="$OUT/component/ed25519-component.pkg"
pkgbuild --root "$STAGE" --identifier "$ID" --version "$VERSION" --install-location / "$comp" >&2

# 3) wrap with the 10.9.5 floor; NO --host-arch (Universal installs on any arch).
final="$OUT/ed25519-${VERSION}.pkg"
sh "$SCRIPTS/set_install_floor.sh" \
  --identifier "$ID" \
  --title "ed25519 ${VERSION}" \
  --component "$comp" \
  --out "$final" >&2

printf '%s\n' "$final"
