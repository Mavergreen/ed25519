# platform: host-agnostic
# build/lib.sh -- sourced helpers. The shared implementations (upstream_version, msc_scripts) live in
# shipyard; this locates them and adds what is genuinely ours.
: "${MAVERICKS_ROOT:=$(cd "$(dirname "${BASH_SOURCE:-$0}")/.." 2>/dev/null && pwd || pwd)}"
export MAVERICKS_ROOT
ED_ROOT="$MAVERICKS_ROOT"; export ED_ROOT   # kept: build scripts here still refer to ED_ROOT
. "$MAVERICKS_ROOT/build/msc.sh"
. "$SHIPYARD/lib.sh"

# platform: a family checkout may live on NFS, where a build cost 11.16s wall / 25% CPU against
#           2.96s / 88% on local disk, identical user time -- the whole difference is I/O wait.
: "${MAVERICKS_BUILD_ROOT:=${TMPDIR:-/tmp}/mm-build}"
export MAVERICKS_BUILD_ROOT
# Only cross mode exists for this repo (build-tools.sh refuses anything else: the arm64 slice
# targets macOS 11.0, which a native 10.9 toolchain cannot do).
ED_BUILD="$MAVERICKS_BUILD_ROOT/ed25519-cross"; export ED_BUILD

# Repo-specific: orlp/ed25519 publishes no releases, so the pinned COMMIT is the upstream identity
# and its date is the version. Renovate bumps UPSTREAM_COMMIT; build/derive-upstream-version.sh
# writes UPSTREAM_VERSION from it.
upstream_commit() { tr -d '[:space:]' < "$MAVERICKS_ROOT/UPSTREAM_COMMIT"; }

# The shipped tools, one src/<tool>.c each. build-tools.sh builds and package-pkg.sh guards this one
# list, so a tool cannot be built without being checked (or checked without being built).
ED_TOOLS="ed25519-keygen ed25519-sign ed25519-verify"
ED_TREE="usr/local/mavergreen/ed25519"
