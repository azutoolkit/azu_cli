require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Endpoint do
  it "creates an endpoint generator with basic properties" do
    generator = AzuCLI::Generate::Endpoint.new("User", ["index"])
    generator.name.should eq("User")
    generator.endpoint_type.should eq("api")
    generator.snake_case_name.should eq("user")
    generator.endpoint_struct_name.should eq("UserEndpoint")
  end

  it "creates an endpoint generator with web type" do
    generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web")
    generator.endpoint_type.should eq("web")
    generator.request_type.should eq("UserContract")
    generator.response_type.should eq("UserPage")
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

  it "generates correct API prefixes" do
    api_generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "api")
    web_generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web")

    api_generator.api_prefix.should eq("/api")
    web_generator.api_prefix.should eq("")
  end

  it "generates correct full paths" do
    api_generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "api")
    web_generator = AzuCLI::Generate::Endpoint.new("User", ["index"], "web")

          api_generator.full_path("index").should eq("/api/users")
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
    components.should eq(["contract", "page"])
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
    index_content.should contain("struct UserIndexEndpoint")
    index_content.should contain("include Azu::Endpoint(UserIndexRequest, UserIndexResponse)")
    index_content.should contain("get \"/api/users\"")
    index_content.should contain("def call : UserIndexResponse")

    # Check create file content
    create_content = File.read(create_file)
    create_content.should contain("struct UserCreateEndpoint")
    create_content.should contain("include Azu::Endpoint(UserCreateRequest, UserCreateResponse)")
    create_content.should contain("post \"/api/users\"")
    create_content.should contain("def call : UserCreateResponse")

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
    index_content.should contain("struct UserIndexEndpoint")
    index_content.should contain("include Azu::Endpoint(UserIndexContract, UserIndexPage)")
    index_content.should contain("get \"/users\"")
    index_content.should contain("def call : UserIndexPage")

    # Check show file content
    show_content = File.read(show_file)
    show_content.should contain("struct UserShowEndpoint")
    show_content.should contain("include Azu::Endpoint(UserShowContract, UserShowPage)")
    show_content.should contain("get \"/users/:id\"")
    show_content.should contain("def call : UserShowPage")

    FileUtils.rm_rf(test_dir)
  end
end
