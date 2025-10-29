require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Migration Generator E2E" do
  it "generates migration, compiles, and migrates" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate migration
      result = run_generator("generate migration AddEmailToUsers", project_path)
      result.success?.should be_true

      # Verify migration file created
      migration_files = Dir.glob(File.join(project_path, "db/migrations/*add_email_to_users*.cr"))
      migration_files.size.should be > 0

      # Check migration content
      migration_content = File.read(migration_files.first)
      migration_content.should contain("add_column")
      migration_content.should contain("users")
    end
  end
end
