/*
 * ed25519-verify — check an ed25519 signature against one or more public keys (native, 10.9-buildable).
 *
 *     ed25519-verify -p <base64 public key> [-p <base64 public key> ...] <file> <base64 signature>
 *
 * Prints the public key that verifies the signature over the file's raw bytes (as canonical base64,
 * so it compares equal to a .pub file) and exits 0. Given several -p, it answers "which of these keys
 * signed this?" -- e.g. an appcast's sparkle:edSignature against every candidate SUPublicEDKey. The
 * operands follow Sparkle's own `sign_update --verify <file> <signature>`.
 *
 * Exit status: 0 a key verifies; 1 none does (stdout stays empty); 2 the input cannot be checked --
 * a malformed key or signature, an unreadable file, bad usage. ed25519-sign exits 1 for every
 * failure; here "wrong key" and "broken input" are different answers to whoever is asking, so they
 * get different codes. Every key is validated before any is tried, so a typo in the candidate list
 * is never masked by another key that matches.
 *
 * Sparkle verifies with its own vendored orlp/ed25519 (sparkle-project/ed25519), whose ed25519_verify
 * is identical to the one built in here: this accepts exactly the signatures a Sparkle client does.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ed25519.h"
#include "mavericks_b64.h"
#include "mavericks_file.h"

static int usage(const char *argv0) {
    fprintf(stderr, "usage: %s -p <base64 public key> [-p <base64 public key> ...] <file> <base64 signature>\n",
            argv0);
    return 2;
}

int main(int argc, char **argv) {
    unsigned char (*keys)[32] = malloc((size_t)argc * sizeof *keys);   /* fewer -p than argv words */
    if (!keys) { fprintf(stderr, "out of memory\n"); return 2; }
    int nkeys = 0, c;
    while ((c = getopt(argc, argv, "p:")) != -1) {
        if (c != 'p') return usage(argv[0]);
        if (mavericks_b64_decode(optarg, keys[nkeys], sizeof keys[nkeys]) != 32) {
            fprintf(stderr, "bad public key #%d: not the base64 of 32 bytes\n", nkeys + 1);
            return 2;
        }
        nkeys++;
    }
    if (nkeys == 0 || argc - optind != 2) return usage(argv[0]);
    const char *path   = argv[optind];
    const char *sigb64 = argv[optind + 1];

    unsigned char sig[64];
    if (mavericks_b64_decode(sigb64, sig, sizeof sig) != 64) {
        fprintf(stderr, "bad signature: not the base64 of 64 bytes\n");
        return 2;
    }

    unsigned char *buf;
    size_t n;
    if (mavericks_read_file(path, &buf, &n) != 0) return 2;

    for (int i = 0; i < nkeys; i++) {
        if (ed25519_verify(sig, buf, n, keys[i])) {
            char pubb64[64];
            mavericks_b64_encode(keys[i], 32, pubb64);
            printf("%s\n", pubb64);
            free(buf);
            free(keys);
            return 0;
        }
    }
    free(buf);
    free(keys);
    if (nkeys == 1)
        fprintf(stderr, "signature does not verify against the public key given\n");
    else
        fprintf(stderr, "signature does not verify against any of the %d public keys given\n", nkeys);
    return 1;
}
