# Real SQL -> CQL telemetry -> Azu bridge -> shared development snapshot.
# Uses only a private disposable SQLite database; never DATABASE_URL.
require "azu/dev"
require "sqlite3"
require "azu/cql"
require "file/tempfile"

file = File.tempfile("azu-cql-telemetry-", ".db")
file.close
schema : CQL::Schema? = nil
begin
  config = Azu::Configuration.new
  config.env = Azu::Environment::Development
  schema = Azu::CQL.schema(:hud_probe, "sqlite3://#{file.path}", driver: :db) do
    table :products do
      primary :id, Int64
      column :name, String
    end
  end
  schema.build
  schema.insert.into(:products).values(name: "private-bound-value").commit
  store = Azu::QueryStore.instance
  store.clear
  Azu::RequestContext.with("hud-request", "GET", "/products", "Products::Index") do
    5.times { schema.query.from(:products).select(:name).where(name: "private-bound-value").all(String) }
  end
  raise "CQL bridge did not record queries" unless store.queries.size == 5
  raise "CQL bridge lost request context" unless store.queries.all? { |query| query.endpoint == "Products::Index" }
  raise "CQL pool was not attached" unless store.pool
  raise "N+1 diagnostics missing" if store.n_plus_one.empty?
  schema.transaction { |_tx| schema.exec("SELECT 1") }
  raise "CQL transactions were not recorded" if store.transactions.empty?
  payload = Azu::Dev::Telemetry.snapshot(config).to_json
  raise "Bound SQL value escaped redaction" if payload.includes?("private-bound-value")
  File.write(ENV.fetch("AZU_SNAPSHOT_OUTPUT"), payload)
ensure
  schema.try { |value| Azu::CQL.untrack(value); Azu::CQL.close(value) }
  Azu::CQL::Instrumentor.uninstall
  File.delete?(file.path)
  File.delete?(file.path + "-wal")
  File.delete?(file.path + "-shm")
end
