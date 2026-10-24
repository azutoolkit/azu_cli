require "../../spec_helper"
require "../../support/command_helpers"

include CommandHelpers

private class FakeEnvironment < AzuCLI::Commands::Console::Environment
  getter script : String? = nil
  getter script_text : String? = nil
  getter dir : String? = nil

  def initialize(@interpreter : Bool, @code : Int32 = 0)
  end

  def interpreter? : Bool
    @interpreter
  end

  def run_interpreter(script : String, dir : String) : Int32
    @script = script
    @script_text = File.read(script)
    @dir = dir
    @code
  end
end

private def with_environment(environment, &)
  original = AzuCLI::Commands::Console.environment
  AzuCLI::Commands::Console.environment = environment
  yield
ensure
  AzuCLI::Commands::Console.environment = original.not_nil!
end

describe AzuCLI::Commands::Console do
  it "exits with 2 and says why when the compiler has no interpreter, without starting anything" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      environment = FakeEnvironment.new(interpreter: false)
      with_environment(environment) do
        result, _ = run_command(AzuCLI::Commands::Console.new, [] of String)

        result.success?.should be_false
        result.exit_code.should eq 2
        result.error.should contain("no interpreter")
        environment.script.should be_nil
      end
    end
  end

  it "runs the interpreter on a scratch file that requires the app and stops at the prompt, then removes it" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      environment = FakeEnvironment.new(interpreter: true)
      with_environment(environment) do
        result, _ = run_command(AzuCLI::Commands::Console.new, [] of String)

        result.success?.should be_true
        text = environment.script_text.to_s
        text.should contain(%(require "./src/blog.cr"))
        text.should contain("debugger")
        File.dirname(environment.script.to_s).should eq Dir.current
        File.exists?(environment.script.to_s).should be_false
      end
    end
  end

  it "fails with the interpreter's exit code" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_environment(FakeEnvironment.new(interpreter: true, code: 3)) do
        result, _ = run_command(AzuCLI::Commands::Console.new, [] of String)

        result.exit_code.should eq 3
      end
    end
  end

  it "fails with 1 outside a project and 2 for an unknown option" do
    in_tmp_project(shard_yml: nil) do
      with_environment(FakeEnvironment.new(interpreter: true)) do
        run_command(AzuCLI::Commands::Console.new, [] of String)[0].exit_code.should eq 1
        run_command(AzuCLI::Commands::Console.new, ["--bogus"])[0].exit_code.should eq 2
      end
    end
  end

  it "documents its limits in --help" do
    _, help = run_command(AzuCLI::Commands::Console.new, ["--help"])

    help.should contain("crystal i")
    help.should contain("Docker")
    help.should contain("exits with 2")
  end

  it "is registered with the CLI" do
    AzuCLI::CLI.new.command_names.should contain("console")
  end
end
