#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift scripts/generate_app_icon.swift

rm -rf docs/assets/AppIcon.iconset Sources/AriaFlow/Resources/AppIcon.icns
mkdir -p docs/assets/AppIcon.iconset Sources/AriaFlow/Resources

pairs=(
  "16 icon_16x16.png"
  "32 icon_16x16@2x.png"
  "32 icon_32x32.png"
  "64 icon_32x32@2x.png"
  "128 icon_128x128.png"
  "256 icon_128x128@2x.png"
  "256 icon_256x256.png"
  "512 icon_256x256@2x.png"
  "512 icon_512x512.png"
  "1024 icon_512x512@2x.png"
)

for pair in "${pairs[@]}"; do
    read -r px name <<< "$pair"
    sips -z "$px" "$px" docs/assets/AppIcon.png --out "docs/assets/AppIcon.iconset/$name" >/dev/null
done

iconutil -c icns docs/assets/AppIcon.iconset -o Sources/AriaFlow/Resources/AppIcon.icns

echo "docs/assets/AppIcon.png"
echo "Sources/AriaFlow/Resources/AppIcon.icns"
