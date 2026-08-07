#!/bin/sh
# Thin wrapper: the logic lives in shipyard (scripts/version.sh) so it cannot drift between repos.
# Every call site -- tests/version-test.sh, build/versions.sh, the release workflow, and a plain
# `sh build/version.sh auto` -- keeps working through this.
set -eu
SELF="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$SELF/.." && pwd)"; export MAVERICKS_ROOT
. "$SELF/msc.sh"
exec sh "$SHIPYARD/version.sh" "$@"
