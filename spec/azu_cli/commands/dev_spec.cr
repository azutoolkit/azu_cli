require "../../spec_helper"
require "../../support/command_helpers"

include CommandHelpers

private def with_builder(command : String, args : Array(String), &)
  original = AzuCLI::Commands::Dev.builder
  AzuCLI::Commands::Dev.builder = ->(target : String) { AzuCLI::DevServer::Builder.new(command, args) }
  yield
ensure
  AzuCLI::Commands::Dev.builder = original.not_nil!
end

private def dev(args = [] of String) : AzuCLI::Commands::Dev
  command = AzuCLI::Commands::Dev.new
  command.parse_args(args)
  command
end

# A "binary" for bin/<target> that records its start and runs until it is stopped.
private def write_app(dir : String, name : String = "blog")
  Dir.mkdir_p(File.join(dir, "bin"))
  path = File.join(dir, "bin", name)
  File.write(path, "#!/bin/sh\necho started >> #{dir}/starts\nexec sleep 30\n")
  File.chmod(path, 0o755)
end

private def starts(dir : String) : Int32
  File.exists?(File.join(dir, "starts")) ? File.read(File.join(dir, "starts")).lines.size : 0
end

describe AzuCLI::Commands::Dev do
  describe "options" do
    it "leaves port, host and environment to the app's own environment unless given" do
      command = dev
      command.read_options.should be_nil

      command.child_env.should be_empty
      command.debounce.should eq 300.milliseconds
      command.interval.should eq 250.milliseconds
    end

    it "passes the flags to the app" do
      command = dev(["--port", "3000", "--host=0.0.0.0", "--env", "staging", "--debounce", "800", "--interval", "100"])
      command.read_options.should be_nil

      command.child_env.should eq({"PORT" => "3000", "HOST" => "0.0.0.0", "CRYSTAL_ENV" => "staging"})
      command.debounce.should eq 800.milliseconds
      command.interval.should eq 100.milliseconds
    end

    it "rejects unknown options and bad values with a usage error (exit 2)" do
      [["--bogus"], ["--port", "abc"], ["--port", "70000"], ["--port", "0"], ["--debounce", "0"], ["--interval", "-5"], ["--no-watch"]].each do |args|
        in_tmp_project do
          result, _ = run_command(AzuCLI::Commands::Dev.new, args)

          result.success?.should be_false
          result.exit_code.should eq 2
        end
      end
    end

    it "fails with 1 outside a project" do
      in_tmp_project(shard_yml: nil) do
        run_command(AzuCLI::Commands::Dev.new, [] of String)[0].exit_code.should eq 1
      end
    end

    it "documents exactly the options it accepts, and what is watched" do
      _, help = run_command(AzuCLI::Commands::Dev.new, ["--help"])

      AzuCLI::Commands::Dev::OPTIONS.each { |option| help.should contain("--#{option}") }
      help.should contain("public/templates/**")
      help.should contain("no build")
      help.should contain("keeps the previous app")
    end
  end

  describe "#apply" do
    it "builds and restarts the app for a source change" do
      in_tmp_project do |dir|
        write_app(dir)
        command = dev
        child = command.attach_child("blog")
        plan = AzuCLI::DevServer::Plan.new(AzuCLI::DevServer::Action::Rebuild, ["src/blog.cr"])
        with_builder("sh", ["-c", "exit 0"]) do
          command.apply(plan, "blog")
          sleep 300.milliseconds
          first = starts(dir)
          command.apply(plan, "blog")
          sleep 300.milliseconds
          second = starts(dir)
          child.stop

          first.should eq 1
          second.should eq 2
        end
      end
    end

    it "keeps the old app running when the build fails" do
      in_tmp_project do |dir|
        write_app(dir)
        command = dev
        child = command.attach_child("blog")
        child.start
        sleep 300.milliseconds
        pid = child.pid

        with_builder("sh", ["-c", "echo 'Error: syntax' >&2; exit 1"]) do
          command.apply(AzuCLI::DevServer::Plan.new(AzuCLI::DevServer::Action::Rebuild, ["src/blog.cr"]), "blog")
        end
        running = child.running?
        same_pid = child.pid == pid
        child.stop

        running.should be_true
        same_pid.should be_true
        starts(dir).should eq 1
      end
    end

    it "does not build or restart for a template change" do
      in_tmp_project do |dir|
        write_app(dir)
        command = dev
        child = command.attach_child("blog")
        child.start
        sleep 300.milliseconds
        pid = child.pid

        with_builder("sh", ["-c", "echo built >> #{dir}/builds"]) do
          command.apply(AzuCLI::DevServer::Plan.new(AzuCLI::DevServer::Action::Templates, ["public/templates/blog/index.jinja"]), "blog")
        end
        same_pid = child.pid == pid
        child.stop

        File.exists?(File.join(dir, "builds")).should be_false
        same_pid.should be_true
      end
    end

    it "restarts without building for an .env change" do
      in_tmp_project do |dir|
        write_app(dir)
        command = dev
        child = command.attach_child("blog")
        child.start
        sleep 300.milliseconds
        pid = child.pid

        with_builder("sh", ["-c", "echo built >> #{dir}/builds"]) do
          command.apply(AzuCLI::DevServer::Plan.new(AzuCLI::DevServer::Action::Restart, [".env"]), "blog")
        end
        sleep 300.milliseconds
        new_pid = child.pid
        child.stop

        File.exists?(File.join(dir, "builds")).should be_false
        new_pid.should_not eq pid
        starts(dir).should eq 2
      end
    end
  end

  describe "stopping" do
    it "ends a build in progress and starts no app afterwards" do
      in_tmp_project do |dir|
        write_app(dir)
        command = dev
        command.attach_child("blog")
        started = Time.instant
        with_builder("sh", ["-c", "sleep 30; true"]) do
          spawn do
            sleep 400.milliseconds
            command.stop
          end
          command.apply(AzuCLI::DevServer::Plan.new(AzuCLI::DevServer::Action::Rebuild, ["src/blog.cr"]), "blog")
        end

        (Time.instant - started).should be < 10.seconds
        starts(dir).should eq 0
      end
    end

    it "starts no new app once it was stopped, even when a build finishes afterwards" do
      in_tmp_project do |dir|
        write_app(dir)
        command = dev
        command.attach_child("blog")
        command.stop
        with_builder("sh", ["-c", "exit 0"]) do
          command.apply(AzuCLI::DevServer::Plan.new(AzuCLI::DevServer::Action::Rebuild, ["src/blog.cr"]), "blog")
          command.apply(AzuCLI::DevServer::Plan.new(AzuCLI::DevServer::Action::Restart, [".env"]), "blog")
        end
        sleep 200.milliseconds

        starts(dir).should eq 0
      end
    end
  end

  describe ".describe_exit" do
    it "names the code of a normal exit and the signal of a killed app, without raising" do
      AzuCLI::Commands::Dev.describe_exit(Process.run("sh", ["-c", "exit 3"])).should eq "exited with code 3"
      killed = Process.run("sh", ["-c", "kill -SEGV $$"])
      AzuCLI::Commands::Dev.describe_exit(killed).should contain("SEGV")
    end
  end

  it "is registered with the CLI" do
    AzuCLI::CLI.new.command_names.should contain("dev")
  end
end
