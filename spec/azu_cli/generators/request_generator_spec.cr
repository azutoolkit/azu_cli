require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Request do
  it "creates a request generator with attributes" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Request.new("CreateProduct", attributes)
    generator.name.should eq("CreateProduct")
    generator.attributes.should eq(attributes)
    generator.snake_case_name.should eq("create_product")
  end

  it "extracts validations for string and float fields" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Request.new("CreateProduct", attributes)
    generator.has_validations?.should be_true
    validations = generator.validation_declarations
    validations.should contain("validate :name, presence: true, size: 2..100")
    validations.should contain("validate :price, gt: 0.0, lt: 1_000_000.0")
  end

  it "generates correct getter declarations" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Request.new("CreateProduct", attributes)
    getters = generator.getter_declarations
    getters.should contain("getter name : String")
    getters.should contain("getter price : Float64")
  end

  it "generates correct constructor params" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Request.new("CreateProduct", attributes)
    params = generator.constructor_params
    params.should contain("@name : String")
    params.should contain("@price : Float64")
  end

  it "generates a request file with correct content" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Request.new("CreateProduct", attributes)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "create_product.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("struct CreateProductRequest")
    content.should contain("include Azu::Request")
    content.should contain("getter name : String")
    content.should contain("getter price : Float64")
    content.should contain("validate :name, presence: true, size: 2..100")
    content.should contain("validate :price, gt: 0.0, lt: 1_000_000.0")
    content.should contain("def initialize(@name : String, @price : Float64)")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end

  it "generates a request file with no attributes and empty constructor" do
    generator = AzuCLI::Generate::Request.new("Empty", {} of String => String)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "empty.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("struct EmptyRequest")
    content.should contain("include Azu::Request")
    content.should contain("def initialize()")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end
end
