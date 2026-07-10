#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCES_DIR="$ROOT_DIR/Sources/AriaFlow/Resources"
SOURCE_PATH=""
TARGET_ARCH="auto"

usage() {
    echo "usage: scripts/install_sidecar.sh [--arch auto|arm64|x86_64] /path/to/aria2c-or-aria2-next" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            TARGET_ARCH="${2:-}"
            shift 2
            ;;
        --arch=*)
            TARGET_ARCH="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -n "$SOURCE_PATH" ]]; then
                usage
                exit 1
            fi
            SOURCE_PATH="$1"
            shift
            ;;
    esac
done

if [[ -z "$SOURCE_PATH" ]]; then
    SOURCE_PATH="$(command -v aria2c || true)"
fi

if [[ -z "$SOURCE_PATH" || ! -f "$SOURCE_PATH" ]]; then
    usage
    echo "no aria2 executable found automatically" >&2
    exit 1
fi

if [[ "$TARGET_ARCH" == "auto" ]]; then
    TARGET_ARCH="$(uname -m)"
fi

case "$TARGET_ARCH" in
    arm64) TARGET_NAME="motrix-next-engine-aarch64-apple-darwin" ;;
    x86_64) TARGET_NAME="motrix-next-engine-x86_64-apple-darwin" ;;
    *)
        echo "unsupported arch: $TARGET_ARCH" >&2
        exit 1
        ;;
esac

mkdir -p "$RESOURCES_DIR"
cp "$SOURCE_PATH" "$RESOURCES_DIR/$TARGET_NAME"
chmod +x "$RESOURCES_DIR/$TARGET_NAME"

if [[ "$TARGET_ARCH" == "$(uname -m)" ]]; then
    "$RESOURCES_DIR/$TARGET_NAME" --version | head -n 1 || true
else
    file "$RESOURCES_DIR/$TARGET_NAME"
fi
echo "$RESOURCES_DIR/$TARGET_NAME"
