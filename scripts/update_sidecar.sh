#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="$(basename "$REPO_ROOT")"
UPSTREAM_REPO="AnInsomniacy/aria2-next"
RESOURCES_DIR="$REPO_ROOT/Sources/$APP_NAME/Resources"
ARCH_A="aarch64"
ARCH_X="x86_64"
DATE="$(TZ=Asia/Shanghai date +%Y-%m-%d)"

cd "$REPO_ROOT"

# 1) current bundled engine version (from THIRD_PARTY_NOTICES.md heading)
CURRENT_ENGINE="$(sed -n 's/^## aria2-next //p' THIRD_PARTY_NOTICES.md | head -1)"
CURRENT_ENGINE="${CURRENT_ENGINE#v}"
[[ "$CURRENT_ENGINE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "cannot parse current engine version" >&2; exit 1; }

# 2) latest upstream tag
LATEST_TAG="$(git ls-remote --tags "https://github.com/$UPSTREAM_REPO.git" \
    | grep -v '\^{}' \
    | sed 's|.*refs/tags/||' \
    | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -1)"
[[ -n "$LATEST_TAG" ]] || { echo "cannot resolve upstream latest tag" >&2; exit 1; }
LATEST_ENGINE="${LATEST_TAG#v}"

# 3) no update -> report and stop
if [[ "$CURRENT_ENGINE" == "$LATEST_ENGINE" ]]; then
    echo "aria2-next already at latest: $CURRENT_ENGINE"
    echo "updated=false" | tee -a "${GITHUB_OUTPUT:-/dev/null}"
    echo "engine_version=$CURRENT_ENGINE" | tee -a "${GITHUB_OUTPUT:-/dev/null}"
    exit 0
fi

echo "updating aria2-next $CURRENT_ENGINE -> $LATEST_ENGINE"

# 4) app version + build number bump
CURRENT_APP="$(ruby -rjson -e 'print JSON.parse(File.read(ARGV[0])).fetch("version")' update.json)"
NEW_APP="$(python3 -c "v='$CURRENT_APP'.split('.'); v[-1]=str(int(v[-1])+1); print('.'.join(v))")"
CURRENT_BUILD="$(sed -n 's/^BUILD_NUMBER="\${BUILD_NUMBER:-\([0-9]*\)}"/\1/p' scripts/package_app.sh)"
NEW_BUILD=$((CURRENT_BUILD + 1))

# 5) download + verify upstream assets
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BASE="https://github.com/$UPSTREAM_REPO/releases/download/$LATEST_TAG"
curl -fsSL --retry 3 -o "$TMP/checksums.sha256" "$BASE/aria2-next-$LATEST_ENGINE-checksums.sha256"
curl -fsSL --retry 3 -o "$TMP/aria2-next-$LATEST_ENGINE-macos-arm64" "$BASE/aria2-next-$LATEST_ENGINE-macos-arm64"
curl -fsSL --retry 3 -o "$TMP/aria2-next-$LATEST_ENGINE-macos-x86_64" "$BASE/aria2-next-$LATEST_ENGINE-macos-x86_64"
(cd "$TMP" && grep -E "macos-(arm64|x86_64)$" checksums.sha256 | shasum -a 256 -c -)

NEW_ARM_SHA="$(grep -E "  aria2-next-$LATEST_ENGINE-macos-arm64$" "$TMP/checksums.sha256" | awk '{print $1}')"
NEW_X86_SHA="$(grep -E "  aria2-next-$LATEST_ENGINE-macos-x86_64$" "$TMP/checksums.sha256" | awk '{print $1}')"
OLD_ARM_SHA="$(grep -E "aria2-next-$CURRENT_ENGINE-macos-arm64" THIRD_PARTY_NOTICES.md | grep -oE '[0-9a-f]{64}' | head -1)"
OLD_X86_SHA="$(grep -E "aria2-next-$CURRENT_ENGINE-macos-x86_64" THIRD_PARTY_NOTICES.md | grep -oE '[0-9a-f]{64}' | head -1)"

# 6) replace bundled binaries
install -m 755 "$TMP/aria2-next-$LATEST_ENGINE-macos-arm64" "$RESOURCES_DIR/motrix-next-engine-aarch64-apple-darwin"
install -m 755 "$TMP/aria2-next-$LATEST_ENGINE-macos-x86_64" "$RESOURCES_DIR/motrix-next-engine-x86_64-apple-darwin"

# 7) rewrite version references across docs, scripts and sources
python3 - "$CURRENT_ENGINE" "$LATEST_ENGINE" "$CURRENT_APP" "$NEW_APP" "$CURRENT_BUILD" "$NEW_BUILD" \
    "$OLD_ARM_SHA" "$NEW_ARM_SHA" "$OLD_X86_SHA" "$NEW_X86_SHA" "$DATE" "$APP_NAME" <<'PY'
import os, re, sys

cur_engine, new_engine = sys.argv[1], sys.argv[2]
cur_app, new_app = sys.argv[3], sys.argv[4]
cur_build, new_build = sys.argv[5], sys.argv[6]
old_arm, new_arm = sys.argv[7], sys.argv[8]
old_x86, new_x86 = sys.argv[9], sys.argv[10]
date, app_name = sys.argv[11], sys.argv[12]

changed = []

def write_if_changed(path, s):
    if s != open(path).read():
        open(path, "w").write(s)
        changed.append(path)

# engine version strings (skip CHANGELOG so history is preserved)
for f in [
    "AGENTS.md", "docs/SIDECAR.md", "THIRD_PARTY_NOTICES.md", "README.md",
    "scripts/smoke_sidecar_download.sh", "scripts/smoke_app_engine.sh",
    f"Sources/{app_name}/SettingsViews.swift",
]:
    if os.path.isfile(f):
        write_if_changed(f, open(f).read().replace(cur_engine, new_engine))

# sidecar checksums
for f in ["THIRD_PARTY_NOTICES.md", "scripts/verify_release.sh"]:
    write_if_changed(f, open(f).read().replace(old_arm, new_arm).replace(old_x86, new_x86))

# app version
for f in [
    f"Sources/{app_name}/SettingsViews.swift",
    f"Sources/{app_name}/SoftwareUpdater.swift",
    "scripts/package_app.sh", "scripts/verify_release.sh",
    "update.json", ".github/workflows/ci.yml",
]:
    write_if_changed(f, open(f).read().replace(cur_app, new_app))

# build number
s = open("scripts/package_app.sh").read()
write_if_changed("scripts/package_app.sh",
    re.sub(r'(BUILD_NUMBER="\$\{BUILD_NUMBER:-)\d+(\}")', rf"\g<1>{new_build}\g<2>", s))

# CHANGELOG: prepend new entry, keep history untouched
p = "CHANGELOG.md"
s = open(p).read()
entry = f"## {new_app} - {date}\n\n- Updated bundled `aria2-next` sidecars to {new_engine} (arm64 and x86_64).\n\n"
marker = f"## {cur_app} - "
assert marker in s, "CHANGELOG marker for current app version not found"
write_if_changed(p, s.replace(marker, entry + marker, 1))

print("updated files:")
for f in changed:
    print("  " + f)
PY

# 8) report to workflow
echo "updated=true" | tee -a "${GITHUB_OUTPUT:-/dev/null}"
echo "version=$NEW_APP" | tee -a "${GITHUB_OUTPUT:-/dev/null}"
echo "engine_version=$LATEST_ENGINE" | tee -a "${GITHUB_OUTPUT:-/dev/null}"
echo "done: $APP_NAME $NEW_APP with aria2-next $LATEST_ENGINE"
