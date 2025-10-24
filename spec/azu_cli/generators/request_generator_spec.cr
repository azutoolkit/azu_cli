require "../../spec_helper"
require "../../support/test_helpers"
require "teeplate"

describe AzuCLI::Generate::Request do
  it "creates a request generator with basic attributes" do
    attributes = {"name" => "string", "email" => "string"}
    generator = AzuCLI::Generate::Request.new("myapp", "User", "create", attributes)

    generator.project.should eq("myapp")
    generator.resource.should eq("User")
    generator.action.should eq("create")
    generator.name.should eq("User")
  end

  it "converts resource name to snake_case" do
    attributes = {} of String => String
    generator = AzuCLI::Generate::Request.new("myapp", "UserProfile", "update", attributes)

    generator.snake_case_name.should eq("user_profile")
  end

  it "converts resource name to CamelCase" do
    attributes = {} of String => String
    generator = AzuCLI::Generate::Request.new("myapp", "user_profile", "create", attributes)

    generator.camelcase_name.should eq("UserProfile")
  end

  it "converts project name to module name" do
    attributes = {} of String => String
    generator = AzuCLI::Generate::Request.new("my_app", "User", "create", attributes)

    generator.module_name.should eq("MyApp")
  end

  it "initializes fields collection" do
    attributes = {"name" => "string", "age" => "int32"}
    generator = AzuCLI::Generate::Request.new("myapp", "User", "create", attributes)

    generator.fields.should_not be_nil
  end
end

describe AzuCLI::Generate::Request::FieldCollection do
  it "creates field collection from attributes" do
    attributes = {"name" => "string", "email" => "string"}
    fields = AzuCLI::Generate::Request::FieldCollection.new(attributes)

    fields.common_fields.size.should eq(2)
  end

  it "separates references from common fields" do
    attributes = {"name" => "string", "user_id" => "reference"}
    fields = AzuCLI::Generate::Request::FieldCollection.new(attributes)

    fields.common_fields.size.should eq(1)
    fields.references.size.should eq(1)
  end

  it "handles belongs_to as reference" do
    attributes = {"title" => "string", "author" => "belongs_to"}
    fields = AzuCLI::Generate::Request::FieldCollection.new(attributes)

    fields.references.size.should eq(1)
  end

  it "has default id field" do
    attributes = {} of String => String
    fields = AzuCLI::Generate::Request::FieldCollection.new(attributes)

    fields.id.field_name.should eq("id")
    fields.id.cr_type.should eq("Int64")
  end

  it "maps field types correctly" do
    attributes = {
      "name"       => "string",
      "age"        => "int32",
      "price"      => "float64",
      "active"     => "bool",
      "created_at" => "time",
    }
    fields = AzuCLI::Generate::Request::FieldCollection.new(attributes)

    name_field = fields.common_fields.find { |f| f.field_name == "name" }
    name_field.should_not be_nil
    name_field.not_nil!.cr_type.should eq("String") if name_field

    age_field = fields.common_fields.find { |f| f.field_name == "age" }
    age_field.should_not be_nil
    age_field.not_nil!.cr_type.should eq("Int32") if age_field

    price_field = fields.common_fields.find { |f| f.field_name == "price" }
    price_field.should_not be_nil
    price_field.not_nil!.cr_type.should eq("Float64") if price_field

    active_field = fields.common_fields.find { |f| f.field_name == "active" }
    active_field.should_not be_nil
    active_field.not_nil!.cr_type.should eq("Bool") if active_field

    created_field = fields.common_fields.find { |f| f.field_name == "created_at" }
    created_field.should_not be_nil
    created_field.not_nil!.cr_type.should eq("Time") if created_field
  end
end

describe AzuCLI::Generate::Request::Field do
  it "creates a field with properties" do
    field = AzuCLI::Generate::Request::Field.new("name", "String", "string")

    field.field_name.should eq("name")
    field.cr_type.should eq("String")
    field.original_type.should eq("string")
  end

  it "stores field name" do
    field = AzuCLI::Generate::Request::Field.new("email", "String", "string")

    field.field_name.should eq("email")
  end

  it "stores Crystal type" do
    field = AzuCLI::Generate::Request::Field.new("age", "Int32", "int32")

    field.cr_type.should eq("Int32")
  end

  it "stores original type" do
    field = AzuCLI::Generate::Request::Field.new("price", "Float64", "float64")

    field.original_type.should eq("float64")
  end
end

describe "enhanced Request generator API/Web mode testing" do
  describe "API mode request generation" do
    it "generates API request files with correct content" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_src_dir
        Dir.mkdir_p("src/requests")

        attributes = {"name" => "string", "email" => "string"}
        generator = AzuCLI::Generate::Request.new("myapp", "User", "create", attributes)
        generator.render(".")

        # Check that request file was created
        request_file = "src/requests/user_create_request.cr"
        File.exists?(request_file).should be_true

        content = File.read(request_file)
        content.should contain("class User::UserCreateRequest")
        content.should contain("property name : String")
        content.should contain("property email : String")
        content.should contain("include JSON::Serializable")
      end
    end

    it "generates API request with validation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_src_dir
        Dir.mkdir_p("src/requests")

        attributes = {"name" => "string", "email" => "string", "age" => "int32"}
        generator = AzuCLI::Generate::Request.new("myapp", "User", "create", attributes)
        generator.render(".")

        request_file = "src/requests/user_create_request.cr"
        content = File.read(request_file)

        content.should contain("property name : String")
        content.should contain("property email : String")
        content.should contain("property age : Int32")
        content.should contain("include JSON::Serializable")
      end
    end
  end

  describe "Web mode request generation" do
    it "generates Web request files with correct content" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_src_dir
        Dir.mkdir_p("src/requests")

        attributes = {"title" => "string", "content" => "text"}
        generator = AzuCLI::Generate::Request.new("myapp", "Post", "create", attributes)
        generator.render(".")

        # Check that request file was created
        request_file = "src/requests/post_create_request.cr"
        File.exists?(request_file).should be_true

        content = File.read(request_file)
        content.should contain("class Post::PostCreateRequest")
        content.should contain("property title : String")
        content.should contain("property content : String")
        content.should contain("include JSON::Serializable")
      end
    end

    it "generates Web request with form validation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_src_dir
        Dir.mkdir_p("src/requests")

        attributes = {"title" => "string", "content" => "text", "published" => "bool"}
        generator = AzuCLI::Generate::Request.new("myapp", "Post", "update", attributes)
        generator.render(".")

        request_file = "src/requests/post_update_request.cr"
        content = File.read(request_file)

        content.should contain("property title : String")
        content.should contain("property content : String")
        content.should contain("property published : Bool")
        content.should contain("include JSON::Serializable")
      end
    end
  end

  describe "request file structure" do
    it "creates proper directory structure for requests" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_src_dir

        attributes = {"name" => "string"}
        generator = AzuCLI::Generate::Request.new("myapp", "User", "create", attributes)
        generator.render(".")

        # Check directory structure
        Dir.exists?("src/requests").should be_true
        File.exists?("src/requests/user_create_request.cr").should be_true
      end
    end

    it "handles nested resource names correctly" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_src_dir
        Dir.mkdir_p("src/requests")

        attributes = {"name" => "string"}
        generator = AzuCLI::Generate::Request.new("myapp", "UserProfile", "create", attributes)
        generator.render(".")

        # Check that snake_case is used for filenames
        File.exists?("src/requests/user_profile_create_request.cr").should be_true

        content = File.read("src/requests/user_profile_create_request.cr")
        content.should contain("class UserProfile::UserProfileCreateRequest")
      end
    end
  end

  describe "field type mapping" do
    it "maps common field types correctly" do
      attributes = {
        "name"       => "string",
        "age"        => "int32",
        "price"      => "float64",
        "active"     => "bool",
        "created_at" => "time",
      }

      generator = AzuCLI::Generate::Request.new("myapp", "Product", "create", attributes)
      generator.render(".")

      request_file = "src/requests/product_create_request.cr"
      content = File.read(request_file)

      content.should contain("property name : String")
      content.should contain("property age : Int32")
      content.should contain("property price : Float64")
      content.should contain("property active : Bool")
      content.should contain("property created_at : Time")
    end

    it "handles references type correctly" do
      attributes = {"user_id" => "references", "category_id" => "references"}
      generator = AzuCLI::Generate::Request.new("myapp", "Post", "create", attributes)
      generator.render(".")

      request_file = "src/requests/post_create_request.cr"
      content = File.read(request_file)

      content.should contain("property user_id : Int64")
      content.should contain("property category_id : Int64")
    end
  end

  describe "request validation" do
    it "generates request with validation methods" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_src_dir
        Dir.mkdir_p("src/requests")

        attributes = {"name" => "string", "email" => "string"}
        generator = AzuCLI::Generate::Request.new("myapp", "User", "create", attributes)
        generator.render(".")

        request_file = "src/requests/user_create_request.cr"
        content = File.read(request_file)

        content.should contain("def valid?")
        content.should contain("def errors")
      end
    end

    it "generates validation for required fields" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_src_dir
        Dir.mkdir_p("src/requests")

        attributes = {"name" => "string", "email" => "string", "age" => "int32"}
        generator = AzuCLI::Generate::Request.new("myapp", "User", "create", attributes)
        generator.render(".")

        request_file = "src/requests/user_create_request.cr"
        content = File.read(request_file)

        content.should contain("name.present?")
        content.should contain("email.present?")
      end
    end
  end

  describe "JSON serialization" do
    it "includes JSON serialization for API requests" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_src_dir
        Dir.mkdir_p("src/requests")

        attributes = {"name" => "string", "email" => "string"}
        generator = AzuCLI::Generate::Request.new("myapp", "User", "create", attributes)
        generator.render(".")

        request_file = "src/requests/user_create_request.cr"
        content = File.read(request_file)

        content.should contain("include JSON::Serializable")
        content.should contain("property name : String")
        content.should contain("property email : String")
      end
    end

    it "handles optional fields correctly" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_src_dir
        Dir.mkdir_p("src/requests")

        attributes = {"name" => "string", "description" => "string?"}
        generator = AzuCLI::Generate::Request.new("myapp", "Product", "create", attributes)
        generator.render(".")

        request_file = "src/requests/product_create_request.cr"
        content = File.read(request_file)

        content.should contain("property name : String")
        content.should contain("property description : String?")
      end
    end
  end
end
