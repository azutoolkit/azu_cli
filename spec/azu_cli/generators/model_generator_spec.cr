require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe AzuCLI::Generate::Model do
  attributes = {"title" => "string", "views" => "int32", "published" => "bool"}

  it "derives the table name from the model name" do
    AzuCLI::Generate::Model.new("UserProfile", {} of String => String).table_name.should eq("user_profiles")
  end

  it "takes the schema constant from src/db/schema.cr" do
    in_generated_project do
      AzuCLI::Generate::Model.new("Post", attributes).database.should eq("BlogDB")
    end
  end

  it "generates constructor parameters from the columns" do
    generator = AzuCLI::Generate::Model.new("Post", attributes.merge({"comments" => "has_many"}))
    generator.constructor_params.should eq("@title : String, @views : Int32, @published : Bool")
  end

  it "declares associations" do
    generator = AzuCLI::Generate::Model.new("Post", {"user_id" => "references", "comments" => "has_many"})
    generator.associations.should eq([
      "belongs_to :user, User, foreign_key: :user_id",
      "has_many :comments, Comment, foreign_key: :post_id",
    ])
  end

  it "renders a top-level class with its columns" do
    in_generated_project do
      content = rendered(AzuCLI::Generate::Model.new("Post", attributes, generate_migration: false), "src/models", "post.cr")

      content.should contain("class Post\n")
      content.should contain("include CQL::ActiveRecord::Model(Int64)")
      content.should contain("db_context BlogDB, :posts")
      content.should contain("property title : String")
      content.should contain("property published : Bool")
      content.should contain("property created_at : Time?")
      content.should contain("def initialize(@title : String, @views : Int32, @published : Bool)")
      content.should_not contain("validate")
    end
  end

  it "leaves out the timestamps on request" do
    in_generated_project do
      content = rendered(AzuCLI::Generate::Model.new("Post", attributes, timestamps: false, generate_migration: false), "src/models", "post.cr")

      content.should_not contain("created_at")
    end
  end

  it "renders the create-table migration in src/db/migrations and registers the table in the schema" do
    in_generated_project do
      rendered(AzuCLI::Generate::Model.new("Post", attributes), "src/models", "post.cr")

      migration = Dir.glob("src/db/migrations/*_create_posts.cr").first
      File.read(migration).should contain("schema.table :posts do")
      File.read("src/db/schema.cr").should contain("  table :posts do\n    primary :id, Int64, auto_increment: true\n    text :title\n    column :views, Int32\n")
    end
  end

  it "creates a create-table migration even for names that look like another kind" do
    in_generated_project do
      {"UpdateLog" => "update_logs", "DeleteItem" => "delete_items", "DropZone" => "drop_zones", "Person" => "people"}.each do |name, table|
        rendered(AzuCLI::Generate::Model.new(name, {"title" => "string"}), "src/models", "#{name.underscore}.cr")

        File.read(Dir.glob("src/db/migrations/*_create_#{table}.cr").first).should contain("schema.table :#{table} do")
      end
    end
  end

  it "does not render a migration when asked not to" do
    in_generated_project do
      rendered(AzuCLI::Generate::Model.new("Post", attributes, generate_migration: false), "src/models", "post.cr")

      Dir.glob("src/db/migrations/*").should be_empty
    end
  end
end
