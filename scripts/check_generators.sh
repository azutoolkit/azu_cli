#!/bin/sh
# Compile every public generator together and execute paths Crystal lazily checks.
# Each run owns a temporary SQLite project; no external database is mutated.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
AZU_BIN=${AZU_BIN:-$ROOT/bin/azu}
TYPE=${1:-web}
WORK=$(mktemp -d)
REDIS_PID=""
cleanup() {
  if [ -n "$REDIS_PID" ]; then kill "$REDIS_PID" 2>/dev/null || true; wait "$REDIS_PID" 2>/dev/null || true; fi
  if [ "${KEEP_TMP:-0}" = 1 ]; then echo "kept $WORK"; else rm -rf "$WORK"; fi
}
trap cleanup EXIT
# Initializers and generated delivery jobs must never use a developer's Redis.
REDIS_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
REDIS_HOST=127.0.0.1
REDIS_URL="redis://$REDIS_HOST:$REDIS_PORT"
export REDIS_HOST REDIS_PORT REDIS_URL
redis-server --bind "$REDIS_HOST" --port "$REDIS_PORT" --save '' --appendonly no > "$WORK/redis.log" 2>&1 &
REDIS_PID=$!
cd "$WORK"
"$AZU_BIN" new generator_matrix --yes --author Test --email test@example.com --type "$TYPE" --db sqlite --no-git --no-docker --ci None
cd generator_matrix
crystal run "$ROOT/scripts/select_framework_versions.cr" -- shard.yml
shards install
# A pristine project must compile before generators populate optional directories.
crystal build src/server.cr --no-codegen --error-trace
# Email is optional; exercise the supported Carbon adapter API, pinned for reproducibility.
cat >> shard.yml <<'YAML'
  carbon:
    github: luckyframework/carbon
    version: 0.6.1
YAML
shards install
"$AZU_BIN" generate joobq --force
"$AZU_BIN" session:setup --force
"$AZU_BIN" generate scaffold Post title:string body:text
"$AZU_BIN" generate model Audit code:string
"$AZU_BIN" generate model Author name:string
"$AZU_BIN" generate model OptionalToken token:uuid?
"$AZU_BIN" generate scaffold TypeProbe count:int32 total:int64 ratio:float32 score:float64 enabled:bool happened_at:time day:date token:uuid contact:email homepage:url author_id:references
# CQL v1 cannot persist JSON::Any in ActiveRecord; fail before writing a broken model.
if "$AZU_BIN" generate scaffold JsonProbe metadata:json; then
  echo "JSON persistence must be rejected until CQL supports it" >&2
  exit 1
fi
[ ! -f src/models/json_probe.cr ]
"$AZU_BIN" generate request Payload create metadata:json token:uuid day:date
"$AZU_BIN" generate endpoint Post index --force
"$AZU_BIN" generate service Post title:string body:text --force
"$AZU_BIN" generate request Post create title:string body:text --force
"$AZU_BIN" generate response Post show title:string body:text --force
"$AZU_BIN" generate page Post index title:string body:text --force
"$AZU_BIN" generate template Post index title:string body:text --force
"$AZU_BIN" generate migration AddAuditIndex
"$AZU_BIN" generate data:migration BackfillAudit
"$AZU_BIN" generate seed Audit --env test
"$AZU_BIN" generate component Counter count:int32 today:date
"$AZU_BIN" generate validator AuditRecord --record Audit
"$AZU_BIN" generate middleware Trace --type logging
"$AZU_BIN" generate channel Chat
"$AZU_BIN" generate job Cleanup id:int64
"$AZU_BIN" generate mailer Notification welcome
"$AZU_BIN" generate mailer Synchronous welcome --skip job
"$AZU_BIN" generate api_resource Product name:string
"$AZU_BIN" openapi:generate "$ROOT/spec/fixtures/generators/openapi.yaml"
# Auth requires its own session payload; session:setup is checked separately first.
crystal build src/server.cr --no-codegen --error-trace
if [ "$TYPE" = web ]; then
  "$AZU_BIN" generate spark Counter count:int32 ratio:float32 total:int64 score:float64 enabled:bool title:string --page
  "$AZU_BIN" generate spark:scaffold Inventory label:string price:float64 enabled:bool
  rm src/initializers/session.cr
  "$AZU_BIN" generate auth
else
  if "$AZU_BIN" generate spark Counter --page; then
    echo "Spark must reject API-only projects" >&2
    exit 1
  fi
  if "$AZU_BIN" generate auth; then
    echo "API session authentication must be rejected explicitly" >&2
    exit 1
  fi
fi
crystal build src/server.cr --no-codegen --error-trace
crystal build src/worker.cr --no-codegen --error-trace
AZU_ENV=test CRYSTAL_ENV=test "$AZU_BIN" db:setup
cat > verify_generators.cr <<'CR'
require "./src/generator_matrix"
require "./src/db/migrations/**"
require "./src/db/data_migrations/**"
require "./src/db/seeds/test/**"
optional = OptionalToken.new(token: nil)
optional.save!
raise "nullable UUID mapping" unless OptionalToken.find!(optional.id!).token.nil?
optional.token = UUID.random
optional.save!
raise "nullable UUID roundtrip" unless OptionalToken.find!(optional.id!).token == optional.token
optional.delete!
author = Author.new(name: "Parent")
author.save!
probe = TypeProbe.new(count: 2, total: 3_i64, ratio: 1.5_f32, score: 2.5, enabled: true,
  happened_at: Time.utc(2026, 10, 29), day: Time.utc(2026, 10, 29), token: UUID.random,
  contact: "test@example.test", homepage: "https://example.test", author_id: author.id!)
probe.save!
loaded = TypeProbe.find!(probe.id!)
raise "typed model mapping" unless loaded.day == probe.day && loaded.token == probe.token && loaded.ratio == probe.ratio
raise "belongs_to mapping" unless loaded.author.not_nil!.id == author.id
loaded.delete!
author.delete!
form = GeneratorMatrix::Payloads::CreateRequest.from_www_form(URI::Params.build do |params|
  params.add("metadata", %({"ok":true}))
  params.add("token", "123e4567-e89b-12d3-a456-426614174000")
  params.add("day", "2026-10-29")
end)
raise "JSON form decoding" unless form.metadata["ok"].as_bool
raise "UUID form decoding" unless form.token.to_s == "123e4567-e89b-12d3-a456-426614174000"
raise "date form decoding" unless form.day == Time.utc(2026, 10, 29)
invoice = Invoice.new(name: "Example", display_name: "Visible")
raise "OpenAPI JSON field names" unless JSON.parse(invoice.to_json)["displayName"].as_s == "Visible"
contract = Invoices::InvoicesCreateRequest.from_json(%({"name":"Example","displayName":"Visible"}))
raise "OpenAPI request field names" unless contract.display_name == "Visible"
raise "OpenAPI route parameters" unless File.read("src/endpoints/invoices/invoices_show_endpoint.cr").includes?(%(get "/invoices/:id"))
begin
  Invoices::InvoicesShowEndpoint.new.call
  raise "OpenAPI endpoint must require an application implementation"
rescue ex : Azu::Response::Error
  raise "OpenAPI stub status" unless ex.status_code == 501
end
raise "OpenAPI object response" unless Invoices::InvoicesShowPage.new(name: "Example").render_json.includes?("Example")
raise "OpenAPI created response" unless Invoices::InvoicesCreatePage.new(name: "Created").render_json.includes?("Created")
raise "OpenAPI array response" unless JSON.parse(Invoices::InvoicesIndexPage.new([invoice]).render_json).as_a.size == 1
message = NotificationMailer.new.welcome(to: Carbon::Address.new("Recipient", "recipient@example.test"), name: "Test")
raise "wrong sender" unless message.from.address == (ENV["MAILER_FROM_EMAIL"]? || "noreply@example.com")
message.deliver
raise "message not delivered" unless Carbon::DevAdapter.delivered?(message)
NotificationMailerJob.new("welcome", "second@example.test", {"name" => "Second"}).perform
raise "job not delivered" unless Carbon::DevAdapter.delivered_emails.size == 2
SynchronousMailer.preview("welcome").deliver
raise "sync mailer not delivered" unless Carbon::DevAdapter.delivered_emails.size == 3
raise "validator contract" unless AuditRecordValidator.new(Audit.new(code: "example")).valid?.empty?
component = CounterComponent.new(1, Time.utc)
component.content
puts "Generated messages, delivery job, validator and component passed"
CR
CRYSTAL_ENV=test crystal run verify_generators.cr --error-trace

if [ "$TYPE" = web ]; then
  crystal spec spec/components/counter_spark_spec.cr --error-trace
fi
