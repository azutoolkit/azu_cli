require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Page do
  describe "API project type (response functionality)" do
    it "creates a page generator with basic fields for API" do
      fields = {"id" => "int64", "name" => "string"}
      generator = AzuCLI::Generate::Page.new("User", fields, "index", "api")
      generator.name.should eq("User")
      generator.fields.should eq(fields)
      generator.snake_case_name.should eq("user")
      generator.struct_name.should eq("User::UserIndexJSON")
      generator.api_type.should be_true
      generator.web_type.should be_false
    end

    it "generates correct getter declarations for API" do
      fields = {"id" => "int64", "name" => "string", "age" => "int32?"}
      generator = AzuCLI::Generate::Page.new("User", fields, "index", "api")
      getters = generator.getter_declarations
      getters.should contain("getter id : Int64")
      getters.should contain("getter name : String")
      getters.should contain("getter age : Int32?")
    end

    it "generates correct constructor params for API" do
      fields = {"id" => "int64", "name" => "string"}
      generator = AzuCLI::Generate::Page.new("User", fields, "index", "api")
      params = generator.constructor_params
      params.should contain("@id : Int64")
      params.should contain("@name : String")
    end

    it "generates assignments from source type for API" do
      fields = {"id" => "int64", "name" => "string"}
      generator = AzuCLI::Generate::Page.new("User", fields, "index", "api", "User")
      assigns = generator.assignments_from_source
      assigns.should contain("@id = user.id")
      assigns.should contain("@name = user.name")
    end

    it "generates API render method" do
      fields = {"id" => "int64", "name" => "string"}
      generator = AzuCLI::Generate::Page.new("User", fields, "index", "api")
      render_method = generator.render_method
      render_method.should contain("def render")
      render_method.should contain("to_json")
    end

    it "generates correct struct name for different actions" do
      fields = {"id" => "int64", "name" => "string"}

      generator = AzuCLI::Generate::Page.new("User", fields, "create", "api")
      generator.struct_name.should eq("User::UserCreateJSON")

      generator = AzuCLI::Generate::Page.new("User", fields, "update", "api")
      generator.struct_name.should eq("User::UserUpdateJSON")

      generator = AzuCLI::Generate::Page.new("User", fields, "show", "api")
      generator.struct_name.should eq("User::UserShowJSON")
    end
  end

  describe "Web project type (page functionality)" do
    it "creates a page generator with basic fields for web" do
      fields = {"id" => "int64", "name" => "string"}
      generator = AzuCLI::Generate::Page.new("User", fields, "index", "web")
      generator.name.should eq("User")
      generator.fields.should eq(fields)
      generator.snake_case_name.should eq("user")
      generator.struct_name.should eq("User::UserIndexPage")
      generator.web_type.should be_true
      generator.api_type.should be_false
    end

    it "generates web render method" do
      fields = {"id" => "int64", "name" => "string"}
      generator = AzuCLI::Generate::Page.new("User", fields, "index", "web")
      render_method = generator.render_method
      render_method.should contain("def render")
      render_method.should contain("view")
    end

    it "generates correct struct name for different actions" do
      fields = {"id" => "int64", "name" => "string"}

      generator = AzuCLI::Generate::Page.new("User", fields, "create", "web")
      generator.struct_name.should eq("User::UserCreatePage")

      generator = AzuCLI::Generate::Page.new("User", fields, "update", "web")
      generator.struct_name.should eq("User::UserUpdatePage")

      generator = AzuCLI::Generate::Page.new("User", fields, "show", "web")
      generator.struct_name.should eq("User::UserShowPage")
    end
  end
end
