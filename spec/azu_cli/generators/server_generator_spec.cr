require "spec"
require "file_utils"
require "teeplate"
require "../../../src/azu_cli/generators/server_generator"

module AzuCLI::Generators
  describe ServerGenerator do
    it "generates a server file with dynamic handler chain" do
      app_name = "my_app"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "server.cr")

      # Define handlers to include in the server (simplified names)
      handlers = [
        "RequestId",
        "Rescuer",
        "Logger",
        "CORS",
        "Throttle",
      ]

      FileUtils.mkdir_p(output_dir)
      File.delete(output_file) if File.exists?(output_file)

      generator = ServerGenerator.new(app_name, handlers, output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      # Check basic structure
      content.should contain("require \"./src/my_app\"")
      content.should contain("MyApp.start")

      # Check dynamic handler chain
      content.should contain("Azu::Handler::RequestId.new")
      content.should contain("Azu::Handler::Rescuer.new")
      content.should contain("Azu::Handler::Logger.new")
      content.should contain("Azu::Handler::CORS.new")
      content.should contain("Azu::Handler::Throttle.new")

      # Check performance monitoring conditional
      content.should contain("{% if env(\"PERFORMANCE_MONITORING\") == \"true\" || flag?(:performance_monitoring) %}")
      content.should contain("Azu::Handler::DevDashboard.new")
      content.should contain("MyApp::CONFIG.performance_monitor.not_nil!")
      content.should contain("{% else %}")
      content.should contain("{% end %}")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
    end

    it "generates server with default handlers when no handlers specified" do
      app_name = "test_app"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "server.cr")

      FileUtils.mkdir_p(output_dir)
      File.delete(output_file) if File.exists?(output_file)

      generator = ServerGenerator.new(app_name, [] of String, output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      # Check default handlers are included
      content.should contain("Azu::Handler::RequestId.new")
      content.should contain("Azu::Handler::Rescuer.new")
      content.should contain("Azu::Handler::Logger.new")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
    end
  end
end
