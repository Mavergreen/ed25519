setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/version-bats.XXXXXX")"   # template: 10.9 BSD mktemp requires one
  mkdir -p "$TMP/build"
  # Copy the WHOLE scaffolding, not a named subset: version.sh is a thin wrapper that sources
  # msc.sh to locate the shared implementation, so cherry-picking files silently breaks it.
  cp "$REPO"/build/*.sh "$TMP/build/"
  printf '20190301\n' > "$TMP/UPSTREAM_COMMIT"   # unused by version.sh, present for lib.sh
  printf '20190301\n' > "$TMP/UPSTREAM_VERSION"
}
teardown() { rm -rf "$TMP"; }
# MAVERICKS_ROOT is the family-wide root variable now (the shared version.sh reads it); ED_ROOT stays
# set for this repo's own build scripts.
run_ver() { ( cd "$TMP" && MAVERICKS_ROOT="$TMP" ED_ROOT="$TMP" MAVERICKS_TAGS="$1" sh build/version.sh "$2" ); }

@test "auto, no prior tags -> mavericks.1, release" {
  run run_ver "" auto
  [ "$status" -eq 0 ]
  [[ "$output" == *"FULL=20190301-mavericks.1"* ]] || false
  [[ "$output" == *"TAG=20190301-mavericks.1"* ]] || false
  [[ "$output" == *"RELEASE=yes"* ]] || false
}
@test "auto, current date already released -> no release" {
  run run_ver "20190301-mavericks.1" auto
  [[ "$output" == *"FULL=20190301-mavericks.1"* ]] || false
  [[ "$output" == *"RELEASE=no"* ]] || false
}
@test "auto, picks max existing rev" {
  run run_ver "$(printf '20190301-mavericks.1\n20190301-mavericks.2')" auto
  [[ "$output" == *"FULL=20190301-mavericks.2"* ]] || false
  [[ "$output" == *"RELEASE=no"* ]] || false
}
@test "auto, upstream date bumped -> reset to mavericks.1, release" {
  ( cd "$TMP" && printf '20240815\n' > UPSTREAM_VERSION )
  run run_ver "$(printf '20190301-mavericks.1\n20190301-mavericks.2')" auto
  [[ "$output" == *"FULL=20240815-mavericks.1"* ]] || false
  [[ "$output" == *"RELEASE=yes"* ]] || false
}
@test "local, increments past max rev" {
  run run_ver "$(printf '20190301-mavericks.1\n20190301-mavericks.2')" local
  [[ "$output" == *"FULL=20190301-mavericks.3"* ]] || false
  [[ "$output" == *"RELEASE=yes"* ]] || false
}
@test "bad mode fails" {
  run run_ver "" bogus
  [ "$status" -ne 0 ]
}
