#!/bin/sh
# Disposable SQLite app + real Chromium. Never targets a deployed application.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
AZU_BIN=${AZU_BIN:-$ROOT/bin/azu}
for tool in crystal shards redis-server python3; do command -v "$tool" >/dev/null; done
python3 -c 'import playwright.sync_api'
WORK=$(mktemp -d "${TMPDIR:-/tmp}/azu-spark-e2e-XXXXXX")
export WORK
export XDG_STATE_HOME="$WORK/state"
unset DATABASE_URL SPARK_SECRET CSRF_SECRET SESSION_SECRET CRYSTAL_ENV PERFORMANCE_MONITORING REDIS_URL REDIS_PASS
mkdir "$WORK/evidence"
trap 'echo "Spark fixture and evidence: $WORK"' EXIT
cd "$WORK"
"$AZU_BIN" new spark_lab --yes --author 'Spark E2E' --email spark@example.test --type web --db sqlite --no-git --no-docker --ci None > evidence/generate.log 2>&1
cd spark_lab
crystal run "$ROOT/scripts/select_framework_versions.cr" -- shard.yml
shards install
cp shard.lock ../evidence/shard.lock
"$AZU_BIN" generate spark Counter count:int32 title:string enabled:bool --page >> ../evidence/generate.log 2>&1
# Exercise the preview/apply path used by an interactive terminal as well as live CRUD.
"$AZU_BIN" generate scaffold Product name:string price_cents:int32 active:bool --spark --check --yes >> ../evidence/generate.log 2>&1
cp .env ../evidence/env-before
cp public/templates/helpers/_sections.jinja ../evidence/nav-before
"$AZU_BIN" generate spark Preview score:float64 --page --dry-run > ../evidence/preview.log 2>&1
cmp .env ../evidence/env-before
cmp public/templates/helpers/_sections.jinja ../evidence/nav-before
test ! -e src/components/preview_spark.cr
rm ../evidence/env-before
"$AZU_BIN" db:setup > ../evidence/migrate.log 2>&1
"$AZU_BIN" db:migrate > ../evidence/migrate-again.log 2>&1
mkdir -p bin
crystal build src/server.cr -o bin/spark_lab --error-trace > ../evidence/build.log 2>&1
crystal spec > ../evidence/specs.log 2>&1
python3 "$ROOT/scripts/e2e_spark_app.py" --app "$WORK/spark_lab" --evidence "$WORK/evidence"
