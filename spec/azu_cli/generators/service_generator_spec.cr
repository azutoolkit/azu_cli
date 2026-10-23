require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe AzuCLI::Generate::Service do
  attributes = {"title" => "string", "published" => "bool"}

  service = ->(action : String) do
    in_generated_project do
      rendered(AzuCLI::Generate::Service.new("Post", action, attributes), "src/services", "posts/#{action}_service.cr")
    end
  end

  it "saves a new record built from the request" do
    content = service.call("create")

    content.should contain("class Posts::CreateService")
    content.should contain("def call(request : Posts::CreateRequest) : Post")
    content.should contain("Post.new(title: request.title, published: request.published)")
    content.should contain("record.save!")
  end

  it "updates the record it is given" do
    content = service.call("update")

    content.should contain("def call(record : Post, request : Posts::UpdateRequest) : Post")
    content.should contain("request.title.try { |value| record.title = value }")
    content.should contain("request.published.try { |value| record.published = value }")
    content.should_not contain("attributes(")
    content.should contain("record.save!")
  end

  it "deletes the record it is given" do
    service.call("destroy").should contain("record.delete!")
  end

  it "does not need a Result class" do
    AzuCLI::Generate::Service::ACTIONS.each do |action|
      service.call(action).should_not contain("Result")
    end
  end
end
