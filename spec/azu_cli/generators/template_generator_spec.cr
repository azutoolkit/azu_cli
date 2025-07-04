require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Template do
  describe "#initialize" do
    it "creates a template generator with basic properties" do
      fields = {"name" => "string", "email" => "string", "age" => "int32"}
      generator = AzuCLI::Generate::Template.new("User", fields, "index")

      generator.name.should eq("User")
      generator.fields.should eq(fields)
      generator.action.should eq("index")
      generator.snake_case_name.should eq("user")
      generator.resource_singular.should eq("user")
      generator.resource_plural.should eq("users")
    end

    it "handles complex resource names correctly" do
      fields = {"title" => "string", "content" => "text"}
      generator = AzuCLI::Generate::Template.new("BlogPost", fields, "show")

      generator.snake_case_name.should eq("blog_post")
      generator.resource_singular.should eq("blogpost")
      generator.resource_plural.should eq("blogposts")
    end

    it "handles empty fields" do
      generator = AzuCLI::Generate::Template.new("Simple", {} of String => String, "new")

      generator.fields.should eq({} of String => String)
      generator.resource_singular.should eq("simple")
      generator.resource_plural.should eq("simples")
    end
  end

  describe "#page_title" do
    it "generates correct page title for index action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "index")
      generator.page_title.should eq("User List")
    end

    it "generates correct page title for new action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.page_title.should eq("New User")
    end

    it "generates correct page title for create action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "create")
      generator.page_title.should eq("Create User")
    end

    it "generates correct page title for show action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "show")
      generator.page_title.should eq("User Details")
    end

    it "generates correct page title for edit action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "edit")
      generator.page_title.should eq("Edit User")
    end

    it "generates correct page title for update action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "update")
      generator.page_title.should eq("Update User")
    end

    it "generates correct page title for delete action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "delete")
      generator.page_title.should eq("Delete User")
    end

    it "generates correct page title for custom action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "custom")
      generator.page_title.should eq("Custom User")
    end

    it "handles complex resource names in page titles" do
      generator = AzuCLI::Generate::Template.new("BlogPost", {} of String => String, "index")
      generator.page_title.should eq("BlogPost List")
    end
  end

  describe "#form_action" do
    it "generates correct form action for new action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.form_action.should eq("/users")
    end

    it "generates correct form action for edit action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "edit")
      generator.form_action.should eq("/users/{{ user.id }}")
    end

    it "generates correct form action for other actions" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "create")
      generator.form_action.should eq("/users")
    end

    it "handles complex resource names in form actions" do
      generator = AzuCLI::Generate::Template.new("BlogPost", {} of String => String, "edit")
      generator.form_action.should eq("/blogposts/{{ blogpost.id }}")
    end
  end

  describe "#form_method" do
    it "generates correct form method for new action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.form_method.should eq("POST")
    end

    it "generates correct form method for edit action" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "edit")
      generator.form_method.should eq("PATCH")
    end

    it "generates correct form method for other actions" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "create")
      generator.form_method.should eq("POST")
    end
  end

  describe "#html_input_type" do
    it "maps email type correctly" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.html_input_type("email").should eq("email")
      generator.html_input_type("Email").should eq("email")
      generator.html_input_type("EMAIL").should eq("email")
    end

    it "maps password type correctly" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.html_input_type("password").should eq("password")
      generator.html_input_type("Password").should eq("password")
    end

    it "maps numeric types correctly" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.html_input_type("int32").should eq("number")
      generator.html_input_type("int64").should eq("number")
      generator.html_input_type("float32").should eq("number")
      generator.html_input_type("float64").should eq("number")
    end

    it "maps boolean type correctly" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.html_input_type("bool").should eq("checkbox")
      generator.html_input_type("Bool").should eq("checkbox")
    end

    it "maps time type correctly" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.html_input_type("time").should eq("datetime-local")
      generator.html_input_type("Time").should eq("datetime-local")
    end

    it "maps text type correctly" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.html_input_type("text").should eq("textarea")
      generator.html_input_type("Text").should eq("textarea")
    end

    it "defaults to text for unknown types" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.html_input_type("string").should eq("text")
      generator.html_input_type("unknown").should eq("text")
      generator.html_input_type("").should eq("text")
    end
  end

  describe "#field_label" do
    it "converts field names to camel case labels" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.field_label("first_name").should eq("FirstName")
      generator.field_label("last_name").should eq("LastName")
      generator.field_label("email_address").should eq("EmailAddress")
    end

    it "handles single word field names" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.field_label("name").should eq("Name")
      generator.field_label("email").should eq("Email")
    end

    it "handles already camel case field names" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.field_label("firstName").should eq("FirstName")
      generator.field_label("lastName").should eq("LastName")
    end
  end

  describe "#field_placeholder" do
    it "generates user-friendly placeholders" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.field_placeholder("first_name").should eq("Enter first name")
      generator.field_placeholder("email_address").should eq("Enter email address")
      generator.field_placeholder("phone_number").should eq("Enter phone number")
    end

    it "handles single word field names" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.field_placeholder("name").should eq("Enter name")
      generator.field_placeholder("email").should eq("Enter email")
    end

    it "handles camel case field names" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.field_placeholder("firstName").should eq("Enter firstname")
      generator.field_placeholder("lastName").should eq("Enter lastname")
    end
  end

  describe "#field_required?" do
    it "returns false for system fields" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.field_required?("id").should be_false
      generator.field_required?("created_at").should be_false
      generator.field_required?("updated_at").should be_false
    end

    it "returns true for user-defined fields" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.field_required?("name").should be_true
      generator.field_required?("email").should be_true
      generator.field_required?("first_name").should be_true
      generator.field_required?("age").should be_true
    end

    it "handles case variations" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.field_required?("ID").should be_true
      generator.field_required?("CreatedAt").should be_true
      generator.field_required?("UpdatedAt").should be_true
    end
  end

  describe "#form_classes" do
    it "returns Bootstrap validation classes" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.form_classes.should eq("needs-validation")
    end
  end

  describe "integration with Teeplate::FileTree" do
    it "inherits from Teeplate::FileTree" do
      generator = AzuCLI::Generate::Template.new("User", {} of String => String, "new")
      generator.should be_a(Teeplate::FileTree)
    end
  end

  describe "complex scenarios" do
    it "handles a complete user registration form scenario" do
      fields = {
        "first_name"     => "string",
        "last_name"      => "string",
        "email"          => "email",
        "password"       => "password",
        "age"            => "int32",
        "terms_accepted" => "bool",
      }
      generator = AzuCLI::Generate::Template.new("User", fields, "new")

      # Test all generated values
      generator.page_title.should eq("New User")
      generator.form_action.should eq("/users")
      generator.form_method.should eq("POST")
      generator.form_classes.should eq("needs-validation")

      # Test field-specific methods
      generator.html_input_type("email").should eq("email")
      generator.html_input_type("password").should eq("password")
      generator.html_input_type("int32").should eq("number")
      generator.html_input_type("bool").should eq("checkbox")

      generator.field_label("first_name").should eq("FirstName")
      generator.field_label("last_name").should eq("LastName")

      generator.field_placeholder("first_name").should eq("Enter first name")
      generator.field_placeholder("email").should eq("Enter email")

      generator.field_required?("first_name").should be_true
      generator.field_required?("email").should be_true
      generator.field_required?("id").should be_false
    end

    it "handles a blog post editing scenario" do
      fields = {
        "title"        => "string",
        "content"      => "text",
        "published_at" => "time",
        "featured"     => "bool",
      }
      generator = AzuCLI::Generate::Template.new("BlogPost", fields, "edit")

      generator.page_title.should eq("Edit BlogPost")
      generator.form_action.should eq("/blogposts/{{ blogpost.id }}")
      generator.form_method.should eq("PATCH")

      generator.html_input_type("text").should eq("textarea")
      generator.html_input_type("time").should eq("datetime-local")
      generator.html_input_type("bool").should eq("checkbox")

      generator.field_label("title").should eq("Title")
      generator.field_placeholder("title").should eq("Enter title")
    end
  end
end
