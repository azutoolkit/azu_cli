require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Validator do
  it "creates a validator generator with basic properties" do
    generator = AzuCLI::Generate::Validator.new("Email", "User")

    generator.name.should eq("Email")
    generator.record_type.should eq("User")
    generator.snake_case_name.should eq("email")
    generator.class_name.should eq("EmailValidator")
  end

  it "creates a validator generator with validation rules" do
    validation_rules = ["email", "presence", "uniqueness"]
    generator = AzuCLI::Generate::Validator.new("Email", "User", validation_rules)

    generator.validation_rules.should eq(validation_rules)
    generator.has_validation_rules?.should be_true
  end

  it "generates correct class name" do
    generator = AzuCLI::Generate::Validator.new("EmailValidator", "User")
    generator.class_name.should eq("EmailValidatorValidator")

    generator = AzuCLI::Generate::Validator.new("Email", "User")
    generator.class_name.should eq("EmailValidator")
  end

  it "generates validation rules comments" do
    validation_rules = ["email", "presence"]
    generator = AzuCLI::Generate::Validator.new("Email", "User", validation_rules)

    comments = generator.validation_rules_comments
    comments.should contain("# email")
    comments.should contain("# presence")
  end

  it "generates validation logic for email rule" do
    validation_rules = ["email"]
    generator = AzuCLI::Generate::Validator.new("Email", "User", validation_rules)

    logic = generator.validation_logic
    logic.should contain("if @record.email? && !@record.email!.includes?(\"@\")")
    logic.should contain("errors << Schema::Error.new(\"email\", \"Invalid email format\")")
  end

  it "generates validation logic for presence rule" do
    validation_rules = ["presence"]
    generator = AzuCLI::Generate::Validator.new("Email", "User", validation_rules)

    logic = generator.validation_logic
    logic.should contain("if @record.name?.try(&.empty?)")
    logic.should contain("errors << Schema::Error.new(\"name\", \"Name is required\")")
  end

  it "generates validation logic for length rule" do
    validation_rules = ["length"]
    generator = AzuCLI::Generate::Validator.new("Email", "User", validation_rules)

    logic = generator.validation_logic
    logic.should contain("if @record.name? && @record.name!.size < 2")
    logic.should contain("errors << Schema::Error.new(\"name\", \"Name must be at least 2 characters\")")
  end

  it "generates validation logic for uniqueness rule" do
    validation_rules = ["uniqueness"]
    generator = AzuCLI::Generate::Validator.new("Email", "User", validation_rules)

    logic = generator.validation_logic
    logic.should contain("if User.where(name: @record.name).exists?")
    logic.should contain("errors << Schema::Error.new(\"name\", \"Name must be unique\")")
  end

  it "generates validation logic for format rule" do
    validation_rules = ["format"]
    generator = AzuCLI::Generate::Validator.new("Email", "User", validation_rules)

    logic = generator.validation_logic
    logic.should contain("if @record.email? && !@record.email!.match(/^[\\w\\-\\.]+@[\\w\\-\\.]+\\.[a-zA-Z]{2,}$/)")
    logic.should contain("errors << Schema::Error.new(\"email\", \"Invalid email format\")")
  end

  it "generates validation logic for range rule" do
    validation_rules = ["range"]
    generator = AzuCLI::Generate::Validator.new("Email", "User", validation_rules)

    logic = generator.validation_logic
    logic.should contain("if @record.age? && (@record.age! < 0 || @record.age! > 150)")
    logic.should contain("errors << Schema::Error.new(\"age\", \"Age must be between 0 and 150\")")
  end

  it "generates custom validation for unknown rules" do
    validation_rules = ["custom_rule"]
    generator = AzuCLI::Generate::Validator.new("Email", "User", validation_rules)

    logic = generator.validation_logic
    logic.should contain("# Custom validation for custom_rule")
  end

  it "generates a validator file with validation rules" do
    validation_rules = ["email", "presence"]
    generator = AzuCLI::Generate::Validator.new("Email", "User", validation_rules)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "email.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("class EmailValidator < Azu::Validator")
    content.should contain("getter :record")
    content.should contain("def initialize(@record : User)")
    content.should contain("def valid? : Array(Schema::Error)")
    content.should contain("errors = [] of Schema::Error")
    content.should contain("if @record.email? && !@record.email!.includes?(\"@\")")
    content.should contain("if @record.name?.try(&.empty?)")
    content.should contain("errors")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end

  it "generates a validator file with no validation rules" do
    generator = AzuCLI::Generate::Validator.new("Simple", "User", [] of String)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "simple.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("class SimpleValidator < Azu::Validator")
    content.should contain("getter :record")
    content.should contain("def initialize(@record : User)")
    content.should contain("def valid? : Array(Schema::Error)")
    content.should contain("errors = [] of Schema::Error")
    content.should contain("# Custom logic here")
    content.should contain("Common validation patterns:")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end

  it "generates a validator file with custom record type" do
    validation_rules = ["email"]
    generator = AzuCLI::Generate::Validator.new("Email", "Customer", validation_rules)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "email.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("class EmailValidator < Azu::Validator")
    content.should contain("def initialize(@record : Customer)")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end

  it "generates an email validator similar to the example" do
    generator = AzuCLI::Generate::Validator.new("Email", "User", [] of String)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "email.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("class EmailValidator < Azu::Validator")
    content.should contain("getter :record")
    content.should contain("def initialize(@record : User)")
    content.should contain("def valid? : Array(Schema::Error)")
    content.should contain("errors = [] of Schema::Error")
    content.should contain("errors")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end
end
