require "../../spec_helper"

# Create a test command for middleware testing
class LoggingTestCommand < AzuCLI::Commands::Base
  def initialize
    super("logging_test", "Test command for logging middleware")
  end

  def execute : AzuCLI::Commands::Result
    success("Logging test executed")
  end
end

describe AzuCLI::Middleware::Logging do
  describe "#before" do
    it "logs command execution start" do
      middleware = AzuCLI::Middleware::Logging.new
      command = LoggingTestCommand.new
      args = ["arg1", "--verbose"]

      # Should not raise - logs internally
      middleware.before(command, args)
    end

    it "handles empty args" do
      middleware = AzuCLI::Middleware::Logging.new
      command = LoggingTestCommand.new

      middleware.before(command, [] of String)
    end
  end

  describe "#after" do
    it "logs success result" do
      middleware = AzuCLI::Middleware::Logging.new
      command = LoggingTestCommand.new
      result = command.success("Operation completed")

      middleware.after(command, result)
    end

    it "logs error result" do
      middleware = AzuCLI::Middleware::Logging.new
      command = LoggingTestCommand.new
      result = command.error("Operation failed")

      middleware.after(command, result)
    end
  end

  describe "#error" do
    it "logs exception details" do
      middleware = AzuCLI::Middleware::Logging.new
      command = LoggingTestCommand.new
      exception = Exception.new("Test error message")

      middleware.error(command, exception)
    end

    it "handles exception without backtrace" do
      middleware = AzuCLI::Middleware::Logging.new
      command = LoggingTestCommand.new
      exception = Exception.new("No backtrace error")

      # Should handle nil backtrace gracefully
      middleware.error(command, exception)
    end
  end
end
