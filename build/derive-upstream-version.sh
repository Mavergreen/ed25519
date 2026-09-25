#!/bin/sh
# platform: host-agnostic
# Write UPSTREAM_VERSION = the pinned orlp/ed25519 commit's committer date (YYYYMMDD),
# read locally from the checkout produced by fetch-ed25519.sh. Single source of truth is
# the pinned SHA (UPSTREAM_COMMIT, Renovate-managed); the date -- and thus the version --
# follows automatically. UPSTREAM_VERSION is build-derived (gitignored), never hand-edited.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
ED_ROOT="$(cd "$SELF/.." && pwd)"; export ED_ROOT
src="${1:?derive-upstream-version: pass the fetched src dir}"
d="$(git -C "$src/.." show -s --format=%cd --date=format:%Y%m%d HEAD)"
case "$d" in [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) : ;; *) echo "derive-upstream-version: bad date '$d'" >&2; exit 1 ;; esac
printf '%s\n' "$d" > "$ED_ROOT/UPSTREAM_VERSION"
printf '%s\n' "$d"
