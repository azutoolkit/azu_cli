require "../../spec_helper"

describe AzuCLI::OpenAPI::ResponseGenerator do
  describe "#initialize" do
    it "initializes with required parameters" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "object"
      schema.properties = {
        "id" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "integer" },
        "name" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "string" }
      }
      schema.required = ["id", "name"]

      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/minimal_spec.yaml")
      generator = AzuCLI::OpenAPI::ResponseGenerator.new("users", "show", schema, parser)

      generator.resource.should eq("users")
      generator.action.should eq("show")
      generator.schema.should eq(schema)
      generator.parser.should eq(parser)
    end

    it "initializes with nil schema" do
      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/minimal_spec.yaml")
      generator = AzuCLI::OpenAPI::ResponseGenerator.new("users", "index", nil, parser)

      generator.resource.should eq("users")
      generator.action.should eq("index")
      generator.schema.should be_nil
    end
  end

  describe "#generate" do
    it "generates response file with schema" do
      # Create test schema
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "object"
      schema.properties = {
        "id" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "integer" },
        "name" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "string" },
        "email" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "string" }
      }
      schema.required = ["id", "name"]

      # Create minimal spec file for parser
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths: {}
      YAML
      File.write("spec/fixtures/test_spec.yaml", spec_content)

      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/test_spec.yaml")
      generator = AzuCLI::OpenAPI::ResponseGenerator.new("users", "show", schema, parser)

      # Generate response file
      generator.generate(true)

      # Check if file was created
      output_path = "src/pages/users/users_show_page.cr"
      File.exists?(output_path).should be_true

      # Check file content
      content = File.read(output_path)
      content.should contain("struct Users::UsersShowPage")
      content.should contain("include Azu::Response")
      content.should contain("include JSON::Serializable")
      content.should contain("property id : Int32")
      content.should contain("property name : String")
      content.should contain("property email : String?")
      content.should contain("def render : String")

      # Cleanup
      File.delete(output_path) if File.exists?(output_path)
      # Remove all files in the directory first
      if Dir.exists?("src/pages/users")
        Dir.each_child("src/pages/users") do |file|
          File.delete(File.join("src/pages/users", file))
        end
        Dir.delete("src/pages/users")
      end
      Dir.delete("src/pages") if Dir.exists?("src/pages")
      File.delete("spec/fixtures/test_spec.yaml")
    end

    it "generates empty response file without schema" do
      # Create minimal spec file for parser
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths: {}
      YAML
      File.write("spec/fixtures/test_spec.yaml", spec_content)

      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/test_spec.yaml")
      generator = AzuCLI::OpenAPI::ResponseGenerator.new("users", "index", nil, parser)

      # Generate response file
      generator.generate(true)

      # Check if file was created
      output_path = "src/pages/users/users_index_page.cr"
      File.exists?(output_path).should be_true

      # Check file content
      content = File.read(output_path)
      content.should contain("struct Users::UsersIndexPage")
      content.should contain("include Azu::Response")
      content.should contain("include JSON::Serializable")
      content.should contain("def render : String")

      # Cleanup
      File.delete(output_path) if File.exists?(output_path)
      # Remove all files in the directory first
      if Dir.exists?("src/pages/users")
        Dir.each_child("src/pages/users") do |file|
          File.delete(File.join("src/pages/users", file))
        end
        Dir.delete("src/pages/users")
      end
      Dir.delete("src/pages") if Dir.exists?("src/pages")
      File.delete("spec/fixtures/test_spec.yaml")
    end

    it "respects force flag" do
      # Create minimal spec file for parser
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths: {}
      YAML
      File.write("spec/fixtures/test_spec.yaml", spec_content)

      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/test_spec.yaml")
      generator = AzuCLI::OpenAPI::ResponseGenerator.new("users", "show", nil, parser)

      # Create existing file
      Dir.mkdir_p("src/pages/users")
      File.write("src/pages/users/users_show_page.cr", "existing content")

      # Generate without force - should not overwrite
      generator.generate(false)
      content = File.read("src/pages/users/users_show_page.cr")
      content.should eq("existing content")

      # Generate with force - should overwrite
      generator.generate(true)
      content = File.read("src/pages/users/users_show_page.cr")
      content.should contain("struct Users::UsersShowPage")

      # Cleanup
      File.delete("src/pages/users/users_show_page.cr")
      # Remove all files in the directory first
      if Dir.exists?("src/pages/users")
        Dir.each_child("src/pages/users") do |file|
          File.delete(File.join("src/pages/users", file))
        end
        Dir.delete("src/pages/users")
      end
      Dir.delete("src/pages") if Dir.exists?("src/pages")
      File.delete("spec/fixtures/test_spec.yaml")
    end
  end
end
