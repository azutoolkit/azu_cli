require "../../../spec_helper"

describe AzuCLI::Commands::Jobs::Worker do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.name.should eq("jobs:worker")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.description.should contain("worker")
    end

    it "has default workers count of 1" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.workers.should eq(1)
    end

    it "has default queues array" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.queues.should eq(["default"])
    end

    it "has daemon set to false by default" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.daemon.should be_false
    end
  end

  describe "option parsing" do
    it "parses --workers option" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.parse_args(["--workers", "4"])

      command.workers.should eq(4)
    end

    it "parses -w short option" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.parse_args(["-w", "8"])

      command.workers.should eq(8)
    end

    it "parses --queues option" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.parse_args(["--queues", "high,medium,low"])

      command.queues.should eq(["high", "medium", "low"])
    end

    it "parses -q short option" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.parse_args(["-q", "mailers,default"])

      command.queues.should eq(["mailers", "default"])
    end

    it "parses --daemon option" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.parse_args(["--daemon"])

      command.daemon.should be_true
    end

    it "parses -d short option" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.parse_args(["-d"])

      command.daemon.should be_true
    end

    it "parses --verbose option" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.parse_args(["--verbose"])

      command.verbose.should be_true
    end

    it "parses -v short option" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.parse_args(["-v"])

      command.verbose.should be_true
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::Jobs::Worker.new
      command.parse_args(["--workers", "2", "--queues", "critical,high", "--verbose"])

      command.workers.should eq(2)
      command.queues.should eq(["critical", "high"])
      command.verbose.should be_true
    end
  end
end
