#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="${APP_VERSION:-0.4.19}"
APP_DIR="$ROOT_DIR/dist/AriaFlow.app"
ZIP_PATH="$ROOT_DIR/dist/AriaFlow-$APP_VERSION.zip"

cd "$ROOT_DIR"

scripts/verify_localizations.py

echo "== unit tests =="
swift test --disable-sandbox

echo "== package =="
scripts/package_app.sh

lipo -info "$APP_DIR/Contents/MacOS/AriaFlow"
xcrun vtool -show-build "$APP_DIR/Contents/MacOS/AriaFlow" | grep -q "minos 14.0"
file \
    "$APP_DIR/Contents/Resources/motrix-next-engine-aarch64-apple-darwin" \
    "$APP_DIR/Contents/Resources/motrix-next-engine-x86_64-apple-darwin"
printf '6767bc6e79e22dbc491fe7bbcd36daca9dc0fb3b28abca7b9a9cfb8e6e67ece5  %s\n' "$APP_DIR/Contents/Resources/motrix-next-engine-aarch64-apple-darwin" | shasum -a 256 -c -
printf '933fb85f42adb6acd56e0e728b5d561908669dcdcb5e13459ec5c0195a960e95  %s\n' "$APP_DIR/Contents/Resources/motrix-next-engine-x86_64-apple-darwin" | shasum -a 256 -c -
plutil -lint "$APP_DIR/Contents/Info.plist"
[[ "$(plutil -extract LSMinimumSystemVersion raw "$APP_DIR/Contents/Info.plist")" == "14.0" ]]
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
(
    cd "$(dirname "$ZIP_PATH")"
    shasum -a 256 -c "$(basename "$ZIP_PATH").sha256"
)
test -f "$APP_DIR/Contents/Resources/THIRD_PARTY_NOTICES.md"
test -f "$APP_DIR/Contents/Resources/ThirdParty/aria2-next/COPYING"
test -f "$APP_DIR/Contents/Resources/en.lproj/Localizable.strings"
test -f "$APP_DIR/Contents/Resources/zh-Hans.lproj/Localizable.strings"
test -f "$APP_DIR/Contents/Resources/zh-Hant.lproj/Localizable.strings"
[[ "$(plutil -extract CFBundleDevelopmentRegion raw "$APP_DIR/Contents/Info.plist")" == "en" ]]

scripts/smoke_sidecar_download.sh
scripts/smoke_app_download.sh

echo "release verification passed: $APP_DIR"
echo "$ZIP_PATH"
