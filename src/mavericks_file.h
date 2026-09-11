/* Read a whole file into memory, dependency-free so the tools build on the native 10.9 toolchain.
 * orlp/ed25519 has no streaming API -- ed25519_sign and ed25519_verify each hash the entire message
 * in one call -- so both tools need the file's bytes in one buffer. */
#ifndef MAVERICKS_FILE_H
#define MAVERICKS_FILE_H
#include <stdio.h>
#include <stdlib.h>

/* Read path into a malloc'd *buf of *len bytes (free() it; an empty file still gets a buffer). On
 * failure, says why on stderr, naming the path, and returns -1. */
static int mavericks_read_file(const char *path, unsigned char **buf, size_t *len) {
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); return -1; }
    if (fseek(f, 0, SEEK_END) != 0) { perror(path); fclose(f); return -1; }
    long n = ftell(f);
    if (n < 0 || fseek(f, 0, SEEK_SET) != 0) { perror(path); fclose(f); return -1; }
    unsigned char *b = malloc((size_t)n ? (size_t)n : 1);
    if (!b) { fprintf(stderr, "%s: out of memory\n", path); fclose(f); return -1; }
    if (fread(b, 1, (size_t)n, f) != (size_t)n) {
        fprintf(stderr, "%s: read error\n", path); fclose(f); free(b); return -1;
    }
    fclose(f);
    *buf = b;
    *len = (size_t)n;
    return 0;
}

#endif /* MAVERICKS_FILE_H */
