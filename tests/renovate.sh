#!/bin/sh
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
J="$R/.github/renovate.json"
[ -f "$J" ] || { echo "no renovate.json" >&2; exit 1; }
if command -v python3 >/dev/null; then
  python3 -c 'import sys,json; json.load(open(sys.argv[1]))' "$J" || { echo "invalid json" >&2; exit 1; }
fi
grep -q 'Mavergreen/shipyard' "$J" || { echo "does not extend shipyard preset" >&2; exit 1; }
grep -q 'orlp/ed25519' "$J" || { echo "does not track orlp/ed25519" >&2; exit 1; }
grep -q 'git-refs' "$J" || { echo "wrong datasource" >&2; exit 1; }
grep -q 'UPSTREAM_COMMIT' "$J" || { echo "not matching UPSTREAM_COMMIT" >&2; exit 1; }
echo "renovate OK"
