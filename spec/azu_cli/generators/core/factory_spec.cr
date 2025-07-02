require "../spec_helper"

describe AzuCLI::Generator::Core::GeneratorFactory do
  describe ".create" do
    it "creates contract generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("contract", "UserContract", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ContractGenerator)
      generator.name.should eq("UserContract")
      generator.project_name.should eq("test_project")
    end

    it "creates model generator" do
      options = create_generator_options(attributes: sample_attributes)
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("model", "User", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ModelGenerator)
      generator.name.should eq("User")
    end

    it "creates service generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("service", "UserService", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ServiceGenerator)
      generator.name.should eq("UserService")
    end

    it "creates endpoint generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("endpoint", "UsersEndpoint", "test_project", options)

      generator.should be_a(AzuCLI::Generator::EndpointGenerator)
      generator.name.should eq("UsersEndpoint")
    end

    it "creates page generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("page", "UserPage", "test_project", options)

      generator.should be_a(AzuCLI::Generator::PageGenerator)
      generator.name.should eq("UserPage")
    end

    it "creates component generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("component", "UserCard", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ComponentGenerator)
      generator.name.should eq("UserCard")
    end

    it "creates middleware generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("middleware", "AuthMiddleware", "test_project", options)

      generator.should be_a(AzuCLI::Generator::MiddlewareGenerator)
      generator.name.should eq("AuthMiddleware")
    end

    it "creates migration generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("migration", "CreateUsers", "test_project", options)

      generator.should be_a(AzuCLI::Generator::MigrationGenerator)
      generator.name.should eq("CreateUsers")
    end

    it "creates validator generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("validator", "EmailValidator", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ValidatorGenerator)
      generator.name.should eq("EmailValidator")
    end

    it "creates scaffold generator" do
      options = create_generator_options(attributes: sample_attributes)
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("scaffold", "User", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ScaffoldGenerator)
      generator.name.should eq("User")
    end

    it "creates channel generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("channel", "ChatChannel", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ChannelGenerator)
      generator.name.should eq("ChatChannel")
    end

    it "creates handler generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("handler", "UserHandler", "test_project", options)

      generator.should be_a(AzuCLI::Generator::HandlerGenerator)
      generator.name.should eq("UserHandler")
    end

    it "creates request generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("request", "UserRequest", "test_project", options)

      generator.should be_a(AzuCLI::Generator::RequestGenerator)
      generator.name.should eq("UserRequest")
    end

    it "creates response generator" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("response", "UserResponse", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ResponseGenerator)
      generator.name.should eq("UserResponse")
    end
  end

  describe "aliases" do
    it "resolves model alias" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("m", "User", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ModelGenerator)
    end

    it "resolves endpoint alias" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("e", "UsersEndpoint", "test_project", options)

      generator.should be_a(AzuCLI::Generator::EndpointGenerator)
    end

    it "resolves contract alias" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("c", "UserContract", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ContractGenerator)
    end

    it "resolves service alias" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("s", "UserService", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ServiceGenerator)
    end

    it "resolves component alias" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("comp", "UserCard", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ComponentGenerator)
    end

    it "resolves scaffold alias" do
      options = create_generator_options
      generator = AzuCLI::Generator::Core::GeneratorFactory.create("sc", "User", "test_project", options)

      generator.should be_a(AzuCLI::Generator::ScaffoldGenerator)
    end
  end

  describe "error handling" do
    it "raises error for unknown generator type" do
      options = create_generator_options

      expect_raises(ArgumentError, "Unknown generator type") do
        AzuCLI::Generator::Core::GeneratorFactory.create("unknown", "Test", "test_project", options)
      end
    end
  end

  describe ".available_types" do
    it "returns all available generator types" do
      types = AzuCLI::Generator::Core::GeneratorFactory.available_types

      types.should contain("contract")
      types.should contain("model")
      types.should contain("service")
      types.should contain("endpoint")
      types.should contain("page")
      types.should contain("component")
      types.should contain("middleware")
      types.should contain("migration")
      types.should contain("validator")
      types.should contain("scaffold")
      types.should contain("channel")
      types.should contain("handler")
      types.should contain("request")
      types.should contain("response")
    end
  end

  describe ".exists?" do
    it "returns true for valid generator types" do
      AzuCLI::Generator::Core::GeneratorFactory.exists?("model").should be_true
      AzuCLI::Generator::Core::GeneratorFactory.exists?("service").should be_true
      AzuCLI::Generator::Core::GeneratorFactory.exists?("scaffold").should be_true
    end

    it "returns true for valid aliases" do
      AzuCLI::Generator::Core::GeneratorFactory.exists?("m").should be_true
      AzuCLI::Generator::Core::GeneratorFactory.exists?("s").should be_true
      AzuCLI::Generator::Core::GeneratorFactory.exists?("sc").should be_true
    end

    it "returns false for invalid generator types" do
      AzuCLI::Generator::Core::GeneratorFactory.exists?("unknown").should be_false
      AzuCLI::Generator::Core::GeneratorFactory.exists?("invalid").should be_false
    end
  end

  describe ".aliases_for" do
    it "returns aliases for model generator" do
      aliases = AzuCLI::Generator::Core::GeneratorFactory.aliases_for("model")
      aliases.should contain("m")
    end

    it "returns aliases for service generator" do
      aliases = AzuCLI::Generator::Core::GeneratorFactory.aliases_for("service")
      aliases.should contain("s")
    end

    it "returns aliases for scaffold generator" do
      aliases = AzuCLI::Generator::Core::GeneratorFactory.aliases_for("scaffold")
      aliases.should contain("sc")
      aliases.should contain("scaffold")
    end
  end

  describe "GeneratorOptions" do
    describe ".from_args" do
      it "parses basic arguments" do
        args = {"force" => "true", "skip-tests" => "true"}
        positional = ["generate", "model", "User", "name:string", "email:string"]

        options = AzuCLI::Generator::Core::GeneratorOptions.from_args(args, positional)

        options.force.should be_true
        options.skip_tests.should be_true
        options.attributes.should eq({"name" => "string", "email" => "string"})
      end

      it "extracts attributes correctly" do
        args = {} of String => String | Array(String)
        positional = ["generate", "model", "User", "name:string", "age:integer", "active:boolean"]

        options = AzuCLI::Generator::Core::GeneratorOptions.from_args(args, positional)

        expected_attributes = {"name" => "string", "age" => "integer", "active" => "boolean"}
        options.attributes.should eq(expected_attributes)
      end

      it "handles additional arguments" do
        args = {} of String => String | Array(String)
        positional = ["generate", "service", "UserService", "create", "update", "delete"]

        options = AzuCLI::Generator::Core::GeneratorOptions.from_args(args, positional)

        options.additional_args.should eq(["create", "update", "delete"])
      end

      it "extracts custom options" do
        args = {"type" => "crud", "interface" => "true"}
        positional = ["generate", "service", "UserService"]

        options = AzuCLI::Generator::Core::GeneratorOptions.from_args(args, positional)

        options.custom_options["type"].should eq("crud")
        options.custom_options["interface"].should eq("true")
      end
    end
  end
end
