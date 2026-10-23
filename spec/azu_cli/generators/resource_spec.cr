require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe AzuCLI::Generate::Field do
  it "maps attribute types to Crystal types" do
    {
      "string" => "String", "text" => "String", "email" => "String", "unknown" => "String",
      "int32" => "Int32", "integer" => "Int32", "int64" => "Int64", "references" => "Int64",
      "float32" => "Float32", "float64" => "Float64", "bool" => "Bool", "boolean" => "Bool",
      "time" => "Time", "date" => "Date", "json" => "JSON::Any", "uuid" => "UUID",
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

  it "leaves associations out of the columns" do
    columns = AzuCLI::Generate::Field.columns({"title" => "string", "comments" => "has_many"})
    columns.map(&.name).should eq(["title"])
  end
end

describe AzuCLI::Generate::Resource do
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
