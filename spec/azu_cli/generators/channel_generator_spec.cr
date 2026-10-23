require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe AzuCLI::Generate::Channel do
  it "names the class, the topic and the route after the channel" do
    in_generated_project do
      generator = AzuCLI::Generate::Channel.new("LiveUpdate")
      content = rendered(generator, ".", "src/channels/live_update_channel.cr")

      generator.route.should eq("/live_update")
      content.should contain("module Blog\n")
      content.should contain("class LiveUpdateChannel < Azu::Channel")
      content.should contain(%(TOPIC = "live_update"))
      content.should contain(%(ws "/live_update"))
    end
  end

  it "implements what Azu::Channel requires" do
    in_generated_project do
      content = rendered(AzuCLI::Generate::Channel.new("Chat"), ".", "src/channels/chat_channel.cr")

      ["on_connect", "on_message(message : String)", "on_binary(binary : Bytes)", "on_ping(message : String)",
       "on_pong(message : String)", "on_close(code : HTTP::WebSocket::CloseCode?, message : String?)"].each do |method|
        content.should contain("def #{method}")
      end
      content.should_not contain("ActionCable")
    end
  end

  it "accepts identifiers only, so a name cannot inject code" do
    ["Chat", "live_update", "Room42"].each { |name| AzuCLI::Generate::Channel.name_error(name).should be_nil }
    ["Chat; puts 1", "1Chat", "a-b", "", "Chat\"", "Chat Room"].each do |name|
      AzuCLI::Generate::Channel.name_error(name).should_not be_nil
    end
  end
end
