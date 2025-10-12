require "../../spec_helper"

describe AzuCLI::Commands::Jobs::Base do
  # Jobs::Base is an abstract class, so we test with a concrete subclass
  describe "job configuration" do
    it "loads default Redis URL" do
      command = AzuCLI::Commands::Jobs::Worker.new

      command.redis_url.should eq("redis://localhost:6379")
    end

    it "loads default queue" do
      command = AzuCLI::Commands::Jobs::Worker.new

      command.queue.should eq("default")
    end

    it "has verbose set to false by default" do
      command = AzuCLI::Commands::Jobs::Worker.new

      command.verbose.should be_false
    end
  end
end
