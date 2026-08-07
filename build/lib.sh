# build/lib.sh -- sourced helpers. The shared implementations (upstream_version, msc_scripts) live in
# shipyard; this locates them and adds what is genuinely ours.
: "${MAVERICKS_ROOT:=$(cd "$(dirname "${BASH_SOURCE:-$0}")/.." 2>/dev/null && pwd || pwd)}"
export MAVERICKS_ROOT
ED_ROOT="$MAVERICKS_ROOT"; export ED_ROOT   # kept: build scripts here still refer to ED_ROOT
. "$MAVERICKS_ROOT/build/msc.sh"
. "$SHIPYARD/lib.sh"

# Repo-specific: orlp/ed25519 publishes no releases, so the pinned COMMIT is the upstream identity
# and its date is the version. Renovate bumps UPSTREAM_COMMIT; build/derive-upstream-version.sh
# writes UPSTREAM_VERSION from it.
upstream_commit() { tr -d '[:space:]' < "$MAVERICKS_ROOT/UPSTREAM_COMMIT"; }
