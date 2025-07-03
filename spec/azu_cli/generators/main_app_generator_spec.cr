require "../../spec_helper"
require "file_utils"
require "teeplate"
require "../../../src/azu_cli/generators/base"
require "../../../src/azu_cli/generators/main_app_generator"

module AzuCLI::Generators
  describe MainAppGenerator do
    describe "#initialize" do
      it "creates generator with valid app name" do
        generator = MainAppGenerator.new("test_app")
        generator.name.should eq("test_app")
        generator.output_dir.should eq("src")
        generator.generate_specs.should be_true
      end

      it "creates generator with custom output directory" do
        generator = MainAppGenerator.new("test_app", "custom_src")
        generator.output_dir.should eq("custom_src")
      end

      it "creates generator with specs disabled" do
        generator = MainAppGenerator.new("test_app", "src", false)
        generator.generate_specs.should be_false
      end

      it "raises error for empty app name" do
        expect_raises(ArgumentError, "Name cannot be empty") do
          MainAppGenerator.new("")
        end
      end

      it "raises error for invalid app name" do
        expect_raises(ArgumentError, "Name must be a valid identifier") do
          MainAppGenerator.new("123invalid")
        end
      end
    end

    describe "#template_directory" do
      it "returns correct template directory" do
        generator = MainAppGenerator.new("test_app")
        generator.template_directory.should contain("templates/generators/main_app")
      end
    end

    describe "#build_output_path" do
      it "returns correct output path for main file" do
        generator = MainAppGenerator.new("test_app")
        generator.build_output_path.should eq("src/test_app.cr")
      end

      it "returns correct output path with custom directory" do
        generator = MainAppGenerator.new("test_app", "custom_src")
        generator.build_output_path.should eq("custom_src/test_app.cr")
      end
    end

    describe "#spec_template_name" do
      it "returns correct spec template name" do
        generator = MainAppGenerator.new("test_app")
        generator.spec_template_name.should eq("{{app_name}}_spec.cr.ecr")
      end
    end

    describe "#app_name_camelcase" do
      it "converts app name to camelcase" do
        generator = MainAppGenerator.new("test_app")
        generator.app_name_camelcase.should eq("TestApp")
      end

      it "handles single word app names" do
        generator = MainAppGenerator.new("blog")
        generator.app_name_camelcase.should eq("Blog")
      end

      it "handles multiple underscores" do
        generator = MainAppGenerator.new("my_awesome_app")
        generator.app_name_camelcase.should eq("MyAwesomeApp")
      end
    end

    describe "#app_name" do
      it "returns original app name" do
        generator = MainAppGenerator.new("test_app")
        generator.app_name.should eq("test_app")
      end
    end

    describe "#generate!" do
      it "validates preconditions" do
        generator = MainAppGenerator.new("test_app")
        # This should not raise an error for valid input
        generator.should respond_to(:generate!)
      end

      it "handles spec generation when enabled" do
        generator = MainAppGenerator.new("test_app", "src", true)
        generator.generate_specs.should be_true
      end

      it "skips spec generation when disabled" do
        generator = MainAppGenerator.new("test_app", "src", false)
        generator.generate_specs.should be_false
      end
    end

    describe "edge cases" do
      it "handles app names with numbers" do
        generator = MainAppGenerator.new("app_v2")
        generator.app_name.should eq("app_v2")
        generator.app_name_camelcase.should eq("AppV2")
      end

      it "handles app names with underscores at start" do
        expect_raises(ArgumentError, "Name must be a valid identifier") do
          MainAppGenerator.new("_invalid_app")
        end
      end

      it "handles very long app names" do
        long_name = "a" * 100
        generator = MainAppGenerator.new(long_name)
        generator.app_name.should eq(long_name)
      end
    end

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
