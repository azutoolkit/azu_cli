require "../../spec_helper"

# Create a test command for error handler middleware testing
class ErrorHandlerTestCommand < AzuCLI::Commands::Base
  def initialize
    super("error_handler_test", "Test command for error handler middleware")
  end

  def execute : AzuCLI::Commands::Result
    success("Error handler test executed")
  end
end

describe AzuCLI::Middleware::ErrorHandler do
  describe "#error" do
    it "handles ArgumentError" do
      middleware = AzuCLI::Middleware::ErrorHandler.new
      command = ErrorHandlerTestCommand.new
      exception = ArgumentError.new("Invalid argument provided")

      # Should log appropriate error message
      middleware.error(command, exception)
    end

    it "handles File::NotFoundError" do
      middleware = AzuCLI::Middleware::ErrorHandler.new
      command = ErrorHandlerTestCommand.new
      exception = File::NotFoundError.new("File not found", file: "/path/to/missing/file")

      middleware.error(command, exception)
    end

    it "handles File::AccessDeniedError" do
      middleware = AzuCLI::Middleware::ErrorHandler.new
      command = ErrorHandlerTestCommand.new
      exception = File::AccessDeniedError.new("Permission denied", file: "/path/to/protected/file")

      middleware.error(command, exception)
    end

    it "handles generic Exception" do
      middleware = AzuCLI::Middleware::ErrorHandler.new
      command = ErrorHandlerTestCommand.new
      exception = Exception.new("Unexpected error occurred")

      middleware.error(command, exception)
    end

    it "handles exception with nil message" do
      middleware = AzuCLI::Middleware::ErrorHandler.new
      command = ErrorHandlerTestCommand.new
      exception = Exception.new

      middleware.error(command, exception)
    end
  end
end
