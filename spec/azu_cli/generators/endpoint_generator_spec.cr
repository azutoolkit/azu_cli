require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe AzuCLI::Generate::Endpoint do
  endpoint = ->(action : String, type : String) do
    in_generated_project do
      rendered(AzuCLI::Generate::Endpoint.new("Post", action, type), "src/endpoints", "posts/#{action}_endpoint.cr")
    end
  end

  it "maps each action to its verb and route" do
    routes = {
      "index" => {"get", "/posts"}, "new" => {"get", "/posts/new"}, "create" => {"post", "/posts"},
      "show" => {"get", "/posts/:id"}, "edit" => {"get", "/posts/:id/edit"},
      "update" => {"patch", "/posts/:id"}, "destroy" => {"delete", "/posts/:id"},
    }
    routes.each do |action, (verb, route)|
      generator = AzuCLI::Generate::Endpoint.new("Post", action)
      {generator.verb, generator.route}.should eq({verb, route})
    end
  end

  it "names a multi-word resource in snake_case routes and CamelCase constants" do
    in_generated_project do
      generator = AzuCLI::Generate::Endpoint.new("UserProfile", "show")
      content = rendered(generator, "src/endpoints", "user_profiles/show_endpoint.cr")

      generator.route.should eq("/user_profiles/:id")
      content.should contain("struct UserProfiles::ShowEndpoint")
      content.should contain("UserProfile.find?(show_request.id)")
    end
  end

  it "renders a page for a read" do
    content = endpoint.call("index", "web")

    content.should contain("module Blog\n  struct Posts::IndexEndpoint")
    content.should contain("include Azu::Endpoint(Posts::IndexRequest, Posts::IndexPage)")
    content.should contain(%(get "/posts"))
    content.should contain("Posts::IndexPage.new(Post.all.to_a)")
  end

  it "answers 404 for a record that does not exist" do
    {"show", "edit", "update", "destroy"}.each do |action|
      content = endpoint.call(action, "web")
      content.should contain("Post.find?(")
      content.should contain("raise Azu::Response::NotFound.new(context.request.path)")
    end
  end

  it "redirects with 303 after a web write" do
    endpoint.call("create", "web").should contain(%(redirect to: "/posts/\#{record.id}", status: 303))
    endpoint.call("update", "web").should contain(%(redirect to: "/posts/\#{record.id}", status: 303))
    endpoint.call("destroy", "web").should contain(%(redirect to: "/posts", status: 303))
  end

  it "takes the id of an update from the path" do
    endpoint.call("update", "web").should contain(%(Post.find?(params["id"].to_i64? || 0)))
    endpoint.call("show", "web").should contain("Post.find?(show_request.id)")
  end

  # Azu leaves the Content-Type to the endpoint and the app sends nosniff: without it a browser shows a page as text
  it "names the media type of every answer with a body" do
    {"index", "show", "new", "edit"}.each do |action|
      endpoint.call(action, "web").should contain(%(def call : Posts::#{action.capitalize}Page\n      content_type "text/html"\n))
    end
    {"index", "show", "create", "update"}.each do |action|
      endpoint.call(action, "api").should contain(%(content_type "application/json"))
    end
    {"create", "update", "destroy"}.each { |action| endpoint.call(action, "web").should_not contain("content_type") }
    endpoint.call("destroy", "api").should_not contain("content_type")
  end

  it "answers with JSON in an API project" do
    endpoint.call("index", "api").should contain("Azu::Endpoint(Posts::IndexRequest, Posts::IndexResponse)")
    endpoint.call("create", "api").should contain("status 201")
    endpoint.call("create", "api").should contain("Posts::ShowResponse.new(record)")
    endpoint.call("destroy", "api").should contain("status 204")
  end
end
