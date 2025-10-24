require "../../spec_helper"

describe AzuCLI::OpenAPI::ModelGenerator do
  describe "#initialize" do
    it "initializes with required parameters" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "object"
      schema.properties = {
        "name" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "string" },
        "age"  => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "integer" },
      }
      schema.required = ["name"]

      # Create temporary spec file
      temp_spec = File.join(Dir.tempdir, "minimal_spec_#{Random::Secure.hex(8)}.yaml")
      File.write(temp_spec, <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths: {}
      YAML
      )

      parser = AzuCLI::OpenAPI::Parser.new(temp_spec)
      generator = AzuCLI::OpenAPI::ModelGenerator.new("User", schema, parser)

      generator.name.should eq("User")
      generator.schema.should eq(schema)
      generator.parser.should eq(parser)

      # Cleanup
      File.delete(temp_spec)
    end
  end

  describe "#generate" do
    it "generates model file with schema properties" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "model_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir) do
        # Create test schema
        schema = AzuCLI::OpenAPI::Schema.new
        schema.type = "object"
        schema.description = "A user in the system"
        schema.properties = {
          "id"     => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "integer"; s.format = "int32" },
          "name"   => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "string" },
          "email"  => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "string"; s.format = "email" },
          "age"    => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "integer" },
          "active" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "boolean" },
        }
        schema.required = ["id", "name", "email"]

        # Create minimal spec file for parser
        spec_content = <<-YAML
        openapi: 3.1.0
        info:
          title: Test API
          version: 1.0.0
        paths: {}
        YAML
        File.write("test_spec.yaml", spec_content)

        parser = AzuCLI::OpenAPI::Parser.new("test_spec.yaml")
        generator = AzuCLI::OpenAPI::ModelGenerator.new("User", schema, parser)

        # Generate model file
        generator.generate(true)

        # Check if file was created
        output_path = "src/models/user.cr"
        File.exists?(output_path).should be_true

        # Check file content
        content = File.read(output_path)
        content.should contain("require \"json\"")
        content.should contain("# A user in the system")
        content.should contain("struct User")
        content.should contain("include JSON::Serializable")
        content.should contain("property id : Int32")
        content.should contain("property name : String")
        content.should contain("property email : String")
        content.should contain("property age : Int32?")
        content.should contain("property active : Bool?")
        content.should contain("def initialize(")
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end

    it "generates model file with nullable types" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "model_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir) do
        # Create test schema with nullable fields
        schema = AzuCLI::OpenAPI::Schema.new
        schema.type = "object"
        schema.properties = {
          "name" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "string"; s.nullable = true },
          "age"  => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "integer" },
        }
        schema.required = ["age"]

        # Create minimal spec file for parser
        spec_content = <<-YAML
        openapi: 3.1.0
        info:
          title: Test API
          version: 1.0.0
        paths: {}
        YAML
        File.write("test_spec.yaml", spec_content)

        parser = AzuCLI::OpenAPI::Parser.new("test_spec.yaml")
        generator = AzuCLI::OpenAPI::ModelGenerator.new("User", schema, parser)

        # Generate model file
        generator.generate(true)

        # Check file content
        content = File.read("src/models/user.cr")
        content.should contain("property name : String?")
        content.should contain("property age : Int32")
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end

    it "respects force flag" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "model_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir) do
        # Create minimal spec file for parser
        spec_content = <<-YAML
        openapi: 3.1.0
        info:
          title: Test API
          version: 1.0.0
        paths: {}
        YAML
        File.write("test_spec.yaml", spec_content)

        schema = AzuCLI::OpenAPI::Schema.new
        schema.type = "object"
        schema.properties = {
          "name" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "string" },
        }

        parser = AzuCLI::OpenAPI::Parser.new("test_spec.yaml")
        generator = AzuCLI::OpenAPI::ModelGenerator.new("User", schema, parser)

        # Create existing file
        Dir.mkdir_p("src/models")
        File.write("src/models/user.cr", "existing content")

        # Generate without force - should not overwrite
        generator.generate(false)
        content = File.read("src/models/user.cr")
        content.should eq("existing content")

        # Generate with force - should overwrite
        generator.generate(true)
        content = File.read("src/models/user.cr")
        content.should contain("struct User")
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end
  end
end
