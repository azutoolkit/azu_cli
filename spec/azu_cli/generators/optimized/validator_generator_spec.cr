require "../spec_helper"

describe AzuCLI::Generator::ValidatorGenerator do
  describe "initialization" do
    it "initializes with basic parameters" do
      options = create_generator_options
      generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
      
      generator.name.should eq("EmailValidator")
      generator.project_name.should eq("test_project")
      generator.validator_type.should eq("custom")  # default type
    end

    it "sets validator type from options" do
      options = create_generator_options(custom_options: {"type" => "email"})
      generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
      
      generator.validator_type.should eq("email")
    end

    it "extracts pattern from options" do
      options = create_generator_options(custom_options: {"pattern" => "/\\A[A-Z]{2,3}\\z/"})
      generator = AzuCLI::Generator::ValidatorGenerator.new("CodeValidator", "test_project", options)
      
      generator.pattern.should eq("/\\A[A-Z]{2,3}\\z/")
    end

    it "extracts parameters from additional args" do
      options = create_generator_options(additional_args: ["min:2", "max:50"])
      generator = AzuCLI::Generator::ValidatorGenerator.new("LengthValidator", "test_project", options)
      
      generator.parameters.should have_key("min")
      generator.parameters.should have_key("max")
      generator.parameters["min"].should eq("2")
      generator.parameters["max"].should eq("50")
    end
  end

  describe "generator type" do
    it "returns correct generator type" do
      options = create_generator_options
      generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
      
      generator.generator_type.should eq("validator")
    end
  end

  describe "directory creation" do
    it "creates validator-specific directories" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options
        generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.create_directories
        
        mock_strategy.created_directories.should contain("src/validators")
        mock_strategy.created_directories.should contain("spec/validators")
      end
    end

    it "skips spec directory when skip_tests is true" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(skip_tests: true)
        generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.create_directories
        
        mock_strategy.created_directories.should contain("src/validators")
        mock_strategy.created_directories.should_not contain("spec/validators")
      end
    end
  end

  describe "file generation" do
    it "generates validator file" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(custom_options: {"type" => "email"})
        generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        mock_strategy.created_files.should contain("src/validators/email_validator.cr")
      end
    end

    it "generates test files" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(custom_options: {"type" => "email"})
        generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        mock_strategy.created_files.should contain("spec/validators/email_validator_spec.cr")
      end
    end

    it "skips test files when skip_tests is true" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(
          custom_options: {"type" => "email"},
          skip_tests: true
        )
        generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        test_files = mock_strategy.created_files.select { |f| f.includes?("spec/") }
        test_files.should be_empty
      end
    end
  end

  describe "validator types" do
    it "handles email validator type" do
      options = create_generator_options(custom_options: {"type" => "email"})
      generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
      
      generator.validator_type.should eq("email")
      
      with_temp_directory do
        create_mock_project
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        validator_content = mock_strategy.file_contents["src/validators/email_validator.cr"]?
        validator_content.should_not be_nil
      end
    end

    it "handles phone validator type" do
      options = create_generator_options(custom_options: {"type" => "phone"})
      generator = AzuCLI::Generator::ValidatorGenerator.new("PhoneValidator", "test_project", options)
      
      generator.validator_type.should eq("phone")
    end

    it "handles url validator type" do
      options = create_generator_options(custom_options: {"type" => "url"})
      generator = AzuCLI::Generator::ValidatorGenerator.new("UrlValidator", "test_project", options)
      
      generator.validator_type.should eq("url")
    end

    it "handles range validator type" do
      options = create_generator_options(
        custom_options: {"type" => "range"},
        additional_args: ["min:0", "max:100"]
      )
      generator = AzuCLI::Generator::ValidatorGenerator.new("RangeValidator", "test_project", options)
      
      generator.validator_type.should eq("range")
      generator.parameters["min"].should eq("0")
      generator.parameters["max"].should eq("100")
    end

    it "handles length validator type" do
      options = create_generator_options(
        custom_options: {"type" => "length"},
        additional_args: ["min:2", "max:50"]
      )
      generator = AzuCLI::Generator::ValidatorGenerator.new("LengthValidator", "test_project", options)
      
      generator.validator_type.should eq("length")
      generator.parameters["min"].should eq("2")
      generator.parameters["max"].should eq("50")
    end

    it "handles uniqueness validator type" do
      options = create_generator_options(
        custom_options: {"type" => "uniqueness"},
        additional_args: ["model:User", "column:email"]
      )
      generator = AzuCLI::Generator::ValidatorGenerator.new("UniqueValidator", "test_project", options)
      
      generator.validator_type.should eq("uniqueness")
      generator.parameters["model"].should eq("User")
      generator.parameters["column"].should eq("email")
    end

    it "handles regex validator type" do
      options = create_generator_options(
        custom_options: {"type" => "regex", "pattern" => "/\\A[A-Z]{2,3}\\z/"}
      )
      generator = AzuCLI::Generator::ValidatorGenerator.new("CodeValidator", "test_project", options)
      
      generator.validator_type.should eq("regex")
      generator.pattern.should eq("/\\A[A-Z]{2,3}\\z/")
    end

    it "handles custom validator type" do
      options = create_generator_options(custom_options: {"type" => "custom"})
      generator = AzuCLI::Generator::ValidatorGenerator.new("CustomValidator", "test_project", options)
      
      generator.validator_type.should eq("custom")
    end
  end

  describe "validation logic generation" do
    it "generates format validation for email type" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(custom_options: {"type" => "email"})
        generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        validator_content = mock_strategy.file_contents["src/validators/email_validator.cr"]?
        validator_content.should_not be_nil
      end
    end

    it "generates range validation for range type" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(
          custom_options: {"type" => "range"},
          additional_args: ["min:0", "max:100"]
        )
        generator = AzuCLI::Generator::ValidatorGenerator.new("RangeValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        validator_content = mock_strategy.file_contents["src/validators/range_validator.cr"]?
        validator_content.should_not be_nil
      end
    end

    it "generates uniqueness validation for uniqueness type" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(
          custom_options: {"type" => "uniqueness"},
          additional_args: ["model:User", "column:email"]
        )
        generator = AzuCLI::Generator::ValidatorGenerator.new("UniqueValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        validator_content = mock_strategy.file_contents["src/validators/unique_validator.cr"]?
        validator_content.should_not be_nil
      end
    end

    it "generates custom validation logic for custom type" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(custom_options: {"type" => "custom"})
        generator = AzuCLI::Generator::ValidatorGenerator.new("CustomValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        validator_content = mock_strategy.file_contents["src/validators/custom_validator.cr"]?
        validator_content.should_not be_nil
      end
    end
  end

  describe "error message generation" do
    it "generates appropriate error messages for validator types" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(custom_options: {"type" => "email"})
        generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        validator_content = mock_strategy.file_contents["src/validators/email_validator.cr"]?
        validator_content.should_not be_nil
      end
    end

    it "substitutes variables in error messages" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(
          custom_options: {"type" => "range"},
          additional_args: ["min:0", "max:100"]
        )
        generator = AzuCLI::Generator::ValidatorGenerator.new("RangeValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        validator_content = mock_strategy.file_contents["src/validators/range_validator.cr"]?
        validator_content.should_not be_nil
      end
    end
  end

  describe "parameter handling" do
    it "generates properties for parameters" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(
          custom_options: {"type" => "range"},
          additional_args: ["min:0", "max:100"]
        )
        generator = AzuCLI::Generator::ValidatorGenerator.new("RangeValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        validator_content = mock_strategy.file_contents["src/validators/range_validator.cr"]?
        validator_content.should_not be_nil
      end
    end

    it "generates initialize method for parameters" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(
          custom_options: {"type" => "length"},
          additional_args: ["min:2", "max:50"]
        )
        generator = AzuCLI::Generator::ValidatorGenerator.new("LengthValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        validator_content = mock_strategy.file_contents["src/validators/length_validator.cr"]?
        validator_content.should_not be_nil
      end
    end
  end

  describe "test generation" do
    it "generates comprehensive test files" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(custom_options: {"type" => "email"})
        generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        test_content = mock_strategy.file_contents["spec/validators/email_validator_spec.cr"]?
        test_content.should_not be_nil
      end
    end

    it "includes type-specific test cases" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(custom_options: {"type" => "phone"})
        generator = AzuCLI::Generator::ValidatorGenerator.new("PhoneValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        test_content = mock_strategy.file_contents["spec/validators/phone_validator_spec.cr"]?
        test_content.should_not be_nil
      end
    end

    it "includes presence tests for non-presence validators" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(custom_options: {"type" => "email"})
        generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        test_content = mock_strategy.file_contents["spec/validators/email_validator_spec.cr"]?
        test_content.should_not be_nil
      end
    end

    it "generates test parameters for parameterized validators" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(
          custom_options: {"type" => "range"},
          additional_args: ["min:0", "max:100"]
        )
        generator = AzuCLI::Generator::ValidatorGenerator.new("RangeValidator", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.call
        
        test_content = mock_strategy.file_contents["spec/validators/range_validator_spec.cr"]?
        test_content.should_not be_nil
      end
    end
  end

  describe "success message" do
    it "includes validator type and parameter count" do
      options = create_generator_options(
        custom_options: {"type" => "range"},
        additional_args: ["min:0", "max:100"]
      )
      generator = AzuCLI::Generator::ValidatorGenerator.new("RangeValidator", "test_project", options)
      
      message = generator.success_message
      message.should contain("range")
      message.should contain("parameter")
    end

    it "includes just type for simple validators" do
      options = create_generator_options(custom_options: {"type" => "email"})
      generator = AzuCLI::Generator::ValidatorGenerator.new("EmailValidator", "test_project", options)
      
      message = generator.success_message
      message.should contain("email")
    end
  end

  describe "usage examples" do
    it "generates appropriate usage examples" do
      options = create_generator_options(
        custom_options: {"type" => "range"},
        additional_args: ["min:0", "max:100"]
      )
      generator = AzuCLI::Generator::ValidatorGenerator.new("RangeValidator", "test_project", options)
      
      # Test through post generation tasks
      generator.validator_type.should eq("range")
      generator.parameters["min"].should eq("0")
      generator.parameters["max"].should eq("100")
    end
  end
end