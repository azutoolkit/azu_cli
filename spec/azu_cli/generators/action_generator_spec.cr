require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::ActionEndpoint do
  it "creates an action endpoint generator with name and action" do
    generator = AzuCLI::Generate::ActionEndpoint.new("User", "index", "web", "user")

    generator.name.should eq("User")
    generator.action.should eq("index")
    generator.endpoint_type.should eq("web")
    generator.snake_case_name.should eq("user")
  end

  it "generates resource names correctly" do
    generator = AzuCLI::Generate::ActionEndpoint.new("Post", "show", "api", "post")

    generator.resource_plural.should eq("posts")
    generator.resource_singular.should eq("post")
  end

  it "generates endpoint struct name" do
    generator = AzuCLI::Generate::ActionEndpoint.new("User", "index", "web", "user")

    generator.endpoint_struct_name.should eq("UserIndexEndpoint")
  end

  it "generates request type" do
    generator = AzuCLI::Generate::ActionEndpoint.new("User", "create", "api", "user")

    generator.request_type.should eq("UserCreateRequest")
  end

  it "generates response type for web endpoints" do
    generator = AzuCLI::Generate::ActionEndpoint.new("User", "index", "web", "user")

    generator.response_type.should eq("UserIndexPage")
  end

  it "generates response type for API endpoints" do
    generator = AzuCLI::Generate::ActionEndpoint.new("User", "index", "api", "user")

    generator.response_type.should eq("UserIndexResponse")
  end

  describe "#http_verb_action" do
    it "returns GET for index action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "index", "web", "user")
      generator.http_verb_action.should eq("get")
    end

    it "returns GET for show action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "show", "web", "user")
      generator.http_verb_action.should eq("get")
    end

    it "returns GET for new action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "new", "web", "user")
      generator.http_verb_action.should eq("get")
    end

    it "returns GET for edit action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "edit", "web", "user")
      generator.http_verb_action.should eq("get")
    end

    it "returns POST for create action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "create", "web", "user")
      generator.http_verb_action.should eq("post")
    end

    it "returns PATCH for update action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "update", "web", "user")
      generator.http_verb_action.should eq("patch")
    end

    it "returns DELETE for destroy action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "destroy", "web", "user")
      generator.http_verb_action.should eq("delete")
    end

    it "returns DELETE for delete action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "delete", "web", "user")
      generator.http_verb_action.should eq("delete")
    end

    it "returns GET for custom action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "custom", "web", "user")
      generator.http_verb_action.should eq("get")
    end
  end

  describe "#action_path" do
    it "generates path for index action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "index", "web", "user")
      generator.action_path.should eq("/users")
    end

    it "generates path for show action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "show", "web", "user")
      generator.action_path.should eq("/users/:id")
    end

    it "generates path for new action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "new", "web", "user")
      generator.action_path.should eq("/users/new")
    end

    it "generates path for create action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "create", "web", "user")
      generator.action_path.should eq("/users")
    end

    it "generates path for edit action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "edit", "web", "user")
      generator.action_path.should eq("/users/:id/edit")
    end

    it "generates path for update action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "update", "web", "user")
      generator.action_path.should eq("/users/:id")
    end

    it "generates path for destroy action" do
      generator = AzuCLI::Generate::ActionEndpoint.new("User", "destroy", "web", "user")
      generator.action_path.should eq("/users/:id")
    end
  end

  it "generates module name" do
    generator = AzuCLI::Generate::ActionEndpoint.new("User", "index", "web", "user")
    generator.module_name.should eq("App")
  end

  it "initializes fields as empty hash" do
    generator = AzuCLI::Generate::ActionEndpoint.new("User", "index", "web", "user")
    generator.fields.should be_empty
  end
end
