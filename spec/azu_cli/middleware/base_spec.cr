require "../../spec_helper"

# Create a concrete implementation of Base for testing
class TestMiddleware < AzuCLI::Middleware::Base
end

# Create a test command for middleware testing
class MiddlewareTestCommand < AzuCLI::Commands::Base
  def initialize
    super("middleware_test", "Test command for middleware testing")
  end

  def execute : AzuCLI::Commands::Result
    success("Middleware test executed")
  end
end

describe AzuCLI::Middleware::Base do
  describe "#before" do
    it "can be called without error" do
      middleware = TestMiddleware.new
      command = MiddlewareTestCommand.new

      # Should not raise - default implementation is empty
      middleware.before(command, ["arg1", "arg2"])
    end

    it "receives command and args" do
      middleware = TestMiddleware.new
      command = MiddlewareTestCommand.new
      args = ["--verbose", "test"]

      # Should accept any valid command and args
      middleware.before(command, args)
    end
  end

  describe "#after" do
    it "can be called with success result" do
      middleware = TestMiddleware.new
      command = MiddlewareTestCommand.new
      result = command.execute

      # Should not raise
      middleware.after(command, result)
    end

    it "can be called with error result" do
      middleware = TestMiddleware.new
      command = MiddlewareTestCommand.new
      result = command.error("Something failed")

      # Should not raise
      middleware.after(command, result)
    end
  end

  describe "#error" do
    it "can be called with exception" do
      middleware = TestMiddleware.new
      command = MiddlewareTestCommand.new
      exception = Exception.new("Test error")

      # Should not raise
      middleware.error(command, exception)
    end

    it "can be called with ArgumentError" do
      middleware = TestMiddleware.new
      command = MiddlewareTestCommand.new
      exception = ArgumentError.new("Invalid argument")

      # Should not raise
      middleware.error(command, exception)
    end
  end
end
