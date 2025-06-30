require "../spec_helper"

describe AzuCLI::Logger do
  describe "#setup" do
    it "sets up logging correctly" do
      AzuCLI::Logger.setup
      # Should not raise any errors
    end
  end

  describe "logging methods" do
    it "provides all standard log levels" do
      # These should not raise errors
      AzuCLI::Logger.debug("Debug message")
      AzuCLI::Logger.info("Info message")
      AzuCLI::Logger.warn("Warning message")
      AzuCLI::Logger.error("Error message")
      AzuCLI::Logger.fatal("Fatal message")
    end

    it "provides CLI-specific logging methods" do
      # These should not raise errors
      AzuCLI::Logger.success("Success message")
      AzuCLI::Logger.title("Title message")
      AzuCLI::Logger.announce("Announcement")
      AzuCLI::Logger.step(1, 3, "Step message")
      AzuCLI::Logger.file_created("/path/to/file")
      AzuCLI::Logger.file_modified("/path/to/file")
      AzuCLI::Logger.file_skipped("/path/to/file")
    end

    it "handles progress logging" do
      AzuCLI::Logger.progress_start("Starting operation")
      AzuCLI::Logger.progress_done(true)

      AzuCLI::Logger.progress_start("Starting another operation")
      AzuCLI::Logger.progress_done(false)
    end

    it "handles exception logging" do
      ex = Exception.new("Test exception")
      # Should not raise errors
      AzuCLI::Logger.exception(ex, "Test context")
      AzuCLI::Logger.exception(ex)
    end
  end
end
