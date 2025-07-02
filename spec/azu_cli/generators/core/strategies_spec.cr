require "../spec_helper"

describe AzuCLI::Generator::Core::EcrTemplateStrategy do
  describe "template rendering" do
    it "renders ECR templates with variables" do
      strategy = AzuCLI::Generator::Core::EcrTemplateStrategy.new

      template_content = <<-ECR
      class {{class_name}}
        def initialize(name : String)
          @name = name
        end

        def greeting
          "Hello, \#{@name}!"
        end
      end
      ECR

      variables = {"class_name" => "TestClass"}
      result = strategy.render(template_content, variables)

      result.should contain("class TestClass")
      result.should contain("def initialize(name : String)")
    end

    it "handles missing template variables gracefully" do
      strategy = AzuCLI::Generator::Core::EcrTemplateStrategy.new

      template_content = <<-ECR
      class {{class_name}}
      end
      ECR

      variables = {} of String => String
      result = strategy.render(template_content, variables)

      # Variables that aren't replaced remain as placeholders
      result.should contain("{{class_name}}")
    end

    it "renders nested template variables" do
      strategy = AzuCLI::Generator::Core::EcrTemplateStrategy.new

      template_content = <<-ECR
      module {{module_name}}
        class {{class_name}}
          property {{property_name}} : {{property_type}}
        end
      end
      ECR

      variables = {
        "module_name"   => "TestModule",
        "class_name"    => "TestClass",
        "property_name" => "name",
        "property_type" => "String",
      }

      result = strategy.render(template_content, variables)

      result.should contain("module TestModule")
      result.should contain("class TestClass")
      result.should contain("property name : String")
    end

    it "supports template type checking" do
      strategy = AzuCLI::Generator::Core::EcrTemplateStrategy.new

      strategy.supports?("ecr").should be_true
      strategy.supports?("template.ecr").should be_true
      strategy.supports?("txt").should be_false
    end
  end
end

describe AzuCLI::Generator::Core::StandardFileCreationStrategy do
  describe "file operations" do
    it "creates files with content" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::StandardFileCreationStrategy.new(verbose: false)

        content = "# This is a test file\nputs \"Hello, World!\""
        result = strategy.create_file("test.cr", content, {"description" => "test file"})

        result.should be_true
        File.exists?("test.cr").should be_true
        File.read("test.cr").should eq(content)
      end
    end

    it "creates directories" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::StandardFileCreationStrategy.new(verbose: false)

        result = strategy.create_directory("src/test")

        result.should be_true
        Dir.exists?("src/test").should be_true
      end
    end

    it "creates nested directories" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::StandardFileCreationStrategy.new(verbose: false)

        result = strategy.create_directory("src/deep/nested/directory")

        result.should be_true
        Dir.exists?("src/deep/nested/directory").should be_true
      end
    end

    it "checks if files exist" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::StandardFileCreationStrategy.new(verbose: false)

        File.write("existing.cr", "content")

        strategy.file_exists?("existing.cr").should be_true
        strategy.file_exists?("nonexistent.cr").should be_false
      end
    end

    it "checks if directories exist" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::StandardFileCreationStrategy.new(verbose: false)

        Dir.mkdir_p("existing_dir")

        strategy.directory_exists?("existing_dir").should be_true
        strategy.directory_exists?("nonexistent_dir").should be_false
      end
    end
  end

  describe "file overwrite protection" do
    it "prevents overwriting existing files by default" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::StandardFileCreationStrategy.new(verbose: false)

        File.write("existing.cr", "original content")

        result = strategy.create_file("existing.cr", "new content", {"description" => "test file"})
        result.should be_false
        File.read("existing.cr").should eq("original content")
      end
    end

    it "allows forced overwriting of existing files" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::StandardFileCreationStrategy.new(force: true, verbose: false)

        File.write("existing.cr", "original content")
        result = strategy.create_file("existing.cr", "new content", {"description" => "test file"})

        result.should be_true
        File.read("existing.cr").should eq("new content")
      end
    end
  end
end

describe AzuCLI::Generator::Core::StandardValidationStrategy do
  describe "validation" do
    it "validates with empty configuration" do
      config = AzuCLI::Generator::Core::Configuration.new("test")
      strategy = AzuCLI::Generator::Core::StandardValidationStrategy.new(config)

      errors = strategy.validate("TestName", {} of String => String)
      errors.should be_empty
    end

    it "validates according to configuration rules" do
      with_temp_directory do
        # Create a test config file
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/base.yml", <<-YAML
        validations:
          name:
            pattern: "^[A-Z][a-zA-Z0-9_]*$"
            message: "Name must start with uppercase letter"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.load("test", "src/azu_cli/generators/config")
        strategy = AzuCLI::Generator::Core::StandardValidationStrategy.new(config)

        # Valid name
        errors = strategy.validate("TestName", {} of String => String)
        errors.should be_empty

        # Invalid name
        errors = strategy.validate("testName", {} of String => String)
        errors.should_not be_empty
        errors.first.should eq("Name must start with uppercase letter")
      end
    end
  end
end

describe AzuCLI::Generator::Core::StandardNamingStrategy do
  describe "case conversions" do
    it "converts to snake_case" do
      strategy = AzuCLI::Generator::Core::StandardNamingStrategy.new

      strategy.snake_case_name("UserProfile").should eq("user_profile")
      strategy.snake_case_name("XMLHttpRequest").should eq("xml_http_request")
      strategy.snake_case_name("HTMLParser").should eq("html_parser")
    end

    it "converts to PascalCase" do
      strategy = AzuCLI::Generator::Core::StandardNamingStrategy.new

      strategy.class_name("user_profile").should eq("UserProfile")
      strategy.class_name("xml_http_request").should eq("XmlHttpRequest")
      strategy.class_name("html_parser").should eq("HtmlParser")
    end

    it "converts to kebab-case" do
      strategy = AzuCLI::Generator::Core::StandardNamingStrategy.new

      strategy.kebab_case_name("UserProfile").should eq("user-profile")
      strategy.kebab_case_name("XMLHttpRequest").should eq("xml-http-request")
    end

    it "handles module names" do
      strategy = AzuCLI::Generator::Core::StandardNamingStrategy.new

      strategy.module_name("my_project").should eq("MyProject")
      strategy.module_name("test-project").should eq("TestProject")
    end
  end

  describe "pluralization" do
    it "pluralizes regular nouns" do
      strategy = AzuCLI::Generator::Core::StandardNamingStrategy.new

      strategy.plural_name("user").should eq("users")
      strategy.plural_name("post").should eq("posts")
      strategy.plural_name("comment").should eq("comments")
    end

    it "handles words ending in s, sh, ch, x, z" do
      strategy = AzuCLI::Generator::Core::StandardNamingStrategy.new

      strategy.plural_name("class").should eq("classes")
      strategy.plural_name("dish").should eq("dishes")
      strategy.plural_name("church").should eq("churches")
      strategy.plural_name("box").should eq("boxes")
      strategy.plural_name("quiz").should eq("quizzes")
    end

    it "handles words ending in y" do
      strategy = AzuCLI::Generator::Core::StandardNamingStrategy.new

      strategy.plural_name("city").should eq("cities")
      strategy.plural_name("key").should eq("keys") # vowel + y
    end

    it "handles words ending in f/fe" do
      strategy = AzuCLI::Generator::Core::StandardNamingStrategy.new

      strategy.plural_name("wolf").should eq("wolves")
      strategy.plural_name("knife").should eq("knives")
    end
  end
end
