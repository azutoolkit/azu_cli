require "../../../spec_helper"

describe AzuCLI::Commands::Jobs::Status do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::Jobs::Status.new
      command.name.should eq("jobs:status")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Jobs::Status.new
      command.description.should contain("status")
    end
  end

  describe "configuration" do
    it "inherits Redis URL from base" do
      command = AzuCLI::Commands::Jobs::Status.new

      command.redis_url.should eq("redis://localhost:6379")
    end

    it "inherits queue from base" do
      command = AzuCLI::Commands::Jobs::Status.new

      command.queue.should eq("default")
    end
  end
end
