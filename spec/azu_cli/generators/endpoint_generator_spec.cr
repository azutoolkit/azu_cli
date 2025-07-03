require "spec"
require "file_utils"
require "teeplate"
require "../../../src/azu_cli/generators/base"
require "../../../src/azu_cli/generators/endpoint_generator"

module AzuCLI::Generators
  describe EndpointGenerator do
    describe "REST endpoint generation" do
      it "generates index endpoint" do
        resource_name = "user"
        action = "index"
        output_dir = "./tmp"
        output_file = File.join(output_dir, "endpoints", "user", "index_endpoint.cr")

        FileUtils.mkdir_p(File.dirname(output_file))
        File.delete(output_file) if File.exists?(output_file)

        generator = EndpointGenerator.new(resource_name, action, output_dir: output_dir)
        generated_path = generator.generate!

        generated_path.should eq(output_file)
        File.exists?(output_file).should be_true
        content = File.read(output_file)

        # Check basic structure
        content.should contain("struct IndexUserEndpoint")
        content.should contain("include Azu::Endpoint(Azu::Request::Empty, UsersResponse)")
        content.should contain("get \"/api/users\"")

        # Check service call
        content.should contain("users = UserService.list_users(request)")
        content.should contain("UsersResponse.new(users)")

        # Clean up
        File.delete(output_file) if File.exists?(output_file)
        FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
      end

      it "generates create endpoint" do
        resource_name = "user"
        action = "create"
        output_dir = "./tmp"
        output_file = File.join(output_dir, "endpoints", "user", "create_endpoint.cr")

        FileUtils.mkdir_p(File.dirname(output_file))
        File.delete(output_file) if File.exists?(output_file)

        generator = EndpointGenerator.new(resource_name, action, output_dir: output_dir)
        generated_path = generator.generate!

        generated_path.should eq(output_file)
        File.exists?(output_file).should be_true
        content = File.read(output_file)

        # Check basic structure
        content.should contain("struct CreateUserEndpoint")
        content.should contain("include Azu::Endpoint(CreateUserRequest, UserResponse)")
        content.should contain("post \"/api/users\"")

        # Check service call
        content.should contain("user = UserService.create_user(request)")
        content.should contain("UserResponse.new(user)")

        # Clean up
        File.delete(output_file) if File.exists?(output_file)
        FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
      end

      it "generates show endpoint" do
        resource_name = "user"
        action = "show"
        output_dir = "./tmp"
        output_file = File.join(output_dir, "endpoints", "user", "show_endpoint.cr")

        FileUtils.mkdir_p(File.dirname(output_file))
        File.delete(output_file) if File.exists?(output_file)

        generator = EndpointGenerator.new(resource_name, action, output_dir: output_dir)
        generated_path = generator.generate!

        generated_path.should eq(output_file)
        File.exists?(output_file).should be_true
        content = File.read(output_file)

        # Check basic structure
        content.should contain("struct ShowUserEndpoint")
        content.should contain("include Azu::Endpoint(Azu::Request::Empty, UserResponse)")
        content.should contain("get \"/api/users/:id\"")

        # Check service call with ID parameter
        content.should contain("user = UserService.find_user(request.path_params[\"id\"])")
        content.should contain("UserResponse.new(user)")

        # Clean up
        File.delete(output_file) if File.exists?(output_file)
        FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
      end

      it "generates update endpoint" do
        resource_name = "user"
        action = "update"
        output_dir = "./tmp"
        output_file = File.join(output_dir, "endpoints", "user", "update_endpoint.cr")

        FileUtils.mkdir_p(File.dirname(output_file))
        File.delete(output_file) if File.exists?(output_file)

        generator = EndpointGenerator.new(resource_name, action, output_dir: output_dir)
        generated_path = generator.generate!

        generated_path.should eq(output_file)
        File.exists?(output_file).should be_true
        content = File.read(output_file)

        # Check basic structure
        content.should contain("struct UpdateUserEndpoint")
        content.should contain("include Azu::Endpoint(UpdateUserRequest, UserResponse)")
        content.should contain("patch \"/api/users/:id\"")

        # Check service call with ID and request parameters
        content.should contain("user = UserService.update_user(request.path_params[\"id\"], request)")
        content.should contain("UserResponse.new(user)")

        # Clean up
        File.delete(output_file) if File.exists?(output_file)
        FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
      end

      it "generates destroy endpoint" do
        resource_name = "user"
        action = "destroy"
        output_dir = "./tmp"
        output_file = File.join(output_dir, "endpoints", "user", "destroy_endpoint.cr")

        FileUtils.mkdir_p(File.dirname(output_file))
        File.delete(output_file) if File.exists?(output_file)

        generator = EndpointGenerator.new(resource_name, action, output_dir: output_dir)
        generated_path = generator.generate!

        generated_path.should eq(output_file)
        File.exists?(output_file).should be_true
        content = File.read(output_file)

        # Check basic structure
        content.should contain("struct DestroyUserEndpoint")
        content.should contain("include Azu::Endpoint(Azu::Request::Empty, Azu::Response::NoContent)")
        content.should contain("delete \"/api/users/:id\"")

        # Check service call
        content.should contain("UserService.delete_user(request.path_params[\"id\"])")
        content.should contain("Azu::Response::NoContent.new")

        # Clean up
        File.delete(output_file) if File.exists?(output_file)
        FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
      end
    end

    describe "custom endpoint configuration" do
      it "generates endpoint with custom request and response classes" do
        resource_name = "product"
        action = "create"
        output_dir = "./tmp"
        output_file = File.join(output_dir, "endpoints", "product", "create_endpoint.cr")

        FileUtils.mkdir_p(File.dirname(output_file))
        File.delete(output_file) if File.exists?(output_file)

        generator = EndpointGenerator.new(
          resource_name,
          action,
          request_class: "CustomProductRequest",
          response_class: "CustomProductResponse",
          service_class: "CustomProductService",
          output_dir: output_dir
        )
        generated_path = generator.generate!

        generated_path.should eq(output_file)
        File.exists?(output_file).should be_true
        content = File.read(output_file)

        # Check custom classes are used
        content.should contain("include Azu::Endpoint(CustomProductRequest, CustomProductResponse)")
        content.should contain("CustomProductService.create_product(request)")
        content.should contain("CustomProductResponse.new(product)")

        # Clean up
        File.delete(output_file) if File.exists?(output_file)
        FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
      end
    end

    describe "endpoint configuration validation" do
      it "validates REST actions" do
        expect_raises(ArgumentError, "Invalid REST action: invalid") do
          EndpointGenerator.new("user", "invalid")
        end
      end

      it "validates resource name" do
        expect_raises(ArgumentError, "Name cannot be empty") do
          EndpointGenerator.new("", "index")
        end
      end
    end

    describe "pluralization helper" do
      it "correctly pluralizes regular words" do
        PluralizeHelper.pluralize("user").should eq("users")
        PluralizeHelper.pluralize("post").should eq("posts")
      end

      it "handles special cases" do
        PluralizeHelper.pluralize("box").should eq("boxes")
        PluralizeHelper.pluralize("city").should eq("cities")
        PluralizeHelper.pluralize("leaf").should eq("leaves")
        PluralizeHelper.pluralize("knife").should eq("knives")
      end
    end
  end

  describe ResourceScaffoldGenerator do
    it "generates all REST endpoints for a resource" do
      resource_name = "post"
      output_dir = "./tmp"

      # Clean up before test
      endpoints_dir = File.join(output_dir, "endpoints", "post")
      FileUtils.rm_rf(endpoints_dir) if Dir.exists?(endpoints_dir)

      scaffold = ResourceScaffoldGenerator.new(resource_name, output_dir)
      generated_files = scaffold.generate_all!

      generated_files.size.should eq(7) # All REST actions

      # Check that all endpoint files were created
      ["index", "new", "create", "show", "edit", "update", "destroy"].each do |action|
        file_path = File.join(output_dir, "endpoints", "post", "#{action}_endpoint.cr")
        File.exists?(file_path).should be_true
      end

      # Clean up
      FileUtils.rm_rf(endpoints_dir) if Dir.exists?(endpoints_dir)
    end

    it "generates only CRUD endpoints" do
      resource_name = "article"
      output_dir = "./tmp"

      # Clean up before test
      endpoints_dir = File.join(output_dir, "endpoints", "article")
      FileUtils.rm_rf(endpoints_dir) if Dir.exists?(endpoints_dir)

      scaffold = ResourceScaffoldGenerator.new(resource_name, output_dir)
      generated_files = scaffold.generate_crud!

      generated_files.size.should eq(4) # CRUD actions only

      # Check that CRUD endpoint files were created
      ["create", "show", "update", "destroy"].each do |action|
        file_path = File.join(output_dir, "endpoints", "article", "#{action}_endpoint.cr")
        File.exists?(file_path).should be_true
      end

      # Clean up
      FileUtils.rm_rf(endpoints_dir) if Dir.exists?(endpoints_dir)
    end

    it "generates only readonly endpoints" do
      resource_name = "report"
      output_dir = "./tmp"

      # Clean up before test
      endpoints_dir = File.join(output_dir, "endpoints", "report")
      FileUtils.rm_rf(endpoints_dir) if Dir.exists?(endpoints_dir)

      scaffold = ResourceScaffoldGenerator.new(resource_name, output_dir)
      generated_files = scaffold.generate_readonly!

      generated_files.size.should eq(2) # Readonly actions only

      # Check that readonly endpoint files were created
      ["index", "show"].each do |action|
        file_path = File.join(output_dir, "endpoints", "report", "#{action}_endpoint.cr")
        File.exists?(file_path).should be_true
      end

      # Clean up
      FileUtils.rm_rf(endpoints_dir) if Dir.exists?(endpoints_dir)
    end
  end
end
