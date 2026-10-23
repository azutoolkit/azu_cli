require "cql"

# Migration to create users table
# Generated at 2026-10-23 13:51:04 UTC
class CreateUsers < CQL::Migration(20261023135104_i64)
  def up
    schema.table :users do
      primary :id, Int64, auto_increment: true
      timestamps
    end
    schema.users.create!
  end

  def down
    # Drop users table
    schema.users.drop!
  end
end
