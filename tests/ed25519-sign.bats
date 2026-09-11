bats_require_minimum_version 1.5.0
load lib/tools

# ed25519-sign's contract, against the real tools compiled for this host.
#
#   ed25519-sign -f <keyfile | -> <file>     the key from a file, or stdin with -
#
# The private key never goes on the command line: argv is visible to other processes (ps) and to
# any shell trace of the caller. The only keys here are throwaway ones generated for the test.
setup_file() {
  build_tools
  K="$BATS_FILE_TMPDIR/keys"; mkdir -p "$K"
  "$BIN/ed25519-keygen" -f "$K/a" >/dev/null
  echo test-message > "$K/msg"
  export K
}

setup() { A="$(cat "$K/a.pub")"; }

sign() { "$BIN/ed25519-sign" "$@"; }

@test "-f <keyfile> signs, and the signature verifies against the key's public half" {
  run --separate-stderr sign -f "$K/a" "$K/msg"
  [ "$status" -eq 0 ]
  run --separate-stderr "$BIN/ed25519-verify" -p "$A" "$K/msg" "$output"
  [ "$status" -eq 0 ]
}

@test "-f - reads the key from stdin, signing exactly as the key file does" {
  from_file="$(sign -f "$K/a" "$K/msg")"
  run --separate-stderr sh -c '"$1" -f - "$2" < "$3"' _ "$BIN/ed25519-sign" "$K/msg" "$K/a"
  [ "$status" -eq 0 ]
  [ "$output" = "$from_file" ]
}

@test "a key file far larger than any key is refused" {
  long_b64 10000 / > "$BATS_TEST_TMPDIR/big"
  run --separate-stderr sign -f "$BATS_TEST_TMPDIR/big" "$K/msg"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"private key"* ]] || false
}

@test "a key file it cannot read is named" {
  run --separate-stderr sign -f "$BATS_TEST_TMPDIR/no-such-key" "$K/msg"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"no-such-key"* ]] || false
}

@test "requires -f and exactly one file" {
  run --separate-stderr sign "$K/msg"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage"* ]] || false
  run --separate-stderr sign -f "$K/a"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage"* ]] || false
}

# -s once took the key as an argument; it is gone, not deprecated. A command line is visible to every
# process that can list processes and to any shell trace, and a CI log can capture either.
@test "-s is refused: the key never goes on the command line" {
  run --separate-stderr sign -s "$(cat "$K/a")" "$K/msg"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage"* ]] || false
  [ -z "$output" ]
}

# Whatever goes wrong, what the tool prints must not help anyone reconstruct the key: its output
# lands in CI logs, which are public for a public repo.
@test "no output, on success or on any failure, carries a piece of the private key" {
  key="$(cat "$K/a")"
  printf '%s\n' "${key%????}" > "$BATS_TEST_TMPDIR/short"                       # 93 bytes
  printf '%s\n' "${key:0:100}$(printf '%s' "${key:100:1}" | tr 'A-Za-z0-9+/' 'B-Za-z0-9+/A')${key:101}" \
    > "$BATS_TEST_TMPDIR/mismatch"                                              # public half altered
  for args in "-f $K/a $K/msg" "-f $BATS_TEST_TMPDIR/short $K/msg" \
              "-f $BATS_TEST_TMPDIR/mismatch $K/msg" "-f $K/a $BATS_TEST_TMPDIR/no-such-file"; do
    run sign $args
    refute_key_material "$K/a" "$output"
  done
}

@test "ed25519-keygen never prints any piece of the private key it writes" {
  run "$BIN/ed25519-keygen" -f "$BATS_TEST_TMPDIR/k"
  [ "$status" -eq 0 ]
  refute_key_material "$BATS_TEST_TMPDIR/k" "$output"
}
