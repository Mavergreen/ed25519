bats_require_minimum_version 1.5.0

# ed25519-verify's contract, exercised against the real tools compiled for THIS host. Unlike the
# Universal build (cross-only: its arm64 slice targets 11.0), a host compile works on a native 10.9
# box too, so these assertions run on a Mavericks machine as well as in CI.
#
#   ed25519-verify -p <pub> [-p <pub> ...] <file> <signature>
#     0  a candidate verifies -- that key is printed on stdout, as canonical base64
#     1  no candidate verifies -- stdout empty
#     2  input it cannot check (malformed key/signature, unreadable file, usage)
setup_file() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # shipyard's scripts: $SHIPYARD_SCRIPTS in CI (exported by install@v1), else a sibling checkout.
  : "${MAVERICKS_SCRIPTS:=${SHIPYARD_SCRIPTS:-$REPO/../mavericks-shipyard/scripts}}"
  [ -d "$MAVERICKS_SCRIPTS" ] || skip "shipyard scripts not found at $MAVERICKS_SCRIPTS"
  ED="$(ED_ROOT="$REPO" sh "$REPO/build/fetch-ed25519.sh")"
  BIN="$BATS_FILE_TMPDIR/bin"; mkdir -p "$BIN"
  for t in ed25519-keygen ed25519-sign ed25519-verify; do
    cc -I"$REPO/src" -I"$ED" "$REPO/src/$t.c" "$ED"/*.c -o "$BIN/$t"
  done
  # Two keypairs: A signs, B is the decoy candidate.
  K="$BATS_FILE_TMPDIR/keys"; mkdir -p "$K"
  "$BIN/ed25519-keygen" -f "$K/a" >/dev/null
  "$BIN/ed25519-keygen" -f "$K/b" >/dev/null
  echo test-message > "$K/msg"
  SIG_A="$("$BIN/ed25519-sign" -s "$(cat "$K/a")" "$K/msg")"
  export BIN K SIG_A
}

setup() {
  A="$(cat "$K/a.pub")"
  B="$(cat "$K/b.pub")"
}

verify() { "$BIN/ed25519-verify" "$@"; }
# n repetitions of a base64 character: valid base64, far longer than any key or signature.
long_b64() { printf "%${1}s" '' | tr ' ' "$2"; }

# RFC 8032 section 7.1, TEST 2 (a one-byte message, 0x72). Cross-checked with OpenSSL 3, so this
# signature did not come from our own signer.
RFC_PUB='PUAXw+hDiVqStwqnTRt+vJyYLM8uxJaMwM1V8Sr0Zgw='
RFC_SIG='kqAJqfDUyrhyDoILX2QlQKKye1QWUD+Ps3YiI+vbadoIWsHkPhWZbkWPNhPQ8R2MOHsurrQwKu6wDSkWErsMAA=='

@test "RFC 8032 test 2: a known-good signature verifies and names its key" {
  printf r > "$BATS_TEST_TMPDIR/msg"
  run --separate-stderr verify -p "$RFC_PUB" "$BATS_TEST_TMPDIR/msg" "$RFC_SIG"
  [ "$status" -eq 0 ]
  [ "$output" = "$RFC_PUB" ]
}

@test "names which of several candidate keys made the signature" {
  run --separate-stderr verify -p "$B" -p "$A" "$K/msg" "$SIG_A"
  [ "$status" -eq 0 ]
  [ "$output" = "$A" ]
}

@test "the key it names is canonical base64, whatever whitespace the -p argument carried" {
  run --separate-stderr verify -p "  $A" "$K/msg" "$SIG_A"
  [ "$status" -eq 0 ]
  [ "$output" = "$A" ]
}

@test "a key that did not sign: exit 1, nothing on stdout" {
  run --separate-stderr verify -p "$B" "$K/msg" "$SIG_A"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "a changed file no longer verifies" {
  { cat "$K/msg"; printf x; } > "$BATS_TEST_TMPDIR/msg"
  run --separate-stderr verify -p "$A" "$BATS_TEST_TMPDIR/msg" "$SIG_A"
  [ "$status" -eq 1 ]
}

@test "a changed signature no longer verifies" {
  case "$SIG_A" in A*) c=B ;; *) c=A ;; esac
  run --separate-stderr verify -p "$A" "$K/msg" "$c${SIG_A#?}"
  [ "$status" -eq 1 ]
}

@test "an empty file signs and verifies" {
  : > "$BATS_TEST_TMPDIR/empty"
  sig="$("$BIN/ed25519-sign" -s "$(cat "$K/a")" "$BATS_TEST_TMPDIR/empty")"
  run --separate-stderr verify -p "$A" "$BATS_TEST_TMPDIR/empty" "$sig"
  [ "$status" -eq 0 ]
  [ "$output" = "$A" ]
}

@test "rejects a public key that is not 32 bytes" {
  run --separate-stderr verify -p "$(printf '%31s' '' | base64)" "$K/msg" "$SIG_A"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"public key"* ]]
}

@test "rejects a public key that is not base64" {
  run --separate-stderr verify -p '!!!!' "$K/msg" "$SIG_A"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"public key"* ]]
}

@test "rejects a signature that is not 64 bytes" {
  run --separate-stderr verify -p "$A" "$K/msg" "$(printf '%63s' '' | base64)"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"signature"* ]]
}

@test "rejects a file it cannot read" {
  run --separate-stderr verify -p "$A" "$BATS_TEST_TMPDIR/no-such-file" "$SIG_A"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"no-such-file"* ]]
}

# A typo in the candidate list must not be masked by a later (or earlier) key that happens to match:
# the inventory would silently have checked one key fewer than it was given.
@test "rejects a malformed candidate even when another candidate matches" {
  run --separate-stderr verify -p "$A" -p '!!!!' "$K/msg" "$SIG_A"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "requires at least one -p" {
  run --separate-stderr verify "$K/msg" "$SIG_A"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage"* ]]
}

@test "requires both a file and a signature" {
  run --separate-stderr verify -p "$A" "$K/msg"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage"* ]]
}

@test "an oversized public key is refused, not a crash" {
  run --separate-stderr verify -p "$(long_b64 10000 A)" "$K/msg" "$SIG_A"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"public key"* ]]
}

@test "an oversized signature is refused, not a crash" {
  run --separate-stderr verify -p "$A" "$K/msg" "$(long_b64 10000 A)"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"signature"* ]]
}

# ed25519-sign decoded -s into a fixed 128-byte stack buffer with no bound: 10000 base64 characters
# are 7500 bytes written over its stack.
@test "ed25519-sign refuses an oversized private key rather than overflowing" {
  run --separate-stderr "$BIN/ed25519-sign" -s "$(long_b64 10000 /)" "$K/msg"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"private key"* ]]
}
