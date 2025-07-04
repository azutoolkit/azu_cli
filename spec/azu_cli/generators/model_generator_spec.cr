require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Model do
  it "creates a model generator with basic attributes" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Model.new("Product", attributes)

    generator.name.should eq("Product")
    generator.attributes.should eq(attributes)
    generator.timestamps.should be_true
    generator.database.should eq("BlogDB")
    generator.id_type.should eq("UUID")
  end

  it "creates a model generator with custom options" do
    attributes = {"title" => "string", "content" => "text"}
    generator = AzuCLI::Generate::Model.new(
      "Post",
      attributes,
      timestamps: false,
      database: "AppDB",
      id_type: "Int32"
    )

    generator.name.should eq("Post")
    generator.timestamps.should be_false
    generator.database.should eq("AppDB")
    generator.id_type.should eq("Int32")
  end

  it "converts name to snake_case" do
    generator = AzuCLI::Generate::Model.new("UserProfile", {} of String => String)
    generator.snake_case_name.should eq("user_profile")
  end

  it "converts name to table name" do
    generator = AzuCLI::Generate::Model.new("Product", {} of String => String)
    generator.table_name.should eq("products")
  end

  it "maps crystal types correctly" do
    generator = AzuCLI::Generate::Model.new("Test", {} of String => String)

    generator.crystal_type("string").should eq("String")
    generator.crystal_type("text").should eq("String")
    generator.crystal_type("int32").should eq("Int32")
    generator.crystal_type("integer").should eq("Int32")
    generator.crystal_type("float64").should eq("Float64")
    generator.crystal_type("float").should eq("Float64")
    generator.crystal_type("bool").should eq("Bool")
    generator.crystal_type("boolean").should eq("Bool")
    generator.crystal_type("time").should eq("Time")
    generator.crystal_type("datetime").should eq("Time")
    generator.crystal_type("date").should eq("Date")
    generator.crystal_type("uuid").should eq("UUID")
    generator.crystal_type("json").should eq("JSON::Any")
  end

  it "generates correct getter declarations" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Model.new("Product", attributes)

    getters = generator.getter_declarations
    getters.should contain("getter id : UUID?")
    getters.should contain("getter name : String")
    getters.should contain("getter price : Float64")
    getters.should contain("getter created_at : Time?")
    getters.should contain("getter updated_at : Time?")
  end

  it "generates correct constructor parameters" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Model.new("Product", attributes)

    params = generator.constructor_params
    params.should contain("@name : String")
    params.should contain("@price : Float64")
  end

  it "generates validation declarations" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Model.new("Product", attributes)

    validations = generator.validation_declarations
    validations.should contain("validate :name, presence: true, size: 2..100")
    validations.should contain("validate :price, gt: 0.0, lt: 1_000_000.0")
  end

  it "generates a model file with correct content" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Model.new("Product", attributes)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "product.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("struct Product")
    content.should contain("include CQL::ActiveRecord::Model(UUID)")
    content.should contain("db_context BlogDB, :products")
    content.should contain("getter id : UUID?")
    content.should contain("getter name : String")
    content.should contain("getter price : Float64")
    content.should contain("getter created_at : Time?")
    content.should contain("getter updated_at : Time?")
    content.should contain("validate :name, presence: true, size: 2..100")
    content.should contain("validate :price, gt: 0.0, lt: 1_000_000.0")
    content.should contain("def initialize(@name : String, @price : Float64)")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end

  it "generates a model file without timestamps" do
    attributes = {"name" => "string"}
    generator = AzuCLI::Generate::Model.new("Product", attributes, timestamps: false)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "product.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("struct Product")
    content.should contain("getter name : String")
    content.should_not contain("getter created_at : Time?")
    content.should_not contain("getter updated_at : Time?")
    content.should contain("def initialize(@name : String)")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end
end
