require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe AzuCLI::Generate::Field do
  it "maps attribute types to Crystal types" do
    {
      "string" => "String", "text" => "String", "email" => "String", "unknown" => "String",
      "int32" => "Int32", "integer" => "Int32", "int64" => "Int64", "references" => "Int64",
      "float32" => "Float32", "float64" => "Float64", "bool" => "Bool", "boolean" => "Bool",
      "time" => "Time", "date" => "Time", "json" => "JSON::Any", "uuid" => "UUID",
    }.each do |type, crystal_type|
      AzuCLI::Generate::Field.new("f", type).crystal_type.should eq(crystal_type)
    end
  end

  it "keeps optional types optional" do
    field = AzuCLI::Generate::Field.new("age", "int32?")
    field.nilable?.should be_true
    field.crystal_type.should eq("Int32?")
    field.column.should eq("column :age, Int32, null: true")
  end

  it "declares the CQL column of each type" do
    AzuCLI::Generate::Field.new("title", "string").column.should eq("text :title")
    AzuCLI::Generate::Field.new("published", "bool").column.should eq("boolean :published, default: false")
    AzuCLI::Generate::Field.new("views", "int64").column.should eq("column :views, Int64")
  end

  it "picks the HTML control of each type" do
    AzuCLI::Generate::Field.new("title", "string").input.should eq("text")
    AzuCLI::Generate::Field.new("body", "text").input.should eq("textarea")
    AzuCLI::Generate::Field.new("published", "bool").input.should eq("checkbox")
    AzuCLI::Generate::Field.new("price", "float64").input.should eq("number")
  end

  it "reads modifiers and references" do
    email = AzuCLI::Generate::Field.new("email", "string:unique:index")
    email.kind.should eq("string")
    email.column.should eq("text :email, unique: true, index: true")

    owner = AzuCLI::Generate::Field.new("owner_id", "int64:ref:users")
    owner.crystal_type.should eq("Int64")
    owner.foreign_key.should eq("foreign_key [:owner_id], references: :users, references_columns: [:id]")
    AzuCLI::Generate::Field.new("user_id", "references").foreign_key.to_s.should contain("references: :users")

    AzuCLI::Generate::Field.new("note", "string?:index").column.should eq("text :note, null: true, index: true")
  end

  it "checks types and modifiers" do
    kinds = %w(string int64)
    AzuCLI::Generate::Field.new("a", "string:unique").type_error(kinds).should be_nil
    AzuCLI::Generate::Field.new("a", "int64:ref:users").type_error(kinds).should be_nil
    AzuCLI::Generate::Field.new("a", "float128").type_error(kinds).to_s.should contain("Unsupported attribute type")
    AzuCLI::Generate::Field.new("a", "string:sparkly").type_error(kinds).to_s.should contain("Unsupported modifier")
    AzuCLI::Generate::Field.new("a", "int64:ref:Users").type_error(kinds).to_s.should contain("Unsupported modifier")
  end

  it "rejects names that are not Crystal identifiers or hide a keyword" do
    AzuCLI::Generate::Field.name_error("first_name").should be_nil
    ["end", "class", "select", "first-name", "Name", "1st", "na\"me", "errors", "hash", "object_id", "save", "inspect", "destroyed", "error_messages"].each do |name|
      AzuCLI::Generate::Field.name_error(name).should_not be_nil
    end
  end

  it "names the attributes the model provides" do
    AzuCLI::Generate::Field.provided({"id" => "int64", "title" => "string", "created_at" => "time"}).should eq(["id", "created_at"])
  end

  it "leaves associations out of the columns" do
    columns = AzuCLI::Generate::Field.columns({"title" => "string", "comments" => "has_many"})
    columns.map(&.name).should eq(["title"])
  end
end

describe AzuCLI::Generate::Resource do
  it "names the model and its routes from the singular, whatever form was typed" do
    in_generated_project do
      {"Post" => "posts", "Posts" => "posts", "Person" => "people", "People" => "people", "Category" => "categories",
       "UpdateLog" => "update_logs"}.each do |name, plural|
        generator = AzuCLI::Generate::Model.new(name, {} of String => String)
        generator.resource_plural.should eq(plural)
        generator.model_name.should eq(plural.singularize.camelcase)
        generator.create_migration_name.should eq("create_#{plural}")
      end
    end
  end

  it "keeps a singular that merely ends in s" do
    in_generated_project do
      {"Campus" => {"campus", "campuses"}, "Analysis" => {"analysis", "analyses"}, "Address" => {"address", "addresses"},
       "Business" => {"business", "businesses"}, "Virus" => {"virus", "viri"}, "Bus" => {"bus", "buses"},
       "Atlas" => {"atlas", "atlases"}, "Alias" => {"alias", "aliases"}, "Census" => {"census", "censuses"},
       "Campuses" => {"campus", "campuses"}, "Addresses" => {"address", "addresses"},
       "Areas" => {"area", "areas"}, "Ideas" => {"idea", "ideas"}, "Cameras" => {"camera", "cameras"}, "Taxis" => {"taxi", "taxis"},
       "Emojis" => {"emoji", "emojis"}, "Lens" => {"lens", "lenses"}}.each do |name, (singular, plural)|
        generator = AzuCLI::Generate::Model.new(name, {} of String => String)
        generator.resource_singular.should eq(singular)
        generator.resource_plural.should eq(plural)
        generator.model_name.should eq(singular.camelcase)
        generator.snake_case_name.should eq(singular)
      end
    end
  end

  it "rejects resource names the generated code cannot use" do
    in_generated_project do
      ["Series", "News", "Sheep", "Fish", "Status", "Request", "Context", "Params", "Template", "Templates", "Param", "App", "Validator", "Markup", "PubSub", "Routable", "Components", "Schema", "Blog", "123x", "a-b"].each do |name|
        AzuCLI::Generate::Resource.name_error(name).should_not be_nil
      end
      ["Post", "Person", "People", "Category", "UpdateLog", "Campus", "Analysis", "Address", "Business", "Header", "Headers"].each do |name|
        AzuCLI::Generate::Resource.name_error(name).should be_nil
      end
    end
  end

  it "names every layer from the resource and the project" do
    in_generated_project do
      generator = AzuCLI::Generate::Request.new("UserProfile", "create")

      generator.model_name.should eq("UserProfile")
      generator.snake_case_name.should eq("user_profile")
      generator.resource_plural.should eq("user_profiles")
      generator.namespace.should eq("UserProfiles")
      generator.app_module.should eq("Blog")
      generator.app_dir.should eq("blog")
    end
  end
end
