require "./schema"

class JsonProbeDocument
  include CQL::ActiveRecord::Model(Int64)
  db_context JsonProbeDB, :json_probe_documents

  property name : String
  @[DB::Field(converter: CQL::JSONBConverter)]
  property data : JSON::Any

  def initialize(@name : String, @data : JSON::Any)
  end
end
