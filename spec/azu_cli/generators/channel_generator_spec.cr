require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Channel do
  it "creates a channel generator with name" do
    generator = AzuCLI::Generate::Channel.new("Chat")

    generator.name.should eq("Chat")
    generator.snake_case_name.should eq("chat")
    generator.camel_case_name.should eq("Chat")
  end

  it "creates a channel generator with custom actions" do
    actions = ["connect", "disconnect", "message"]
    generator = AzuCLI::Generate::Channel.new("Notification", actions)

    generator.name.should eq("Notification")
    generator.actions.should eq(actions)
  end

  it "uses default actions when none provided" do
    generator = AzuCLI::Generate::Channel.new("Chat")

    generator.actions.should contain("subscribed")
    generator.actions.should contain("unsubscribed")
    generator.actions.should contain("receive")
  end

  it "converts name to snake_case" do
    generator = AzuCLI::Generate::Channel.new("UserNotification")

    generator.snake_case_name.should eq("user_notification")
  end

  it "converts name to camelCase" do
    generator = AzuCLI::Generate::Channel.new("user_chat")

    generator.camel_case_name.should eq("UserChat")
  end

  describe "#action_methods" do
    it "generates subscribed method" do
      generator = AzuCLI::Generate::Channel.new("Chat", ["subscribed"])

      methods = generator.action_methods
      methods.should contain("def subscribed")
      methods.should contain("Client subscribed")
    end

    it "generates unsubscribed method" do
      generator = AzuCLI::Generate::Channel.new("Chat", ["unsubscribed"])

      methods = generator.action_methods
      methods.should contain("def unsubscribed")
      methods.should contain("Client unsubscribed")
    end

    it "generates receive method" do
      generator = AzuCLI::Generate::Channel.new("Chat", ["receive"])

      methods = generator.action_methods
      methods.should contain("def receive(data : JSON::Any)")
      methods.should contain("Received data")
    end

    it "generates custom action methods" do
      generator = AzuCLI::Generate::Channel.new("Chat", ["send_message"])

      methods = generator.action_methods
      methods.should contain("def send_message(data : JSON::Any)")
    end

    it "generates multiple action methods" do
      generator = AzuCLI::Generate::Channel.new("Chat", ["subscribed", "receive", "custom"])

      methods = generator.action_methods
      methods.should contain("def subscribed")
      methods.should contain("def receive")
      methods.should contain("def custom")
    end
  end

  describe "#client_javascript" do
    it "generates client-side JavaScript" do
      generator = AzuCLI::Generate::Channel.new("Chat")

      js = generator.client_javascript
      js.should contain("class ChatChannel")
      js.should contain("constructor")
      js.should contain("connect()")
      js.should contain("subscribe()")
      js.should contain("send(data)")
      js.should contain("disconnect()")
      js.should contain("WebSocket")
    end

    it "includes channel name in JavaScript class" do
      generator = AzuCLI::Generate::Channel.new("Notification")

      js = generator.client_javascript
      js.should contain("class NotificationChannel")
      js.should contain("Connected to NotificationChannel")
    end

    it "includes snake_case identifier" do
      generator = AzuCLI::Generate::Channel.new("UserChat")

      js = generator.client_javascript
      js.should contain("identifier: 'user_chat'")
    end
  end
end
