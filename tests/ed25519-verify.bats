bats_require_minimum_version 1.5.0
load lib/tools

# ed25519-verify's contract, against the real tools compiled for this host (see lib/tools.bash).
#
#   ed25519-verify -p <pub> [-p <pub> ...] <file> <signature>
#     0  a candidate verifies -- that key is printed on stdout, as canonical base64
#     1  no candidate verifies -- stdout empty
#     2  input it cannot check (malformed key/signature, unreadable file, usage)
setup_file() {
  build_tools
  # Two keypairs: A signs, B is the decoy candidate.
  K="$BATS_FILE_TMPDIR/keys"; mkdir -p "$K"
  "$BIN/ed25519-keygen" -f "$K/a" >/dev/null
  "$BIN/ed25519-keygen" -f "$K/b" >/dev/null
  echo test-message > "$K/msg"
  SIG_A="$("$BIN/ed25519-sign" -f "$K/a" "$K/msg")"
  export K SIG_A
}

setup() {
  A="$(cat "$K/a.pub")"
  B="$(cat "$K/b.pub")"
}

verify() { "$BIN/ed25519-verify" "$@"; }

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
  sig="$("$BIN/ed25519-sign" -f "$K/a" "$BATS_TEST_TMPDIR/empty")"
  run --separate-stderr verify -p "$A" "$BATS_TEST_TMPDIR/empty" "$sig"
  [ "$status" -eq 0 ]
  [ "$output" = "$A" ]
}

@test "rejects a public key that is not 32 bytes" {
  run --separate-stderr verify -p "$(printf '%31s' '' | base64)" "$K/msg" "$SIG_A"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"public key"* ]] || false
}

@test "rejects a public key that is not base64" {
  run --separate-stderr verify -p '!!!!' "$K/msg" "$SIG_A"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"public key"* ]] || false
}

@test "rejects a signature that is not 64 bytes" {
  run --separate-stderr verify -p "$A" "$K/msg" "$(printf '%63s' '' | base64)"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"signature"* ]] || false
}

@test "rejects a file it cannot read" {
  run --separate-stderr verify -p "$A" "$BATS_TEST_TMPDIR/no-such-file" "$SIG_A"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"no-such-file"* ]] || false
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
  [[ "$stderr" == *"usage"* ]] || false
}

@test "requires both a file and a signature" {
  run --separate-stderr verify -p "$A" "$K/msg"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage"* ]] || false
}

@test "an oversized public key is refused, not a crash" {
  run --separate-stderr verify -p "$(long_b64 10000 A)" "$K/msg" "$SIG_A"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"public key"* ]] || false
}

@test "an oversized signature is refused, not a crash" {
  run --separate-stderr verify -p "$A" "$K/msg" "$(long_b64 10000 A)"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"signature"* ]] || false
}
