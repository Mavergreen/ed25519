#!/bin/sh
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
# The arm64 slice must build against the pinned arm64 SDK (fetch_sdk.sh --arch arm64), never
# whatever SDK the host's own toolchain defaults to. Checked statically (grep), so it fails on ANY
# host, not only where the cross build below actually runs.
grep -qF 'SDK_ARM64="${SDK_ARM64:-$(sh "$SCRIPTS/fetch_sdk.sh" --arch arm64)}"' "$R/build/build-tools.sh" \
  || { echo "build-tools.sh: SDK_ARM64 must come from fetch_sdk.sh --arch arm64" >&2; exit 1; }
grep -qF 'cc -arch arm64 -isysroot "$SDK_ARM64"' "$R/build/build-tools.sh" \
  || { echo "build-tools.sh: the arm64 cc invocation must pass -isysroot \"\$SDK_ARM64\"" >&2; exit 1; }
# shipyard's scripts: $SHIPYARD_SCRIPTS in CI (exported by install@v1), else a sibling checkout.
# This used to hardcode one developer's absolute path, so the test only ever passed on that machine --
# invisible until CI started running it. With neither available there is nothing to build against, so
# exit 77 = SKIP (the family convention) rather than fail.
: "${MAVERICKS_SCRIPTS:=${SHIPYARD_SCRIPTS:-$R/../mavergreen-shipyard/scripts}}"
[ -d "$MAVERICKS_SCRIPTS" ] || { echo "shipyard scripts not found at $MAVERICKS_SCRIPTS -- skipping" >&2; exit 77; }
export MAVERICKS_SCRIPTS
# CROSS-ONLY by design, so ask the family's mode helper rather than inventing a local probe. The
# Universal build compiles its arm64 slice at -mmacosx-version-min=11.0, a version 10.9's clang
# rejects outright ("invalid version number in '-mmacosx-version-min=11.0'"). A Mavericks box cannot
# produce this artifact and is not supposed to -- that is a host limitation, not a failure, so it
# SKIPs (77) the same way every other host-impossible test in the family does.
[ "$(sh "$MAVERICKS_SCRIPTS/mavericks_mode.sh")" = cross ] || {
  echo "native 10.9 host: the Universal build needs a modern toolchain for the arm64 slice -- skipping" >&2
  exit 77
}
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/build-tools.XXXXXX")"; trap 'rm -rf "$STAGE"' EXIT   # template: 10.9 BSD mktemp requires one
ED_ROOT="$R" sh "$R/build/build-tools.sh" "$STAGE" >/dev/null
for t in ed25519-keygen ed25519-sign ed25519-verify; do
  b="$STAGE/usr/local/bin/$t"
  [ -x "$b" ] || { echo "missing $t" >&2; exit 1; }
  lipo -info "$b" | grep -q x86_64 || { echo "$t: no x86_64 slice" >&2; exit 1; }
  lipo -info "$b" | grep -q arm64  || { echo "$t: no arm64 slice"  >&2; exit 1; }
done
# The keygen's native (host-arch) slice must run: write the private key to a 0600 file + a .pub,
# print the PUBLIC key to stdout, and NEVER print the private key.
KT="$(mktemp -d "${TMPDIR:-/tmp}/build-tools-kt.XXXXXX")"; trap 'rm -rf "$STAGE" "$KT"' EXIT   # template: 10.9 BSD mktemp requires one
out="$("$STAGE/usr/local/bin/ed25519-keygen" -f "$KT/k")"
[ -f "$KT/k" ] || { echo "keygen did not write the private key file" >&2; rm -rf "$KT"; exit 1; }
mode=$(ls -l "$KT/k" | cut -c1-10)
[ "$mode" = "-rw-------" ] || { echo "private key file mode is $mode, want -rw------- (0600)" >&2; rm -rf "$KT"; exit 1; }
grep -qE '^[A-Za-z0-9+/]{128}={0,2}$' "$KT/k" || { echo "private key file is not the expected 96-byte base64 blob" >&2; rm -rf "$KT"; exit 1; }
[ -f "$KT/k.pub" ] || { echo "keygen did not write the .pub file" >&2; rm -rf "$KT"; exit 1; }
printf '%s\n' "$out" | grep -qE '[A-Za-z0-9+/]{40,}={0,2}' || { echo "keygen did not print a public key" >&2; rm -rf "$KT"; exit 1; }
priv="$(cat "$KT/k")"
case "$out" in *"$priv"*) echo "keygen leaked the private key to stdout" >&2; rm -rf "$KT"; exit 1;; esac
# ed25519-sign round-trip: sign a file with the generated key. The signer ed25519_verify's before
# printing, so a 64-byte (88-char base64) signature back means sign+verify both work end-to-end.
echo test-message > "$KT/msg"
sig="$("$STAGE/usr/local/bin/ed25519-sign" -f "$KT/k" "$KT/msg")"
printf '%s\n' "$sig" | grep -qE '^[A-Za-z0-9+/]{86}==$' || { echo "ed25519-sign did not emit a valid 64-byte signature" >&2; rm -rf "$KT"; exit 1; }
# ...and the shipped ed25519-verify names the key that made it (its full contract is in
# ed25519-verify.bats; this proves the Universal binary is that tool).
[ "$("$STAGE/usr/local/bin/ed25519-verify" -p "$(cat "$KT/k.pub")" "$KT/msg" "$sig")" = "$(cat "$KT/k.pub")" ] \
  || { echo "ed25519-verify did not verify ed25519-sign's signature" >&2; rm -rf "$KT"; exit 1; }
rm -rf "$KT"
echo "build-tools OK"
