#!/bin/sh
# platform: macOS-only -- runs the tools the pkg installed, and reads its receipt with pkgutil
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
T=/usr/local/mavergreen/ed25519
[ -f "$T/mavergreen.plist" ] || { echo "ed25519 is not installed here -- skipping" >&2; exit 77; }
if [ -n "${ED25519_VERSION_UNDER_TEST:-}" ]; then
  V="$ED25519_VERSION_UNDER_TEST"
  got="$(/usr/libexec/PlistBuddy -c 'Print :version' "$T/mavergreen.plist")"
  [ "$got" = "$V" ] || { echo "the installed manifest says $got, not $V" >&2; exit 1; }
  got="$(pkgutil --pkg-info dev.mavergreen.ed25519 | sed -n 's/^version: //p')"
  [ "$got" = "$V" ] || { echo "the receipt says $got, not $V" >&2; exit 1; }
fi
for t in ed25519-keygen ed25519-sign ed25519-verify; do
  [ "/usr/local/mavergreen/bin/$t" -ef "$T/bin/$t" ] \
    || { echo "/usr/local/mavergreen/bin/$t is not the installed $t" >&2; exit 1; }
done
K="$(mktemp -d "${TMPDIR:-/tmp}/installed-smoke.XXXXXX")"; trap 'rm -rf "$K"' EXIT
"$T/bin/ed25519-keygen" -f "$K/k" >/dev/null
echo test-message > "$K/msg"
sig="$("$T/bin/ed25519-sign" -f "$K/k" "$K/msg")"
[ "$("$T/bin/ed25519-verify" -p "$(cat "$K/k.pub")" "$K/msg" "$sig")" = "$(cat "$K/k.pub")" ] \
  || { echo "the installed ed25519-verify did not verify the installed ed25519-sign's signature" >&2; exit 1; }
FX="$R/tests/fixtures/pinned-signer"
[ "$("$T/bin/ed25519-sign" -f "$FX/throwaway-key" "$FX/message")" = "$(cat "$FX/signature")" ] \
  || { echo "the installed ed25519-sign does not sign the fixture as the pinned Mac release did" >&2; exit 1; }
echo "installed-smoke OK"
