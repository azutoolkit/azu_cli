require "../spec_helper"

# Concrete implementation for testing AbstractGenerator
class TestGenerator < AzuCLI::Generator::Core::AbstractGenerator
  def generator_type : String
    "test"
  end

  def generate_files : Nil
    create_file_from_template("test.cr.ecr", "src/test.cr", {"name" => name}, "test file")
  end
end

describe AzuCLI::Generator::Core::AbstractGenerator do
  describe "initialization" do
    it "initializes with required parameters" do
      generator = TestGenerator.new("TestName", "test_project", false, false)

      generator.name.should eq("TestName")
      generator.project_name.should eq("test_project")
      generator.force.should be_false
      generator.skip_tests.should be_false
    end

    it "sets force and skip_tests flags" do
      generator = TestGenerator.new("TestName", "test_project", true, true)

      generator.force.should be_true
      generator.skip_tests.should be_true
    end
  end

  describe "naming helpers" do
    it "converts to snake_case" do
      generator = TestGenerator.new("UserProfile", "test_project", false, false)
      generator.snake_case_name.should eq("user_profile")
    end

    it "converts to class_name (PascalCase)" do
      generator = TestGenerator.new("user_profile", "test_project", false, false)
      generator.class_name.should eq("UserProfile")
    end

    it "converts to plural_name" do
      generator = TestGenerator.new("User", "test_project", false, false)
      generator.plural_name.should eq("users")
    end

    it "handles complex names" do
      generator = TestGenerator.new("UserAccountSetting", "test_project", false, false)

      generator.snake_case_name.should eq("user_account_setting")
      generator.class_name.should eq("UserAccountSetting")
      generator.plural_name.should eq("user_account_settings")
    end
  end

  describe "configuration loading" do
    it "loads configuration for generator type" do
      with_temp_directory do
        create_mock_project

        generator = TestGenerator.new("TestName", "test_project", false, false)
        config = generator.config

        config.should be_a(AzuCLI::Generator::Core::Configuration)
      end
    end
  end

  describe "template variables" do
    it "generates default template variables" do
      generator = TestGenerator.new("UserProfile", "test_project", false, false)
      variables = generator.default_template_variables

      variables["name"].should eq("UserProfile")
      variables["snake_case_name"].should eq("user_profile")
      variables["class_name"].should eq("UserProfile")
      variables["plural_name"].should eq("user_profiles")
      variables["project_name"].should eq("test_project")
    end
  end

  describe "file operations" do
    it "creates directories" do
      with_temp_directory do
        create_mock_project

        generator = TestGenerator.new("TestName", "test_project", false, false)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.create_directories

        mock_strategy.created_directories.should_not be_empty
      end
    end

    it "creates files from templates" do
      with_temp_directory do
        create_mock_project

        generator = TestGenerator.new("TestName", "test_project", false, false)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        # Mock template content
        variables = {"name" => "TestName"}
        generator.create_file_from_template("test.cr.ecr", "src/test.cr", variables, "test file")

        mock_strategy.created_files.should contain("src/test.cr")
      end
    end
  end

  describe "validation" do
    it "validates preconditions" do
      generator = TestGenerator.new("TestName", "test_project", false, false)

      # Should not raise any exceptions for valid input
      generator.validate_input!
    end

    it "raises error for invalid names" do
      expect_raises(ArgumentError, "Invalid generator name") do
        TestGenerator.new("", "test_project", false, false)
      end
    end

    it "raises error for invalid project names" do
      expect_raises(ArgumentError, "Invalid project name") do
        TestGenerator.new("TestName", "", false, false)
      end
    end
  end

  describe "generation workflow" do
    it "executes complete generation workflow" do
      with_temp_directory do
        create_mock_project

        generator = TestGenerator.new("TestName", "test_project", false, false)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        # Should have created directories and files
        mock_strategy.created_directories.should_not be_empty
      end
    end

    it "skips tests when skip_tests is true" do
      with_temp_directory do
        create_mock_project

        generator = TestGenerator.new("TestName", "test_project", false, true)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        # Should not have created test files
        test_files = mock_strategy.created_files.select { |f| f.includes?("spec/") }
        test_files.should be_empty
      end
    end
  end

  describe "success reporting" do
    it "provides success message" do
      generator = TestGenerator.new("TestName", "test_project", false, false)
      message = generator.success_message

      message.should contain("TestName")
      message.should contain("generated")
    end

    it "handles post generation tasks" do
      generator = TestGenerator.new("TestName", "test_project", false, false)

      # Should not raise any exceptions
      generator.post_generation_tasks
    end
  end
end
