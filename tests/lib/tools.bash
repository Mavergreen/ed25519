# Shared by the tools' bats files (tests/lib/ is not itself run: run-repo-tests.sh takes top-level
# tests only).

# Compile the three tools for THIS host into $BIN. Unlike the Universal build (cross-only: its arm64
# slice targets 11.0), a host compile works on a native 10.9 box too, so the tools' contracts are
# checked on a Mavericks machine as well as in CI. Call from setup_file.
build_tools() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # shipyard's scripts: $SHIPYARD_SCRIPTS in CI (exported by install@v1), else a sibling checkout.
  : "${MAVERICKS_SCRIPTS:=${SHIPYARD_SCRIPTS:-$REPO/../mavergreen-shipyard/scripts}}"
  [ -d "$MAVERICKS_SCRIPTS" ] || skip "shipyard scripts not found at $MAVERICKS_SCRIPTS"
  ED="$(ED_ROOT="$REPO" sh "$REPO/build/fetch-ed25519.sh")"
  BIN="$BATS_FILE_TMPDIR/bin"; mkdir -p "$BIN"
  for t in ed25519-keygen ed25519-sign ed25519-verify; do
    cc -I"$REPO/src" -I"$ED" "$REPO/src/$t.c" "$ED"/*.c -o "$BIN/$t"
  done
  export BIN
}

# n repetitions of a base64 character: valid base64, far longer than any key or signature.
long_b64() { printf "%${1}s" '' | tr ' ' "$2"; }

# Fail if TEXT carries any piece of the private key in KEYFILE: any 16-character window of its
# base64, or any 32-character window of its hex (either case). 16 base64 characters are 12 bytes of
# key -- a leak that short is already a brute force away from the rest, and no honest output
# contains 12 given random bytes by chance.
refute_key_material() {  # KEYFILE TEXT
  local key hex i w
  key="$(tr -d '[:space:]' < "$1")"
  hex="$(printf '%s' "$key" | base64 --decode | xxd -p | tr -d '\n')"
  for ((i = 0; i + 16 <= ${#key}; i++)); do
    w="${key:i:16}"
    [[ "$2" != *"$w"* ]] || { echo "output carries private key base64 at offset $i" >&2; return 1; }
  done
  for ((i = 0; i + 32 <= ${#hex}; i++)); do
    w="${hex:i:32}"
    [[ "$2" != *"$w"* ]] || { echo "output carries private key hex at offset $i" >&2; return 1; }
    w="$(printf '%s' "$w" | tr a-f A-F)"
    [[ "$2" != *"$w"* ]] || { echo "output carries private key HEX at offset $i" >&2; return 1; }
  done
}
