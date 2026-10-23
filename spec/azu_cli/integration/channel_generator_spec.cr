require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Channel Generator E2E" do
  it "generates a channel in the project module, routed at /<name>" do
    with_temp_project("testapp", "web") do |project_path|
      result = run_generator("generate channel LiveUpdate", project_path)
      result.success?.should be_true

      content = read_file(project_path, "src/channels/live_update_channel.cr").not_nil!
      content.should contain("module Testapp")
      content.should contain("class LiveUpdateChannel < Azu::Channel")
      content.should contain(%(ws "/live_update"))
      content.should contain("subscribe(TOPIC)")
      content.should contain("broadcast(TOPIC, message)")
    end
  end

  it "refuses a name that is not an identifier and actions a channel does not have" do
    with_temp_project("testapp", "web") do |project_path|
      run_generator(%(generate channel "Chat; puts 1"), project_path).success?.should be_false
      run_generator("generate channel Chat subscribed receive", project_path).success?.should be_false
      file_exists?(project_path, "src/channels/chat_channel.cr").should be_false
    end
  end
end
