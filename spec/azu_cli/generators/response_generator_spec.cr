require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Response do
  it "creates a response generator with basic fields" do
    fields = {"id" => "int64", "name" => "string"}
    generator = AzuCLI::Generate::Response.new("User", fields)
    generator.name.should eq("User")
    generator.fields.should eq(fields)
    generator.snake_case_name.should eq("user")
    generator.struct_name.should eq("UserResponse")
  end

  it "generates correct getter declarations" do
    fields = {"id" => "int64", "name" => "string", "age" => "int32?"}
    generator = AzuCLI::Generate::Response.new("User", fields)
    getters = generator.getter_declarations
    getters.should contain("getter id : Int64")
    getters.should contain("getter name : String")
    getters.should contain("getter age : Int32?")
  end

  it "generates correct constructor params" do
    fields = {"id" => "int64", "name" => "string"}
    generator = AzuCLI::Generate::Response.new("User", fields)
    params = generator.constructor_params
    params.should contain("@id : Int64")
    params.should contain("@name : String")
  end

  it "generates assignments from source type" do
    fields = {"id" => "int64", "name" => "string"}
    generator = AzuCLI::Generate::Response.new("User", fields, "User")
    assigns = generator.assignments_from_source
    assigns.should contain("@id = user.id")
    assigns.should contain("@name = user.name")
  end

  it "generates a response file with fields and from_type" do
    fields = {
      "id"                => "int64",
      "name"              => "string",
      "email"             => "string",
      "age"               => "int32?",
      "profile_image_url" => "string?",
      "created_at"        => "string",
    }
    generator = AzuCLI::Generate::Response.new("User", fields, "User")
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)
    generated_file = File.join(test_dir, "user.cr")
    File.exists?(generated_file).should be_true
    content = File.read(generated_file)
    content.should contain("struct UserResponse")
    content.should contain("include Azu::Response")
    content.should contain("include JSON::Serializable")
    content.should contain("getter id : Int64")
    content.should contain("getter name : String")
    content.should contain("getter email : String")
    content.should contain("getter age : Int32?")
    content.should contain("getter profile_image_url : String?")
    content.should contain("getter created_at : String")
    content.should contain("def initialize(user : User)")
    content.should contain("@id = user.id")
    content.should contain("@name = user.name")
    content.should contain("@email = user.email")
    content.should contain("@age = user.age")
    content.should contain("@profile_image_url = user.profile_image_url")
    content.should contain("@created_at = user.created_at")
    content.should contain("def render")
    content.should contain("to_json")
    content.should contain("end")
    FileUtils.rm_rf(test_dir)
  end

  it "generates a response file with only fields" do
    fields = {"id" => "int64", "name" => "string"}
    generator = AzuCLI::Generate::Response.new("User", fields)
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)
    generated_file = File.join(test_dir, "user.cr")
    File.exists?(generated_file).should be_true
    content = File.read(generated_file)
    content.should contain("struct UserResponse")
    content.should contain("def initialize(@id : Int64, @name : String)")
    content.should contain("def render")
    content.should contain("to_json")
    content.should contain("end")
    FileUtils.rm_rf(test_dir)
  end
end
