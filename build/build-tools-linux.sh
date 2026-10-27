#!/bin/sh
# platform: host-agnostic
#   usage: sh build/build-tools-linux.sh [OUT]
#          Builds the ed25519 tools ($ED_TOOLS, build/lib.sh) for x86_64 Linux with the pinned clang22's
#          Linux archive (build/fetch-clang22.sh), against the host's glibc, into OUT/bin (default OUT:
#          $ED_BUILD/out, ED_BUILD being ed25519-linux), and prints OUT/bin. Runs on an x86_64 Linux host only.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ED_ROOT="$(cd "$SELF/.." && pwd)"; export ED_ROOT
ED_TARGET=linux
. "$SELF/lib.sh"
[ "$(uname -s)" = Linux ] || { echo "build-tools-linux: the Linux tools build on a Linux host, not $(uname -s)" >&2; exit 2; }

OUT="${1:-$ED_BUILD/out}"
SRC="$ED_ROOT/src"
ED="$(sh "$SELF/fetch-ed25519.sh")"
CL="$(sh "$SELF/fetch-clang22.sh")"
rm -rf "$OUT/bin"; mkdir -p "$OUT/bin"
for tool in $ED_TOOLS; do
  # platform: clang22's clang.cfg targets Mavericks, and the only compiler-rt it carries is Darwin's
  "$CL/bin/clang" --no-default-config --target=x86_64-linux-gnu --rtlib=libgcc -fuse-ld=lld \
    -I"$SRC" -I"$ED" "$SRC/$tool.c" "$ED"/*.c -o "$OUT/bin/$tool"
  chmod 755 "$OUT/bin/$tool"
done
printf '%s\n' "$OUT/bin"
