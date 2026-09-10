#!/bin/sh
# Print the URL of what changed upstream for one ed25519 version. shipyard's upstream-notes.sh links
# it from our release notes when a release ships a NEW upstream.
#   usage: upstream-release-notes-url.sh <upstream-version>      (bare: 20221003)
#
# orlp/ed25519 publishes no releases or notes, and our version is the pinned commit's DATE, which
# cannot be mapped back to a commit -- so link the history leading up to the pinned commit itself.
set -eu
: "${1:?usage: upstream-release-notes-url.sh <upstream-version>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
printf 'https://github.com/orlp/ed25519/commits/%s\n' "$(tr -d '[:space:]' < "$ROOT/UPSTREAM_COMMIT")"
