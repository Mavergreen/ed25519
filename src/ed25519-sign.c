/*
 * ed25519-sign — sign a file with an ed25519 private key (native, 10.9-buildable).
 *
 *     ed25519-sign -f <private key file | -> <file>
 *
 * Prints the base64 ed25519 signature of the file's raw bytes (RFC 8032, deterministic) to stdout.
 * The private key is read from the file ed25519-keygen wrote, or from stdin given `-` -- never from
 * the command line, where other processes (ps) and any shell trace of the caller can see it, and
 * where a CI log can capture it. (An `-s <base64 private key>` option once did exactly that; it is gone.)
 *
 * Key bytes: the private key is the 96-byte blob private[64] || public[32] that ed25519-keygen writes
 * (private[64] is orlp/ed25519's EXPANDED key, which ed25519_sign takes directly). After signing we
 * ed25519_verify against the public half, so a bad key or a wrong private/public split fails loudly
 * instead of emitting a signature no verifier would accept. That proves the signature matches THIS
 * key, not the key a Sparkle updater trusts -- `ed25519-verify -p <SUPublicEDKey>` checks that.
 *
 * The signature is standard ed25519, so any verifier accepts it (openssl, or Sparkle's SUPublicEDKey
 * check). Native C means no modern toolchain -- it runs anywhere from 10.9 up and in CI. (See the
 * README for assembling a Sparkle appcast enclosure from the signature + file length.)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ed25519.h"
#include "mavericks_b64.h"
#include <unistd.h>
#include "mavericks_file.h"

static int usage(const char *argv0) {
    fprintf(stderr, "usage: %s -f <private key file | -> <file>\n", argv0);
    return 2;
}

/* Read the base64 private key from path (stdin for "-") into text, NUL-terminated. A key is 128
 * base64 characters and a newline; input that does not fit in cap is refused rather than decoded.
 * Returns 0, or -1 having said why -- naming the path, never echoing the contents. */
static int read_key_text(const char *path, char *text, size_t cap) {
    FILE *f = strcmp(path, "-") == 0 ? stdin : fopen(path, "r");
    if (!f) { perror(path); return -1; }
    size_t n = fread(text, 1, cap - 1, f);
    int more = n == cap - 1 && fgetc(f) != EOF;
    int err = ferror(f);
    if (f != stdin) fclose(f);
    if (err) { fprintf(stderr, "%s: read error\n", path); return -1; }
    if (more) { fprintf(stderr, "bad private key: %s is larger than any key\n", path); return -1; }
    text[n] = 0;
    return 0;
}

int main(int argc, char **argv) {
    const char *keyfile = NULL;
    int c;
    while ((c = getopt(argc, argv, "f:")) != -1) {
        if (c == 'f') keyfile = optarg;
        else return usage(argv[0]);
    }
    if (keyfile == NULL || argc - optind != 1) return usage(argv[0]);
    const char *path = argv[optind];

    char keytext[512];
    if (read_key_text(keyfile, keytext, sizeof keytext) != 0) return 1;
    const char *keyb64 = keytext;

    unsigned char key[96];
    long klen = mavericks_b64_decode(keyb64, key, sizeof key);
    if (klen < 0) {
        fprintf(stderr, "bad private key: not base64, or longer than 96 bytes (private[64] || public[32])\n");
        return 1;
    }
    if (klen != 96) {
        fprintf(stderr, "bad private key: decoded %ld bytes, expected 96 (private[64] || public[32])\n", klen);
        return 1;
    }
    const unsigned char *priv = key;        /* [0:64]  expanded private key */
    const unsigned char *pub  = key + 64;   /* [64:96] public key           */

    unsigned char *buf;
    size_t n;
    if (mavericks_read_file(path, &buf, &n) != 0) return 1;

    unsigned char sig[64];
    ed25519_sign(sig, buf, n, pub, priv);

    if (!ed25519_verify(sig, buf, n, pub)) {
        free(buf);
        fprintf(stderr, "signature self-check failed -- bad key, or the blob is not private[64]||public[32]\n");
        return 1;
    }
    free(buf);

    char sigb64[128];
    mavericks_b64_encode(sig, 64, sigb64);
    printf("%s\n", sigb64);
    return 0;
}
