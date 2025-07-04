require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::PageResponse do
  it "creates a page response generator with basic fields" do
    fields = {"user" => "User", "posts" => "Array(Post)"}
    generator = AzuCLI::Generate::PageResponse.new("User", fields)
    generator.name.should eq("User")
    generator.fields.should eq(fields)
    generator.snake_case_name.should eq("user")
    generator.struct_name.should eq("UserPageResponse")
  end

  it "generates correct getter declarations" do
    fields = {"user" => "User", "posts" => "Array(Post)"}
    generator = AzuCLI::Generate::PageResponse.new("User", fields)
    getters = generator.getter_declarations
    getters.should contain("getter user : User")
    getters.should contain("getter posts : Array(Post)")
  end

  it "generates correct constructor params" do
    fields = {"user" => "User", "posts" => "Array(Post)"}
    generator = AzuCLI::Generate::PageResponse.new("User", fields)
    params = generator.constructor_params
    params.should contain("@user : User")
    params.should contain("@posts : Array(Post)")
  end

  it "generates a page response file with fields" do
    fields = {"user" => "User", "posts" => "Array(Post)"}
    generator = AzuCLI::Generate::PageResponse.new("User", fields)
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)
    generated_file = File.join(test_dir, "user_page_response.cr")
    File.exists?(generated_file).should be_true
    content = File.read(generated_file)
    content.should contain("struct UserPageResponse")
    content.should contain("include Azu::Response")
    content.should contain("include Azu::Templates::Renderable")
    content.should contain("getter user : User")
    content.should contain("getter posts : Array(Post)")
    content.should contain("def initialize(@user : User, @posts : Array(Post))")
    content.should contain("def render")
    content.should contain("view")
    content.should contain("data:")
    content.should contain("end")
    FileUtils.rm_rf(test_dir)
  end
end
