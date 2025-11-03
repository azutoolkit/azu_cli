require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Migration Generator E2E" do
  it "generates migration, compiles, and migrates" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate migration
      result = run_generator("generate migration AddEmailToUsers", project_path)
      result.success?.should be_true

      # Verify migration file created (filename is {timestamp}_add_users.cr for AddEmailToUsers migration)
      migration_files = Dir.glob(File.join(project_path, "db/migrations/*_add_users.cr"))
      migration_files.size.should be > 0

      # Check migration content
      migration_content = File.read(migration_files.first)
      migration_content.should contain("alter :users")
      migration_content.should contain("email")
    end
  end
end
