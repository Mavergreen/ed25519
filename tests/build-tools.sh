#!/bin/sh
# platform: host-agnostic
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
grep -qF 'SDK_ARM64="${SDK_ARM64:-$(sh "$SCRIPTS/fetch_sdk.sh" --arch arm64)}"' "$R/build/build-tools.sh" \
  || { echo "build-tools.sh: SDK_ARM64 must come from fetch_sdk.sh --arch arm64" >&2; exit 1; }
grep -qF -- '--target=arm64-apple-macos11.0 -isysroot "$SDK_ARM64"' "$R/build/build-tools.sh" \
  || { echo "build-tools.sh: the arm64 slice must target macOS 11.0 against \$SDK_ARM64" >&2; exit 1; }
[ "$(grep -c -- '-fuse-ld=lld --ld-path="$CL/bin/ld64.lld"' "$R/build/build-tools.sh")" = 2 ] \
  || { echo "build-tools.sh: both slices must link with -fuse-ld=lld and clang22's ld64.lld, so every host's clang22 drives the linker alike" >&2; exit 1; }
grep -qF -- '--target=x86_64-apple-macos10.9 -isysroot "$SDK"' "$R/build/build-tools.sh" \
  || { echo "build-tools.sh: the x86_64 slice must target 10.9 against \$SDK" >&2; exit 1; }
: "${MAVERICKS_SCRIPTS:=${SHIPYARD_SCRIPTS:-$R/../mavergreen-shipyard/scripts}}"
[ -d "$MAVERICKS_SCRIPTS" ] || { echo "shipyard scripts not found at $MAVERICKS_SCRIPTS -- skipping" >&2; exit 77; }
SHIPYARD_SCRIPTS="$MAVERICKS_SCRIPTS"; export SHIPYARD_SCRIPTS MAVERICKS_SCRIPTS
[ "$(sh "$MAVERICKS_SCRIPTS/mavericks_mode.sh")" = cross ] || {
  echo "native 10.9 host: clang22-cross, which builds the arm64 slice, runs on macOS 11 and later -- skipping" >&2
  exit 77
}
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/build-tools.XXXXXX")"; trap 'rm -rf "$STAGE"' EXIT
ED_ROOT="$R" sh "$R/build/build-tools.sh" "$STAGE" >/dev/null
LIPO="${LIPO:-$(sh "$R/build/fetch-clang22.sh")/bin/llvm-lipo}"
for t in ed25519-keygen ed25519-sign ed25519-verify; do
  b="$STAGE/usr/local/mavergreen/ed25519/bin/$t"
  [ -x "$b" ] || { echo "missing $t" >&2; exit 1; }
  archs="$(printf '%s\n' $("$LIPO" -archs "$b") | LC_ALL=C sort | tr '\n' ' ')"
  [ "$archs" = "arm64 x86_64 " ] || { echo "$t carries [$archs], not exactly arm64 and x86_64" >&2; exit 1; }
done
echo "build-tools OK"
