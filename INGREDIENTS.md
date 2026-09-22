# Build ingredients

Everything baked into the shipped artifacts, and how a change to it reaches a release. An *ingredient*
is an input to the product; the *own upstream* is the thing this repo exists to port.

This repo publishes the `ed25519-sign` tool the rest of the family signs releases with — shipyard's
`sign_and_appcast.sh` fetches it at signing time. So a change here reaches every sibling's next release,
which is a reason to keep its inputs few and legible.

| Ingredient | Pinned in | Renovate | On a bump |
|---|---|---|---|
| orlp/ed25519 source (own upstream) | `UPSTREAM_COMMIT` (a 40-char commit) | ✅ `git-refs` on `orlp/ed25519` | `build/version.sh` cuts `<date>-mavericks.1` |
| MacOSX10.9 SDK, packaging helpers | `Mavergreen/shipyard@v1` | ✅ github-actions manager tracks the tag | `@v1` is a *moving* tag: content changes without the pin changing, so nothing auto-repackages |

Not ingredients: the build scripts and `patches/` are this repo's own recipe. A change there is a
repackage you cut deliberately (`workflow_dispatch` with `local_release=true`).

## Why the upstream pin is a commit, not a tag

`orlp/ed25519` publishes no releases and has not tagged in years, so there is no version to track — the
commit *is* the version. `git-refs` moves it forward on the default branch; the shipped version string
is date-based (`<date>-mavericks.N`) because upstream provides nothing better to name it after.

## No repackage-on-ingredient-bump caller here

The only versioned input is the own upstream, which is the `-mavericks.1` path this repo's
`release.yml` already owns. Its other input is `shipyard@v1`, whose moving tag no path filter can
observe. A caller would have nothing to watch. Add one the day a real file-based ingredient pin lands,
with `own-upstream-paths: UPSTREAM_COMMIT`.

## Release notes

`release.yml` calls mavericks-shipyard's `release-notes.sh` (`--product ed25519`, `--min-os 10.9.5`)
to write `dist/RELEASE_NOTES.md`, which the shared `publish-release.yml` uses as the Release body —
it refuses an empty one. This repo has no Sparkle updater and publishes no appcast, so the Release
body is that file's only consumer; there is no second copy to keep in sync. See `release-notes/`
for the (optional) per-release prose convention.
