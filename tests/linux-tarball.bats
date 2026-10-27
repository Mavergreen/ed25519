# platform: host-agnostic
bats_require_minimum_version 1.5.0

# The release's Linux asset, ed25519-<version>-linux-x86_64.tar.gz: $TARBALL when the caller names
# one (the release job does), else one built here, which only a Linux host can do.
setup_file() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  : "${SHIPYARD_SCRIPTS:=${MAVERICKS_SCRIPTS:-$REPO/../mavergreen-shipyard/scripts}}"
  [ -d "$SHIPYARD_SCRIPTS" ] || skip "shipyard scripts not found at $SHIPYARD_SCRIPTS"
  if [ -z "${TARBALL:-}" ]; then
    [ "$(uname -s)" = Linux ] || skip "the Linux tarball is built on Linux; set TARBALL to check one"
    bin="$(SHIPYARD_SCRIPTS="$SHIPYARD_SCRIPTS" sh "$REPO/build/build-tools-linux.sh")"
    TARBALL="$(VERSION=20190301-mavericks.1 OUT="$BATS_FILE_TMPDIR/dist" SHIPYARD_SCRIPTS="$SHIPYARD_SCRIPTS" \
      sh "$REPO/build/package-tar.sh" "$bin")"
  fi
  mkdir -p "$BATS_FILE_TMPDIR/extracted"
  EXTRACTED="$(cd "$BATS_FILE_TMPDIR/extracted" && pwd -P)/ed25519"
  export REPO SHIPYARD_SCRIPTS TARBALL EXTRACTED
}

sha256() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

@test "the asset is named ed25519-<version>-linux-x86_64.tar.gz" {
  case "$(basename "$TARBALL")" in
    ed25519-?*-linux-x86_64.tar.gz) : ;;
    *) echo "unexpected name $(basename "$TARBALL")" >&2; false ;;
  esac
}

@test "it holds exactly opt/mavergreen/ed25519's three tools and the notices" {
  run --separate-stderr tar -tzf "$TARBALL"
  [ "$status" -eq 0 ]
  want="opt/
opt/mavergreen/
opt/mavergreen/ed25519/
opt/mavergreen/ed25519/bin/
opt/mavergreen/ed25519/bin/ed25519-keygen
opt/mavergreen/ed25519/bin/ed25519-sign
opt/mavergreen/ed25519/bin/ed25519-verify
opt/mavergreen/ed25519/share/
opt/mavergreen/ed25519/share/doc/
opt/mavergreen/ed25519/share/doc/THIRD-PARTY-NOTICES.txt"
  [ "$output" = "$want" ]
}

@test "every entry is ustar, owned by 0:0, and stamped with the commit's time" {
  epoch="$(cd "$REPO" && sh "$SHIPYARD_SCRIPTS/source-date-epoch.sh")"
  run --separate-stderr python3 - "$TARBALL" "$epoch" <<'PY'
import sys, tarfile
bad = []
with open(sys.argv[1], "rb") as f:
    raw = f.read()
import gzip
data = gzip.decompress(raw)
if data[257:263] != b"ustar\x00":
    bad.append("not ustar")
with tarfile.open(sys.argv[1], "r:gz") as t:
    for m in t.getmembers():
        if (m.uid, m.gid, m.uname, m.gname) != (0, 0, "", ""):
            bad.append("%s owner %s:%s %s:%s" % (m.name, m.uid, m.gid, m.uname, m.gname))
        if m.mtime != int(sys.argv[2]):
            bad.append("%s mtime %s" % (m.name, m.mtime))
        if m.mode & 0o022:
            bad.append("%s mode %o" % (m.name, m.mode))
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
  [ "$status" -eq 0 ]
}

@test "shipyard's product-tar.py accepts it, as fetch_product_tar.sh will" {
  run --separate-stderr python3 "$SHIPYARD_SCRIPTS/product-tar.py" "$TARBALL" ed25519 "$(sha256 "$TARBALL")" "$EXTRACTED"
  [ "$status" -eq 0 ]
  for t in ed25519-keygen ed25519-sign ed25519-verify; do [ -x "$EXTRACTED/bin/$t" ]; done
  cmp "$REPO/THIRD-PARTY-NOTICES.txt" "$EXTRACTED/share/doc/THIRD-PARTY-NOTICES.txt"
}

@test "packaging the same tools again writes the same bytes" {
  "${TAR:-tar}" --version 2>/dev/null | grep -q 'GNU tar' || skip "repackaging needs GNU tar; set TAR to one"
  [ -x "$EXTRACTED/bin/ed25519-sign" ] \
    || python3 "$SHIPYARD_SCRIPTS/product-tar.py" "$TARBALL" ed25519 "$(sha256 "$TARBALL")" "$EXTRACTED"
  v="$(basename "$TARBALL")"; v="${v#ed25519-}"; v="${v%-linux-x86_64.tar.gz}"
  again="$(VERSION="$v" OUT="$BATS_TEST_TMPDIR" sh "$REPO/build/package-tar.sh" "$EXTRACTED/bin")"
  cmp "$TARBALL" "$again"
}

@test "the tools need no glibc newer than 2.35" {
  [ "$(uname -s)" = Linux ] || skip "reading the ELF's symbol versions needs the Linux host's objdump"
  [ -x "$EXTRACTED/bin/ed25519-sign" ] \
    || python3 "$SHIPYARD_SCRIPTS/product-tar.py" "$TARBALL" ed25519 "$(sha256 "$TARBALL")" "$EXTRACTED"
  for t in ed25519-keygen ed25519-sign ed25519-verify; do
    run --separate-stderr objdump -T "$EXTRACTED/bin/$t"
    [ "$status" -eq 0 ]
    newest="$(printf '%s\n' "$output" | grep -o 'GLIBC_[0-9][0-9.]*' | sed 's/^GLIBC_//' \
      | awk -F. '{ printf "%d %d %s\n", $1, $2, $0 }' | sort -n -k1,1 -k2,2 | tail -1 | cut -d' ' -f3)"
    [ -n "$newest" ]
    awk -v v="$newest" 'BEGIN { split(v, p, "."); exit !(p[1] < 2 || (p[1] == 2 && p[2] <= 35)) }' \
      || { echo "$t needs glibc $newest" >&2; false; }
  done
}
