require "spec"
require "file_utils"
require "teeplate"
require "../../../src/azu_cli/generators/base"
require "../../../src/azu_cli/generators/response_generator"

module AzuCLI::Generators
  describe ResponseGenerator do
    it "generates a response with attributes and JSON serialization" do
      response_name = "user_response"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "responses", "user_response.cr")

      # Define response attributes
      attributes = [
        {name: "id", type: "Int64", default: "0"},
        {name: "name", type: "String", default: "\"\""},
        {name: "email", type: "String", default: "\"\""},
        {name: "created_at", type: "Time?", default: "nil"},
      ]

      FileUtils.mkdir_p(File.dirname(output_file))
      File.delete(output_file) if File.exists?(output_file)

      generator = ResponseGenerator.new(response_name, attributes, include_json: true, output_dir: output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      # Check basic structure
      content.should contain("class UserResponse")
      content.should contain("include Response")
      content.should contain("include JSON::Serializable")

      # Check attributes
      content.should contain("@id : Int64 = 0")
      content.should contain("@name : String = \"\"")
      content.should contain("@email : String = \"\"")
      content.should contain("@created_at : Time? = nil")

      # Check initializer
      content.should contain("def initialize(@id = 0, @name = \"\", @email = \"\", @created_at = nil)")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
      FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
    end

    it "generates response without JSON serialization when disabled" do
      response_name = "simple_response"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "responses", "simple_response.cr")

      attributes = [
        {name: "message", type: "String", default: "\"\""},
        {name: "status", type: "Int32", default: "200"},
      ]

      FileUtils.mkdir_p(File.dirname(output_file))
      File.delete(output_file) if File.exists?(output_file)

      generator = ResponseGenerator.new(response_name, attributes, include_json: false, output_dir: output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      # Check basic structure without JSON
      content.should contain("class SimpleResponse")
      content.should contain("include Response")
      content.should_not contain("include JSON::Serializable")

      # Check attributes
      content.should contain("@message : String = \"\"")
      content.should contain("@status : Int32 = 200")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
      FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
    end

    it "generates minimal response with no attributes" do
      response_name = "empty_response"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "responses", "empty_response.cr")

      FileUtils.mkdir_p(File.dirname(output_file))
      File.delete(output_file) if File.exists?(output_file)

      generator = ResponseGenerator.new(response_name, [] of ResponseAttribute, include_json: true, output_dir: output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      content.should contain("class EmptyResponse")
      content.should contain("include Response")
      content.should contain("include JSON::Serializable")
      content.should contain("def initialize()")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
      FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
    end
  end
end
