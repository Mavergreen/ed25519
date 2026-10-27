#!/bin/sh
# platform: host-agnostic
#   usage: sh build/build-tools.sh [STAGE]
#          Builds the ed25519 tools ($ED_TOOLS, build/lib.sh) as Universal binaries with the pinned clang22
#          (build/fetch-clang22.sh), on Linux or a modern Mac: x86_64 at 10.9 against the pinned 10.9 SDK and
#          arm64 at 11.0 against the pinned 11.3 SDK, merged with LIPO (default: clang22's llvm-lipo). Installs
#          them into STAGE/usr/local/mavergreen/ed25519/bin (default STAGE: $ED_BUILD/stage) and prints STAGE.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ED_ROOT="$(cd "$SELF/.." && pwd)"; export ED_ROOT
. "$SELF/lib.sh"

STAGE="${1:-$ED_BUILD/stage}"
SRC="$ED_ROOT/src"
SCRIPTS="$(msc_scripts)"
if [ "$(sh "$SCRIPTS/mavericks_mode.sh")" != cross ]; then
  echo "build-tools: the arm64 slice needs clang22-cross, which runs on macOS 11 and later, or Linux;" >&2
  echo "    this native 10.9 host cannot build it. Build it where release.yml does." >&2
  exit 1
fi
ED="$(sh "$SELF/fetch-ed25519.sh")"
CL="$(sh "$SELF/fetch-clang22.sh")"
LIPO="${LIPO:-$CL/bin/llvm-lipo}"

SDK="${SDK:-$(sh "$SCRIPTS/fetch_sdk.sh")}"
SDK_ARM64="${SDK_ARM64:-$(sh "$SCRIPTS/fetch_sdk.sh" --arch arm64)}"

mkdir -p "$ED_BUILD"
WORK="$(mktemp -d "$ED_BUILD/obj.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
rm -rf "$STAGE"; mkdir -p "$STAGE/$ED_TREE/bin"

for tool in $ED_TOOLS; do
  "$CL/bin/clang" --no-default-config --target=x86_64-apple-macos10.9 -isysroot "$SDK" --ld-path="$CL/bin/ld64.lld" \
    -I"$SRC" -I"$ED" "$SRC/$tool.c" "$ED"/*.c -o "$WORK/$tool.x86_64"
  "$CL/bin/clang" --no-default-config --target=arm64-apple-macos11.0 -isysroot "$SDK_ARM64" --ld-path="$CL/bin/ld64.lld" \
    -I"$SRC" -I"$ED" "$SRC/$tool.c" "$ED"/*.c -o "$WORK/$tool.arm64"
  "$LIPO" -create "$WORK/$tool.x86_64" "$WORK/$tool.arm64" -output "$STAGE/$ED_TREE/bin/$tool"
  chmod 755 "$STAGE/$ED_TREE/bin/$tool"
done

printf '%s\n' "$STAGE"
