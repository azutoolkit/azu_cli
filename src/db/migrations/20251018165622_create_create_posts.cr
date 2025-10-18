require "cql"

# Migration to create create_posts table
# Generated at 2025-10-18 16:56:22 UTC
# Model location: CreatePosts::CreatePostsModel
class Createcreate_postses < CQL::Migration(20251018165622)
  def up
    # Create create_posts table
    schema.table :create_posts do
      primary :id, Int64
      column :name, String
      column :content, String
      timestamps
    end

    # Create the table in the database
    schema.create_posts.create!

    # Add indexes
    schema.alter :create_posts do
      create_index :name_idx, [:name]
    end
  end

  def down
    # Drop create_posts table
    schema.create_posts.drop!
  end
end
