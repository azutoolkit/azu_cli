require "../../spec_helper"
require "../../support/test_helpers"

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
      generator.struct_name.should eq("Post::PostIndexPage")
    end

    it "returns the correct struct name for API project" do
      generator = AzuCLI::Generate::Page.new("Post", project_type: "api")
      generator.struct_name.should eq("Post::PostIndexJSON")
    end

    it "returns the correct struct name for different actions" do
      generator = AzuCLI::Generate::Page.new("Post", action: "create")
      generator.struct_name.should eq("Post::PostCreatePage")

      generator = AzuCLI::Generate::Page.new("Post", action: "update", project_type: "api")
      generator.struct_name.should eq("Post::PostUpdateJSON")
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

  describe "enhanced API/Web mode testing" do
    describe "Web mode page generation" do
      it "generates Web page files with correct content" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/pages")

          generator = AzuCLI::Generate::Page.new("Post", {"title" => "String", "content" => "String"}, "index")
          generator.render(".")

          # Check that page file was created
          page_file = "src/pages/post_index_page.cr"
          File.exists?(page_file).should be_true

          content = File.read(page_file)
          content.should contain("class Post::PostIndexPage")
          content.should contain("include Azu::Page")
          content.should contain("property title : String")
          content.should contain("property content : String")
        end
      end

      it "generates Web page with template path" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/pages")

          generator = AzuCLI::Generate::Page.new("Post", {"title" => "String"}, "show")
          generator.render(".")

          page_file = "src/pages/post_show_page.cr"
          content = File.read(page_file)

          content.should contain("class Post::PostShowPage")
          content.should contain("template_path \"posts/show\"")
        end
      end

      it "generates Web page with form data for new action" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/pages")

          generator = AzuCLI::Generate::Page.new("Post", {"title" => "String", "content" => "String"}, "new")
          generator.render(".")

          page_file = "src/pages/post_new_page.cr"
          content = File.read(page_file)

          content.should contain("class Post::PostNewPage")
          content.should contain("template_path \"posts/new\"")
        end
      end
    end

    describe "API mode JSON generation" do
      it "generates API JSON files with correct content" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/responses")

          generator = AzuCLI::Generate::Page.new("Post", {"title" => "String", "content" => "String"}, "index", "api")
          generator.render(".")

          # Check that response file was created
          response_file = "src/responses/post_index_response.cr"
          File.exists?(response_file).should be_true

          content = File.read(response_file)
          content.should contain("class Post::PostIndexJSON")
          content.should contain("include JSON::Serializable")
          content.should contain("property title : String")
          content.should contain("property content : String")
        end
      end

      it "generates API JSON with proper serialization" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/responses")

          generator = AzuCLI::Generate::Page.new("Post", {"title" => "String", "created_at" => "Time"}, "show", "api")
          generator.render(".")

          response_file = "src/responses/post_show_response.cr"
          content = File.read(response_file)

          content.should contain("class Post::PostShowJSON")
          content.should contain("include JSON::Serializable")
          content.should contain("property title : String")
          content.should contain("property created_at : Time")
        end
      end
    end

    describe "project type handling" do
      it "handles Web project type correctly" do
        generator = AzuCLI::Generate::Page.new("Post", project_type: "web")
        generator.project_type.should eq("web")
      end

      it "handles API project type correctly" do
        generator = AzuCLI::Generate::Page.new("Post", project_type: "api")
        generator.project_type.should eq("api")
      end

      it "defaults to web project type" do
        generator = AzuCLI::Generate::Page.new("Post")
        generator.project_type.should eq("web")
      end
    end

    describe "file structure and placement" do
      it "creates proper directory structure for Web pages" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          generator = AzuCLI::Generate::Page.new("Post", {"title" => "String"}, "index", "web")
          generator.render(".")

          # Check directory structure
          Dir.exists?("src/pages").should be_true
          File.exists?("src/pages/post_index_page.cr").should be_true
        end
      end

      it "creates proper directory structure for API responses" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          generator = AzuCLI::Generate::Page.new("Post", {"title" => "String"}, "index", "api")
          generator.render(".")

          # Check directory structure
          Dir.exists?("src/responses").should be_true
          File.exists?("src/responses/post_index_response.cr").should be_true
        end
      end

      it "handles nested resource names correctly for Web" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/pages")

          generator = AzuCLI::Generate::Page.new("UserProfile", {"name" => "String"}, "index", "web")
          generator.render(".")

          # Check that snake_case is used for filenames
          File.exists?("src/pages/user_profile_index_page.cr").should be_true

          content = File.read("src/pages/user_profile_index_page.cr")
          content.should contain("class UserProfile::UserProfileIndexPage")
        end
      end

      it "handles nested resource names correctly for API" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/responses")

          generator = AzuCLI::Generate::Page.new("UserProfile", {"name" => "String"}, "index", "api")
          generator.render(".")

          # Check that snake_case is used for filenames
          File.exists?("src/responses/user_profile_index_response.cr").should be_true

          content = File.read("src/responses/user_profile_index_response.cr")
          content.should contain("class UserProfile::UserProfileIndexJSON")
        end
      end
    end

    describe "template and view handling" do
      it "generates correct template paths for Web pages" do
        generator = AzuCLI::Generate::Page.new("Post", action: "index")
        generator.template_path.should eq("posts/index")

        generator = AzuCLI::Generate::Page.new("Post", action: "show")
        generator.template_path.should eq("posts/show")

        generator = AzuCLI::Generate::Page.new("Post", action: "new")
        generator.template_path.should eq("posts/new")
      end

      it "generates correct view data for different actions" do
        generator = AzuCLI::Generate::Page.new("Post", action: "index")
        generator.view_data_hash.should eq("posts: posts")

        generator = AzuCLI::Generate::Page.new("Post", action: "show")
        generator.view_data_hash.should eq("post: post")

        generator = AzuCLI::Generate::Page.new("Post", action: "new")
        generator.view_data_hash.should eq("form: form")
      end
    end

    describe "attribute handling" do
      it "handles complex attribute types" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/pages")

          attributes = {
            "title"      => "String",
            "content"    => "String",
            "published"  => "Bool",
            "created_at" => "Time",
            "tags"       => "Array(String)",
          }

          generator = AzuCLI::Generate::Page.new("Post", attributes, "index", "web")
          generator.render(".")

          page_file = "src/pages/post_index_page.cr"
          content = File.read(page_file)

          content.should contain("property title : String")
          content.should contain("property content : String")
          content.should contain("property published : Bool")
          content.should contain("property created_at : Time")
          content.should contain("property tags : Array(String)")
        end
      end

      it "handles optional attributes correctly" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/pages")

          attributes = {"title" => "String", "description" => "String?"}
          generator = AzuCLI::Generate::Page.new("Post", attributes, "index", "web")
          generator.render(".")

          page_file = "src/pages/post_index_page.cr"
          content = File.read(page_file)

          content.should contain("property title : String")
          content.should contain("property description : String?")
        end
      end
    end
  end
end
