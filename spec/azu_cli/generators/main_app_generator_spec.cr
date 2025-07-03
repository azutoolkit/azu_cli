require "spec"
require "file_utils"
require "teeplate"
require "../../../src/azu_cli/generators/base"
require "../../../src/azu_cli/generators/main_app_generator"

module AzuCLI::Generators
  describe MainAppGenerator do
    it "generates a main application file with correct module name and structure" do
      app_name = "test_app"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "#{app_name}.cr")
      FileUtils.mkdir_p(output_dir)
      File.delete(output_file) if File.exists?(output_file)

      generator = MainAppGenerator.new(app_name, output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)
      content.should contain("module TestApp")
      content.should contain("include Azu")
      content.should contain("configure do")
      content.should contain("require \"./models/*\"")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
    end
  end
end
