require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe AzuCLI::Generate::Request do
  attributes = {"title" => "string", "body" => "text", "published" => "bool", "note" => "string?"}

  request = ->(action : String, fields : Hash(String, String)) do
    in_generated_project do
      rendered(AzuCLI::Generate::Request.new("Post", action, fields), "src/requests", "posts/#{action}_request.cr")
    end
  end
  no_fields = {} of String => String

  it "renders in the plural namespace of the project module" do
    request.call("index", no_fields).should eq("module Blog\n  struct Posts::IndexRequest\n    include Azu::Request\n  end\nend\n")
  end

  it "carries the id of the record the action works on" do
    {"show", "edit", "destroy"}.each do |action|
      request.call(action, no_fields).should contain("getter id : Int64")
    end
    request.call("new", no_fields).should_not contain("getter id")
  end

  it "carries and validates the fields of a create" do
    content = request.call("create", attributes)

    content.should contain("struct Posts::CreateRequest")
    content.should contain("getter title : String\n")
    content.should contain("getter published : Bool = false")
    content.should contain("getter note : String?")
    content.should contain("validate title, presence: true")
    content.should contain("validate body, presence: true")
    content.should_not contain("validate published")
    content.should_not contain("validate note")
    content.should_not contain("getter id")
  end

  it "makes every field of an update optional so a PATCH only changes what it carries" do
    content = request.call("update", attributes)

    content.should_not contain("getter id")
    content.should contain("getter title : String?")
    content.should contain("getter published : Bool?\n")
    content.should_not contain("= false")
    content.should contain("validate title, given: true")
    content.should_not contain("presence")
  end

  it "renders the given predicate with the update only" do
    in_generated_project do
      AzuCLI::Generate::Request.new("Post", "update", attributes).render(File.expand_path("src/requests"), force: true, interactive: false)
      File.read("src/requests/predicates.cr").should contain("def given?(value, other)")

      File.delete("src/requests/predicates.cr")
      AzuCLI::Generate::Request.new("Post", "create", attributes).render(File.expand_path("src/requests"), force: true, interactive: false)
      File.exists?("src/requests/predicates.cr").should be_false
    end
  end
end
