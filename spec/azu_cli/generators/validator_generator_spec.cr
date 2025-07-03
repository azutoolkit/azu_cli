require "spec"
require "file_utils"
require "teeplate"
require "../../../src/azu_cli/generators/base"
require "../../../src/azu_cli/generators/validator_generator"

module AzuCLI::Generators
  describe ValidatorGenerator do
    it "generates a custom validator with correct structure and model reference" do
      validator_name = "email_validator"
      model_name = "User"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "validators", "email_validator.cr")
      FileUtils.mkdir_p(File.dirname(output_file))
      File.delete(output_file) if File.exists?(output_file)

      generator = ValidatorGenerator.new(validator_name, model_name, output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      # Check basic structure
      content.should contain("class EmailValidator < Azu::Validator")
      content.should contain("getter :record, :message")

      # Check initialize method with model reference
      content.should contain("def initialize(@record : User)")
      content.should contain("@message = \" User must be valid!\"")

      # Check valid? method signature
      content.should contain("def valid? : Array(Schema::Error)")
      content.should contain("errors = [] of Schema::Error")
      content.should contain("# Todo Custom Validator logic")
      content.should contain("errors")
      content.should contain("end")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
      FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
    end

    it "generates validator with different model name" do
      validator_name = "unique_validator"
      model_name = "Product"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "validators", "unique_validator.cr")
      FileUtils.mkdir_p(File.dirname(output_file))
      File.delete(output_file) if File.exists?(output_file)

      generator = ValidatorGenerator.new(validator_name, model_name, output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      content.should contain("class UniqueValidator < Azu::Validator")
      content.should contain("def initialize(@record : Product)")
      content.should contain("@message = \" Product must be valid!\"")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
      FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
    end
  end
end
