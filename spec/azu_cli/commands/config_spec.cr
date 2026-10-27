require "../../spec_helper"
require "../../support/command_helpers"

include CommandHelpers

private FIXTURE = [
  AzuCLI::AppConfig::Setting.new("server", "port", "4000"),
  AzuCLI::AppConfig::Setting.new("server", "host", "127.0.0.1"),
  AzuCLI::AppConfig::Setting.new("secrets", "CSRF_SECRET", "set"),
  AzuCLI::AppConfig::Setting.new("secrets", "SESSION_SECRET", "not set"),
  AzuCLI::AppConfig::Setting.new("database", "url", "postgres://admin:***@db/app"),
]

private def with_loader(settings = FIXTURE, &)
  original = AzuCLI::Commands::Config.loader
  AzuCLI::Commands::Config.loader = ->(app_file : String) { settings }
  yield
ensure
  AzuCLI::Commands::Config.loader = original.not_nil!
end

describe AzuCLI::Commands::Config do
  it "prints the settings of the application, grouped by section" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_loader do
        result, output = run_command(AzuCLI::Commands::Config.new, [] of String)

        result.success?.should be_true
        output.should contain("SERVER")
        output.should match(/port\s+4000/)
        output.should match(/SESSION_SECRET\s+not set/)
      end
    end
  end

  it "prints JSON with --format json and nothing else on stdout" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_loader do
        result, output = run_command(AzuCLI::Commands::Config.new, ["--format", "json"])

        result.success?.should be_true
        json = JSON.parse(output)
        json["server"]["port"].as_s.should eq "4000"
        json["database"]["url"].as_s.should eq "postgres://admin:***@db/app"
      end
    end
  end

  it "shows one section with --section, in any case" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_loader do
        _, output = run_command(AzuCLI::Commands::Config.new, ["--section", "SERVER", "--format=json"])

        JSON.parse(output).as_h.keys.should eq ["server"]
      end
    end
  end

  it "rejects an unknown section and lists the known ones (exit code 2)" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_loader do
        result, _ = run_command(AzuCLI::Commands::Config.new, ["--section", "nope"])

        result.exit_code.should eq 2
        result.error.should contain("Unknown section 'nope': use server, secrets, database")
      end
    end
  end

  it "rejects an unknown format and an unknown option (exit code 2)" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_loader do
        run_command(AzuCLI::Commands::Config.new, ["--format", "yaml"])[0].exit_code.should eq 2
        run_command(AzuCLI::Commands::Config.new, ["--bogus"])[0].exit_code.should eq 2
      end
    end
  end

  it "fails outside an Azu project (exit code 1)" do
    in_tmp_project do
      with_loader do
        result, _ = run_command(AzuCLI::Commands::Config.new, [] of String)

        result.exit_code.should eq 1
        result.error.should contain("not found")
      end
    end
  end

  it "passes the app file of the project to the loader" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      seen = nil
      original = AzuCLI::Commands::Config.loader
      AzuCLI::Commands::Config.loader = ->(app_file : String) { seen = app_file; FIXTURE }
      begin
        run_command(AzuCLI::Commands::Config.new, [] of String)
        seen.should eq "./src/#{AzuCLI::Utils.project_name}.cr"
      ensure
        AzuCLI::Commands::Config.loader = original.not_nil!
      end
    end
  end
end
