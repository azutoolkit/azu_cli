require "../../spec_helper"

describe AzuCLI::OpenAPI::RequestGenerator do
  describe "#initialize" do
    it "initializes with required parameters" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "object"
      schema.properties = {
        "name" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "string" },
        "age" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "integer" }
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
      generator = AzuCLI::OpenAPI::RequestGenerator.new("users", "create", schema, parser)

      generator.resource.should eq("users")
      generator.action.should eq("create")
      generator.schema.should eq(schema)
      generator.parser.should eq(parser)

      # Cleanup
      File.delete(temp_spec)
    end

    it "initializes with nil schema" do
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
      generator = AzuCLI::OpenAPI::RequestGenerator.new("users", "index", nil, parser)

      generator.resource.should eq("users")
      generator.action.should eq("index")
      generator.schema.should be_nil

      # Cleanup
      File.delete(temp_spec)
    end
  end

  describe "#generate" do
    it "generates request file with schema" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "request_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir) do
        # Create test schema
        schema = AzuCLI::OpenAPI::Schema.new
        schema.type = "object"
        schema.properties = {
          "name" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "string" },
          "age" => AzuCLI::OpenAPI::Schema.new.tap { |s| s.type = "integer" }
        }
        schema.required = ["name"]

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
        generator = AzuCLI::OpenAPI::RequestGenerator.new("users", "create", schema, parser)

        # Generate request file
        generator.generate(true)

        # Check if file was created
        output_path = "src/requests/users/users_create_request.cr"
        File.exists?(output_path).should be_true

        # Check file content
        content = File.read(output_path)
        content.should contain("struct Users::UsersCreateRequest")
        content.should contain("include Azu::Request")
        content.should contain("property name : String")
        content.should contain("property age : Int32?")
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end

    it "generates empty request file without schema" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "request_generator_test_#{Random::Secure.hex(8)}")
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

        parser = AzuCLI::OpenAPI::Parser.new("test_spec.yaml")
        generator = AzuCLI::OpenAPI::RequestGenerator.new("users", "index", nil, parser)

        # Generate request file
        generator.generate(true)

        # Check if file was created
        output_path = "src/requests/users/users_index_request.cr"
        File.exists?(output_path).should be_true

        # Check file content
        content = File.read(output_path)
        content.should contain("struct Users::UsersIndexRequest")
        content.should contain("include Azu::Request")
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end

    it "respects force flag" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "request_generator_test_#{Random::Secure.hex(8)}")
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

        parser = AzuCLI::OpenAPI::Parser.new("test_spec.yaml")
        generator = AzuCLI::OpenAPI::RequestGenerator.new("users", "create", nil, parser)

        # Create existing file
        Dir.mkdir_p("src/requests/users")
        File.write("src/requests/users/users_create_request.cr", "existing content")

        # Generate without force - should not overwrite
        generator.generate(false)
        content = File.read("src/requests/users/users_create_request.cr")
        content.should eq("existing content")

        # Generate with force - should overwrite
        generator.generate(true)
        content = File.read("src/requests/users/users_create_request.cr")
        content.should contain("struct Users::UsersCreateRequest")
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end
  end
end
