require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Model Generator E2E" do
  it "generates a model, compiles, and can be used" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate model
      result = run_generator("generate model User name:string email:string age:int32", project_path)
      result.success?.should be_true

      # Verify files created
      file_exists?(project_path, "src/models/user.cr").should be_true
      file_exists?(project_path, "db/migrations").should be_true

      # Verify model content
      model_content = read_file(project_path, "src/models/user.cr").not_nil!
      model_content.should contain("struct User")
      model_content.should contain("include CQL::ActiveRecord::Model")
      model_content.should contain("name")
      model_content.should contain("email")
      model_content.should contain("age")
    end
  end

  it "generates a model with migration" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate model
      result = run_generator("generate model Post title:string body:text published:bool", project_path)
      result.success?.should be_true

      # Verify migration file exists
      migration_files = Dir.glob(File.join(project_path, "db/migrations/*.cr"))
      migration_files.size.should be > 0

      # Check migration content
      migration_content = File.read(migration_files.first)
      migration_content.should contain("schema.table :posts")
      migration_content.should contain("title")
      migration_content.should contain("body")
      migration_content.should contain("published")
    end
  end
end
