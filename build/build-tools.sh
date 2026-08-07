#!/bin/sh
# Build both Sparkle ed25519 tools as Universal binaries: x86_64 @ min-10.9 (against the
# shipyard-fetched 10.9 SDK) + arm64 @ min-11.0, lipo'd together. Installs into
# <stage>/usr/local/bin. Host tools -- the x86_64 slice is 10.9 so a Mavericks dev can run it.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ED_ROOT="$(cd "$SELF/.." && pwd)"; export ED_ROOT
. "$SELF/lib.sh"

STAGE="${1:-$ED_ROOT/build/stage}"
SRC="$ED_ROOT/src"
ED="$(sh "$SELF/fetch-ed25519.sh")"
SCRIPTS="$(msc_scripts)"
SDK="${SDK:-$(sh "$SCRIPTS/fetch_sdk.sh")}"

WORK="$ED_ROOT/build/obj"; rm -rf "$WORK"; mkdir -p "$WORK"
rm -rf "$STAGE"; mkdir -p "$STAGE/usr/local/bin"

for tool in ed25519-keygen ed25519-sign; do
  cc -arch x86_64 -isysroot "$SDK" -mmacosx-version-min=10.9 \
     -I"$SRC" -I"$ED" "$SRC/$tool.c" "$ED"/*.c -o "$WORK/$tool.x86_64"
  cc -arch arm64 -mmacosx-version-min=11.0 \
     -I"$SRC" -I"$ED" "$SRC/$tool.c" "$ED"/*.c -o "$WORK/$tool.arm64"
  lipo -create "$WORK/$tool.x86_64" "$WORK/$tool.arm64" -output "$STAGE/usr/local/bin/$tool"
done

printf '%s\n' "$STAGE"
