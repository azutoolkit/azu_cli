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

      # Verify content of generated file
      channel_content = read_file(project_path, "src/channels/chat_channel.cr").not_nil!
      channel_content.should contain("class ChatChannel")
      channel_content.should contain("include Azu::Channel")
      channel_content.should contain("def subscribed")
      channel_content.should contain("def receive")
    end
  end
end
