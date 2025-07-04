require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Endpoint do
  it "creates an endpoint generator with basic properties" do
    generator = AzuCLI::Generate::Endpoint.new("User")
    generator.name.should eq("User")
    generator.endpoint_type.should eq("api")
    generator.snake_case_name.should eq("user")
    generator.endpoint_struct_name.should eq("UserEndpoint")
  end

  it "creates an endpoint generator with web type" do
    generator = AzuCLI::Generate::Endpoint.new("User", [] of String, "web")
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
    generator = AzuCLI::Generate::Endpoint.new("User")
    generator.http_verb("index").should eq("get")
    generator.http_verb("show").should eq("get")
    generator.http_verb("create").should eq("post")
    generator.http_verb("update").should eq("patch")
    generator.http_verb("destroy").should eq("delete")
  end

  it "generates correct paths for actions" do
    generator = AzuCLI::Generate::Endpoint.new("User")
    generator.action_path("index").should eq("/user")
    generator.action_path("new").should eq("/user/new")
    generator.action_path("create").should eq("/user")
    generator.action_path("show").should eq("/user/:id")
    generator.action_path("edit").should eq("/user/:id/edit")
    generator.action_path("update").should eq("/user/:id")
    generator.action_path("destroy").should eq("/user/:id")
  end

  it "generates correct API prefixes" do
    api_generator = AzuCLI::Generate::Endpoint.new("User", [] of String, "api")
    web_generator = AzuCLI::Generate::Endpoint.new("User", [] of String, "web")

    api_generator.api_prefix.should eq("/api")
    web_generator.api_prefix.should eq("")
  end

  it "generates correct full paths" do
    api_generator = AzuCLI::Generate::Endpoint.new("User", [] of String, "api")
    web_generator = AzuCLI::Generate::Endpoint.new("User", [] of String, "web")

    api_generator.full_path("index").should eq("/api/user")
    web_generator.full_path("index").should eq("/user")
  end

  it "generates endpoint methods for actions" do
    actions = ["index", "create"]
    generator = AzuCLI::Generate::Endpoint.new("User", actions, "api")
    methods = generator.endpoint_methods

    methods.should contain("get \"/api/user\"")
    methods.should contain("post \"/api/user\"")
    methods.should contain("def index : UserResponse")
    methods.should contain("def create : UserResponse")
  end

  it "generates scaffold components for API type" do
    generator = AzuCLI::Generate::Endpoint.new("User", [] of String, "api", true)
    components = generator.scaffold_components
    components.should eq(["request", "response"])
  end

  it "generates scaffold components for Web type" do
    generator = AzuCLI::Generate::Endpoint.new("User", [] of String, "web", true)
    components = generator.scaffold_components
    components.should eq(["contract", "page"])
  end

  it "uses default actions when none provided" do
    generator = AzuCLI::Generate::Endpoint.new("User")
    effective_actions = generator.effective_actions
    effective_actions.should eq(["index", "show", "create", "update", "destroy"])
  end

  it "generates an API endpoint file with actions" do
    actions = ["index", "create"]
    generator = AzuCLI::Generate::Endpoint.new("User", actions, "api")
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)
    generated_file = File.join(test_dir, "user_endpoints.cr")
    File.exists?(generated_file).should be_true
    content = File.read(generated_file)
    content.should contain("struct UserEndpoint")
    content.should contain("include Azu::Endpoint(UserRequest, UserResponse)")
    content.should contain("get \"/api/user\"")
    content.should contain("post \"/api/user\"")
    content.should contain("def index : UserResponse")
    content.should contain("def create : UserResponse")
    content.should contain("end")
    FileUtils.rm_rf(test_dir)
  end

  it "generates a Web endpoint file with actions" do
    actions = ["index", "show"]
    generator = AzuCLI::Generate::Endpoint.new("User", actions, "web")
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)
    generated_file = File.join(test_dir, "user_endpoints.cr")
    File.exists?(generated_file).should be_true
    content = File.read(generated_file)
    content.should contain("struct UserEndpoint")
    content.should contain("include Azu::Endpoint(UserContract, UserPage)")
    content.should contain("get \"/user\"")
    content.should contain("get \"/user/:id\"")
    content.should contain("def index : UserPage")
    content.should contain("def show : UserPage")
    content.should contain("end")
    FileUtils.rm_rf(test_dir)
  end

  it "generates an endpoint file without actions" do
    generator = AzuCLI::Generate::Endpoint.new("User", [] of String, "api")
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)
    generated_file = File.join(test_dir, "user_endpoints.cr")
    File.exists?(generated_file).should be_true
    content = File.read(generated_file)
    content.should contain("struct UserEndpoint")
    content.should contain("include Azu::Endpoint(UserRequest, UserResponse)")
    content.should contain("# TODO: Add your endpoint actions here")
    content.should contain("end")
    FileUtils.rm_rf(test_dir)
  end
end
