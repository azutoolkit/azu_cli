require "cql"
require "sqlite3"
require "pg"

# Use a disposable database: the validation creates and drops its own table.
JsonProbeDB = CQL::Schema.define(:json_probe,
  uri: ENV.fetch("CQL_JSON_DATABASE_URL"),
  adapter: CQL::Adapter.parse(ENV.fetch("CQL_JSON_ADAPTER"))) do
  table :json_probe_documents do
    primary :id, Int64, auto_increment: true
    text :name
    json :data
  end
end
