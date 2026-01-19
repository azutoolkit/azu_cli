require "../../spec_helper"
require "../../support/test_helpers"
require "teeplate"

describe AzuCLI::Generate::Endpoint do
  it "creates an endpoint generator with basic properties" do
    generator = AzuCLI::Generate::Endpoint.new("User", ["index"])
    generator.name.should eq("User")
    generator.endpoint_type.should eq("api")
    generator.snake_case_name.should eq("user")
    generator.endpoint_struct_name.should eq("User::UserEndpoint")
  end

  it "creates an endpoint generator with web type" do
    generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web")
    generator.endpoint_type.should eq("web")
    generator.request_type.should eq("User::UserRequest")
    generator.response_type.should eq("User::UserPage")
  end

  it "creates an endpoint generator with actions" do
    actions = ["index", "show", "create"]
    generator = AzuCLI::Generate::Endpoint.new("User", actions)
    generator.actions.should eq(actions)
    generator.has_actions?.should be_true
  end

  it "generates correct HTTP verbs for actions" do
    generator = AzuCLI::Generate::Endpoint.new("User", ["index"])
    generator.http_verb("index").should eq("get")
    generator.http_verb("show").should eq("get")
    generator.http_verb("create").should eq("post")
    generator.http_verb("update").should eq("patch")
    generator.http_verb("destroy").should eq("delete")
  end

  it "generates correct paths for actions" do
    generator = AzuCLI::Generate::Endpoint.new("User", ["index"])
    generator.action_path("index").should eq("/users")
    generator.action_path("new").should eq("/users/new")
    generator.action_path("create").should eq("/users")
    generator.action_path("show").should eq("/users/:id")
    generator.action_path("edit").should eq("/users/:id/edit")
    generator.action_path("update").should eq("/users/:id")
    generator.action_path("destroy").should eq("/users/:id")
  end

  it "generates correct full paths" do
    api_generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "api")
    web_generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web")

    api_generator.full_path("index").should eq("/users")
    web_generator.full_path("index").should eq("/users")
  end

  it "generates scaffold components for API type" do
    generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "api", true)
    components = generator.scaffold_components
    components.should eq(["request", "response"])
  end

  it "generates scaffold components for Web type" do
    generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web", true)
    components = generator.scaffold_components
    components.should eq(["request", "page"])
  end

  it "returns provided actions as effective actions" do
    actions = ["index", "create", "update"]
    generator = AzuCLI::Generate::Endpoint.new("User", actions)
    effective_actions = generator.effective_actions
    effective_actions.should eq(actions)
  end

  it "generates separate endpoint files for each action" do
    actions = ["index", "create"]
    generator = AzuCLI::Generate::Endpoint.new("User", actions, "api")
    test_dir = "./tmp_test"

    FileUtils.mkdir_p(test_dir)

    generator.render(test_dir, interactive: false)

    # Check that individual action files were created
    index_file = File.join(test_dir, "users", "user_index_endpoint.cr")
    create_file = File.join(test_dir, "users", "user_create_endpoint.cr")

    File.exists?(index_file).should be_true
    File.exists?(create_file).should be_true

    # Check index file content
    index_content = File.read(index_file)
    index_content.should contain("struct IndexEndpoint")
    index_content.should contain("include Azu::Endpoint(User::IndexRequest, User::IndexResponse)")
    index_content.should contain("get \"/users\"")
    index_content.should contain("def call : User::IndexResponse")

    # Check create file content
    create_content = File.read(create_file)
    create_content.should contain("struct CreateEndpoint")
    create_content.should contain("include Azu::Endpoint(User::CreateRequest, User::CreateResponse)")
    create_content.should contain("post \"/users\"")
    create_content.should contain("def call : User::CreateResponse")

    FileUtils.rm_rf(test_dir)
  end

  it "generates web endpoint files with correct types" do
    actions = ["index", "show"]
    generator = AzuCLI::Generate::Endpoint.new("User", actions, "web")
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir, interactive: false)

    # Check that individual action files were created
    index_file = File.join(test_dir, "users", "user_index_endpoint.cr")
    show_file = File.join(test_dir, "users", "user_show_endpoint.cr")

    File.exists?(index_file).should be_true
    File.exists?(show_file).should be_true

    # Check index file content
    index_content = File.read(index_file)
    index_content.should contain("struct IndexEndpoint")
    index_content.should contain("include Azu::Endpoint(User::IndexRequest, User::IndexPage)")
    index_content.should contain("get \"/users\"")
    index_content.should contain("def call : User::IndexPage")

    # Check show file content
    show_content = File.read(show_file)
    show_content.should contain("struct ShowEndpoint")
    show_content.should contain("include Azu::Endpoint(User::ShowRequest, User::ShowPage)")
    show_content.should contain("get \"/users/:id\"")
    show_content.should contain("def call : User::ShowPage")

    FileUtils.rm_rf(test_dir)
  end

  describe "scaffold generation with proper module structure" do
    it "generates web endpoints with nested module structure and Request types" do
      actions = ["create"]
      generator = AzuCLI::Generate::Endpoint.new("Post", actions, "web")
      test_dir = "./tmp_test"
      FileUtils.mkdir_p(test_dir)
      generator.render(test_dir, interactive: false)

      # Check that the endpoint file was created with proper structure
      create_file = File.join(test_dir, "posts", "post_create_endpoint.cr")
      File.exists?(create_file).should be_true

      create_content = File.read(create_file)

      # Should use nested module structure
      create_content.should contain("module AzuCli::Post")
      create_content.should contain("struct CreateEndpoint")

      # Should always use Request, not Contract
      create_content.should contain("include Azu::Endpoint(Post::CreateRequest, Post::CreatePage)")
      create_content.should contain("def call : Post::CreatePage")

      # Should not contain Contract references
      create_content.should_not contain("Contract")

      FileUtils.rm_rf(test_dir)
    end

    it "generates API endpoints with nested module structure" do
      actions = ["create"]
      generator = AzuCLI::Generate::Endpoint.new("Post", actions, "api")
      test_dir = "./tmp_test"
      FileUtils.mkdir_p(test_dir)
      generator.render(test_dir, interactive: false)

      # Check that the endpoint file was created with proper structure
      create_file = File.join(test_dir, "posts", "post_create_endpoint.cr")
      File.exists?(create_file).should be_true

      create_content = File.read(create_file)

      # Should use nested module structure
      create_content.should contain("module AzuCli::Post")
      create_content.should contain("struct CreateEndpoint")

      # Should use Request and Response for API
      create_content.should contain("include Azu::Endpoint(Post::CreateRequest, Post::CreateResponse)")
      create_content.should contain("def call : Post::CreateResponse")

      FileUtils.rm_rf(test_dir)
    end

    it "generates endpoints with proper module nesting for complex resource names" do
      actions = ["create"]
      generator = AzuCLI::Generate::Endpoint.new("BlogPost", actions, "web")
      test_dir = "./tmp_test"
      FileUtils.mkdir_p(test_dir)
      generator.render(test_dir, interactive: false)

      # Check that the endpoint file was created with proper structure
      create_file = File.join(test_dir, "blogposts", "blogpost_create_endpoint.cr")
      File.exists?(create_file).should be_true

      create_content = File.read(create_file)

      # Should use nested module structure with proper CamelCase
      create_content.should contain("module AzuCli::BlogPost")
      create_content.should contain("struct CreateEndpoint")
      create_content.should contain("include Azu::Endpoint(BlogPost::CreateRequest, BlogPost::CreatePage)")

      FileUtils.rm_rf(test_dir)
    end
  end

  describe "request type validation" do
    it "always generates Request types for web applications" do
      generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web")
      generator.request_type.should eq("User::UserRequest")
      generator.request_type.should_not contain("Contract")
    end

    it "always generates Request types for API applications" do
      generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "api")
      generator.request_type.should eq("User::UserRequest")
    end

    it "generates correct response types based on application type" do
      web_generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web")
      api_generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "api")

      web_generator.response_type.should eq("User::UserPage")
      api_generator.response_type.should eq("User::UserResponse")
    end
  end

  describe "enhanced API/Web mode testing" do
    it "handles API project type correctly" do
      generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "api")
      generator.endpoint_type.should eq("api")
    end

    it "handles Web project type correctly" do
      generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web")
      generator.endpoint_type.should eq("web")
    end

    it "generates same full paths for API and Web (path prefix is handled by router)" do
      api_generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "api")
      web_generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web")

      # Both return the same path - API prefix is handled at the router level, not in the endpoint
      api_generator.full_path("index").should eq("/users")
      web_generator.full_path("index").should eq("/users")
    end

    it "generates scaffold components correctly for API" do
      generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "api", true)
      components = generator.scaffold_components
      components.should eq(["request", "response"])
    end

    it "generates scaffold components correctly for Web" do
      generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web", true)
      components = generator.scaffold_components
      components.should eq(["request", "page"])
    end

    it "handles nested resource names correctly" do
      test_dir = "./tmp_test_nested"
      FileUtils.mkdir_p(test_dir)

      generator = AzuCLI::Generate::Endpoint.new("UserProfile", ["index"], "api")
      generator.render(test_dir, interactive: false)

      # Generator creates files at {output_dir}/{resource_plural}/{resource_singular}_{action}_endpoint.cr
      endpoint_file = File.join(test_dir, "userprofiles", "userprofile_index_endpoint.cr")
      File.exists?(endpoint_file).should be_true

      content = File.read(endpoint_file)
      content.should contain("struct IndexEndpoint")
      content.should contain("UserProfile")

      FileUtils.rm_rf(test_dir)
    end

    it "creates proper directory structure for endpoints" do
      test_dir = "./tmp_test_structure"
      FileUtils.mkdir_p(test_dir)

      generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "api")
      generator.render(test_dir, interactive: false)

      # Check directory structure: {output_dir}/{resource_plural}/
      Dir.exists?(File.join(test_dir, "users")).should be_true
      File.exists?(File.join(test_dir, "users", "user_index_endpoint.cr")).should be_true

      FileUtils.rm_rf(test_dir)
    end

    it "generates all standard RESTful actions for API" do
      test_dir = "./tmp_test_api_actions"
      FileUtils.mkdir_p(test_dir)

      actions = ["index", "show", "create", "update", "destroy"]
      generator = AzuCLI::Generate::Endpoint.new("User", actions, "api")
      generator.render(test_dir, interactive: false)

      # Check all action files were created in {output_dir}/{resource_plural}/
      actions.each do |action|
        file_path = File.join(test_dir, "users", "user_#{action}_endpoint.cr")
        File.exists?(file_path).should be_true
      end

      FileUtils.rm_rf(test_dir)
    end

    it "generates all standard RESTful actions for Web" do
      test_dir = "./tmp_test_web_actions"
      FileUtils.mkdir_p(test_dir)

      actions = ["index", "show", "new", "create", "edit", "update", "destroy"]
      generator = AzuCLI::Generate::Endpoint.new("User", actions, "web")
      generator.render(test_dir, interactive: false)

      # Check all action files were created in {output_dir}/{resource_plural}/
      actions.each do |action|
        file_path = File.join(test_dir, "users", "user_#{action}_endpoint.cr")
        File.exists?(file_path).should be_true
      end

      FileUtils.rm_rf(test_dir)
    end
  end
end
