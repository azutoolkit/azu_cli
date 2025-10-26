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

      # Build project
      build_project(project_path).should be_true

      # Test model usage
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test model can be instantiated
        user = User.new
        user.name = "John Doe"
        user.email = "john@example.com"
        user.age = 30

        puts "Model test passed: \#{user.name}"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Model test passed: John Doe")
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
      migration_content.should contain("create_table")
      migration_content.should contain("title")
      migration_content.should contain("body")
      migration_content.should contain("published")
    end
  end
end
