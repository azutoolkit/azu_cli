#!/bin/sh
# End-to-end gate for `azu new --docker --ci`: generate a project, build its Dockerfile with the host
# docker, run the image and check it from the host. CI runs this on a Docker-enabled host.
#
# What it checks: the Dockerfile and the workflow are generated; the image builds; the container runs
# as a non-root user; /health and / answer; the development handlers are not mounted in production; a
# web container started without CSRF_SECRET / SESSION_SECRET exits with a clear error; the image
# reports itself healthy; on SQLite /data is writable.
#
# Usage: scripts/e2e_docker.sh [web|api]      (default: web)
# Env:   AZU_BIN             path to the azu binary to test (default: <repo>/bin/azu)
#        DOCKER_BUILD_ARGS   extra `docker build` arguments (a proxy, --network host, ...)
#        E2E_DOCKER_CA       path to a CA certificate (PEM) to trust inside the build, for a network behind a TLS-intercepting
#                            proxy; unset (the default) leaves the generated Dockerfile untouched. Combine with
#                            DOCKER_BUILD_ARGS="--build-arg HTTPS_PROXY=..." if the proxy must be named too
#        KEEP_TMP            set to 1 to keep the temp dir for debugging
#        E2E_AZU_BRANCH      pin the generated project's azu dependency to this branch (e.g. master)
#        KEEP_IMAGE          set to 1 to keep the built image
set -eu

TYPE="${1:-web}"
NAME="e2e_app"
IMAGE="azu-e2e-$NAME:$$"
CONTAINER="azu-e2e-$NAME-$$"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AZU_BIN="${AZU_BIN:-$REPO_ROOT/bin/azu}"
# The script changes directory before it reads the CA: make a relative path absolute now.
if [ -n "${E2E_DOCKER_CA:-}" ] && [ -f "$E2E_DOCKER_CA" ]; then
  E2E_DOCKER_CA="$(cd "$(dirname "$E2E_DOCKER_CA")" && pwd)/$(basename "$E2E_DOCKER_CA")"
fi

command -v docker >/dev/null || { echo "docker is required" >&2; exit 2; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
[ -x "$AZU_BIN" ] || { echo "azu binary not found at $AZU_BIN (build it first or set AZU_BIN)" >&2; exit 2; }

WORK="$(mktemp -d)"

cleanup() {
  status=$?
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  [ "${KEEP_IMAGE:-0}" = 1 ] && echo "kept image $IMAGE" || docker image rm -f "$IMAGE" >/dev/null 2>&1 || true
  [ "${KEEP_TMP:-0}" = 1 ] && echo "kept $WORK" || rm -rf "$WORK"
  exit "$status"
}
trap cleanup EXIT INT TERM

step() { echo "==> $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

free_port() {
  for candidate in $(seq 20200 20300); do
    code=0
    curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$candidate/" || code=$?
    if [ "$code" -eq 7 ]; then echo "$candidate"; return 0; fi
  done
  return 1
}

secret() { od -An -N32 -tx1 /dev/urandom | tr -d ' \n'; }

# run_container_without NAME...: starts the image without the named secrets, expects it to exit with an error naming it.
expect_boot_refused() {
  missing="$1"; shift
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker run -d --name "$CONTAINER" "$@" "$IMAGE" >/dev/null
  tries=0
  while [ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER")" = true ]; do
    tries=$((tries + 1))
    [ "$tries" -lt 30 ] || fail "the container is still running without $missing"
    sleep 1
  done
  [ "$(docker inspect --format '{{.State.ExitCode}}' "$CONTAINER")" != 0 ] || fail "the container exited 0 without $missing"
  docker logs "$CONTAINER" 2>&1 | grep -q "$missing is not set" || fail "no '$missing is not set' in the logs: $(docker logs "$CONTAINER" 2>&1 | head -n 8)"
  echo "ok: a container without $missing exits with '$missing is not set'"
  docker rm -f "$CONTAINER" >/dev/null
}

step "generate a $TYPE project with --docker --ci"
cd "$WORK"
"$AZU_BIN" new "$NAME" --yes --author "E2E" --email e2e@example.com \
  --type "$TYPE" --db sqlite --no-git --docker --ci "GitHub Actions"
cd "$NAME"
crystal run "$REPO_ROOT/scripts/select_framework_versions.cr" -- shard.yml
shards install
for file in Dockerfile .dockerignore .github/workflows/ci.yml; do
  [ -f "$file" ] || fail "$file was not generated"
done
echo "ok: Dockerfile, .dockerignore and .github/workflows/ci.yml exist"
if [ "$TYPE" = web ]; then
  "$AZU_BIN" generate auth >/dev/null
fi

# Opt-in: trust an extra CA in every stage of the image under test (only this temp copy of the Dockerfile changes).
if [ -n "${E2E_DOCKER_CA:-}" ]; then
  [ -f "$E2E_DOCKER_CA" ] || fail "E2E_DOCKER_CA is not a file: $E2E_DOCKER_CA"
  cp "$E2E_DOCKER_CA" e2e-extra-ca.crt
  awk '{ print } /^FROM / { print "COPY e2e-extra-ca.crt /usr/local/share/ca-certificates/e2e-extra-ca.crt"; print "RUN update-ca-certificates 2>/dev/null || (mkdir -p /etc/ssl/certs && cat /usr/local/share/ca-certificates/e2e-extra-ca.crt >> /etc/ssl/certs/ca-certificates.crt)" }' Dockerfile >Dockerfile.new && mv Dockerfile.new Dockerfile
  echo "extra CA $E2E_DOCKER_CA trusted in the build"
fi

step "docker build"
# shellcheck disable=SC2086
docker build ${DOCKER_BUILD_ARGS:-} -t "$IMAGE" . || fail "docker build failed"

step "the image"
[ "$(docker run --rm --entrypoint id "$IMAGE" -u)" != 0 ] || fail "the image runs as root"
echo "ok: the container runs as a non-root user"

if [ "$TYPE" = web ]; then
  step "the production guards"
  # The session initializer (authentication) loads before the CSRF configuration, so it complains first.
  expect_boot_refused SESSION_SECRET
  expect_boot_refused CSRF_SECRET -e "SESSION_SECRET=$(secret)"
fi

step "run the container"
PORT="$(free_port)" || fail "no free port found"
docker run -d --name "$CONTAINER" -p "127.0.0.1:$PORT:$PORT" -e "PORT=$PORT" -e "CSRF_SECRET=$(secret)" -e "SESSION_SECRET=$(secret)" "$IMAGE" >/dev/null

tries=0
until curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$PORT/health"; do
  [ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER")" = true ] || fail "the container exited: $(docker logs "$CONTAINER" 2>&1 | grep -v '^  from' | tail -n 12)"
  tries=$((tries + 1))
  [ "$tries" -lt 60 ] || fail "the container is not ready after 60 tries"
  sleep 1
done

expect_get() {
  got="$(curl -s -o "$WORK/body" -w '%{http_code}' --max-time 10 "http://127.0.0.1:$PORT$1")"
  [ "$got" = "$2" ] || fail "GET $1 returned $got, expected $2"
  echo "ok: GET $1 -> $got"
}
expect_get /health 200
grep -q '"status":"ok"' "$WORK/body" || fail "/health body: $(cat "$WORK/body")"
[ "$TYPE" = web ] && { expect_get / 200; grep -q "Welcome to E2eApp" "$WORK/body" || fail "/ body lacks the welcome page"; }
expect_get /dev-dashboard 404

tries=0
until [ "$(docker inspect --format '{{.State.Health.Status}}' "$CONTAINER")" = healthy ]; do
  tries=$((tries + 1))
  [ "$tries" -lt 60 ] || fail "the container never became healthy: $(docker inspect --format '{{.State.Health.Status}}' "$CONTAINER")"
  sleep 1
done
echo "ok: the container reports healthy"

docker exec "$CONTAINER" touch /data/probe || fail "/data is not writable by the container user"
echo "ok: /data is writable"

step "PASS: the generated Dockerfile builds and the container serves"
