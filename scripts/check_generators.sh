#!/bin/sh
# Compile every public generator together and execute paths Crystal lazily checks.
# Each run owns a temporary SQLite project; no external database is mutated.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
AZU_BIN=${AZU_BIN:-$ROOT/bin/azu}
TYPE=${1:-web}
WORK=$(mktemp -d)
trap 'if [ "${KEEP_TMP:-0}" = 1 ]; then echo "kept $WORK"; else rm -rf "$WORK"; fi' EXIT
cd "$WORK"
"$AZU_BIN" new generator_matrix --yes --author Test --email test@example.com --type "$TYPE" --db sqlite --no-git --no-docker --ci None
cd generator_matrix
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
cat > verify_generators.cr <<'CR'
require "./src/generator_matrix"
require "./src/db/migrations/**"
require "./src/db/data_migrations/**"
require "./src/db/seeds/test/**"
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
