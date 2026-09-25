#!/bin/sh
# platform: host-agnostic
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
for f in UPSTREAM_COMMIT .gitignore README.md build/lib.sh \
         src/ed25519-sign.c src/ed25519-keygen.c src/mavericks_b64.h; do
  [ -f "$R/$f" ] || { echo "missing: $f" >&2; fail=1; }
done
# The moved tools must still reference their headers (sanity that the copy is intact).
grep -q '#include "mavericks_b64.h"' "$R/src/ed25519-sign.c" || { echo "sign tool lost b64 include" >&2; fail=1; }
grep -q '#include "ed25519.h"'       "$R/src/ed25519-keygen.c" || { echo "keygen lost ed25519 include" >&2; fail=1; }
# lib.sh must be sourceable and expose the helpers.
( ED_ROOT="$R"; . "$R/build/lib.sh"; command -v msc_scripts >/dev/null && command -v upstream_commit >/dev/null ) \
  || { echo "lib.sh missing helpers" >&2; fail=1; }
[ "$(ED_ROOT="$R"; . "$R/build/lib.sh"; upstream_commit)" = "b1f19fab4aebe607805620d25a5e42566ce46a0e" ] \
  || { echo "upstream_commit wrong" >&2; fail=1; }
[ "$fail" -eq 0 ] && echo "skeleton OK"
exit "$fail"
