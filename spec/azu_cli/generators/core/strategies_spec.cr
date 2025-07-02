require "../spec_helper"

describe AzuCLI::Generator::Core::TemplateStrategy do
  describe "template rendering" do
    it "renders ECR templates with variables" do
      strategy = AzuCLI::Generator::Core::TemplateStrategy.new

      template_content = <<-ECR
      class <%= class_name %>
        def initialize(@name : String)
        end

        def greeting
          "Hello, #{@name}!"
        end
      end
      ECR

      variables = {"class_name" => "TestClass"}
      result = strategy.render(template_content, variables)

      result.should contain("class TestClass")
      result.should contain("def initialize(@name : String)")
    end

    it "handles missing template variables gracefully" do
      strategy = AzuCLI::Generator::Core::TemplateStrategy.new

      template_content = <<-ECR
      class <%= class_name %>
      end
      ECR

      variables = {} of String => String

      expect_raises(Exception) do
        strategy.render(template_content, variables)
      end
    end

    it "renders nested template variables" do
      strategy = AzuCLI::Generator::Core::TemplateStrategy.new

      template_content = <<-ECR
      module <%= module_name %>
        class <%= class_name %>
          property <%= property_name %> : <%= property_type %>
        end
      end
      ECR

      variables = {
        "module_name" => "TestModule",
        "class_name" => "TestClass",
        "property_name" => "name",
        "property_type" => "String"
      }

      result = strategy.render(template_content, variables)

      result.should contain("module TestModule")
      result.should contain("class TestClass")
      result.should contain("property name : String")
    end

    it "handles conditional template logic" do
      strategy = AzuCLI::Generator::Core::TemplateStrategy.new

      template_content = <<-ECR
      class <%= class_name %>
        <% if has_validation %>
        def valid?
          true
        end
        <% end %>
      end
      ECR

      variables = {
        "class_name" => "TestClass",
        "has_validation" => "true"
      }

      result = strategy.render(template_content, variables)

      result.should contain("def valid?")
    end
  end

  describe "error handling" do
    it "provides helpful error messages for template errors" do
      strategy = AzuCLI::Generator::Core::TemplateStrategy.new

      invalid_template = <<-ECR
      class <%= class_name %>
        <%= invalid_method() %>
      end
      ECR

      variables = {"class_name" => "TestClass"}

      expect_raises(Exception) do
        strategy.render(invalid_template, variables)
      end
    end
  end
end

describe AzuCLI::Generator::Core::FileStrategy do
  describe "file operations" do
    it "creates files with content" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::FileStrategy.new

        content = "# This is a test file\nputs \"Hello, World!\""
        strategy.create_file("test.cr", content, "test file")

        File.exists?("test.cr").should be_true
        File.read("test.cr").should eq(content)
      end
    end

    it "creates directories" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::FileStrategy.new

        strategy.create_directory("src/test")

        Dir.exists?("src/test").should be_true
      end
    end

    it "creates nested directories" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::FileStrategy.new

        strategy.create_directory("src/deep/nested/directory")

        Dir.exists?("src/deep/nested/directory").should be_true
      end
    end

    it "checks if files exist" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::FileStrategy.new

        File.write("existing.cr", "content")

        strategy.file_exists?("existing.cr").should be_true
        strategy.file_exists?("nonexistent.cr").should be_false
      end
    end

    it "checks if directories exist" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::FileStrategy.new

        Dir.mkdir_p("existing_dir")

        strategy.directory_exists?("existing_dir").should be_true
        strategy.directory_exists?("nonexistent_dir").should be_false
      end
    end
  end

  describe "file overwrite protection" do
    it "prevents overwriting existing files by default" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::FileStrategy.new

        File.write("existing.cr", "original content")

        expect_raises(Exception, "File already exists") do
          strategy.create_file("existing.cr", "new content", "test file")
        end
      end
    end

    it "allows forced overwriting of existing files" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::FileStrategy.new(force: true)

        File.write("existing.cr", "original content")
        strategy.create_file("existing.cr", "new content", "test file")

        File.read("existing.cr").should eq("new content")
      end
    end
  end
end

describe AzuCLI::Generator::Core::ValidationStrategy do
  describe "name validation" do
    it "validates valid generator names" do
      strategy = AzuCLI::Generator::Core::ValidationStrategy.new

      strategy.validate_name("User").should be_true
      strategy.validate_name("UserProfile").should be_true
      strategy.validate_name("user_profile").should be_true
      strategy.validate_name("API::User").should be_true
    end

    it "rejects invalid generator names" do
      strategy = AzuCLI::Generator::Core::ValidationStrategy.new

      strategy.validate_name("").should be_false
      strategy.validate_name("123User").should be_false
      strategy.validate_name("user-profile").should be_false
      strategy.validate_name("user.profile").should be_false
    end

    it "validates project names" do
      strategy = AzuCLI::Generator::Core::ValidationStrategy.new

      strategy.validate_project_name("my_project").should be_true
      strategy.validate_project_name("test-project").should be_true
      strategy.validate_project_name("TestProject").should be_true
    end

    it "rejects invalid project names" do
      strategy = AzuCLI::Generator::Core::ValidationStrategy.new

      strategy.validate_project_name("").should be_false
      strategy.validate_project_name("123project").should be_false
      strategy.validate_project_name("project with spaces").should be_false
    end
  end

  describe "attribute validation" do
    it "validates attribute formats" do
      strategy = AzuCLI::Generator::Core::ValidationStrategy.new

      strategy.validate_attribute("name:string").should be_true
      strategy.validate_attribute("age:integer").should be_true
      strategy.validate_attribute("active:boolean").should be_true
      strategy.validate_attribute("email:string").should be_true
    end

    it "rejects invalid attribute formats" do
      strategy = AzuCLI::Generator::Core::ValidationStrategy.new

      strategy.validate_attribute("name").should be_false
      strategy.validate_attribute("name:").should be_false
      strategy.validate_attribute(":string").should be_false
      strategy.validate_attribute("invalid-name:string").should be_false
    end

    it "validates attribute types" do
      strategy = AzuCLI::Generator::Core::ValidationStrategy.new

      valid_types = ["string", "integer", "boolean", "datetime", "text", "float"]
      valid_types.each do |type|
        strategy.validate_attribute_type(type).should be_true
      end
    end

    it "rejects invalid attribute types" do
      strategy = AzuCLI::Generator::Core::ValidationStrategy.new

      strategy.validate_attribute_type("invalid").should be_false
      strategy.validate_attribute_type("unknown").should be_false
    end
  end

  describe "precondition validation" do
    it "validates that project directory exists" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::ValidationStrategy.new

        File.write("shard.yml", "name: test\nversion: 0.1.0")

        strategy.validate_project_exists.should be_true
      end
    end

    it "fails validation when project directory doesn't exist" do
      with_temp_directory do
        strategy = AzuCLI::Generator::Core::ValidationStrategy.new

        # No shard.yml file
        strategy.validate_project_exists.should be_false
      end
    end

    it "validates Crystal syntax if possible" do
      strategy = AzuCLI::Generator::Core::ValidationStrategy.new

      valid_crystal = <<-CRYSTAL
      class TestClass
        def initialize(@name : String)
        end
      end
      CRYSTAL

      # Basic syntax validation
      strategy.validate_crystal_syntax(valid_crystal).should be_true
    end
  end
end

describe AzuCLI::Generator::Core::NamingStrategy do
  describe "case conversions" do
    it "converts to snake_case" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.to_snake_case("UserProfile").should eq("user_profile")
      strategy.to_snake_case("XMLHttpRequest").should eq("xml_http_request")
      strategy.to_snake_case("HTMLParser").should eq("html_parser")
    end

    it "converts to PascalCase" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.to_pascal_case("user_profile").should eq("UserProfile")
      strategy.to_pascal_case("xml_http_request").should eq("XmlHttpRequest")
      strategy.to_pascal_case("html_parser").should eq("HtmlParser")
    end

    it "converts to camelCase" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.to_camel_case("user_profile").should eq("userProfile")
      strategy.to_camel_case("xml_http_request").should eq("xmlHttpRequest")
    end

    it "converts to kebab-case" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.to_kebab_case("UserProfile").should eq("user-profile")
      strategy.to_kebab_case("XMLHttpRequest").should eq("xml-http-request")
    end
  end

  describe "pluralization" do
    it "pluralizes regular nouns" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.pluralize("user").should eq("users")
      strategy.pluralize("post").should eq("posts")
      strategy.pluralize("comment").should eq("comments")
    end

    it "handles irregular plurals" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.pluralize("person").should eq("people")
      strategy.pluralize("child").should eq("children")
      strategy.pluralize("mouse").should eq("mice")
    end

    it "singularizes plural nouns" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.singularize("users").should eq("user")
      strategy.singularize("posts").should eq("post")
      strategy.singularize("people").should eq("person")
    end
  end

  describe "namespace handling" do
    it "extracts namespace from qualified names" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.extract_namespace("API::User").should eq("API")
      strategy.extract_namespace("Admin::Reports::User").should eq("Admin::Reports")
      strategy.extract_namespace("User").should eq("")
    end

    it "extracts class name from qualified names" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.extract_class_name("API::User").should eq("User")
      strategy.extract_class_name("Admin::Reports::User").should eq("User")
      strategy.extract_class_name("User").should eq("User")
    end
  end

  describe "file path generation" do
    it "generates appropriate file paths" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.file_path("UserProfile", "models").should eq("models/user_profile.cr")
      strategy.file_path("API::User", "endpoints").should eq("endpoints/api/user.cr")
    end

    it "generates spec file paths" do
      strategy = AzuCLI::Generator::Core::NamingStrategy.new

      strategy.spec_path("UserProfile", "models").should eq("spec/models/user_profile_spec.cr")
      strategy.spec_path("API::User", "endpoints").should eq("spec/endpoints/api/user_spec.cr")
    end
  end
end
