#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AriaFlow"
BUNDLE_ID="${BUNDLE_ID:-com.ariaflow.desktop}"
APP_VERSION="${APP_VERSION:-0.3.0}"
BUILD_NUMBER="${BUILD_NUMBER:-2}"
UNIVERSAL="${UNIVERSAL:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SWIFT_BUILD_FLAGS=(--disable-sandbox)
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/dist/$APP_NAME-$APP_VERSION.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

cd "$ROOT_DIR"

swift_build() {
    swift build "${SWIFT_BUILD_FLAGS[@]}" "$@"
}

sign_app() {
    if ! command -v codesign >/dev/null 2>&1; then
        return
    fi

    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        codesign --force --deep --sign - "$APP_DIR"
    else
        codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
    fi

    codesign --verify --deep --strict "$APP_DIR"
}

create_zip() {
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
    (
        cd "$(dirname "$ZIP_PATH")"
        shasum -a 256 "$(basename "$ZIP_PATH")"
    ) > "$CHECKSUM_PATH"
}

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

[[ -f "$ROOT_DIR/THIRD_PARTY_NOTICES.md" ]] || {
    echo "missing THIRD_PARTY_NOTICES.md" >&2
    exit 1
}
[[ -f "$ROOT_DIR/third_party/aria2-next/COPYING" ]] || {
    echo "missing aria2-next GPL-2.0 notice" >&2
    exit 1
}

if [[ "$UNIVERSAL" == "1" ]]; then
    command -v lipo >/dev/null 2>&1 || {
        echo "lipo is required for UNIVERSAL=1" >&2
        exit 1
    }

    swift_build -c release --triple x86_64-apple-macosx14.0
    swift_build -c release --triple arm64-apple-macosx14.0

    X86_BIN_DIR="$(swift_build -c release --triple x86_64-apple-macosx14.0 --show-bin-path)"
    ARM_BIN_DIR="$(swift_build -c release --triple arm64-apple-macosx14.0 --show-bin-path)"
    lipo -create "$X86_BIN_DIR/$APP_NAME" "$ARM_BIN_DIR/$APP_NAME" -output "$APP_DIR/Contents/MacOS/$APP_NAME"
    RESOURCE_BUNDLE="$X86_BIN_DIR/${APP_NAME}_${APP_NAME}.bundle"
else
    swift_build -c release

    BIN_DIR="$(swift_build -c release --show-bin-path)"
    cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
    RESOURCE_BUNDLE="$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle"
fi

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE/Resources/." "$APP_DIR/Contents/Resources/"
fi

mkdir -p "$APP_DIR/Contents/Resources/ThirdParty/aria2-next"
cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$APP_DIR/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp "$ROOT_DIR/third_party/aria2-next/COPYING" "$APP_DIR/Contents/Resources/ThirdParty/aria2-next/COPYING"

for engine in \
    motrix-next-engine-aarch64-apple-darwin \
    motrix-next-engine-x86_64-apple-darwin \
    aria2-next \
    aria2c
do
    if [[ -f "$APP_DIR/Contents/Resources/$engine" ]]; then
        chmod +x "$APP_DIR/Contents/Resources/$engine"
    fi
done

if ! find "$APP_DIR/Contents/Resources" -maxdepth 1 \( \
    -name "motrix-next-engine-aarch64-apple-darwin" -o \
    -name "motrix-next-engine-x86_64-apple-darwin" -o \
    -name "aria2-next" -o \
    -name "aria2c" \
\) -type f -perm -111 | grep -q .; then
    echo "warning: no bundled aria2 sidecar found; app will rely on system aria2 if available" >&2
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Torrent File</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>org.bittorrent.torrent</string>
            </array>
        </dict>
    </array>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>Magnet Link</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>magnet</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleURLName</key>
            <string>ED2K Link</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>ed2k</string>
            </array>
        </dict>
    </array>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

sign_app

plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null

create_zip

if [[ -n "$NOTARY_PROFILE" ]]; then
    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        echo "NOTARY_PROFILE requires SIGN_IDENTITY with a Developer ID Application certificate" >&2
        exit 1
    fi

    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_DIR"
    sign_app
    create_zip
fi

echo "$APP_DIR"
echo "$ZIP_PATH"
echo "$CHECKSUM_PATH"
