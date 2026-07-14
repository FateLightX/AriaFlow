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
BLOCKLIST_PATH="$TMP_DIR/blocklist.txt"
BASE_PORT=$(( ( $$ % 1000 ) * 10 + 21000 ))
HTTP_PORT="${HTTP_PORT:-$BASE_PORT}"
RPC_PORT="${RPC_PORT:-$((BASE_PORT + 1))}"
mkdir -p "$SERVER_DIR" "$DOWNLOAD_DIR" "$APP_SUPPORT_DIR"
printf "# app startup blocklist\n203.0.113.0/24\n2001:db8::/32\n" > "$BLOCKLIST_PATH"

cleanup() {
    [[ -n "${HTTP_PID:-}" ]] && kill "$HTTP_PID" >/dev/null 2>&1 || true
    [[ -n "${HTTP_PID:-}" ]] && wait "$HTTP_PID" >/dev/null 2>&1 || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

printf "AriaFlow app smoke test\n" > "$SERVER_DIR/payload.txt"
URL="http://127.0.0.1:$HTTP_PORT/payload.txt"
"$PYTHON_BIN" -m http.server "$HTTP_PORT" --bind 127.0.0.1 --directory "$SERVER_DIR" >/dev/null 2>&1 &
HTTP_PID=$!
for _ in {1..40}; do
    if curl -fsS --max-time 1 "$URL" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
if ! curl -fsS --max-time 1 "$URL" >/dev/null; then
    echo "failed to start local HTTP server on 127.0.0.1:$HTTP_PORT" >&2
    echo "this environment may block local TCP listeners" >&2
    exit 1
fi

ARIAFLOW_APP_SUPPORT_DIR="$APP_SUPPORT_DIR" \
ARIAFLOW_SMOKE_BLOCKLIST_PATH="$BLOCKLIST_PATH" \
    "$APP_EXECUTABLE" \
    --smoke-download "$URL" "$DOWNLOAD_DIR" "$RPC_PORT"

cmp "$SERVER_DIR/payload.txt" "$DOWNLOAD_DIR/payload.txt"
echo "app download smoke test passed"
