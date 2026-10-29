#!/bin/sh
# Generate a disposable SQLite app, then exercise its UI in real Chromium.
# Requires Crystal/shards, Node/npm, Redis, Python Playwright and Chromium. Keeps evidence.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
AZU_BIN=${AZU_BIN:-$ROOT/bin/azu}
for tool in crystal shards node npm redis-server python3; do command -v "$tool" > /dev/null; done
python3 -c 'import playwright.sync_api'
test -x "$AZU_BIN"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/azu-browser-e2e-XXXXXX")
export WORK
unset DATABASE_URL CSRF_SECRET SESSION_SECRET CRYSTAL_ENV PERFORMANCE_MONITORING REDIS_URL REDIS_PASS
mkdir "$WORK/evidence"
trap 'echo "Browser fixture and evidence: $WORK"' EXIT
cd "$WORK"
"$AZU_BIN" new browser_shop --yes --author 'Browser E2E' --email browser-e2e@example.test \
  --type web --db sqlite --no-git --no-docker --ci None > evidence/generate.log 2>&1
cd browser_shop
# Rebuild before the future pages exist: the class manifest must retain their styles.
npm ci --ignore-scripts --no-audit --no-fund > ../evidence/npm-ci.log 2>&1
npm run build:css > ../evidence/css-build.log 2>&1
"$AZU_BIN" generate scaffold Product name:string price_cents:int32 active:bool >> ../evidence/generate.log 2>&1
"$AZU_BIN" generate auth >> ../evidence/generate.log 2>&1
"$AZU_BIN" generate channel Chat >> ../evidence/generate.log 2>&1
# Index endpoint registration is idempotent and appears in a preview without
# changing either the navigation or endpoints during a dry run.
cp public/templates/helpers/_sections.jinja ../evidence/navigation-before.jinja
"$AZU_BIN" generate endpoint Product index --force >> ../evidence/generate.log 2>&1
cmp public/templates/helpers/_sections.jinja ../evidence/navigation-before.jinja
"$AZU_BIN" generate endpoint Report index --dry-run > ../evidence/navigation-preview.log 2>&1
cmp public/templates/helpers/_sections.jinja ../evidence/navigation-before.jinja
test ! -e src/endpoints/reports/index_endpoint.cr
"$AZU_BIN" db:setup > ../evidence/migrate.log 2>&1
"$AZU_BIN" db:migrate > ../evidence/migrate-again.log 2>&1
mkdir -p bin
crystal build src/server.cr -o bin/browser_shop --error-trace > ../evidence/build.log 2>&1
python3 "$ROOT/scripts/e2e_browser_app.py" --app "$WORK/browser_shop" \
  --evidence "$WORK/evidence" --cli "$AZU_BIN"
