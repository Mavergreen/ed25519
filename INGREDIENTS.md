# Build ingredients

Everything baked into the shipped artifacts, and how a change to it reaches a release. An *ingredient*
is an input to the product; the *own upstream* is the thing this repo exists to port.

This repo publishes the `ed25519-sign` tool the rest of the family signs releases with — shipyard's
`sign_and_appcast.sh` fetches it at signing time. So a change here reaches every sibling's next release,
which is a reason to keep its inputs few and legible.

| Ingredient | Pinned in | Renovate | On a bump |
|---|---|---|---|
| orlp/ed25519 source (own upstream) | `UPSTREAM_COMMIT` (a 40-char commit) | ✅ `git-refs` on `orlp/ed25519` | `build/version.sh` cuts `<date>-mavericks.1` |
| MacOSX10.9 SDK, packaging helpers | `ModernMavericks/shipyard@v1` | ✅ github-actions manager tracks the tag | `@v1` is a *moving* tag: content changes without the pin changing, so nothing auto-repackages |

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

This repo keeps no `release-notes/` directory: the product is a single signing tool with no Sparkle
updater and no feed description to fill. Its release workflow generates a minimal `RELEASE_NOTES.md`
into the artifact, which the shared `publish-release.yml` uses as the Release body — it refuses an
empty one. If this ever grows curated notes, adopt `release-notes-file.sh` as golang and
macports-legacy-support do.
