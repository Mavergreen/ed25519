#!/bin/sh
# platform: host-agnostic
#   usage: VERSION=V [OUT=DIR] [TAR=tar] sh build/package-tar.sh BINDIR
#          Writes OUT/ed25519-V-linux-x86_64.tar.gz (default OUT: $ED_BUILD/dist, ED_BUILD being
#          ed25519-linux) and prints its path. It holds opt/mavergreen/ed25519/ alone: BINDIR's $ED_TOOLS
#          in bin/ and THIRD-PARTY-NOTICES.txt in share/doc/, owned by 0:0, every mtime the commit's time
#          (SOURCE_DATE_EPOCH wins), in ustar entries sorted by name, gzipped by the pinned stevedore, so
#          the same tools always give the same bytes. TAR must be GNU tar.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ED_ROOT="$(cd "$SELF/.." && pwd)"; export ED_ROOT
ED_TARGET=linux
. "$SELF/lib.sh"
: "${VERSION:?package-tar: VERSION required}"
[ $# -eq 1 ] || { echo "usage: VERSION=V sh build/package-tar.sh BINDIR" >&2; exit 2; }
BINDIR="$1"
OUT="${OUT:-$ED_BUILD/dist}"
SCRIPTS="$(msc_scripts)"
for t in $ED_TOOLS; do
  [ -f "$BINDIR/$t" ] && [ -x "$BINDIR/$t" ] || { echo "package-tar: no executable $t in $BINDIR" >&2; exit 1; }
done
MT="$(cd "$ED_ROOT" && sh "$SCRIPTS/source-date-epoch.sh")"
SD="$(sh "$SCRIPTS/fetch_stevedore.sh")"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
W="$(mktemp -d "$OUT/package-tar.XXXXXX")"
trap 'rm -rf "$W"' EXIT
P="$W/root/opt/mavergreen/ed25519"
mkdir -p "$P/bin" "$P/share/doc"
for t in $ED_TOOLS; do cp "$BINDIR/$t" "$P/bin/$t"; chmod 755 "$P/bin/$t"; done
cp "$ED_ROOT/THIRD-PARTY-NOTICES.txt" "$P/share/doc/THIRD-PARTY-NOTICES.txt"
chmod 644 "$P/share/doc/THIRD-PARTY-NOTICES.txt"
find "$W/root" -type d -exec chmod 755 {} +
"${TAR:-tar}" --sort=name --format=ustar --owner=0 --group=0 --numeric-owner --mtime="@$MT" \
  -C "$W/root" -cf "$W/ed25519.tar" opt
out="$OUT/ed25519-$VERSION-linux-x86_64.tar.gz"
"$SD" gzip < "$W/ed25519.tar" > "$W/out.tar.gz"
mv "$W/out.tar.gz" "$out"
printf '%s\n' "$out"
