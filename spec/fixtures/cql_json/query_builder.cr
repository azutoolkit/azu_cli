require "./model"

payload = JSON.parse(%({"profile":{"country":"US"},"tags":["a","b"],"active":true,"count":3}))
updated = JSON.parse(%({"profile":{"country":"UK"},"active":false}))
JsonProbeDB.json_probe_documents.create!
begin
  # The query builder accepts JSON::Any directly and serializes bound values.
  JsonProbeDB.insert.into(:json_probe_documents).values(name: "builder", data: payload).commit
  names = JsonProbeDB.query.from(:json_probe_documents).select(:name)
    .where { json_probe_documents.data.json_eq(["profile", "country"], "US") }.all(as: String)
  raise "nested JSON predicate failed" unless names == ["builder"]
  raise "typed model JSON predicate failed" unless JsonProbeDocument.query.where { data.json_eq("active", true) }.count == 1

  if ENV["CQL_JSON_ADAPTER"] == "SQLite"
    row = JsonProbeDocument.query.select(:data).first!
    raise "typed JSON projection failed" unless row.data == payload
  else
    # PostgreSQL's converter maps JSONB back to JSON::Any. The class-level
    # create API accepts explicitly serialized JSON without invoking #attributes.
    record = JsonProbeDocument.create!(name: "model", data: CQL::JSONBConverter.to_db(payload))
    raise "JSONB model create/read failed" unless record.data == payload
    raise "JSONB converter find failed" unless JsonProbeDocument.find!(record.id!).data == payload
    contained = JsonProbeDocument.query.where { data.json_contains({active: true}) }.count
    raise "JSON containment failed" unless contained == 2
    JsonProbeDocument.delete!(record.id!)
  end

  JsonProbeDB.update.table(:json_probe_documents).set(data: updated).where(name: "builder").commit
  raise "JSON update failed" unless JsonProbeDocument.query.where { data.json_eq("active", false) }.count == 1
  JsonProbeDB.delete.from(:json_probe_documents).where(name: "builder").commit
  raise "JSON row delete failed" unless JsonProbeDocument.query.count == 0
  puts "PASS: #{ENV["CQL_JSON_ADAPTER"]} JSON column, query-builder CRUD and typed model predicates"
ensure
  JsonProbeDB.json_probe_documents.drop!
end
