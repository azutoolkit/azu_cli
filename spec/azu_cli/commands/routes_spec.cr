require "../../spec_helper"
require "../../support/command_helpers"

include CommandHelpers

private FIXTURE = [
  AzuCLI::RouteListing::Entry.new("GET", "/posts", "Blog::Posts::IndexEndpoint", "Blog::Posts::IndexRequest", "Blog::Posts::IndexPage"),
  AzuCLI::RouteListing::Entry.new("POST", "/posts", "Blog::Posts::CreateEndpoint", "Blog::Posts::CreateRequest", "Azu::Response::Empty"),
  AzuCLI::RouteListing::Entry.new("HEAD", "/posts", "Blog::Posts::IndexEndpoint", "Blog::Posts::IndexRequest", "Blog::Posts::IndexPage"),
]

private def with_loader(routes = FIXTURE, &)
  original = AzuCLI::Commands::Routes.loader
  AzuCLI::Commands::Routes.loader = ->(app_file : String) { routes }
  yield
ensure
  AzuCLI::Commands::Routes.loader = original.not_nil!
end

describe AzuCLI::Commands::Routes do
  it "prints a table of the routes of the project" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_loader do
        result, output = run_command(AzuCLI::Commands::Routes.new, [] of String)

        result.success?.should be_true
        output.should contain("METHOD")
        output.should contain("link_to_post_posts_create")
        output.should contain("2 routes")
        output.should_not contain("HEAD")
      end
    end
  end

  it "prints JSON with --format json and nothing else on stdout" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_loader do
        result, output = run_command(AzuCLI::Commands::Routes.new, ["--format", "json"])

        result.success?.should be_true
        JSON.parse(output).as_a.map(&.["method"].as_s).should eq ["GET", "POST"]
      end
    end
  end

  it "filters with --method and --path" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_loader do
        _, output = run_command(AzuCLI::Commands::Routes.new, ["--method", "post", "--path", "/posts", "--format=json"])

        JSON.parse(output).as_a.map(&.["endpoint"].as_s).should eq ["Blog::Posts::CreateEndpoint"]
      end
    end
  end

  it "passes the app file of the project to the loader" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      seen = nil
      original = AzuCLI::Commands::Routes.loader
      AzuCLI::Commands::Routes.loader = ->(app_file : String) { seen = app_file; FIXTURE }
      begin
        run_command(AzuCLI::Commands::Routes.new, [] of String)
      ensure
        AzuCLI::Commands::Routes.loader = original
      end

      seen.should eq "./src/blog.cr"
    end
  end

  it "exits with 2 for an unknown option, format or method" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_loader do
        [["--bogus"], ["--format", "xml"], ["--method", "FETCH"], ["--port", "1"]].each do |args|
          result, _ = run_command(AzuCLI::Commands::Routes.new, args)
          result.success?.should be_false
          result.exit_code.should eq 2
        end
      end
    end
  end

  it "fails with 1 outside a project, or when the app cannot be loaded" do
    in_tmp_project(shard_yml: nil) do
      result, _ = run_command(AzuCLI::Commands::Routes.new, [] of String)
      result.exit_code.should eq 1
      result.error.should contain("not found")
    end

    in_tmp_project(files: {"src/blog.cr" => ""}) do
      original = AzuCLI::Commands::Routes.loader
      AzuCLI::Commands::Routes.loader = ->(app_file : String) { raise AzuCLI::RouteListing::Runner::Error.new("the application could not be loaded") }
      begin
        result, _ = run_command(AzuCLI::Commands::Routes.new, [] of String)
        result.exit_code.should eq 1
        result.error.should contain("could not be loaded")
      ensure
        AzuCLI::Commands::Routes.loader = original
      end
    end
  end

  it "documents exactly the options it accepts" do
    _, help = run_command(AzuCLI::Commands::Routes.new, ["--help"])

    AzuCLI::Commands::Routes::OPTIONS.each { |option| help.should contain("--#{option}") }
  end

  it "is registered with the CLI and answers with the exit code of its result" do
    in_tmp_project(shard_yml: nil) do
      AzuCLI::CLI.new.command_names.should contain("routes")
      AzuCLI::CLI.new.run(["routes", "--bogus"]).should eq 2
      AzuCLI::CLI.new.run(["routes"]).should eq 1
    end
  end
end

describe "AzuCLI::Commands::Routes on a terminal" do
  it "draws the routes as a card, without the namespace every endpoint shares" do
    in_tmp_project(files: {"src/blog.cr" => ""}) do
      with_loader do
        card = IO::Memory.new
        command = AzuCLI::Commands::Routes.new
        command.ui = AzuCLI::UI::Rich.new(AzuCLI::UI::Terminal.fake(card, columns: 100))
        result, _ = run_command(command, [] of String)

        result.success?.should be_true
        text = card.to_s
        text.should contain "2 routes"
        text.should contain "POST    /posts  Posts::CreateEndpoint  Posts::CreateRequest ▸ Azu::Response::Empty"
        text.should contain "names under Blog"
        text.should_not contain "HEAD"
      end
    end
  end

  it "finds the namespace all endpoints share" do
    AzuCLI::Commands::Routes.shared_namespace(["Blog::A", "Blog::B::C"]).should eq "Blog::"
    AzuCLI::Commands::Routes.shared_namespace(["Blog::A", "Chat"]).should eq ""
    AzuCLI::Commands::Routes.shared_namespace([] of String).should eq ""
  end
end
