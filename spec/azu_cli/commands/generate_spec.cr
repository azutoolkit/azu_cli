require "../../spec_helper"
require "../../support/test_helpers"
require "../../support/generator_helpers"

private struct ScratchProject
  include GeneratorHelpers
end

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
      repository = Dir.current
      before = Dir.glob("#{repository}/**/*", match: :dot_files).reject { |path| path.includes?("/lib/") || path.includes?("/bin/") || path.includes?("/.git/") || path.ends_with?("/.git") || path.includes?("/tmp_test_") }.sort
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        temp_project.create_config_dir
        temp_project.create_src_dir

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["auth"])

        # The generator writes into the working directory: keep it inside the scratch project.
        Dir.cd(temp_project.path) do
          TestHelpers::TestSetup.with_captured_output do |_|
            result = command.execute
            result.success?.should be_true
          end
        end
      end
      after = Dir.glob("#{repository}/**/*", match: :dot_files).reject { |path| path.includes?("/lib/") || path.includes?("/bin/") || path.includes?("/.git/") || path.ends_with?("/.git") || path.includes?("/tmp_test_") }.sort
      after.should eq(before) # nothing was written into the repository
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
    # Flags are parsed by #execute and follow the type and name (`azu generate <type> <name> [options]`),
    # so each example runs the command in a scratch project.
    it "reads the type, name and attributes" do
      ScratchProject.new.in_generated_project do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["model", "User", "name:string", "email:string", "age:int32"])
        TestHelpers::TestSetup.with_captured_output { command.execute.success?.should be_true }

        command.generator_type.should eq("model")
        command.generator_name.should eq("User")
        command.attributes.should eq({"name" => "string", "email" => "string", "age" => "int32"})
      end
    end

    it "handles force flag" do
      ScratchProject.new.in_generated_project do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["model", "User", "--force"])
        TestHelpers::TestSetup.with_captured_output { command.execute.success?.should be_true }

        command.force.should be_true
      end
    end

    it "handles api-only flag" do
      ScratchProject.new.in_generated_project do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["model", "User", "--api-only"])
        TestHelpers::TestSetup.with_captured_output { command.execute.success?.should be_true }

        command.api_only.should be_true
      end
    end

    it "handles web-only flag" do
      ScratchProject.new.in_generated_project do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["model", "User", "--web-only"])
        TestHelpers::TestSetup.with_captured_output { command.execute.success?.should be_true }

        command.web_only.should be_true
      end
    end

    it "handles skip-tests flag" do
      ScratchProject.new.in_generated_project do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["model", "User", "--skip-tests"])
        TestHelpers::TestSetup.with_captured_output { command.execute.success?.should be_true }

        command.skip_tests.should be_true
        Dir.glob("db/migrations/*").should be_empty
      end
    end
  end

  describe "project type detection" do
    it "detects API projects and sets api_only mode" do
      ScratchProject.new.in_generated_project do
        Dir.mkdir_p("config")
        File.write("config/azu.yml", "project:\n  type: api\n")

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["model", "User"])

        TestHelpers::TestSetup.with_captured_output { command.execute.success?.should be_true }
        command.api_only.should be_true
      end
    end

    it "keeps web mode for a web-only request in an API project" do
      ScratchProject.new.in_generated_project do
        Dir.mkdir_p("config")
        File.write("config/azu.yml", "project:\n  type: api\n")

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["model", "User", "--web-only"])

        TestHelpers::TestSetup.with_captured_output { command.execute.success?.should be_true }
        command.api_only.should be_false
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
    it "routes every supported generator type" do
      AzuCLI::Commands::Generate::GENERATOR_TYPES.each do |generator_type|
        ScratchProject.new.in_generated_project do
          command = AzuCLI::Commands::Generate.new
          if AzuCLI::Commands::Generate::NAMELESS_GENERATORS.includes?(generator_type)
            command.parse_args([generator_type])
          else
            command.parse_args([generator_type, "TestName"])
          end

          # The generation itself may fail for lack of project structure, but the type must be routed.
          TestHelpers::TestSetup.with_captured_output do
            result = command.execute
            result.error.to_s.should_not contain("Unknown generator type")
          end
          command.generator_type.should eq(generator_type)
        end
      end
    end
  end
end
