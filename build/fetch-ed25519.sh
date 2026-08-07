#!/bin/sh
# Fetch orlp/ed25519 at the pinned commit (build/../UPSTREAM_COMMIT) via shipyard's clone_pinned.sh:
# it fetches exactly that commit and verifies the checkout is it (git also verifies the fetched objects
# hash to the sha), so there is no separate tarball checksum to keep in sync. Renovate bumps
# UPSTREAM_COMMIT (git-refs/currentDigest on master). Prints the src/ dir (the *.c + ed25519.h).
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ED_ROOT="$(cd "$SELF/.." && pwd)"; export ED_ROOT
. "$SELF/lib.sh"
. "$SELF/msc.sh"   # -> $SHIPYARD (installed mavericks-shipyard scripts dir)

C="$(upstream_commit)"
DEST="${1:-$ED_ROOT/build/ed25519}"
mkdir -p "$DEST"; DEST="$(cd "$DEST" && pwd)"   # normalize -> contract: prints an ABSOLUTE src dir
CO="$DEST/ed25519-$C"
sh "$SHIPYARD/clone_pinned.sh" https://github.com/orlp/ed25519.git master "$C" "$CO"
[ -f "$CO/src/sign.c" ] || { echo "fetch-ed25519: no src/sign.c after fetch" >&2; exit 1; }
printf '%s\n' "$CO/src"
