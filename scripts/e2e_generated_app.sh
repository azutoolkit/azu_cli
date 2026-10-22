#!/bin/sh
# End-to-end gate for `azu new`: generate a project with the built CLI, install its shards,
# compile it, boot it on a free port and check that it serves.
#
# Usage: scripts/e2e_generated_app.sh [web|api]      (default: web)
# Env:   AZU_BIN  path to the azu binary to test     (default: <repo>/bin/azu)
#        E2E_DB   database adapter for `azu new`     (default: sqlite)
#        KEEP_TMP set to 1 to keep the temp dir for debugging
set -eu

TYPE="${1:-web}"
DB="${E2E_DB:-sqlite}"
NAME="e2e_app"
MODULE="E2eApp"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AZU_BIN="${AZU_BIN:-$REPO_ROOT/bin/azu}"
READY_TRIES=60 # one second apart

command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
[ -x "$AZU_BIN" ] || { echo "azu binary not found at $AZU_BIN (build it first or set AZU_BIN)" >&2; exit 2; }

WORK="$(mktemp -d)"
SERVER_PID=""

cleanup() {
  status=$?
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  if [ "$status" -ne 0 ] && [ -f "$WORK/server.log" ]; then
    echo "--- server log ---" >&2
    tail -n 40 "$WORK/server.log" >&2
  fi
  [ "${KEEP_TMP:-0}" = 1 ] && echo "kept $WORK" || rm -rf "$WORK"
  exit "$status"
}
trap cleanup EXIT INT TERM

step() { echo "==> $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

# A port is free when nothing accepts a connection on it (curl exit 7 = connection refused).
free_port() {
  for candidate in $(seq 20000 20100); do
    code=0
    curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$candidate/" || code=$?
    if [ "$code" -eq 7 ]; then echo "$candidate"; return 0; fi
  done
  return 1
}

# fetch PATH: stores the body in $WORK/body, returns the HTTP status code.
fetch() {
  curl -s -o "$WORK/body" -w '%{http_code}' --max-time 10 "http://127.0.0.1:$PORT$1"
}

expect_status() {
  got="$(fetch "$1")"
  [ "$got" = "$2" ] || fail "GET $1 returned $got, expected $2"
  echo "ok: GET $1 -> $got"
}

expect_body() {
  grep -q -- "$1" "$WORK/body" || fail "response body does not contain '$1'"
  echo "ok: body contains '$1'"
}

step "generate a $TYPE project ($DB) with $AZU_BIN"
cd "$WORK"
"$AZU_BIN" new "$NAME" --yes --author "E2E" --email e2e@example.com \
  --type "$TYPE" --db "$DB" --no-git --no-docker
cd "$NAME"

step "shards install"
shards install --ignore-crystal-version

ENTRY=src/server.cr
[ "$TYPE" = api ] && ENTRY=src/api.cr
step "compile $ENTRY"
mkdir -p bin
crystal build "$ENTRY" -o "bin/$NAME"

step "start the server"
PORT="$(free_port)" || fail "no free port found"
echo "port $PORT"
HOST=127.0.0.1 PORT="$PORT" "./bin/$NAME" >"$WORK/server.log" 2>&1 &
SERVER_PID=$!

step "wait for readiness (up to $READY_TRIES tries)"
tries=0
until curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$PORT/health"; do
  kill -0 "$SERVER_PID" 2>/dev/null || fail "server exited before becoming ready"
  tries=$((tries + 1))
  [ "$tries" -lt "$READY_TRIES" ] || fail "server not ready after $READY_TRIES tries"
  sleep 1
done

step "check responses"
expect_status /health 200
expect_body '"status":"ok"'
if [ "$TYPE" = web ]; then
  expect_status / 200
  expect_body "Welcome to $MODULE"
  expect_body "Typed contracts"
  expect_status /assets/app.css 200
fi

kill -0 "$SERVER_PID" 2>/dev/null || fail "server died while serving requests"
step "PASS: generated $TYPE app compiles, boots and serves"
