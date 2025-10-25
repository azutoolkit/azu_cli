require "../../spec_helper"
require "../../support/test_helpers"

describe AzuCLI::Commands::Generate do
  describe "#initialize" do
    it "sets up generate command properties" do
      command = AzuCLI::Commands::Generate.new

      command.name.should eq("generate")
      command.description.should eq("Generate code from templates")
      command.generator_type.should eq("")
      command.generator_name.should eq("")
      command.attributes.should be_empty
      command.actions.should be_empty
      command.options.should be_empty
      command.force.should be_false
      command.api_only.should be_false
      command.web_only.should be_false
      command.skip_tests.should be_false
      command.skip_components.should be_empty
    end
  end

  describe "#execute" do
    it "handles generators without name requirements" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["auth"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles validate generator" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["validate"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "requires name for most generators" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["model"])

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Usage: azu generate <type> <name>")
      end
    end

    it "handles model generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["model", "User", "name:string", "email:string"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles endpoint generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["endpoint", "User", "index", "show"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles service generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["service", "User", "create"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles request generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["request", "User", "create"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles contract generation (deprecated)" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["contract", "User", "create"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
          capture.stderr.should contain("'contract' generator is deprecated")
        end
      end
    end

    it "handles page generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["page", "User", "index"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles job generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["job", "EmailJob"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles joobq setup generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["joobq"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles middleware generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["middleware", "AuthMiddleware"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles migration generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir
        Dir.mkdir_p("db/migrations")

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["migration", "CreateUsers", "name:string", "email:string"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles data migration generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir
        Dir.mkdir_p("db/migrations")

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["data:migration", "UpdateUserData"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles seed generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["seed", "UserSeed"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles component generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["component", "UserCard"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles validator generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["validator", "UserValidator"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles response generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["response", "UserResponse"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles template generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["template", "user_form"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles scaffold generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["scaffold", "User", "name:string", "email:string"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles mailer generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["mailer", "UserMailer"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles channel generation" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["channel", "UserChannel"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "handles unknown generator types" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["unknown_generator", "Name"])

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Unknown generator type")
      end
    end
  end

  describe "argument parsing" do
    it "parses attributes in name:type format" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["model", "User", "name:string", "email:string", "age:int32"])

      command.generator_type.should eq("model")
      command.generator_name.should eq("User")
      # Attributes parsing is tested in the generator classes
    end

    it "handles force flag" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["--force", "model", "User"])

      command.force.should be_true
    end

    it "handles api-only flag" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["--api-only", "model", "User"])

      command.api_only.should be_true
    end

    it "handles web-only flag" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["--web-only", "model", "User"])

      command.web_only.should be_true
    end

    it "handles skip-tests flag" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["--skip-tests", "model", "User"])

      command.skip_tests.should be_true
    end
  end

  describe "project type detection" do
    it "detects API projects and sets api_only mode" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        # Create a project that looks like an API project
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        # Create an API-like structure
        Dir.mkdir_p("src/endpoints")
        File.write("src/endpoints/api.cr", "# API endpoint")

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["model", "User"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
          capture.stderr.should contain("API project detected")
        end
      end
    end
  end

  describe "error handling" do
    it "handles missing required arguments" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["model"])

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Usage: azu generate <type> <name>")
      end
    end

    it "handles invalid generator types" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["invalid_type", "Name"])

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Unknown generator type")
      end
    end
  end

  describe "generator routing" do
    it "routes to all supported generator types" do
      supported_generators = [
        "model", "endpoint", "service", "request", "contract", "page",
        "job", "joobq", "middleware", "migration", "data:migration", "data_migration",
        "seed", "component", "validator", "response", "template", "scaffold",
        "mailer", "channel", "auth", "authentication", "api_resource", "api-resource",
      ]

      supported_generators.each do |generator_type|
        command = AzuCLI::Commands::Generate.new

        if ["auth", "authentication", "validate"].includes?(generator_type)
          command.parse_args([generator_type])
        else
          command.parse_args([generator_type, "TestName"])
        end

        # Should not throw an error for unknown generator type
        # (The actual generation might fail due to missing project structure, but routing should work)
        command.generator_type.should eq(generator_type)
      end
    end
  end
end
