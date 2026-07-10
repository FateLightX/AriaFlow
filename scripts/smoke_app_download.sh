#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${APP_DIR:-$ROOT_DIR/dist/AriaFlow.app}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
APP_EXECUTABLE="$APP_DIR/Contents/MacOS/AriaFlow"

if [[ ! -x "$APP_EXECUTABLE" ]]; then
    echo "missing executable app: $APP_EXECUTABLE" >&2
    exit 1
fi

command -v "$PYTHON_BIN" >/dev/null 2>&1 || {
    echo "python3 is required for the app smoke test" >&2
    exit 1
}

TMP_DIR="$(mktemp -d)"
SERVER_DIR="$TMP_DIR/server"
DOWNLOAD_DIR="$TMP_DIR/downloads"
APP_SUPPORT_DIR="$TMP_DIR/app-support"
BASE_PORT=$(( ( $$ % 1000 ) * 10 + 21000 ))
HTTP_PORT="${HTTP_PORT:-$BASE_PORT}"
RPC_PORT="${RPC_PORT:-$((BASE_PORT + 1))}"
mkdir -p "$SERVER_DIR" "$DOWNLOAD_DIR" "$APP_SUPPORT_DIR"

cleanup() {
    [[ -n "${HTTP_PID:-}" ]] && kill "$HTTP_PID" >/dev/null 2>&1 || true
    [[ -n "${HTTP_PID:-}" ]] && wait "$HTTP_PID" >/dev/null 2>&1 || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

printf "AriaFlow app smoke test\n" > "$SERVER_DIR/payload.txt"
"$PYTHON_BIN" -m http.server "$HTTP_PORT" --bind 127.0.0.1 --directory "$SERVER_DIR" >/dev/null 2>&1 &
HTTP_PID=$!
sleep 0.2
if ! kill -0 "$HTTP_PID" >/dev/null 2>&1; then
    echo "failed to start local HTTP server on 127.0.0.1:$HTTP_PORT" >&2
    echo "this environment may block local TCP listeners" >&2
    exit 1
fi

ARIAFLOW_APP_SUPPORT_DIR="$APP_SUPPORT_DIR" \
    "$APP_EXECUTABLE" \
    --smoke-download "http://127.0.0.1:$HTTP_PORT/payload.txt" "$DOWNLOAD_DIR" "$RPC_PORT"

cmp "$SERVER_DIR/payload.txt" "$DOWNLOAD_DIR/payload.txt"
echo "app download smoke test passed"
