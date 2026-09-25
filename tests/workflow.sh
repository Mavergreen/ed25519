#!/bin/sh
# platform: host-agnostic
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
W="$R/.github/workflows/release.yml"
fail=0
[ -f "$W" ] || { echo "no release.yml" >&2; exit 1; }
for needle in \
  'actions/install@v1' \
  'build/fetch-ed25519.sh' \
  'build/derive-upstream-version.sh' \
  'build/version.sh' \
  'build/build-tools.sh' \
  'build/package-pkg.sh' \
  'publish-release.yml@v1'; do
  grep -q "$needle" "$W" || { echo "release.yml missing: $needle" >&2; fail=1; }
done
# Must NOT reference Sparkle signing/appcast (out of scope).
for bad in SPARKLE_PRIVATE_KEY sign_and_appcast appcast; do
  grep -qi "$bad" "$W" && { echo "release.yml should not mention $bad" >&2; fail=1; } || true
done
# yaml sanity if a parser is present. Check PyYAML is IMPORTABLE, not merely that python3 exists: the
# runner has python3 without PyYAML, so this reported "not valid yaml" for a perfectly good file.
if command -v python3 >/dev/null && python3 -c 'import yaml' 2>/dev/null; then
  python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$W" || { echo "release.yml not valid yaml" >&2; fail=1; }
fi
[ "$fail" -eq 0 ] && echo "workflow OK"
exit "$fail"
