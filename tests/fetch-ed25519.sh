#!/bin/sh
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$(mktemp -d "${TMPDIR:-/tmp}/fetch-ed25519.XXXXXX")"; trap 'rm -rf "$DEST"' EXIT   # template: 10.9 BSD mktemp requires one
src="$(ED_ROOT="$R" sh "$R/build/fetch-ed25519.sh" "$DEST")"
[ -f "$src/sign.c" ] || { echo "no sign.c in $src" >&2; exit 1; }
[ -f "$src/ed25519.h" ] || { echo "no ed25519.h in $src" >&2; exit 1; }
# The checkout root is one level up from src/; its HEAD must be the pinned commit.
head="$(git -C "$src/.." rev-parse HEAD)"
[ "$head" = "b1f19fab4aebe607805620d25a5e42566ce46a0e" ] || { echo "HEAD != pinned commit ($head)" >&2; exit 1; }
echo "fetch-ed25519 OK: $src"
