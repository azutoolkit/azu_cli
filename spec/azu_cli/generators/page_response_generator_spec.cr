require "../../spec_helper"

describe AzuCLI::Generate::Page do
  describe "#initialize" do
    it "creates a page response generator with default action" do
      generator = AzuCLI::Generate::Page.new("Post", {"title" => "String", "content" => "String"})
      generator.name.should eq("Post")
      generator.action.should eq("index")
      generator.resource_singular.should eq("post")
      generator.resource_plural.should eq("posts")
    end

    it "creates a page response generator with custom action" do
      generator = AzuCLI::Generate::Page.new("Post", {"title" => "String", "content" => "String"}, "new")
      generator.name.should eq("Post")
      generator.action.should eq("new")
      generator.resource_singular.should eq("post")
      generator.resource_plural.should eq("posts")
    end
  end

  describe "#struct_name" do
    it "returns the correct struct name for web project" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.struct_name.should eq("PostIndexPage")
    end

    it "returns the correct struct name for API project" do
      generator = AzuCLI::Generate::Page.new("Post", project_type: "api")
      generator.struct_name.should eq("PostIndexJSON")
    end

    it "returns the correct struct name for different actions" do
      generator = AzuCLI::Generate::Page.new("Post", action: "create")
      generator.struct_name.should eq("PostCreatePage")

      generator = AzuCLI::Generate::Page.new("Post", action: "update", project_type: "api")
      generator.struct_name.should eq("PostUpdateJSON")
    end
  end

  describe "#page_title" do
    it "returns correct title for index action" do
      generator = AzuCLI::Generate::Page.new("Post", action: "index")
      generator.page_title.should eq("Post List")
    end

    it "returns correct title for new action" do
      generator = AzuCLI::Generate::Page.new("Post", action: "new")
      generator.page_title.should eq("New Post")
    end

    it "returns correct title for show action" do
      generator = AzuCLI::Generate::Page.new("Post", action: "show")
      generator.page_title.should eq("Post Details")
    end

    it "returns correct title for edit action" do
      generator = AzuCLI::Generate::Page.new("Post", action: "edit")
      generator.page_title.should eq("Edit Post")
    end
  end

  describe "#form_action" do
    it "returns correct action for new" do
      generator = AzuCLI::Generate::Page.new("Post", action: "new")
      generator.form_action.should eq("/posts")
    end

    it "returns correct action for edit" do
      generator = AzuCLI::Generate::Page.new("Post", action: "edit")
      generator.form_action.should eq("/posts/{{ post.id }}")
    end
  end

  describe "#form_method" do
    it "returns POST for new action" do
      generator = AzuCLI::Generate::Page.new("Post", action: "new")
      generator.form_method.should eq("POST")
    end

    it "returns PATCH for edit action" do
      generator = AzuCLI::Generate::Page.new("Post", action: "edit")
      generator.form_method.should eq("PATCH")
    end
  end

  describe "#html_input_type" do
    it "returns correct input type for email" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.html_input_type("email").should eq("email")
    end

    it "returns correct input type for password" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.html_input_type("password").should eq("password")
    end

    it "returns correct input type for number fields" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.html_input_type("int32").should eq("number")
      generator.html_input_type("float64").should eq("number")
    end

    it "returns correct input type for boolean" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.html_input_type("bool").should eq("checkbox")
    end

    it "returns correct input type for text" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.html_input_type("text").should eq("textarea")
    end

    it "returns text as default" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.html_input_type("string").should eq("text")
    end
  end

  describe "#field_required?" do
    it "returns false for id field" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.field_required?("id").should be_false
    end

    it "returns false for created_at field" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.field_required?("created_at").should be_false
    end

    it "returns false for updated_at field" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.field_required?("updated_at").should be_false
    end

    it "returns true for other fields" do
      generator = AzuCLI::Generate::Page.new("Post")
      generator.field_required?("title").should be_true
      generator.field_required?("content").should be_true
    end
  end

  describe "#view_data_hash" do
    it "returns correct hash for index action" do
      generator = AzuCLI::Generate::Page.new("Post", action: "index")
      generator.view_data_hash.should eq("posts: posts")
    end

    it "returns correct hash for show action" do
      generator = AzuCLI::Generate::Page.new("Post", action: "show")
      generator.view_data_hash.should eq("post: post")
    end

    it "returns correct hash for new action" do
      generator = AzuCLI::Generate::Page.new("Post", action: "new")
      generator.view_data_hash.should eq("form: form")
    end

    it "returns correct hash for edit action" do
      generator = AzuCLI::Generate::Page.new("Post", action: "edit")
      generator.view_data_hash.should eq("post: post")
    end
  end
end
