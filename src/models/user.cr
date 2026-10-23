require "cql"

class User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  property created_at : Time?
  property updated_at : Time?

  def initialize()
  end
end
