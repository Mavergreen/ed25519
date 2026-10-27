# Build ingredients

Everything baked into the shipped artifacts, and how a change to it reaches a release. An *ingredient*
is an input to the product; the *own upstream* is the thing this repo exists to port.

This repo publishes the `ed25519-sign` tool the rest of the family signs releases with — shipyard's
`sign_and_appcast.sh` fetches it at signing time. So a change here reaches every sibling's next release,
which is a reason to keep its inputs few and legible.

| Ingredient | Pinned in | Renovate | On a bump |
|---|---|---|---|
| orlp/ed25519 source (own upstream) | `UPSTREAM_COMMIT` (a 40-char commit) | ✅ `git-refs` on `orlp/ed25519` | `build/version.sh` cuts `<date>-mavericks.1` |
| clang22, the compiler and linker of every build (Linux, and both Mach-O slices) | `components/clang22/version` (the release) and `components/clang22/sha256` (its `linux-x86_64` archive, which Linux builds with); on a Mac the installed `/usr/local/mavergreen/clang22-cross` when it is that release, else its `clang22-cross` pkg, verified against the release's `SHA256SUMS` (`build/fetch-clang22.sh`) | ✅ github-releases manager tracks `Mavergreen/clang-22` | `repackage-on-ingredient-bump.yml` cuts `-mavericks.(N+1)`; the Linux build fails at the fetch until `components/clang22/sha256` is the new archive's: `.github/workflows/pins-bot.yml` writes it on the bump's branch with `sh build/pin-clang22.sh fill`; if the bot did not run, `sh build/pin-clang22.sh` on that branch does the same |
| MacOSX10.9 and 11.3 SDKs, stevedore (the packager), packaging helpers | `Mavergreen/shipyard@v1` | ✅ github-actions manager tracks the tag | `@v1` is a *moving* tag: content changes without the pin changing, so nothing auto-repackages |

Not ingredients: the build scripts and `patches/` are this repo's own recipe. A change there is a
repackage you cut deliberately (`workflow_dispatch` with `local_release=true`).

## Why the upstream pin is a commit, not a tag

`orlp/ed25519` publishes no releases and has not tagged in years, so there is no version to track — the
commit *is* the version. `git-refs` moves it forward on the default branch; the shipped version string
is date-based (`<date>-mavericks.N`) because upstream provides nothing better to name it after.

## Repackage on an ingredient bump

`.github/workflows/repackage-on-ingredient-bump.yml` watches `components/**` and dispatches a
`-mavericks.(N+1)` when the clang22 pin moves (`own-upstream-paths: UPSTREAM_COMMIT`, whose own bump
is the `-mavericks.1` path `release.yml` already owns). `shipyard@v1` is a moving tag no path filter
can observe.

## What ships

The pkg carries the three tools as Universal Mach-O, x86_64 at 10.9 against the 10.9 SDK and arm64 at
11.0 against the 11.3 SDK, both compiled by clang22 with `--no-default-config`, so no Mavericks
runtime (`librecaulk.a`, libc++) reaches them, and packaged by shipyard's stevedore seams. The release
also carries `ed25519-<version>-linux-x86_64.tar.gz`: the same tools for x86_64 Linux, built on
Ubuntu by clang22's Linux archive against the host's glibc, needing no glibc newer than 2.35
(`tests/linux-tarball.bats`). Everything builds on Linux; the only macOS job installs the pkg and
runs its arm64 slice.

## Declared state

- upstream: UPSTREAM_COMMIT
- clang22: components/clang22/version

## Release notes

`release.yml` calls mavericks-shipyard's `release-notes.sh` (`--product ed25519`, `--min-os 10.9.5`)
to write `dist/RELEASE_NOTES.md`, which the shared `publish-release.yml` uses as the Release body —
it refuses an empty one. This repo has no Sparkle updater and publishes no appcast, so the Release
body is that file's only consumer; there is no second copy to keep in sync. See `release-notes/`
for the (optional) per-release prose convention.

## Conformance deviations

- linux: shipyard signs on Linux runners with ed25519-sign, which serves producing Mavericks artifacts; x86_64 only, a tarball under opt/mavergreen/ed25519/ that shipyard's fetch_product_tar.sh fetches, no .deb
- arm64:usr/local/mavergreen/ed25519/bin/*: shipyard's sign_and_appcast.sh runs the signer from this pkg on Apple Silicon Macs, so the pkg carries an arm64 (11.0) slice beside the x86_64 (10.9) one
- macos-runner:release.yml:modern-smoke: the arm64 slice is installed and run on current macOS (spec: modern-slice products); exit: none while the slice ships
- on-target:bats-suites: the 10.9 guest has no bats, so the tools' bats suites run on Linux against the tarball's tools, not in the guest; the guest runs tests/installed-smoke.sh, which signs and verifies with the installed tools and checks the pinned Mac signer's fixture; exit: bats in the 10.9 guest image
