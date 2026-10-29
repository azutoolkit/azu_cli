require "../../../spec_helper"

private class SeedRunnerProbe < AzuCLI::Commands::DB::SeedRunner
  property fail = false
  getter runs = 0
  getter script = ""
  getter child_env : Hash(String, String)?

  protected def run_crystal_script(path : String, task_name : String, env : Hash(String, String)? = nil) : Bool
    @runs += 1
    @script = File.read(path)
    @child_env = env
    !@fail
  end
end

private def with_seed_project(&)
  TestHelpers::TestSetup.with_temp_project("seed_runner") do
    Dir.mkdir_p("src/db/seeds/test")
    Dir.mkdir_p("src/db/seeds/shared")
    Dir.mkdir_p("src/initializers")
    File.write("src/initializers/cql_config.cr", "")
    File.write("src/db/schema.cr", "")
    TestHelpers::TestSetup.with_env({"DATABASE_URL" => "sqlite3://#{Dir.current}/test.db"}) do
      yield
    end
  end
end

describe AzuCLI::Commands::DB::SeedRunner do
  it "loads application configuration before a seed and skips completed seeds" do
    with_seed_project do
      file = "src/db/seeds/test/001_accounts.cr"
      File.write(file, "")
      original_environment = ENV["CRYSTAL_ENV"]?
      runner = SeedRunnerProbe.new("test")
      runner.run_seeds.should be_true
      runner.run_seeds.should be_true
      runner.runs.should eq(1)
      runner.script.index("./src/initializers/**").not_nil!.should be < runner.script.index("./src/db/schema.cr").not_nil!
      runner.script.index("./src/db/schema.cr").not_nil!.should be < runner.script.index(file).not_nil!
      runner.child_env.not_nil!["CRYSTAL_ENV"].should eq("test")
      ENV["CRYSTAL_ENV"]?.should eq(original_environment)
      runner.get_seed_status[file].should eq("executed")
      Dir.glob(".azu_seed_*").should be_empty
    end
  end

  it "does not mark failed scripts completed, and explicit force reruns a completed seed" do
    with_seed_project do
      file = "src/db/seeds/test/001_accounts.cr"
      File.write(file, "")
      runner = SeedRunnerProbe.new("test")
      runner.fail = true
      runner.run_seed_file(file).should be_false
      runner.get_seed_status[file].should eq("pending")
      runner.fail = false
      runner.run_seed_file(file).should be_true
      runner.force_run_seed(file).should be_true
      runner.runs.should eq(3)
    end
  end

  it "distinguishes equal basenames in environment and shared directories" do
    with_seed_project do
      {"test", "shared"}.each { |dir| File.write("src/db/seeds/#{dir}/001_accounts.cr", "") }
      runner = SeedRunnerProbe.new("test")
      runner.run_seeds.should be_true
      runner.runs.should eq(2)
      runner.get_seed_status.values.should eq(["executed", "executed"])
      expect_raises(ArgumentError, "exactly one") { runner.resolve_files(["accounts"]) }
    end
  end

  it "resolves named seeds, includes the legacy entry point, and refuses unknown names" do
    with_seed_project do
      File.write("src/db/seed.cr", "")
      File.write("src/db/seeds/test/001_accounts.cr", "")
      runner = SeedRunnerProbe.new("test")
      runner.find_seed_files.size.should eq(2)
      runner.resolve_files(["accounts"]).should eq(["./src/db/seeds/test/001_accounts.cr"])
      expect_raises(ArgumentError, "found 0") { runner.resolve_files(["missing"]) }
    end
  end

  it "refuses a seed outside the project through a symlink" do
    with_seed_project do
      File.symlink("/etc/passwd", "src/db/seeds/test/escape.cr")
      runner = SeedRunnerProbe.new("test")
      runner.run_seed_file("src/db/seeds/test/escape.cr").should be_false
      runner.runs.should eq(0)
    end
  end
end
