require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Channel Generator E2E" do
  it "generates websocket channel, compiles, and connects" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate channel
      result = run_generator("generate channel Chat", project_path)
      result.success?.should be_true

      # Verify channel file created
      file_exists?(project_path, "src/channels/chat_channel.cr").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test channel can be instantiated
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test channel can be instantiated
        channel = ChatChannel.new
        puts "Channel test passed: \#{channel.class.name}"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Channel test passed")
    end
  end
end
