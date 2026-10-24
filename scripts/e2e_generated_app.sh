#!/bin/sh
# End-to-end gate for `azu new` and `azu generate scaffold`: generate a project with the built CLI,
# install its shards, compile it, boot it on a free port and check that it serves. A project on
# SQLite also gets a `Post` scaffold: `azu db:setup` creates its table and curl exercises the CRUD
# (web: forms with a CSRF token and a `_method` override, writes redirect with 303; api: JSON).
# A web project also gets a Chat channel (two WebSocket clients) and authentication (sign up, sign in,
# a protected page, sign out; the password is stored as a bcrypt digest).
#
# Usage: scripts/e2e_generated_app.sh [web|api]      (default: web)
# Env:   AZU_BIN  path to the azu binary to test     (default: <repo>/bin/azu)
#        E2E_DB   database adapter for `azu new`     (default: sqlite)
#        KEEP_TMP set to 1 to keep the temp dir for debugging
#        E2E_AZU_BRANCH  pin the generated project's azu dependency to this branch (e.g. master)
set -eu

# The secrets come from the generated .env, which the app loads at boot: do not let the caller's shell supply them.
unset CSRF_SECRET SESSION_SECRET DATABASE_URL

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

step "generate a $TYPE project ($DB) with $AZU_BIN"
cd "$WORK"
"$AZU_BIN" new "$NAME" --yes --author "E2E" --email e2e@example.com \
  --type "$TYPE" --db "$DB" --no-git --no-docker --ci "GitHub Actions"
cd "$NAME"

step "the generated .env lists the secrets, .env.example and the per-environment files exist"
if [ "$TYPE" = web ]; then
  grep -Eq '^CSRF_SECRET=[0-9a-f]{64}$' .env || fail ".env has no random CSRF_SECRET"
fi
[ "$(stat -c %a .env)" = 600 ] || fail ".env is not mode 600"
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
shards install --ignore-crystal-version

if [ "$SCAFFOLD" = 1 ]; then
  step "create and migrate the database (azu db:setup)"
  "$AZU_BIN" db:setup
fi

ENTRY=src/server.cr
[ "$TYPE" = api ] && ENTRY=src/api.cr
step "compile $ENTRY"
mkdir -p bin
crystal build "$ENTRY" -o "bin/$NAME"

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
  HOST=127.0.0.1 PORT="$PORT" "./bin/$NAME" >"$WORK/server.log" 2>&1 &
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
start_server

step "check responses"
expect_status /health 200
expect_body '"status":"ok"'
if [ "$TYPE" = web ]; then
  expect_status / 200
  expect_body "Welcome to $MODULE"
  expect_body "Typed contracts"
  expect_status /assets/app.css 200
fi

if [ "$SCAFFOLD" = 1 ]; then
  step "check the Post scaffold"
  if [ "$TYPE" = web ]; then check_web_scaffold; else check_api_scaffold; fi
fi

if [ "$SCAFFOLD" = 1 ] && [ "$TYPE" = web ]; then
  step "check the Chat channel"
  check_channel
  step "check authentication"
  check_auth
fi

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
  production_boot() {
    code=0
    (cd "$WORK/bare" && env "$@" CRYSTAL_ENV=production PORT=1 "$APP_DIR/bin/$NAME" >"$WORK/production.log" 2>&1) || code=$?
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
  expect_missing SESSION_SECRET CSRF_SECRET="$secret_value"
  expect_missing CSRF_SECRET SESSION_SECRET="$secret_value"
fi
step "PASS: generated $TYPE app compiles, boots and serves"
