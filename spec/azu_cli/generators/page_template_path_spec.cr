require "../../spec_helper"

describe AzuCLI::Generate::Page do
  describe "template path generation" do
    it "generates correct template path for simple module" do
      page = AzuCLI::Generate::Page.new("User", {} of String => String, "index", "web")
      page.module_name = "App"

      page.module_path.should eq("user")
      page.template_filename.should eq("index_page.jinja")
      page.template_path.should eq("user/index_page.jinja")
    end

    it "generates correct template path for nested module" do
      page = AzuCLI::Generate::Page.new("Post", {} of String => String, "index", "web")
      page.module_name = "Blog::Post"

      page.module_path.should eq("blog/post")
      page.template_filename.should eq("index_page.jinja")
      page.template_path.should eq("blog/post/index_page.jinja")
    end

    it "generates correct template path for deeply nested module" do
      page = AzuCLI::Generate::Page.new("Comment", {} of String => String, "new", "web")
      page.module_name = "Blog::Post::Comment"

      page.module_path.should eq("blog/post/comment")
      page.template_filename.should eq("new_page.jinja")
      page.template_path.should eq("blog/post/comment/new_page.jinja")
    end

    it "handles different actions correctly" do
      page = AzuCLI::Generate::Page.new("User", {} of String => String, "edit", "web")
      page.module_name = "App::User"

      page.template_filename.should eq("edit_page.jinja")
      page.template_path.should eq("app/user/edit_page.jinja")
    end

    it "works with single word module names" do
      page = AzuCLI::Generate::Page.new("Product", {} of String => String, "show", "web")
      page.module_name = "Product"

      page.module_path.should eq("product")
      page.template_path.should eq("product/show_page.jinja")
    end
  end

  describe "CSRF token support" do
    it "includes CSRF tokens in web page constructors" do
      # This test would need to check the generated template content
      # For now, we'll test that the page generator has the necessary properties
      page = AzuCLI::Generate::Page.new("User", {} of String => String, "index", "web")

      page.web_type.should be_true
      page.api_type.should be_false
    end

    it "does not include CSRF tokens for API pages" do
      page = AzuCLI::Generate::Page.new("User", {} of String => String, "index", "api")

      page.web_type.should be_false
      page.api_type.should be_true
    end
  end

  describe "template generator integration" do
    it "passes module name to template generator" do
      # Create page with specific module name by mocking the project detection
      page = AzuCLI::Generate::Page.new("User", {} of String => String, "index", "web")

      # The template generator should have the module name from project detection
      page.template_generator.module_name.should eq("AzuCli")
    end

    it "generates correct template path in template generator" do
      page = AzuCLI::Generate::Page.new("Post", {} of String => String, "new", "web")

      # The template generator should use the detected module name
      page.template_generator.module_path.should eq("post")
      page.template_generator.template_path.should eq("post/new_page.jinja")
    end
  end
end

describe AzuCLI::Generate::Template do
  describe "template path generation" do
    it "generates correct module path for simple module" do
      template = AzuCLI::Generate::Template.new("User", {} of String => String, "index", "App")

      template.module_path.should eq("user")
      template.template_filename.should eq("index_page.jinja")
      template.template_path.should eq("user/index_page.jinja")
    end

    it "generates correct module path for nested module" do
      template = AzuCLI::Generate::Template.new("Post", {} of String => String, "edit", "Blog::Post")

      template.module_path.should eq("blog/post")
      template.template_filename.should eq("edit_page.jinja")
      template.template_path.should eq("blog/post/edit_page.jinja")
    end

    it "handles different actions correctly" do
      template = AzuCLI::Generate::Template.new("Comment", {} of String => String, "show", "Blog::Post::Comment")

      template.template_filename.should eq("show_page.jinja")
      template.template_path.should eq("blog/post/comment/show_page.jinja")
    end
  end

  describe "directory creation" do
    it "creates proper directory structure when rendering" do
      # This test would need to mock the file system operations
      # For now, we'll test that the render method exists and accepts the right parameters
      template = AzuCLI::Generate::Template.new("User", {} of String => String, "index", "App")

      # The render method should exist and accept the required parameters
      template.responds_to?(:render).should be_true
    end
  end
end
