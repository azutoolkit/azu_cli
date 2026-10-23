require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe "page generators" do
  attributes = {"title" => "string", "body" => "text", "published" => "bool"}

  describe AzuCLI::Generate::Page do
    page = ->(action : String) do
      in_generated_project do
        rendered(AzuCLI::Generate::Page.new("Post", action, {"title" => "string"}), "src/pages", "posts/#{action}_page.cr")
      end
    end

    it "renders a Renderable page whose class name is the template path" do
      content = page.call("show")

      content.should contain("module Blog\n  struct Posts::ShowPage")
      content.should contain("include Azu::Templates::Renderable")
      content.should contain(%("post" => @post.attributes.transform_keys(&.to_s)))
    end

    it "gives the form pages a CSRF tag" do
      page.call("new").should contain("def initialize(@csrf_tag : String)")
      page.call("edit").should contain("@post : Post, @csrf_tag : String")
    end

    it "lists the records of an index" do
      page.call("index").should contain("def initialize(@posts : Array(Post))")
    end
  end

  describe AzuCLI::Generate::Response do
    it "renders a JSON response of the record" do
      in_generated_project do
        content = rendered(AzuCLI::Generate::Response.new("Post", "show", attributes), "src/responses", "posts/show_response.cr")

        content.should contain("struct Posts::ShowResponse")
        content.should contain("include JSON::Serializable")
        content.should contain("getter published : Bool")
        content.should contain("@title = post.title")
      end
    end

    it "renders a list of those responses" do
      in_generated_project do
        content = rendered(AzuCLI::Generate::Response.new("Post", "index", attributes), "src/responses", "posts/index_response.cr")

        content.should contain("Posts::ShowResponse.new(post)")
      end
    end
  end

  describe AzuCLI::Generate::Template do
    template = ->(action : String, file : String) do
      in_generated_project do
        rendered(AzuCLI::Generate::Template.new("Post", action, attributes), "public/templates", "blog/posts/#{file}")
      end
    end

    it "renders where Renderable#page_path looks" do
      in_generated_project do
        AzuCLI::Generate::Template.new("Post", "index", attributes).render(File.expand_path("public/templates"), force: true, interactive: false)

        File.exists?("public/templates/blog/posts/index_page.jinja").should be_true
        File.exists?("public/templates/blog/posts/show_page.jinja").should be_false
      end
    end

    it "escapes what users typed" do
      template.call("index", "index_page.jinja").should contain("{{ post.title | e }}")
      template.call("show", "show_page.jinja").should contain("{{ post.body | e }}")
    end

    it "posts the form with a CSRF field and a method override" do
      form = template.call("new", "_form.jinja")

      form.should contain(%(<form action="{{ form_action }}" method="post"))
      form.should contain("{{ csrf_tag | safe }}")
      form.should contain(%(name="_method" value="{{ form_method }}"))
      form.should contain(%(<textarea name="body"))
      form.should contain(%(<input type="checkbox" name="published" value="true"{% if post.published %} checked{% endif %}>))
    end

    it "edits with PATCH and deletes from the show page" do
      template.call("edit", "edit_page.jinja").should contain(%({% set form_method = "patch" %}))
      template.call("show", "show_page.jinja").should contain(%(name="_method" value="delete"))
    end

    it "shares the form between new and edit only" do
      in_generated_project do
        AzuCLI::Generate::Template.new("Post", "show", attributes).render(File.expand_path("public/templates"), force: true, interactive: false)

        File.exists?("public/templates/blog/posts/_form.jinja").should be_false
      end
    end
  end
end
