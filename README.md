# ed25519

General-purpose command-line EdDSA tools built for Mac OS X 10.9 Mavericks and higher:

- `ed25519-keygen`
- `ed25519-sign`
- `ed25519-verify`

## Set up a Sparkle updater

In your project (assuming 1Password and GitHub):

```sh
ed25519-keygen
item_title="$(basename "$PWD") Sparkle private key"
op document create ed25519_key --title "${item_title}"
rm ed25519_key
op document get "${item_title}" | gh secret set SPARKLE_PRIVATE_KEY
mkdir -p updater
mv ed25519_key.pub updater/
git add updater/ed25519_key.pub
```

## Which key signed a release?

`ed25519-verify` takes any number of candidate public keys and prints the one that verifies the
signature (exit 0), or prints nothing and exits 1 if none does. Exit 2 means it could not check at all:
a malformed key or signature, or an unreadable file.

A Sparkle updater accepts an update only if the appcast's `sparkle:edSignature` verifies against the
`SUPublicEDKey` it shipped with. `ed25519-sign` only checks its signature against the public half of
the private key it was given, so this is how you learn whether a product's `SPARKLE_PRIVATE_KEY` matches
its updater:

```sh
product=openssh
curl -fsSL "https://github.com/ModernMavericks/$product/releases/latest/download/appcast.xml" > appcast.xml
url=$(sed -n 's/.*<enclosure[^>]* url="\([^"]*\)".*/\1/p' appcast.xml | head -1)
sig=$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' appcast.xml | head -1)
curl -fsSL -o update.pkg "$url"
ed25519-verify -p "$(cat updater/ed25519_key.pub)" -p "$(cat ../other-product/updater/ed25519_key.pub)" \
  update.pkg "$sig"
```

Sparkle verifies with its own vendored copy of orlp/ed25519, whose verification code is identical to
the copy built into these tools, so `ed25519-verify` accepts exactly the signatures a Sparkle client
does.

## Alternative: OpenSSL equivalents

If you have OpenSSL 3.x, the following scripts are equivalent.

`ed25519-keygen`:

```sh
#!/bin/sh
set -eu
key=ed25519_key
while getopts f: o; do case $o in f) key=$OPTARG ;; *) echo "usage: $0 [-f <file>]" >&2; exit 2 ;; esac; done
for f in "$key" "$key.pub"; do [ -e "$f" ] && { echo "$f: exists -- refusing to overwrite" >&2; exit 1; }; done
( umask 077; openssl genpkey -algorithm ed25519 -out "$key" )
pub=$(openssl pkey -in "$key" -pubout -outform DER | tail -c 32 | base64)
printf '%s\n' "$pub" > "$key.pub"
printf 'Public key (base64):\n  %s\nPrivate key -> %s (0600), public key -> %s.pub\n' "$pub" "$key" "$key"
```

`ed25519-sign`:

```sh
#!/bin/sh
set -eu
[ "$#" -eq 3 ] && [ "$1" = -s ] || { echo "usage: $0 -s <private key PEM> <file>" >&2; exit 2; }
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
( umask 077; printf '%s\n' "$2" > "$tmp" )
openssl pkeyutl -sign -inkey "$tmp" -rawin -in "$3" | base64
```

`ed25519-verify` (OpenSSL can't sign or verify an empty file; the native tool can):

```sh
#!/bin/sh
set -eu
usage() { echo "usage: $0 -p <base64 public key> [-p ...] <file> <base64 signature>" >&2; exit 2; }
keys=
while getopts p: o; do case $o in p) keys="$keys $OPTARG" ;; *) usage ;; esac; done
shift $((OPTIND - 1)); [ -n "$keys" ] && [ "$#" -eq 2 ] || usage
tmp=$(mktemp -d "${TMPDIR:-/tmp}/ed25519-verify.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
printf '%s' "$2" | openssl base64 -d -A > "$tmp/sig"
for k in $keys; do
  { printf '302a300506032b6570032100' | xxd -r -p; printf '%s' "$k" | openssl base64 -d -A; } > "$tmp/pub.der"
  if openssl pkeyutl -verify -pubin -keyform DER -inkey "$tmp/pub.der" -rawin -in "$1" -sigfile "$tmp/sig" >/dev/null 2>&1; then
    printf '%s\n' "$k"; exit 0
  fi
done
echo "signature does not verify against any public key given" >&2; exit 1
```

## Attribution

`ed25519-keygen`, `ed25519-sign`, and `ed25519-verify` embed [orlp/ed25519](https://github.com/orlp/ed25519)
by Orson Peters (zlib license). See [THIRD-PARTY-NOTICES.txt](THIRD-PARTY-NOTICES.txt).
