require "cql"

# Migration to create users table
# Generated at 2026-10-23 11:39:15 UTC
class CreateUsers < CQL::Migration(20261023113915)
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
