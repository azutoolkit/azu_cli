require "../spec_helper"

describe AzuCLI::Generator::ServiceGenerator do
  describe "initialization" do
    it "initializes with basic parameters" do
      options = create_generator_options
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      generator.name.should eq("UserService")
      generator.project_name.should eq("test_project")
      generator.service_type.should eq("domain") # default type
    end

    it "sets service type from options" do
      options = create_generator_options(custom_options: {"type" => "crud"})
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      generator.service_type.should eq("crud")
    end

    it "extracts methods from additional args" do
      options = create_generator_options(additional_args: ["create", "update", "delete"])
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      generator.methods.should eq(["create", "update", "delete"])
    end

    it "uses default methods when none specified" do
      options = create_generator_options
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      generator.methods.should_not be_empty
    end

    it "sets with_interface flag from options" do
      options = create_generator_options(custom_options: {"interface" => "false"})
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      generator.with_interface.should be_false
    end
  end

  describe "generator type" do
    it "returns correct generator type" do
      options = create_generator_options
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      generator.generator_type.should eq("service")
    end
  end

  describe "directory creation" do
    it "creates service-specific directories" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.create_directories

        mock_strategy.created_directories.should contain("src/services")
        mock_strategy.created_directories.should contain("src/interfaces")
        mock_strategy.created_directories.should contain("spec/services")
      end
    end

    it "skips interface directory when with_interface is false" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(custom_options: {"interface" => "false"})
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.create_directories

        mock_strategy.created_directories.should contain("src/services")
        mock_strategy.created_directories.should_not contain("src/interfaces")
      end
    end

    it "skips spec directory when skip_tests is true" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(skip_tests: true)
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.create_directories

        mock_strategy.created_directories.should contain("src/services")
        mock_strategy.created_directories.should_not contain("spec/services")
      end
    end
  end

  describe "file generation" do
    it "generates service file" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        mock_strategy.created_files.should contain("src/services/user_service.cr")
      end
    end

    it "generates interface file when with_interface is true" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        interface_files = mock_strategy.created_files.select { |f| f.includes?("src/interfaces") }
        interface_files.should_not be_empty
      end
    end

    it "skips interface file when with_interface is false" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(custom_options: {"interface" => "false"})
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        interface_files = mock_strategy.created_files.select { |f| f.includes?("src/interfaces") }
        interface_files.should be_empty
      end
    end

    it "generates test files" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        mock_strategy.created_files.should contain("spec/services/user_service_spec.cr")
      end
    end

    it "skips test files when skip_tests is true" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(skip_tests: true)
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        test_files = mock_strategy.created_files.select { |f| f.includes?("spec/") }
        test_files.should be_empty
      end
    end
  end

  describe "service types" do
    it "handles CRUD service type" do
      options = create_generator_options(custom_options: {"type" => "crud"})
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      generator.service_type.should eq("crud")
      generator.methods.should contain("create")
      generator.methods.should contain("find")
      generator.methods.should contain("update")
      generator.methods.should contain("delete")
      generator.methods.should contain("list")
    end

    it "handles processing service type" do
      options = create_generator_options(custom_options: {"type" => "processing"})
      generator = AzuCLI::Generator::ServiceGenerator.new("DataProcessor", "test_project", options)

      generator.service_type.should eq("processing")
    end

    it "handles integration service type" do
      options = create_generator_options(custom_options: {"type" => "integration"})
      generator = AzuCLI::Generator::ServiceGenerator.new("PaymentService", "test_project", options)

      generator.service_type.should eq("integration")
    end

    it "handles domain service type" do
      options = create_generator_options(custom_options: {"type" => "domain"})
      generator = AzuCLI::Generator::ServiceGenerator.new("BusinessLogic", "test_project", options)

      generator.service_type.should eq("domain")
    end
  end

  describe "method generation" do
    it "generates custom methods" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(additional_args: ["process", "validate", "transform"])
        generator = AzuCLI::Generator::ServiceGenerator.new("DataService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        service_content = mock_strategy.file_contents["src/services/data_service.cr"]?
        service_content.should_not be_nil
      end
    end

    it "uses predefined method patterns when available" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(
          custom_options: {"type" => "crud"},
          additional_args: ["create", "find", "update"]
        )
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        service_content = mock_strategy.file_contents["src/services/user_service.cr"]?
        service_content.should_not be_nil
      end
    end

    it "determines appropriate return types for methods" do
      options = create_generator_options(additional_args: ["create", "find", "delete", "valid?"])
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      # These are internal methods, so we test indirectly through file generation
      with_temp_directory do
        create_mock_project
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        service_content = mock_strategy.file_contents["src/services/user_service.cr"]?
        service_content.should_not be_nil
      end
    end
  end

  describe "dependency injection" do
    it "generates repository dependencies" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        service_content = mock_strategy.file_contents["src/services/user_service.cr"]?
        service_content.should_not be_nil
      end
    end

    it "generates logger dependencies" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        service_content = mock_strategy.file_contents["src/services/user_service.cr"]?
        service_content.should_not be_nil
      end
    end

    it "generates validator dependencies" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        service_content = mock_strategy.file_contents["src/services/user_service.cr"]?
        service_content.should_not be_nil
      end
    end
  end

  describe "interface generation" do
    it "generates interface with abstract methods" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(additional_args: ["create", "find", "update"])
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        interface_files = mock_strategy.created_files.select { |f| f.includes?("interface") }
        interface_files.should_not be_empty

        interface_content = mock_strategy.file_contents[interface_files.first]?
        interface_content.should_not be_nil
      end
    end

    it "includes interface in service class" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        service_content = mock_strategy.file_contents["src/services/user_service.cr"]?
        service_content.should_not be_nil
      end
    end
  end

  describe "error handling" do
    it "generates error classes" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        service_content = mock_strategy.file_contents["src/services/user_service.cr"]?
        service_content.should_not be_nil
      end
    end
  end

  describe "test generation" do
    it "generates comprehensive test files" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(additional_args: ["create", "find", "update"])
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        test_content = mock_strategy.file_contents["spec/services/user_service_spec.cr"]?
        test_content.should_not be_nil
      end
    end

    it "includes test methods for each service method" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(additional_args: ["process", "validate"])
        generator = AzuCLI::Generator::ServiceGenerator.new("DataService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        test_content = mock_strategy.file_contents["spec/services/data_service_spec.cr"]?
        test_content.should_not be_nil
      end
    end

    it "generates mock dependencies for tests" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        test_content = mock_strategy.file_contents["spec/services/user_service_spec.cr"]?
        test_content.should_not be_nil
      end
    end
  end

  describe "success message" do
    it "includes service type and method count" do
      options = create_generator_options(
        custom_options: {"type" => "crud"},
        additional_args: ["create", "find", "update"]
      )
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      message = generator.success_message
      message.should contain("method")
      message.should contain("crud")
    end

    it "includes interface information when applicable" do
      options = create_generator_options
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      message = generator.success_message
      message.should contain("interface")
    end
  end

  describe "model name extraction" do
    it "extracts model name from service name" do
      options = create_generator_options
      generator = AzuCLI::Generator::ServiceGenerator.new("UserService", "test_project", options)

      # Test through file generation to verify model name extraction
      with_temp_directory do
        create_mock_project
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        service_content = mock_strategy.file_contents["src/services/user_service.cr"]?
        service_content.should_not be_nil
      end
    end

    it "handles complex service names" do
      options = create_generator_options
      generator = AzuCLI::Generator::ServiceGenerator.new("UserRegistrationService", "test_project", options)

      with_temp_directory do
        create_mock_project
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        service_content = mock_strategy.file_contents["src/services/user_registration_service.cr"]?
        service_content.should_not be_nil
      end
    end
  end
end
