#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${APP_DIR:-$ROOT_DIR/dist/AriaFlow.app}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
SECRET="ariaflow-smoke"

case "$(uname -m)" in
    arm64) ENGINE_NAME="motrix-next-engine-aarch64-apple-darwin" ;;
    x86_64) ENGINE_NAME="motrix-next-engine-x86_64-apple-darwin" ;;
    *)
        echo "unsupported smoke-test arch: $(uname -m)" >&2
        exit 1
        ;;
esac

ENGINE_PATH="$APP_DIR/Contents/Resources/$ENGINE_NAME"
if [[ ! -x "$ENGINE_PATH" ]]; then
    echo "missing executable sidecar: $ENGINE_PATH" >&2
    exit 1
fi

command -v "$PYTHON_BIN" >/dev/null 2>&1 || {
    echo "python3 is required for the local HTTP smoke test" >&2
    exit 1
}

BASE_PORT=$(( ( $$ % 1000 ) * 10 + 20000 ))
RPC_PORT="${RPC_PORT:-$BASE_PORT}"
HTTP_PORT="${HTTP_PORT:-$((BASE_PORT + 1))}"
TMP_DIR="$(mktemp -d)"
SERVER_DIR="$TMP_DIR/server"
DOWNLOAD_DIR="$TMP_DIR/downloads"
mkdir -p "$SERVER_DIR" "$DOWNLOAD_DIR"

cleanup() {
    [[ -n "${ARIA2_PID:-}" ]] && kill "$ARIA2_PID" >/dev/null 2>&1 || true
    [[ -n "${HTTP_PID:-}" ]] && kill "$HTTP_PID" >/dev/null 2>&1 || true
    [[ -n "${ARIA2_PID:-}" ]] && wait "$ARIA2_PID" >/dev/null 2>&1 || true
    [[ -n "${HTTP_PID:-}" ]] && wait "$HTTP_PID" >/dev/null 2>&1 || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

printf "AriaFlow sidecar smoke test\n" > "$SERVER_DIR/payload.txt"

"$PYTHON_BIN" -m http.server "$HTTP_PORT" --bind 127.0.0.1 --directory "$SERVER_DIR" >/dev/null 2>&1 &
HTTP_PID=$!
sleep 0.2
if ! kill -0 "$HTTP_PID" >/dev/null 2>&1; then
    echo "failed to start local HTTP server on 127.0.0.1:$HTTP_PORT" >&2
    echo "this environment may block local TCP listeners" >&2
    exit 1
fi

"$ENGINE_PATH" \
    --enable-rpc=true \
    --rpc-listen-all=false \
    --rpc-listen-port="$RPC_PORT" \
    --rpc-secret="$SECRET" \
    --dir="$DOWNLOAD_DIR" \
    --save-session="$TMP_DIR/download.session" \
    --log="$TMP_DIR/aria2-next.log" \
    --quiet=true >/dev/null 2>&1 &
ARIA2_PID=$!
sleep 0.2
if ! kill -0 "$ARIA2_PID" >/dev/null 2>&1; then
    echo "failed to start aria2 RPC on 127.0.0.1:$RPC_PORT" >&2
    echo "this environment may block local TCP listeners" >&2
    exit 1
fi

rpc() {
    local method="$1"
    local extra_params="${2:-}"
    local params="\"token:$SECRET\""
    if [[ -n "$extra_params" ]]; then
        params="$params,$extra_params"
    fi
    curl -fsS \
        -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"id\":\"smoke\",\"method\":\"$method\",\"params\":[$params]}" \
        "http://127.0.0.1:$RPC_PORT/jsonrpc"
}

for _ in {1..40}; do
    if rpc "aria2.getVersion" >/dev/null 2>&1; then
        break
    fi
    sleep 0.25
done

rpc "aria2.getVersion" >/dev/null

URL="http://127.0.0.1:$HTTP_PORT/payload.txt"
ADD_RESPONSE="$(rpc "aria2.addUri" "[\"$URL\"],{\"dir\":\"$DOWNLOAD_DIR\"}")"
GID="$(printf "%s" "$ADD_RESPONSE" | "$PYTHON_BIN" -c 'import json,sys; print(json.load(sys.stdin)["result"])')"

for _ in {1..80}; do
    STATUS_RESPONSE="$(rpc "aria2.tellStatus" "\"$GID\"")"
    STATUS="$(printf "%s" "$STATUS_RESPONSE" | "$PYTHON_BIN" -c 'import json,sys; print(json.load(sys.stdin)["result"]["status"])')"
    if [[ "$STATUS" == "complete" ]]; then
        cmp "$SERVER_DIR/payload.txt" "$DOWNLOAD_DIR/payload.txt"
        echo "sidecar download smoke test passed: $ENGINE_NAME"
        exit 0
    fi
    if [[ "$STATUS" == "error" || "$STATUS" == "removed" ]]; then
        echo "$STATUS_RESPONSE" >&2
        exit 1
    fi
    sleep 0.25
done

echo "timed out waiting for sidecar download" >&2
exit 1
