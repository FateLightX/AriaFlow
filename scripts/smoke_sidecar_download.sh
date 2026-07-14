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
BLOCKLIST_PATH="$TMP_DIR/blocklist.txt"
export RELOAD_BLOCKLIST_PATH="$TMP_DIR/reload-blocklist.txt"
INVALID_BLOCKLIST_PATH="$TMP_DIR/invalid-blocklist.txt"
printf "# startup rules\n203.0.113.0/24\n2001:db8::/32\n" > "$BLOCKLIST_PATH"
printf "# reload rules\n198.51.100.25\n2001:db8:abcd::/48\n" > "$RELOAD_BLOCKLIST_PATH"
printf "not-an-ip\n" > "$INVALID_BLOCKLIST_PATH"

cleanup() {
    [[ -n "${ARIA2_PID:-}" ]] && kill "$ARIA2_PID" >/dev/null 2>&1 || true
    [[ -n "${HTTP_PID:-}" ]] && kill "$HTTP_PID" >/dev/null 2>&1 || true
    [[ -n "${ARIA2_PID:-}" ]] && wait "$ARIA2_PID" >/dev/null 2>&1 || true
    [[ -n "${HTTP_PID:-}" ]] && wait "$HTTP_PID" >/dev/null 2>&1 || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

printf "AriaFlow sidecar smoke test\n" > "$SERVER_DIR/payload.txt"
URL="http://127.0.0.1:$HTTP_PORT/payload.txt"

"$PYTHON_BIN" -m http.server "$HTTP_PORT" --bind 127.0.0.1 --directory "$SERVER_DIR" >/dev/null 2>&1 &
HTTP_PID=$!
for _ in {1..40}; do
    if curl -fsS --max-time 1 "$URL" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
curl -fsS --max-time 1 "$URL" >/dev/null || {
    echo "failed to start local HTTP server on 127.0.0.1:$HTTP_PORT" >&2
    echo "this environment may block local TCP listeners" >&2
    exit 1
}

"$ENGINE_PATH" \
    --enable-rpc=true \
    --rpc-listen-all=false \
    --rpc-listen-port="$RPC_PORT" \
    --rpc-secret="$SECRET" \
    --dir="$DOWNLOAD_DIR" \
    --save-session="$TMP_DIR/download.session" \
    --log="$TMP_DIR/aria2-next.log" \
    --log-level=info \
    --bt-peer-blocklist="$BLOCKLIST_PATH" \
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
    curl -sS \
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

VERSION_RESPONSE="$(rpc "aria2.getVersion")"
printf "%s" "$VERSION_RESPONSE" | "$PYTHON_BIN" -c '
import json, sys
version = json.load(sys.stdin)["result"]["version"]
assert version == "2.5.1", version
'

RELOAD_RESPONSE="$(rpc "aria2.changeGlobalOption" "{\"bt-peer-blocklist\":\"$RELOAD_BLOCKLIST_PATH\"}")"
printf "%s" "$RELOAD_RESPONSE" | "$PYTHON_BIN" -c '
import json, sys
assert json.load(sys.stdin).get("result") == "OK"
'

GLOBAL_OPTIONS_RESPONSE="$(rpc "aria2.getGlobalOption")"
printf "%s" "$GLOBAL_OPTIONS_RESPONSE" | "$PYTHON_BIN" -c '
import json, os, sys
value = json.load(sys.stdin)["result"].get("bt-peer-blocklist")
assert value == os.environ["RELOAD_BLOCKLIST_PATH"], value
'

INVALID_RESPONSE="$(rpc "aria2.changeGlobalOption" "{\"bt-peer-blocklist\":\"$INVALID_BLOCKLIST_PATH\"}")"
printf "%s" "$INVALID_RESPONSE" | "$PYTHON_BIN" -c '
import json, sys
assert "error" in json.load(sys.stdin)
'

GLOBAL_OPTIONS_RESPONSE="$(rpc "aria2.getGlobalOption")"
printf "%s" "$GLOBAL_OPTIONS_RESPONSE" | "$PYTHON_BIN" -c '
import json, os, sys
value = json.load(sys.stdin)["result"].get("bt-peer-blocklist")
assert value == os.environ["RELOAD_BLOCKLIST_PATH"], value
'

CLEAR_RESPONSE="$(rpc "aria2.changeGlobalOption" "{\"bt-peer-blocklist\":\"\"}")"
printf "%s" "$CLEAR_RESPONSE" | "$PYTHON_BIN" -c '
import json, sys
assert json.load(sys.stdin).get("result") == "OK"
'

GLOBAL_OPTIONS_RESPONSE="$(rpc "aria2.getGlobalOption")"
printf "%s" "$GLOBAL_OPTIONS_RESPONSE" | "$PYTHON_BIN" -c '
import json, sys
value = json.load(sys.stdin)["result"].get("bt-peer-blocklist", "")
assert value == "", value
'

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
