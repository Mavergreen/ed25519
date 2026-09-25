#!/bin/sh
# platform: macOS-only -- cc and lipo build the Universal binaries
# Build the ed25519 tools ($ED_TOOLS, build/lib.sh) as Universal binaries: x86_64 @ min-10.9 (against the
# shipyard-fetched 10.9 SDK) + arm64 @ min-11.0 (against the shipyard-fetched 11.3 SDK), lipo'd
# together. Installs into <stage>/usr/local/mavergreen/ed25519/bin. Host tools -- the x86_64 slice is 10.9 so a
# Mavericks dev can run it.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ED_ROOT="$(cd "$SELF/.." && pwd)"; export ED_ROOT
. "$SELF/lib.sh"

STAGE="${1:-$ED_BUILD/stage}"
SRC="$ED_ROOT/src"
ED="$(sh "$SELF/fetch-ed25519.sh")"
SCRIPTS="$(msc_scripts)"
# Same cross-only rule as the tests, checked before any work: on a 10.9 box cc rejects the arm64
# slice's -mmacosx-version-min=11.0, and the resulting "invalid version number" says nothing about
# why. The release workflow builds these on an Apple-Silicon runner.
if [ "$(sh "$SCRIPTS/mavericks_mode.sh")" != cross ]; then
  echo "build-tools: the Universal build needs a modern host -- its arm64 slice targets macOS 11.0," >&2
  echo "    which this native 10.9 toolchain cannot target. Build it where release.yml does." >&2
  exit 1
fi

SDK="${SDK:-$(sh "$SCRIPTS/fetch_sdk.sh")}"
SDK_ARM64="${SDK_ARM64:-$(sh "$SCRIPTS/fetch_sdk.sh" --arch arm64)}"

WORK="$ED_BUILD/obj"; rm -rf "$WORK"; mkdir -p "$WORK"
rm -rf "$STAGE"; mkdir -p "$STAGE/$ED_TREE/bin"

for tool in $ED_TOOLS; do
  cc -arch x86_64 -isysroot "$SDK" -mmacosx-version-min=10.9 \
     -I"$SRC" -I"$ED" "$SRC/$tool.c" "$ED"/*.c -o "$WORK/$tool.x86_64"
  cc -arch arm64 -isysroot "$SDK_ARM64" -mmacosx-version-min=11.0 \
     -I"$SRC" -I"$ED" "$SRC/$tool.c" "$ED"/*.c -o "$WORK/$tool.arm64"
  lipo -create "$WORK/$tool.x86_64" "$WORK/$tool.arm64" -output "$STAGE/$ED_TREE/bin/$tool"
done

printf '%s\n' "$STAGE"
