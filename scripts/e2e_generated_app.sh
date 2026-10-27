#!/bin/sh
# End-to-end gate for `azu new` and `azu generate scaffold`: generate a project with the built CLI,
# install its shards, compile it, boot it on a free port and check that it serves. A project on
# SQLite also gets a `Post` scaffold: `azu db:setup` creates its table and curl exercises the CRUD
# (web: forms with a CSRF token and a `_method` override, writes redirect with 303; api: JSON).
# A web project also gets a Chat channel (two WebSocket clients) and authentication (sign up, sign in,
# a protected page, sign out; the password is stored as a bcrypt digest).
#
# It also drives the CLI's own development commands against the project: `azu routes`, `azu openapi:export`, `azu doctor`, and
# `azu dev` (rebuild and restart on a source change, no rebuild for a template, a failed build keeps the old app).
#
# Usage: scripts/e2e_generated_app.sh [web|api]      (default: web)
# Env:   AZU_BIN  path to the azu binary to test     (default: <repo>/bin/azu)
#        E2E_DB   database adapter for `azu new`     (default: sqlite)
#        KEEP_TMP set to 1 to keep the temp dir for debugging
#        E2E_SKIP_DEV set to 1 to skip the `azu dev` check (two more compiles, a few minutes)
#        Secrets: CSRF_SECRET (web) always; SESSION_SECRET only once `azu generate auth` ran, which this script does for
#        web on SQLite (not for PostgreSQL, which only boots). The production checks run in a clean environment.
#        E2E_AZU_BRANCH  pin the generated project's azu dependency to this branch (e.g. master)
set -eu

# The secrets come from the generated .env, which the app loads at boot: do not let the caller's shell supply them.
unset CSRF_SECRET SESSION_SECRET DATABASE_URL
# The app runs in development, and .env.development turns the request monitor on: the caller's shell must not decide.
unset CRYSTAL_ENV PERFORMANCE_MONITORING

TYPE="${1:-web}"
DB="${E2E_DB:-sqlite}"
NAME="e2e_app"
MODULE="E2eApp"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AZU_BIN="${AZU_BIN:-$REPO_ROOT/bin/azu}"
READY_TRIES=60 # one second apart

# The scaffold needs a database that works without a server.
SCAFFOLD=0
[ "$DB" = sqlite ] && SCAFFOLD=1

command -v curl >/dev/null || { echo "curl is required" >&2; exit 2; }
if [ "$TYPE" = web ] && [ "$DB" = sqlite ]; then
  command -v sqlite3 >/dev/null || { echo "sqlite3 is required to check the stored password digest" >&2; exit 2; }
fi
[ -x "$AZU_BIN" ] || { echo "azu binary not found at $AZU_BIN (build it first or set AZU_BIN)" >&2; exit 2; }

WORK="$(mktemp -d)"
SERVER_PID=""
DEV_PID=""

cleanup() {
  status=$?
  if [ -n "$DEV_PID" ] && kill -0 "$DEV_PID" 2>/dev/null; then
    kill "$DEV_PID" 2>/dev/null || true
    wait "$DEV_PID" 2>/dev/null || true
  fi
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  if [ "$status" -ne 0 ] && [ -f "$WORK/server.log" ]; then
    echo "--- server log ---" >&2
    tail -n 40 "$WORK/server.log" >&2
  fi
  if [ "$status" -ne 0 ] && [ -f "$WORK/dev.log" ]; then
    echo "--- azu dev log ---" >&2
    tail -n 60 "$WORK/dev.log" >&2
  fi
  [ "${KEEP_TMP:-0}" = 1 ] && echo "kept $WORK" || rm -rf "$WORK"
  exit "$status"
}
trap cleanup EXIT INT TERM

# The octal mode of a file (GNU stat, then BSD stat).
file_mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

# A command that must finish: wrapped in timeout when the host has it.
bounded() { if command -v timeout >/dev/null; then timeout 20 "$@"; else "$@"; fi; }

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

# fetch PATH [JAR]: stores the body in $WORK/body, returns the HTTP status code. With JAR the
# cookies the server sets (the CSRF token) are saved there and sent back.
fetch() {
  curl -s -o "$WORK/body" -w '%{http_code}' --max-time 10 ${2:+-c "$2" -b "$2"} "http://127.0.0.1:$PORT$1"
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

expect_no_body() {
  ! grep -q -- "$1" "$WORK/body" || fail "response body contains '$1'"
  echo "ok: body does not contain '$1'"
}

# The CSRF token of the first form in the last response body.
csrf_token() {
  sed -n 's/.*name="_csrf" value="\([^"]*\)".*/\1/p' "$WORK/body" | head -n 1
}

# submit JAR PATH STATUS [form fields...]: POSTs a urlencoded form with the token of the last
# fetched page; the response headers go to $WORK/headers and its cookies into JAR.
submit() {
  jar="$1"; path="$2"; want="$3"; shift 3
  got="$(curl -s -o "$WORK/body" -D "$WORK/headers" -w '%{http_code}' --max-time 10 -b "$jar" -c "$jar" \
    --data-urlencode "_csrf=$(csrf_token)" "$@" "http://127.0.0.1:$PORT$path")"
  [ "$got" = "$want" ] || fail "POST $path returned $got, expected $want"
  echo "ok: POST $path -> $got"
}

expect_redirect() {
  tr -d '\r' <"$WORK/headers" | grep -qi "^location: $1\$" || fail "not redirected to $1"
  echo "ok: redirected to $1"
}

# api_request METHOD PATH STATUS [JSON]: sends the request, stores the body in $WORK/body.
api_request() {
  method="$1"; path="$2"; want="$3"; json="${4:-}"
  got="$(curl -s -o "$WORK/body" -w '%{http_code}' --max-time 10 -X "$method" \
    ${json:+-H 'Content-Type: application/json' -d "$json"} "http://127.0.0.1:$PORT$path")"
  [ "$got" = "$want" ] || fail "$method $path returned $got, expected $want"
  echo "ok: $method $path -> $got"
}

# The Post scaffold of an API project: JSON in and out.
check_api_scaffold() {
  api_request GET /posts 200
  expect_body '^\[\]$'
  api_request POST /posts 422 '{"title":"","body":""}'
  api_request POST /posts 201 '{"title":"Hello","body":"First post","published":true}'
  expect_body '"title":"Hello"'
  api_request GET /posts/1 200
  expect_body '"body":"First post"'
  api_request PATCH /posts/1 200 '{"title":"Updated","body":"Edited"}'
  expect_body '"title":"Updated"'
  expect_body '"published":true' # a PATCH without published keeps it
  api_request PATCH /posts/1 422 '{"title":""}'
  api_request GET /posts 200
  expect_body '"title":"Updated"'
  api_request DELETE /posts/1 204
  api_request GET /posts/1 404
}

# The Post scaffold of a web project: list, form, create, show, edit, update, delete. Every form is
# fetched with a fresh cookie jar because the CSRF cookie is scoped to the page that set it.
check_web_scaffold() {
  jar="$WORK/jar"
  expect_status /posts 200
  expect_status /posts/new 200
  expect_body '<form action="/posts" method="post"'
  expect_body 'name="title"'
  expect_no_body '_method'

  got="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 --data-urlencode title=x --data-urlencode body=y "http://127.0.0.1:$PORT/posts")"
  [ "$got" = 403 ] || fail "POST /posts without a CSRF token returned $got, expected 403"
  echo "ok: POST /posts without a CSRF token -> 403"

  fetch /posts/new "$jar" >/dev/null
  submit "$jar" /posts 422 --data-urlencode title= --data-urlencode body=

  fetch /posts/new "$jar" >/dev/null
  submit "$jar" /posts 303 --data-urlencode "title=Hello <e2e>" --data-urlencode "body=First post" --data-urlencode published=false --data-urlencode published=true
  expect_redirect /posts/1
  expect_status /posts/1 200
  expect_body 'Hello &lt;e2e&gt;'
  expect_body 'First post'
  expect_body '<dd>true</dd>'
  expect_status /posts 200
  expect_body 'href="/posts/1"'

  rm -f "$jar"
  [ "$(fetch /posts/1/edit "$jar")" = 200 ] || fail "GET /posts/1/edit did not return 200"
  expect_body 'name="_method" value="patch"'
  expect_body 'First post</textarea>'
  submit "$jar" /posts/1 422 --data-urlencode _method=patch --data-urlencode "title="
  fetch /posts/1/edit "$jar" >/dev/null
  submit "$jar" /posts/1 303 --data-urlencode _method=patch --data-urlencode "title=Updated title" --data-urlencode "body=Edited"
  expect_redirect /posts/1
  expect_status /posts/1 200
  expect_body 'Updated title'
  expect_body '<dd>true</dd>' # a PATCH without published keeps it

  rm -f "$jar"
  fetch /posts/1/edit "$jar" >/dev/null
  submit "$jar" /posts/1 303 --data-urlencode _method=patch --data-urlencode published=false
  expect_status /posts/1 200
  expect_body '<dd>false</dd>'
  expect_body 'Updated title'

  rm -f "$jar"
  fetch /posts/1 "$jar" >/dev/null
  submit "$jar" /posts/1 303 --data-urlencode _method=delete
  expect_redirect /posts
  expect_status /posts/1 404
  expect_status /posts 200
}

# The Chat channel: two WebSocket clients, a message of one reaches both (the generated channel
# broadcasts every message to the topic its clients subscribe to).
check_channel() {
  cat >"$WORK/ws_check.cr" <<'CRYSTAL'
require "http/web_socket"

port, path = ARGV
uri = URI.parse("ws://127.0.0.1:#{port}#{path}")
inbox = {a: Channel(String).new(4), b: Channel(String).new(4)}
first = HTTP::WebSocket.new(uri)
second = HTTP::WebSocket.new(uri)
first.on_message { |message| inbox[:a].send(message) }
second.on_message { |message| inbox[:b].send(message) }
spawn { first.run }
spawn { second.run }
# A message sent before the server has registered both sockets would be missed: retry a probe until
# both clients see it, then run the real check.
probe = "probe"
connected = false
20.times do
  first.send(probe)
  got = [] of Symbol
  {a: inbox[:a], b: inbox[:b]}.each do |name, channel|
    select
    when message = channel.receive
      got << name if message == probe
    when timeout(250.milliseconds)
    end
  end
  if got.size == 2
    connected = true
    break
  end
end
abort "the clients never saw each other's messages" unless connected

first.send("hello e2e")
{a: inbox[:a], b: inbox[:b]}.each do |name, channel|
  waits = 0
  loop do
    select
    when message = channel.receive
      next if message == probe # a late echo of the connection probe
      abort "client #{name} got #{message.inspect}, expected \"hello e2e\"" unless message == "hello e2e"
      break
    when timeout(1.second)
      waits += 1
      abort "client #{name} received nothing within 5s" if waits >= 5
    end
  end
end
puts "both clients received hello e2e"
CRYSTAL
  out="$(crystal run "$WORK/ws_check.cr" -- "$PORT" /chat 2>&1)" || fail "WebSocket /chat: $out"
  echo "ok: $out"

  # A page on another origin must not be able to open the socket (cross-site WebSocket hijacking).
  got="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
    -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' -H 'Origin: http://evil.example' "http://127.0.0.1:$PORT/chat")"
  [ "$got" != 101 ] || fail "WebSocket /chat accepted an upgrade from Origin http://evil.example"
  echo "ok: WebSocket /chat refuses a foreign Origin ($got)"
}

# The generated authentication: sign up, sign in, a protected page, sign out; passwords are hashed.
check_auth() {
  jar="$WORK/auth.jar"
  base="http://127.0.0.1:$PORT"

  got="$(curl -s -o /dev/null -D "$WORK/headers" -w '%{http_code}' --max-time 10 "$base/account")"
  [ "$got" = 303 ] || fail "GET /account signed out returned $got, expected 303"
  expect_redirect /login

  # A form without the CSRF token is refused before it reaches the endpoint.
  for path in /register /login; do
    got="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 --data-urlencode email=x@example.com --data-urlencode password=whatever-pass "$base$path")"
    [ "$got" = 403 ] || fail "POST $path without a CSRF token returned $got, expected 403"
    echo "ok: POST $path without a CSRF token -> 403"
  done

  rm -f "$jar"
  [ "$(fetch /register "$jar")" = 200 ] || fail "GET /register did not return 200"
  expect_body 'name="email"'
  expect_body 'name="password"'
  submit "$jar" /register 422 --data-urlencode email=nobody --data-urlencode password=short
  # bcrypt refuses more than 72 bytes: the contracts must answer 422, not crash.
  long_ascii="$(printf 'a%.0s' $(seq 1 100))"
  four_byte="$(printf '\360\237\230\200%.0s' $(seq 1 30))" # 30 characters, 120 bytes
  fetch /register "$jar" >/dev/null
  submit "$jar" /register 422 --data-urlencode email=long@example.com --data-urlencode "password=$long_ascii"
  fetch /register "$jar" >/dev/null
  submit "$jar" /register 422 --data-urlencode email=long@example.com --data-urlencode "password=$four_byte"
  fetch /login "$jar" >/dev/null
  submit "$jar" /login 422 --data-urlencode email=long@example.com --data-urlencode "password=$long_ascii"
  fetch /login "$jar" >/dev/null
  submit "$jar" /login 422 --data-urlencode email=long@example.com --data-urlencode "password=$four_byte"
  fetch /register "$jar" >/dev/null
  submit "$jar" /register 303 --data-urlencode "email=Dev@Example.com" --data-urlencode "password=correct horse"
  expect_redirect /login
  digest="$(sqlite3 "db/${NAME}_development.db" 'select password_digest from users')"
  case "$digest" in '$2'*) echo "ok: the password is stored as a bcrypt digest" ;; *) fail "password_digest is not a bcrypt digest: $digest" ;; esac
  case "$digest" in *"correct horse"*) fail "the password is stored in plain text" ;; esac
  fetch /register "$jar" >/dev/null
  submit "$jar" /register 303 --data-urlencode "email=dev@example.com" --data-urlencode "password=another pass"
  expect_redirect /register
  [ "$(sqlite3 "db/${NAME}_development.db" 'select count(*) from users')" = 1 ] || fail "a second user was created for the same email"

  rm -f "$jar"
  fetch /login "$jar" >/dev/null
  submit "$jar" /login 303 --data-urlencode email=dev@example.com --data-urlencode "password=wrong password"
  expect_redirect /login
  [ "$(fetch /login "$jar")" = 200 ] || fail "GET /login did not return 200"
  expect_body 'Invalid email or password'
  expect_status /account 303

  fetch /login "$jar" >/dev/null
  submit "$jar" /login 303 --data-urlencode email=Dev@Example.com --data-urlencode "password=correct horse"
  expect_redirect /account
  cookie="$(tr -d '\r' <"$WORK/headers" | grep -i '^set-cookie: e2e_app_session=' | head -n 1)"
  [ -n "$cookie" ] || fail "sign in did not set the session cookie"
  for flag in HttpOnly SameSite=Strict Secure; do
    printf '%s' "$cookie" | grep -qi "$flag" || fail "the session cookie lacks $flag: $cookie"
  done
  echo "ok: the session cookie is HttpOnly, Secure and SameSite=Strict"
  [ "$(fetch /account "$jar")" = 200 ] || fail "GET /account signed in did not return 200"
  expect_body 'dev@example.com'
  expect_body 'name="_method" value="delete"'

  submit "$jar" /logout 303 --data-urlencode _method=delete
  expect_redirect /login
  got="$(curl -s -o /dev/null -b "$jar" -D "$WORK/headers" -w '%{http_code}' --max-time 10 "$base/account")"
  [ "$got" = 303 ] || fail "GET /account after sign out returned $got, expected 303"
  expect_redirect /login
}

# `azu routes`: the routes of the app, as a table and as JSON, filtered, with the exit codes it documents.
check_routes() {
  "$AZU_BIN" routes >"$WORK/routes.txt" || fail "azu routes failed"
  for expected in "GET *\/health  *$MODULE::Health::HealthEndpoint  *$MODULE::Health::HealthRequest  *$MODULE::Health::HealthPage  *link_to_get_health_health" \
    "GET  *\/ .*$MODULE::Welcome::IndexEndpoint"; do
    [ "$TYPE" = api ] && [ "${expected#*Welcome}" != "$expected" ] && continue
    grep -q -- "$expected" "$WORK/routes.txt" || { cat "$WORK/routes.txt" >&2; fail "azu routes does not list: $expected"; }
  done
  grep -q '^METHOD  *PATH  *ENDPOINT  *REQUEST  *RESPONSE  *HELPERS' "$WORK/routes.txt" || fail "azu routes has no header row"
  ! grep -q '^OPTIONS\|^HEAD' "$WORK/routes.txt" || fail "azu routes shows the implicit HEAD/OPTIONS routes"
  echo "ok: azu routes lists the health endpoint with its types and helpers"

  "$AZU_BIN" routes --format json >"$WORK/routes.json" || fail "azu routes --format json failed"
  [ "$(head -c 1 "$WORK/routes.json")" = "[" ] || fail "azu routes --format json prints something besides JSON: $(head -n 1 "$WORK/routes.json")"
  grep -q "\"endpoint\": \"$MODULE::Health::HealthEndpoint\"" "$WORK/routes.json" || fail "routes JSON lacks the health endpoint"
  echo "ok: azu routes --format json is JSON only"

  if [ "$SCAFFOLD" = 1 ]; then
    "$AZU_BIN" routes --method POST --path /posts >"$WORK/routes.txt" || fail "azu routes --method POST failed"
    grep -q "POST  *\/posts  *$MODULE::Posts::CreateEndpoint" "$WORK/routes.txt" || fail "azu routes --method POST --path /posts lacks the create endpoint"
    ! grep -q "GET\|DELETE" "$WORK/routes.txt" || fail "azu routes --method POST lists other methods"
    "$AZU_BIN" routes --method DELETE >"$WORK/routes.txt" || fail "azu routes --method DELETE failed"
    grep -q "button_to_delete_posts_destroy" "$WORK/routes.txt" || fail "the delete route lists no button_to_delete helper"
    echo "ok: azu routes --method/--path filter"
  fi

  code=0
  "$AZU_BIN" routes --format xml >/dev/null 2>&1 || code=$?
  [ "$code" = 2 ] || fail "azu routes --format xml exited $code, expected 2"
  echo "ok: azu routes rejects an unknown format with exit 2"
}

# `azu openapi:export`: the document Azu::OpenAPI builds from the compiled app, as JSON and as YAML.
check_openapi() {
  "$AZU_BIN" openapi:export --output "$WORK/openapi.json" || fail "azu openapi:export failed"
  grep -q '"openapi": "3.1.0"' "$WORK/openapi.json" || fail "openapi.json is not an OpenAPI 3.1 document"
  grep -q "\"operationId\": \"$MODULE.Health.HealthEndpoint\"" "$WORK/openapi.json" || fail "openapi.json lacks the health endpoint"
  if [ "$SCAFFOLD" = 1 ]; then
    grep -q '"/posts/{id}"' "$WORK/openapi.json" || fail "openapi.json lacks /posts/{id} (path parameters must be {id}, not :id)"
    grep -q "\"operationId\": \"$MODULE.Posts.CreateEndpoint\"" "$WORK/openapi.json" || fail "openapi.json lacks the create endpoint"
  fi
  echo "ok: azu openapi:export writes the app's OpenAPI document as JSON"

  "$AZU_BIN" openapi:export --output "$WORK/openapi.yaml" --project "E2E API" --version 9.9.9 || fail "azu openapi:export (yaml) failed"
  grep -Eq '^openapi: "?3\.1\.0' "$WORK/openapi.yaml" || fail "openapi.yaml is not an OpenAPI 3.1 document"
  grep -q 'title: E2E API' "$WORK/openapi.yaml" || fail "openapi.yaml lacks the --project title"
  echo "ok: azu openapi:export writes YAML with the given title"

  code=0
  "$AZU_BIN" openapi:export --format xml >/dev/null 2>&1 || code=$?
  [ "$code" = 2 ] || fail "azu openapi:export --format xml exited $code, expected 2"
  echo "ok: azu openapi:export rejects an unknown format with exit 2"
}

# doctor_status ID: the status of a check in $WORK/doctor.json (the JSON puts the id before the status).
doctor_status() {
  grep -A1 "\"id\": \"$1\"" "$WORK/doctor.json" | sed -n 's/.*"status": "\([a-z]*\)".*/\1/p'
}

expect_doctor() {
  got="$(doctor_status "$1")"
  [ "$got" = "$2" ] || { cat "$WORK/doctor.json" >&2; fail "azu doctor: $1 is '$got', expected '$2'"; }
  echo "ok: azu doctor $1 -> $2"
}

# `azu doctor`: a fresh project has no failing check; the port is free before the server runs and taken after.
check_doctor() {
  # A fresh project has no failing check. The PostgreSQL and MySQL variants only boot (no database server runs), so
  # there exactly the database check fails and every other check is ok.
  code=0
  "$AZU_BIN" doctor >"$WORK/doctor.txt" || code=$?
  grep -q '^ok  *crystal' "$WORK/doctor.txt" || { cat "$WORK/doctor.txt" >&2; fail "azu doctor: crystal is not ok"; }
  grep -q 'failures$' "$WORK/doctor.txt" || fail "azu doctor prints no summary"
  case "$DB" in
    sqlite) [ "$code" = 0 ] || { cat "$WORK/doctor.txt" >&2; fail "azu doctor failed on a fresh project (exit $code)"; } ;;
    *)
      [ "$code" = 1 ] || { cat "$WORK/doctor.txt" >&2; fail "azu doctor exited $code without a database server, expected 1"; }
      [ "$(grep -c '^fail ' "$WORK/doctor.txt")" = 1 ] && grep -q '^fail  *database' "$WORK/doctor.txt" ||
        { cat "$WORK/doctor.txt" >&2; fail "azu doctor: expected exactly the database check to fail"; }
      ;;
  esac
  echo "ok: azu doctor on a fresh project ($DB)"

  code=0
  PORT="$1" "$AZU_BIN" doctor --json >"$WORK/doctor.json" || code=$?
  [ "$code" = 0 ] || [ "$DB" != sqlite ] || fail "azu doctor --json failed"
  [ "$(head -c 1 "$WORK/doctor.json")" = "{" ] || fail "azu doctor --json prints something besides JSON"
  for id in crystal shards dependencies database env secrets port docker gitignore; do
    grep -q "\"id\": \"$id\"" "$WORK/doctor.json" || fail "azu doctor --json lacks the $id check"
  done
  expect_doctor crystal ok
  expect_doctor dependencies ok
  expect_doctor port "$2"
  if [ "$DB" = sqlite ]; then
    expect_doctor database ok
  else
    expect_doctor database fail
    for id in crystal shards dependencies env secrets port gitignore; do
      [ "$(doctor_status "$id")" != fail ] || fail "azu doctor: $id failed besides the database"
    done
  fi

  code=0
  PORT=not-a-port "$AZU_BIN" doctor >/dev/null 2>&1 || code=$?
  [ "$code" = 1 ] || fail "azu doctor with an invalid PORT exited $code, expected 1"
  code=0
  "$AZU_BIN" doctor --fix >/dev/null 2>&1 || code=$?
  [ "$code" = 2 ] || fail "azu doctor --fix exited $code, expected 2"
  echo "ok: azu doctor exits 1 on a failing check and 2 on an unknown option"
}

# Sign-in is limited to 5 attempts per address and email (429 with Retry-After on the 6th, another email is
# unaffected), sign-up to 5 per address. The server runs with a long window so the check cannot straddle one.
check_throttle() {
  jar="$WORK/throttle.jar"
  rm -f "$jar"
  for attempt in 1 2 3 4 5; do
    fetch /login "$jar" >/dev/null
    submit "$jar" /login 303 --data-urlencode email=victim@example.com --data-urlencode "password=wrong password $attempt"
  done
  fetch /login "$jar" >/dev/null
  submit "$jar" /login 429 --data-urlencode email=victim@example.com --data-urlencode "password=wrong password 6"
  retry="$(tr -d '\r' <"$WORK/headers" | sed -n 's/^[Rr]etry-[Aa]fter: *//p')"
  case "$retry" in ''|*[!0-9]*) fail "the 429 has no numeric Retry-After header: '$retry'" ;; esac
  [ "$retry" -ge 1 ] && [ "$retry" -le 300 ] || fail "Retry-After is $retry, expected 1..300"
  echo "ok: the 6th sign-in attempt is refused with 429, Retry-After: $retry"

  fetch /login "$jar" >/dev/null
  submit "$jar" /login 303 --data-urlencode email=bystander@example.com --data-urlencode "password=wrong password"
  echo "ok: another account is not throttled"

  # Two sign-ups from the dev account steps above are already counted: three more are allowed, the next is refused.
  for n in 1 2 3; do
    fetch /register "$jar" >/dev/null
    submit "$jar" /register 303 --data-urlencode "email=throttle$n@example.com" --data-urlencode "password=correct horse"
  done
  fetch /register "$jar" >/dev/null
  submit "$jar" /register 429 --data-urlencode "email=throttle4@example.com" --data-urlencode "password=correct horse"
  [ "$(sqlite3 "db/${NAME}_development.db" "select count(*) from users where email = 'throttle4@example.com'")" = 0 ] || fail "a throttled sign-up created a user"
  echo "ok: the 6th sign-up attempt is refused with 429 and creates nothing"
}

# `azu dev`: builds and runs the app; a source change rebuilds and restarts it; a template change does neither; a
# broken source keeps the old app serving; SIGTERM stops the app too.
check_dev() {
  dev_port="$(free_port)" || fail "no free port found"
  PORT="$dev_port" HOST=127.0.0.1 "$AZU_BIN" dev --port "$dev_port" --debounce 300 --interval 200 >"$WORK/dev.log" 2>&1 &
  DEV_PID=$!
  dev_fetch() { curl -s -o "$WORK/dev_body" -w '%{http_code}' --max-time 5 "http://127.0.0.1:$dev_port$1" || true; }
  wait_until() { # wait_until SECONDS DESCRIPTION COMMAND...
    limit="$1"; what="$2"; shift 2
    waited=0
    until "$@" >/dev/null 2>&1; do
      kill -0 "$DEV_PID" 2>/dev/null || fail "azu dev exited while waiting for $what"
      waited=$((waited + 1))
      [ "$waited" -lt "$limit" ] || fail "timed out waiting for $what"
      sleep 1
    done
  }
  dev_body_has() { [ "$(dev_fetch /health)" = 200 ] && grep -q -- "$1" "$WORK/dev_body"; }
  log_has() { grep -q -- "$1" "$WORK/dev.log"; }
  builds() { grep -c 'Built in' "$WORK/dev.log" || true; }

  wait_until 400 "the first build and start" dev_body_has '"status":"ok"'
  echo "ok: azu dev built and started the app"
  [ "$(builds)" = 1 ] || fail "expected one build, saw $(builds)"

  if [ -f public/templates/layout.jinja ]; then
    printf '\n{# touched by the e2e #}\n' >>public/templates/layout.jinja
    wait_until 30 "the template change to be noticed" log_has 'public/templates/layout.jinja'
    sleep 2
    [ "$(builds)" = 1 ] || fail "a template change started a build"
    grep -q 'Changed: public/templates/layout.jinja.*no rebuild' "$WORK/dev.log" || fail "azu dev did not say that a template change needs no rebuild"
    echo "ok: a template change does not rebuild"
  fi

  endpoint=src/endpoints/health/health_endpoint.cr
  cp "$endpoint" "$WORK/health_endpoint.cr.orig"
  printf '\nthis is not crystal (\n' >>"$endpoint"
  wait_until 300 "the failed build" log_has 'Build failed'
  [ "$(dev_fetch /health)" = 200 ] || fail "the app stopped serving after a failed build"
  grep -q '"status":"ok"' "$WORK/dev_body" || fail "the app serves something else after a failed build"
  log_has 'previous build keeps running' || fail "azu dev did not say it keeps the previous build running"
  echo "ok: a failed build keeps the old app serving"

  sed 's/status: "ok"/status: "ok-rebuilt"/' "$WORK/health_endpoint.cr.orig" >"$endpoint"
  wait_until 300 "the rebuilt app" dev_body_has '"status":"ok-rebuilt"'
  [ "$(builds)" = 2 ] || fail "expected two successful builds, saw $(builds)"
  echo "ok: a source change rebuilds and restarts the app"

  kill -TERM "$DEV_PID"
  wait "$DEV_PID" 2>/dev/null || true
  DEV_PID=""
  code=0
  curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$dev_port/health" || code=$?
  [ "$code" = 7 ] || fail "the app still answers after azu dev was stopped (curl exit $code)"
  echo "ok: SIGTERM stops azu dev and the app"
}

step "generate a $TYPE project ($DB) with $AZU_BIN"
cd "$WORK"
"$AZU_BIN" new "$NAME" --yes --author "E2E" --email e2e@example.com \
  --type "$TYPE" --db "$DB" --no-git --no-docker --ci "GitHub Actions" >"$WORK/new.log" 2>&1 ||
  { cat "$WORK/new.log"; fail "azu new failed"; }
cat "$WORK/new.log"
cd "$NAME"

step "the next steps name the port the app listens on"
env_port="$(sed -n 's/^PORT=//p' .env)"
[ -n "$env_port" ] || fail ".env sets no PORT"
grep -q "http://localhost:$env_port" "$WORK/new.log" || fail "azu new does not point at the PORT of .env ($env_port)"
! grep -q "localhost:3000" "$WORK/new.log" || fail "azu new still points at port 3000"

if [ "$DB" = sqlite ]; then
  step "azu db:migrate right after azu new (no database file, no migration yet)"
  "$AZU_BIN" db:migrate || fail "azu db:migrate fails on a fresh project"
  ls db/*_development.db >/dev/null 2>&1 || fail "azu db:migrate did not create the SQLite database file"
fi

step "the generated .env lists the secrets, .env.example and the per-environment files exist"
if [ "$TYPE" = web ]; then
  grep -Eq '^CSRF_SECRET=[0-9a-f]{64}$' .env || fail ".env has no random CSRF_SECRET"
fi
[ "$(file_mode .env)" = 600 ] || fail ".env is not mode 600"
[ -f .env.example ] && [ -f .env.development ] && [ -f .env.test ] || fail ".env.example / .env.development / .env.test missing"
git check-ignore -q .env 2>/dev/null || grep -qx '/.env' .gitignore || fail ".env is not git-ignored"
! grep -Eq '[0-9a-f]{64}' .env.example || fail ".env.example holds a secret"

# Opt-in: test against a branch of azu instead of the release the generated shard.yml requires (its version
# constraint is dropped for the branch).
if [ -n "${E2E_AZU_BRANCH:-}" ]; then
  awk -v ref="$E2E_AZU_BRANCH" '/^    github: azutoolkit\/azu$/ { print; print "    branch: " ref; skip = 1; next } skip && /^    version:/ { skip = 0; next } { skip = 0; print }' shard.yml >shard.yml.new && mv shard.yml.new shard.yml
  grep -q "branch: $E2E_AZU_BRANCH" shard.yml || fail "could not pin azu to $E2E_AZU_BRANCH in shard.yml"
  echo "azu pinned to branch $E2E_AZU_BRANCH"
fi

if [ "$SCAFFOLD" = 1 ]; then
  step "generate a Post scaffold"
  "$AZU_BIN" generate scaffold Post title:string body:text published:bool
fi

if [ "$SCAFFOLD" = 1 ] && [ "$TYPE" = web ]; then
  step "generate a Chat channel and authentication"
  "$AZU_BIN" generate channel Chat
  "$AZU_BIN" generate auth
fi

step "shards install"
shards install

if [ "$SCAFFOLD" = 1 ]; then
  step "create and migrate the database (azu db:setup)"
  "$AZU_BIN" db:setup
fi

ENTRY=src/server.cr
[ "$TYPE" = api ] && ENTRY=src/api.cr
step "compile $ENTRY"
mkdir -p bin
crystal build "$ENTRY" -o "bin/$NAME"

step "azu routes"
check_routes

step "azu openapi:export"
check_openapi

# The generated CI workflow must pass on a fresh project: run the commands it runs (the Crystal
# version is the one this script runs with, the workflow pins another).
step "run the generated workflow's checks (format, specs)"
for command in "crystal tool format --check src spec" "crystal spec"; do
  grep -q "run: $command" .github/workflows/ci.yml || fail ".github/workflows/ci.yml does not run '$command'"
  sh -c "$command" || fail "'$command' failed on the generated project"
  echo "ok: $command"
done

# Starts the server from the project directory (it loads .env there) and waits until /health answers.
start_server() {
  # A long throttle window, so the sign-in/sign-up limits cannot be reset in the middle of check_throttle.
  AUTH_THROTTLE_WINDOW=300 HOST=127.0.0.1 PORT="$PORT" "./bin/$NAME" >"$WORK/server.log" 2>&1 &
  SERVER_PID=$!
  tries=0
  until curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$PORT/health"; do
    kill -0 "$SERVER_PID" 2>/dev/null || fail "server exited before becoming ready"
    tries=$((tries + 1))
    [ "$tries" -lt "$READY_TRIES" ] || fail "server not ready after $READY_TRIES tries"
    sleep 1
  done
}

stop_server() {
  kill "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" 2>/dev/null || true
  SERVER_PID=""
}

step "start the server (no secrets exported: it loads .env)"
PORT="$(free_port)" || fail "no free port found"
echo "port $PORT"
step "azu doctor (before the server runs)"
check_doctor "$PORT" ok
start_server

step "check responses"
expect_status /health 200
expect_body '"status":"ok"'
if [ "$TYPE" = web ]; then
  expect_status / 200
  expect_body "Welcome to $MODULE"
  expect_body "Typed contracts"
  expect_status /assets/app.css 200
  # A file that is not in public/ falls through Static to the router: azu's negotiated 404, not the bare
  # text/plain "404 Not Found" of the stdlib handler (what a Static used as a route target answers).
  expect_status /missing.css 404
  ! grep -qx '404 Not Found' "$WORK/body" || fail "GET /missing.css answered the stdlib 404, not azu's"
  expect_body 'missing.css'
  # The Jinja sources under public/templates are not static files: they answer azu's 404, whatever the spelling.
  tmpl="$(find public/templates -name '*.jinja' | head -n 1)"
  [ -n "$tmpl" ] || fail "the generated project has no .jinja template to probe"
  tmpl_url="/${tmpl#public/}"
  for probe in "$tmpl_url" "$(printf %s "$tmpl_url" | sed 's|/templates|/Templates|')" "/assets/..$tmpl_url" "/%74emplates${tmpl_url#/templates}" "//${tmpl_url#/}"; do
    got="$(curl -s --path-as-is -o "$WORK/body" -w '%{http_code}' --max-time 10 "http://127.0.0.1:$PORT$probe")"
    [ "$got" = 404 ] || fail "GET $probe returned $got, expected 404 (template source exposed)"
    ! grep -q -e '{%' -e '{{' "$WORK/body" || fail "GET $probe answered with template source"
    echo "ok: GET $probe -> 404"
  done
  expect_status /assets/app.css 200
fi
# Every response carries the security headers; HSTS only over TLS (this server is plain http).
curl -s -o /dev/null -D "$WORK/headers" --max-time 10 "http://127.0.0.1:$PORT/health"
grep -qi '^x-content-type-options: nosniff' "$WORK/headers" || fail "GET /health lacks X-Content-Type-Options: nosniff"
! grep -qi '^strict-transport-security' "$WORK/headers" || fail "HSTS sent over plain http"
echo "ok: security headers present, no HSTS over http"

# The server runs in development (CRYSTAL_ENV is unset above), where .env.development turns on PERFORMANCE_MONITORING:
# the dashboard reads the monitor the app mounts, so the requests above show up on it.
step "the development dashboard shows the requests"
for _ in 1 2 3; do expect_status /health 200; done
expect_status /dev-dashboard 200
grep -Eq '[1-9][0-9,]* requests' "$WORK/body" || fail "GET /dev-dashboard counts no request: the monitor that records them is not the one it reads"
! grep -q 'No requests recorded yet' "$WORK/body" || fail "GET /dev-dashboard says no request was recorded"
! grep -q 'has no performance monitor' "$WORK/server.log" || fail "DevDashboard warned that no performance monitor feeds it"
echo "ok: /dev-dashboard lists the requests"

if [ "$SCAFFOLD" = 1 ]; then
  step "check the Post scaffold"
  if [ "$TYPE" = web ]; then check_web_scaffold; else check_api_scaffold; fi
fi

if [ "$SCAFFOLD" = 1 ] && [ "$TYPE" = web ]; then
  step "check the Chat channel"
  check_channel
  step "check authentication"
  check_auth
  step "check sign-in and sign-up throttling"
  check_throttle
fi

step "azu doctor (the port is taken by the running server)"
code=0
PORT="$PORT" "$AZU_BIN" doctor --json >"$WORK/doctor.json" || code=$?
[ "$code" = 0 ] || [ "$DB" != sqlite ] || fail "azu doctor --json failed while the server runs"
expect_doctor port warn

kill -0 "$SERVER_PID" 2>/dev/null || fail "server died while serving requests"

# The CSRF key comes from .env, so a token issued before a restart is still accepted afterwards. A random
# per-process key would answer 403 here.
if [ "$TYPE" = web ] && [ "$SCAFFOLD" = 1 ]; then
  step "the CSRF key survives a restart (it comes from .env)"
  jar="$WORK/jar_restart"
  fetch /posts/new "$jar" >/dev/null
  stop_server
  start_server
  submit "$jar" /posts 422 --data-urlencode title= --data-urlencode body=
fi

# Production reads the environment, not a file lying around: from a directory without .env the app refuses to
# boot, and each secret is required on its own (which one is reported first depends on initialization order, so
# boot with all but one set and expect that one to be named).
if [ "$TYPE" = web ]; then
  step "production refuses to boot without its secrets"
  APP_DIR="$(pwd)"
  mkdir -p "$WORK/bare"
  secret_value="0123456789abcdef0123456789abcdef"
  # A clean environment: whatever the caller or the CI job exports cannot mask a missing guard or add a secret.
  production_boot() {
    code=0
    (cd "$WORK/bare" && bounded env -u SESSION_SECRET -u CSRF_SECRET -u DATABASE_URL "$@" CRYSTAL_ENV=production PORT="$(free_port)" "$APP_DIR/bin/$NAME" >"$WORK/production.log" 2>&1) || code=$?
  }
  production_boot
  [ "$code" -ne 0 ] || fail "production booted without any secret"
  echo "ok: production without secrets exits with status $code"
  expect_missing() {
    missing="$1"; shift
    production_boot "$@"
    [ "$code" -ne 0 ] || fail "production booted without $missing"
    grep -q "$missing is not set" "$WORK/production.log" || fail "production did not say $missing is not set: $(grep -v ' INFO \| WARN \|^  from' "$WORK/production.log" | head -n 4)"
    echo "ok: production without $missing exits with '$missing is not set'"
  }
  # SESSION_SECRET is required only by the authentication initializer, which is generated with the scaffold
  # (SQLite); without it a web app boots in production with CSRF_SECRET alone, as it should.
  if [ "$SCAFFOLD" = 1 ]; then
    expect_missing SESSION_SECRET CSRF_SECRET="$secret_value"
    expect_missing CSRF_SECRET SESSION_SECRET="$secret_value"
  else
    expect_missing CSRF_SECRET
    # Without authentication CSRF_SECRET alone is enough: the app boots (until `timeout` stops it: 124/137/143).
    production_boot CSRF_SECRET="$secret_value"
    case "$code" in 124 | 137 | 143) ;; *) fail "production with only CSRF_SECRET did not boot (status $code): $(head -n 3 "$WORK/production.log")" ;; esac
    ! grep -q "is not set" "$WORK/production.log" || fail "production with only CSRF_SECRET asked for another secret"
    echo "ok: production boots with CSRF_SECRET alone when authentication is not generated"
  fi
fi

if [ "$SCAFFOLD" = 1 ] && [ "${E2E_SKIP_DEV:-0}" != 1 ]; then
  step "stop the server, then check azu dev"
  kill "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" 2>/dev/null || true
  SERVER_PID=""
  check_dev
fi

step "PASS: generated $TYPE app compiles, boots and serves"
