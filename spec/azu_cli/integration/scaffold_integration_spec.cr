require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe "Scaffold Integration" do
  scaffold = ->(arguments : Array(String)) do
    command = AzuCLI::Commands::Generate.new
    command.parse_args(["scaffold", "Post", "title:string", "body:text", "published:bool"] + arguments)
    command.execute
  end

  it "generates every layer of a web resource in one namespace" do
    in_generated_project do
      scaffold.call([] of String).success?.should be_true

      files = Dir.glob("{src,public}/**/*").select { |path| File.file?(path) && !path.starts_with?("src/db/schema") }.sort
      files.reject! { |path| path.matches?(/\d{14}_create_posts/) }
      files.should eq(%w(
        public/templates/blog/posts/_form.jinja
        public/templates/blog/posts/edit_page.jinja
        public/templates/blog/posts/index_page.jinja
        public/templates/blog/posts/new_page.jinja
        public/templates/blog/posts/show_page.jinja
        src/endpoints/posts/create_endpoint.cr
        src/endpoints/posts/destroy_endpoint.cr
        src/endpoints/posts/edit_endpoint.cr
        src/endpoints/posts/index_endpoint.cr
        src/endpoints/posts/new_endpoint.cr
        src/endpoints/posts/show_endpoint.cr
        src/endpoints/posts/update_endpoint.cr
        src/models/post.cr
        src/pages/posts/edit_page.cr
        src/pages/posts/index_page.cr
        src/pages/posts/new_page.cr
        src/pages/posts/show_page.cr
        src/requests/posts/create_request.cr
        src/requests/posts/destroy_request.cr
        src/requests/posts/edit_request.cr
        src/requests/posts/index_request.cr
        src/requests/posts/new_request.cr
        src/requests/posts/show_request.cr
        src/requests/posts/update_request.cr
        src/requests/predicates.cr
        src/services/posts/create_service.cr
        src/services/posts/destroy_service.cr
        src/services/posts/update_service.cr
      ))
      Dir.glob("src/db/migrations/*_create_posts.cr").size.should eq(1)
    end
  end

  it "defines every constant the endpoints use" do
    in_generated_project do
      scaffold.call([] of String).success?.should be_true

      sources = Dir.glob("src/**/*.cr").map { |path| File.read(path) }.join("\n")
      endpoints = Dir.glob("src/endpoints/posts/*.cr").map { |path| File.read(path) }.join("\n")
      used = endpoints.scan(/Posts::\w+/).map(&.[0]).to_set

      used.should_not be_empty
      used.each do |constant|
        sources.should match(/(struct|class) #{constant}\b/)
      end
    end
  end

  it "renders each page where Renderable#page_path looks for its template" do
    in_generated_project do
      scaffold.call([] of String).success?.should be_true

      Dir.glob("src/pages/posts/*_page.cr").each do |page|
        class_name = "Blog::Posts::#{File.basename(page, ".cr").camelcase}"
        template = "public/templates/#{class_name.split("::").join("/").underscore}.jinja"
        File.exists?(template).should be_true
      end
    end
  end

  it "creates the table in the migration and in the schema" do
    in_generated_project do
      scaffold.call([] of String).success?.should be_true

      Dir.glob("src/db/migrations/*_create_posts.cr").first.tap do |migration|
        File.read(migration).should contain("boolean :published, default: false")
      end
      File.read("src/db/schema.cr").should contain("table :posts do")
    end
  end

  it "generates JSON responses and no forms for an API" do
    in_generated_project do
      scaffold.call(["--api-only"]).success?.should be_true

      File.exists?("src/responses/posts/index_response.cr").should be_true
      File.exists?("src/responses/posts/show_response.cr").should be_true
      File.exists?("src/endpoints/posts/create_endpoint.cr").should be_true
      File.exists?("src/endpoints/posts/new_endpoint.cr").should be_false
      Dir.glob("src/pages/**/*").should be_empty
      Dir.glob("public/**/*").should be_empty
    end
  end

  it "skips the components it is told to" do
    in_generated_project do
      scaffold.call(["--skip", "template,page"]).success?.should be_true

      Dir.glob("public/**/*").should be_empty
      Dir.glob("src/pages/**/*").should be_empty
      File.exists?("src/models/post.cr").should be_true
    end
  end

  it "rejects resource names that collide with the generated code" do
    in_generated_project do
      ["Status", "Series"].each do |name|
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["scaffold", name, "title:string"])

        command.execute.success?.should be_false
        Dir.glob("src/**/*.cr").reject { |path| path.starts_with?("src/db") }.should be_empty
      end
    end
  end

  it "rejects field names that are not identifiers or are keywords" do
    in_generated_project do
      ["end:time", "first-name:string", "na\"me:string"].each do |attribute|
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["scaffold", "Post", attribute])

        command.execute.success?.should be_false
      end
    end
  end

  it "supports modifiers and optional types" do
    in_generated_project do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["scaffold", "Person", "email:string:unique", "age:int32?", "team_id:int64:ref:teams"])
      command.execute.success?.should be_true

      migration = File.read(Dir.glob("src/db/migrations/*_create_people.cr").first)
      migration.should contain("text :email, unique: true")
      migration.should contain("column :age, Int32, null: true")
      migration.should contain("foreign_key [:team_id], references: :teams")
      File.exists?("src/models/person.cr").should be_true
      File.read("src/requests/people/update_request.cr").should contain("getter age : Int32?")
    end
  end

  it "names the actions it supports when asked for another" do
    in_generated_project do
      {["endpoint", "Users", "activate"], ["service", "EmailSender", "send"], ["request", "User", "archive"]}.each do |arguments|
        command = AzuCLI::Commands::Generate.new
        command.parse_args(arguments)
        result = command.execute

        result.success?.should be_false
        result.error.should contain("Supported actions")
        Dir.glob("src/{endpoints,services,requests}/**/*.cr").should be_empty
      end
    end
  end

  it "rejects an unsupported attribute type" do
    in_generated_project do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["scaffold", "Post", "title:invalid_type"])

      command.execute.success?.should be_false
    end
  end
end
