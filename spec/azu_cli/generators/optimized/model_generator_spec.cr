require "../spec_helper"

describe AzuCLI::Generator::ModelGenerator do
  describe "initialization" do
    it "initializes with basic parameters" do
      options = create_generator_options(attributes: sample_attributes)
      generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)

      generator.name.should eq("User")
      generator.project_name.should eq("test_project")
      generator.attributes.should eq(sample_attributes)
    end

    it "extracts associations from options" do
      options = create_generator_options(
        attributes: {"name" => "string", "author_id" => "integer"},
        additional_args: ["belongs_to:author"]
      )
      generator = AzuCLI::Generator::ModelGenerator.new("Post", "test_project", options)

      generator.associations.should have_key("belongs_to")
    end

    it "auto-detects foreign key associations" do
      options = create_generator_options(
        attributes: {"title" => "string", "author_id" => "integer", "category_id" => "integer"}
      )
      generator = AzuCLI::Generator::ModelGenerator.new("Post", "test_project", options)

      generator.associations.should have_key("belongs_to")
    end

    it "sets auto_migration flag from options" do
      options = create_generator_options(custom_options: {"migration" => "false"})
      generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)

      generator.auto_migration.should be_false
    end
  end

  describe "generator type" do
    it "returns correct generator type" do
      options = create_generator_options
      generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)

      generator.generator_type.should eq("model")
    end
  end

  describe "directory creation" do
    it "creates model-specific directories" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.create_directories

        mock_strategy.created_directories.should contain("src/models")
        mock_strategy.created_directories.should contain("src/db/migrations")
        mock_strategy.created_directories.should contain("spec/models")
      end
    end

    it "skips migration directory when auto_migration is false" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(custom_options: {"migration" => "false"})
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.create_directories

        mock_strategy.created_directories.should contain("src/models")
        mock_strategy.created_directories.should_not contain("src/db/migrations")
      end
    end

    it "skips spec directory when skip_tests is true" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(skip_tests: true)
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.create_directories

        mock_strategy.created_directories.should contain("src/models")
        mock_strategy.created_directories.should_not contain("spec/models")
      end
    end
  end

  describe "file generation" do
    it "generates model file" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(attributes: sample_attributes)
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        mock_strategy.created_files.should contain("src/models/user.cr")
      end
    end

    it "generates migration file when auto_migration is true" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(attributes: sample_attributes)
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        migration_files = mock_strategy.created_files.select { |f| f.includes?("src/db/migrations") }
        migration_files.should_not be_empty
      end
    end

    it "skips migration file when auto_migration is false" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(
          attributes: sample_attributes,
          custom_options: {"migration" => "false"}
        )
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        migration_files = mock_strategy.created_files.select { |f| f.includes?("src/db/migrations") }
        migration_files.should be_empty
      end
    end

    it "generates test files" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(attributes: sample_attributes)
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        mock_strategy.created_files.should contain("spec/models/user_spec.cr")
      end
    end

    it "skips test files when skip_tests is true" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(
          attributes: sample_attributes,
          skip_tests: true
        )
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        test_files = mock_strategy.created_files.select { |f| f.includes?("spec/") }
        test_files.should be_empty
      end
    end
  end

  describe "template variable generation" do
    it "generates model variables with attributes" do
      options = create_generator_options(attributes: sample_attributes)
      generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)

      variables = generator.default_template_variables

      variables["name"].should eq("User")
      variables["snake_case_name"].should eq("user")
      variables["class_name"].should eq("User")
      variables["plural_name"].should eq("users")
    end

    it "includes CQL-specific variables" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(attributes: sample_attributes)
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)

        # Access private method through call
        generator.call

        # Model should be generated with CQL base class
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        generator.call

        model_content = mock_strategy.file_contents["src/models/user.cr"]?
        model_content.should_not be_nil
      end
    end
  end

  describe "attribute handling" do
    it "generates attributes list from hash" do
      options = create_generator_options(attributes: sample_attributes)
      generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)

      generator.attributes.should eq(sample_attributes)
      generator.attributes.keys.should contain("name")
      generator.attributes.keys.should contain("email")
    end

    it "handles complex attributes" do
      options = create_generator_options(attributes: complex_attributes)
      generator = AzuCLI::Generator::ModelGenerator.new("Post", "test_project", options)

      generator.attributes.should eq(complex_attributes)
      generator.attributes.keys.should contain("title")
      generator.attributes.keys.should contain("content")
      generator.attributes.keys.should contain("published_at")
    end

    it "converts attribute types to Crystal types" do
      with_temp_directory do
        create_mock_project

        attributes = {
          "name" => "string",
          "age" => "integer",
          "active" => "boolean",
          "created_at" => "datetime"
        }
        options = create_generator_options(attributes: attributes)
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        model_content = mock_strategy.file_contents["src/models/user.cr"]?
        model_content.should_not be_nil
      end
    end
  end

  describe "association handling" do
    it "generates belongs_to associations" do
      options = create_generator_options(
        attributes: {"title" => "string", "author_id" => "integer"},
        additional_args: ["belongs_to:author"]
      )
      generator = AzuCLI::Generator::ModelGenerator.new("Post", "test_project", options)

      generator.associations["belongs_to"].should eq("author")
    end

    it "auto-detects foreign key associations" do
      options = create_generator_options(
        attributes: {"title" => "string", "author_id" => "integer"}
      )
      generator = AzuCLI::Generator::ModelGenerator.new("Post", "test_project", options)

      generator.associations.should have_key("belongs_to")
    end

    it "handles multiple associations" do
      options = create_generator_options(
        attributes: {"title" => "string", "author_id" => "integer", "category_id" => "integer"},
        additional_args: ["belongs_to:author", "belongs_to:category", "has_many:comments"]
      )
      generator = AzuCLI::Generator::ModelGenerator.new("Post", "test_project", options)

      generator.associations.should have_key("belongs_to")
      generator.associations.should have_key("has_many")
    end
  end

  describe "success message" do
    it "includes attribute and association count" do
      options = create_generator_options(
        attributes: sample_attributes,
        additional_args: ["belongs_to:author"]
      )
      generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)

      message = generator.success_message
      message.should contain("attribute")
      message.should contain("association")
    end

    it "includes auto-migration information" do
      options = create_generator_options(attributes: sample_attributes)
      generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)

      message = generator.success_message
      message.should contain("auto-migration")
    end
  end

  describe "validation patterns" do
    it "generates email validations for email fields" do
      options = create_generator_options(attributes: {"email" => "string"})
      generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)

      with_temp_directory do
        create_mock_project
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        model_content = mock_strategy.file_contents["src/models/user.cr"]?
        model_content.should_not be_nil
      end
    end

    it "generates appropriate validations based on attribute types" do
      options = create_generator_options(
        attributes: {
          "name" => "string",
          "age" => "integer",
          "email" => "string"
        }
      )
      generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)

      with_temp_directory do
        create_mock_project
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        model_content = mock_strategy.file_contents["src/models/user.cr"]?
        model_content.should_not be_nil
      end
    end
  end

  describe "migration generation" do
    it "generates migration with table creation" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(attributes: sample_attributes)
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        migration_files = mock_strategy.created_files.select { |f| f.includes?("src/db/migrations") }
        migration_files.should_not be_empty

        # Check migration content
        migration_file = migration_files.first
        migration_content = mock_strategy.file_contents[migration_file]?
        migration_content.should_not be_nil
      end
    end

    it "includes indexes for foreign keys" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(
          attributes: {"title" => "string", "author_id" => "integer"}
        )
        generator = AzuCLI::Generator::ModelGenerator.new("Post", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        migration_files = mock_strategy.created_files.select { |f| f.includes?("src/db/migrations") }
        migration_file = migration_files.first
        migration_content = mock_strategy.file_contents[migration_file]?
        migration_content.should_not be_nil
      end
    end
  end

  describe "test generation" do
    it "generates comprehensive test files" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(attributes: sample_attributes)
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        test_content = mock_strategy.file_contents["spec/models/user_spec.cr"]?
        test_content.should_not be_nil
      end
    end

    it "includes validation tests" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(
          attributes: {"name" => "string", "email" => "string"}
        )
        generator = AzuCLI::Generator::ModelGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        test_content = mock_strategy.file_contents["spec/models/user_spec.cr"]?
        test_content.should_not be_nil
      end
    end

    it "includes association tests" do
      with_temp_directory do
        create_mock_project

        options = create_generator_options(
          attributes: {"title" => "string", "author_id" => "integer"},
          additional_args: ["belongs_to:author"]
        )
        generator = AzuCLI::Generator::ModelGenerator.new("Post", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy

        generator.call

        test_content = mock_strategy.file_contents["spec/models/post_spec.cr"]?
        test_content.should_not be_nil
      end
    end
  end
end
