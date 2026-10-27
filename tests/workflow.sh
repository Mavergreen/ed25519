#!/bin/sh
# platform: host-agnostic
set -eu
R="$(cd "$(dirname "$0")/.." && pwd)"
W="$R/.github/workflows/release.yml"
fail=0
[ -f "$W" ] || { echo "no release.yml" >&2; exit 1; }
for needle in \
  'actions/install@v1' \
  'build/fetch-ed25519.sh' \
  'build/derive-upstream-version.sh' \
  'build/version.sh' \
  'build/build-tools.sh' \
  'build/build-tools-linux.sh' \
  'build/package-pkg.sh' \
  'build/package-tar.sh' \
  'run-repo-tests.sh" --strict-host' \
  'release-needed.sh' \
  'check-artifact-conformance.sh' \
  'Mavergreen/mavericks-vm@v1' \
  'tests/installed-smoke.sh' \
  'actions/required-gate@v1' \
  'retry-release.yml@v1' \
  'publish-release.yml@v1'; do
  grep -qF "$needle" "$W" || { echo "release.yml missing: $needle" >&2; fail=1; }
done
# Must NOT reference Sparkle signing/appcast (out of scope).
for bad in SPARKLE_PRIVATE_KEY sign_and_appcast appcast; do
  grep -qi "$bad" "$W" && { echo "release.yml should not mention $bad" >&2; fail=1; } || true
done
python3 -c 'import yaml' 2>/dev/null || { echo "python3 with PyYAML is needed to read release.yml's jobs -- skipping" >&2; exit 77; }
python3 - "$W" <<'PY' || fail=1
import re, sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
jobs = wf["jobs"]
on = wf.get("on", wf.get(True))
bad = []
def needs(j):
    n = jobs[j].get("needs") or []
    return [n] if isinstance(n, str) else list(n)
mac = sorted(j for j, b in jobs.items() if re.search(r"macos-", str(b.get("runs-on", "")), re.I))
if mac != ["modern-smoke"]:
    bad.append("the only job on a macos-* runner must be modern-smoke, not %s" % mac)
pubs = [j for j, b in jobs.items() if "publish-release.yml" in str(b.get("uses", ""))]
if pubs != ["publish"]:
    bad.append("one job, publish, calls publish-release.yml; found %s" % pubs)
else:
    for j in ("build", "vm-test", "modern-smoke"):
        if j not in needs("publish"):
            bad.append("publish does not need %s" % j)
if "ubuntu" not in str(jobs.get("build", {}).get("runs-on", "")):
    bad.append("build runs on ubuntu")
gate = jobs.get("required", {})
if gate.get("name") != "required (release)" or gate.get("if") != "always()":
    bad.append("the required job is named 'required (release)' and runs if: always()")
if sorted(needs("required") if "required" in jobs else []) != sorted(j for j in jobs if j != "required"):
    bad.append("the required job needs every other job")
retry = [j for j, b in jobs.items() if "retry-release.yml" in str(b.get("uses", ""))]
if not retry or "publish" not in needs(retry[0]):
    bad.append("a retry job calls retry-release.yml and needs publish")
inputs = ((on or {}).get("workflow_dispatch") or {}).get("inputs") or {}
r = inputs.get("reconcile") or {}
if (r.get("type"), r.get("default"), r.get("description")) != ("boolean", False, "Set by the nightly reconcile backstop"):
    bad.append("workflow_dispatch declares the reconcile input")
for b in bad:
    print("release.yml: " + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PY
[ "$fail" -eq 0 ] && echo "workflow OK"
exit "$fail"
