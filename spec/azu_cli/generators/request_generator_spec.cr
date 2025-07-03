require "spec"
require "file_utils"
require "teeplate"
require "../../../src/azu_cli/generators/base"
require "../../../src/azu_cli/generators/request_generator"

module AzuCLI::Generators
  describe RequestGenerator do
    it "generates a request object with dynamic properties and validations" do
      request_name = "user_request"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "requests", "user_request.cr")

      # Define properties with their types and validations
      properties = [
        {
          name:        "name",
          type:        "String",
          default:     "\"\"",
          validations: ["presence: true", "length: {min: 2, max: 50}"],
        },
        {
          name:        "email",
          type:        "String",
          default:     "\"\"",
          validations: ["presence: true", "format: /\\A[\\w+\\-.]+@[a-z\\d\\-]+(\\.[a-z\\d\\-]+)*\\.[a-z]+\\z/i"],
        },
        {
          name:        "age",
          type:        "Int32?",
          default:     "nil",
          validations: ["numericality: {greater_than: 0, less_than: 150}", "if: ->{ age }"],
        },
        {
          name:        "profile_image",
          type:        "Azu::Params::Multipart::File?",
          default:     "nil",
          validations: [] of String,
        },
      ]

      FileUtils.mkdir_p(File.dirname(output_file))
      File.delete(output_file) if File.exists?(output_file)

      generator = RequestGenerator.new(request_name, properties, output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      # Check basic structure
      content.should contain("struct UserRequest")
      content.should contain("include Azu::Request")

      # Check dynamic getter declarations
      content.should contain("getter name : String")
      content.should contain("getter email : String")
      content.should contain("getter age : Int32?")
      content.should contain("getter profile_image : Azu::Params::Multipart::File?")

      # Check initializer with defaults
      content.should contain("def initialize(@name = \"\", @email = \"\", @age = nil, @profile_image = nil)")

      # Check validations
      content.should contain("validate :name, presence: true")
      content.should contain("validate :name, length: {min: 2, max: 50}")
      content.should contain("validate :email, presence: true")
      content.should contain("validate :age, numericality: {greater_than: 0, less_than: 150}")
      content.should contain("validate :age, if: ->{ age }")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
      FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
    end

    it "generates simple request with minimal properties" do
      request_name = "search_request"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "requests", "search_request.cr")

      properties = [
        {
          name:        "query",
          type:        "String",
          default:     "\"\"",
          validations: ["presence: true"],
        },
      ]

      FileUtils.mkdir_p(File.dirname(output_file))
      File.delete(output_file) if File.exists?(output_file)

      generator = RequestGenerator.new(request_name, properties, output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      content.should contain("struct SearchRequest")
      content.should contain("getter query : String")
      content.should contain("validate :query, presence: true")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
      FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
    end
  end
end
