require "../../../spec_helper"
require "file_utils"

# A SQLite project needs no server: `db:create` and `db:drop` work on the file `db/<name>_<env>.db`
# that the generated initializer connects to, and the adapter comes from the project's shards.
describe "db commands in a SQLite project" do
  with_sqlite_project = ->(shards : String, block : Proc(Nil)) do
    root = File.tempname("azu_sqlite")
    project = File.join(root, "blog")
    Dir.mkdir_p(project)
    File.write(File.join(project, "shard.yml"), "name: blog\nversion: 0.1.0\ndependencies:\n#{shards}")
    Dir.cd(project) { block.call }
ensure
  FileUtils.rm_rf(root) if root
  end

  it "takes the adapter from the shards the project depends on" do
    with_sqlite_project.call("  sqlite3:\n    github: crystal-lang/crystal-sqlite3\n", -> {
      AzuCLI::Commands::DB::Create.new.adapter.should eq("sqlite3")
    })
    with_sqlite_project.call("  mysql:\n    github: crystal-lang/crystal-mysql\n", -> {
      AzuCLI::Commands::DB::Create.new.adapter.should eq("mysql")
    })
    with_sqlite_project.call("  pg:\n    github: will/crystal-pg\n", -> {
      AzuCLI::Commands::DB::Create.new.adapter.should eq("postgres")
    })
  end

  it "stays on PostgreSQL when its driver is there next to others" do
    with_sqlite_project.call("  pg:\n    github: will/crystal-pg\n  sqlite3:\n    github: crystal-lang/crystal-sqlite3\n", -> {
      AzuCLI::Commands::DB::Create.new.adapter.should eq("postgres")
    })
  end

  it "creates and drops the database file" do
    with_sqlite_project.call("  sqlite3:\n    github: crystal-lang/crystal-sqlite3\n", -> {
      AzuCLI::Commands::DB::Create.new.execute.success?.should be_true
      File.exists?("db/blog_test.db").should be_true

      AzuCLI::Commands::DB::Create.new.execute.success?.should be_false

      drop = AzuCLI::Commands::DB::Drop.new
      drop.parse_args(["--force"])
      drop.execute.success?.should be_true
      File.exists?("db/blog_test.db").should be_false
    })
  end

  sqlite_shards = "  sqlite3:\n    github: crystal-lang/crystal-sqlite3\n"

  it "uses the file named by DATABASE_URL, without its query string" do
    with_sqlite_project.call(sqlite_shards, -> {
      ENV["DATABASE_URL"] = "sqlite3://./data/app.db?journal_mode=wal"
      begin
        AzuCLI::Commands::DB::Create.new.execute.success?.should be_true
        File.exists?("data/app.db").should be_true
      ensure
        ENV.delete("DATABASE_URL")
      end
    })
  end

  it "keeps the file of DATABASE_URL out of reach of another database name" do
    with_sqlite_project.call(sqlite_shards, -> {
      ENV["DATABASE_URL"] = "sqlite3://./data/app.db"
      begin
        AzuCLI::Commands::DB::Create.new.execute.success?.should be_true

        create = AzuCLI::Commands::DB::Create.new
        create.parse_args(["--database", "other", "--force"])
        create.execute.success?.should be_true
        File.exists?("db/other.db").should be_true
        File.exists?("data/app.db").should be_true

        drop = AzuCLI::Commands::DB::Drop.new
        drop.parse_args(["--database", "other", "--force"])
        drop.execute.success?.should be_true
        File.exists?("db/other.db").should be_false
        File.exists?("data/app.db").should be_true
      ensure
        ENV.delete("DATABASE_URL")
      end
    })
  end

  # `azu new` then `azu db:migrate`: the database file does not exist yet and there is no migration
  it "migrates a fresh project: creates the database file, and no migration is not an error" do
    with_sqlite_project.call(sqlite_shards, -> {
      result = AzuCLI::Commands::DB::Migrate.new.execute
      result.success?.should be_true
      File.exists?("db/blog_test.db").should be_true

      AzuCLI::Commands::DB::Migrate.new.execute.success?.should be_true
    })
  end

  it "creates nothing on a dry run" do
    with_sqlite_project.call(sqlite_shards, -> {
      migrate = AzuCLI::Commands::DB::Migrate.new
      migrate.parse_args(["--dry-run"])
      migrate.execute.success?.should be_true
      File.exists?("db/blog_test.db").should be_false
    })
  end

  # A server database is never created by db:migrate: it stops and names the commands that create one
  it "leaves a missing PostgreSQL or MySQL database alone and points at db:create / db:setup" do
    {"  pg:\n    github: will/crystal-pg\n"               => "postgres://127.0.0.1:1/blog_test",
     "  mysql:\n    github: crystal-lang/crystal-mysql\n" => "mysql://root@127.0.0.1:1/blog_test"}.each do |shards, url|
      with_sqlite_project.call(shards, -> {
        ENV["DATABASE_URL"] = url
        begin
          result = AzuCLI::Commands::DB::Migrate.new.execute
          result.success?.should be_false
          result.error.should contain("azu db:create")
          result.error.should contain("azu db:setup")
          Dir.exists?("db").should be_false
        ensure
          ENV.delete("DATABASE_URL")
        end
      })
    end
  end

  it "sets up a fresh project that has no migration yet" do
    with_sqlite_project.call(sqlite_shards, -> {
      AzuCLI::Commands::DB::Setup.new.execute.success?.should be_true
      File.exists?("db/blog_test.db").should be_true
    })
  end

  it "refuses an in-memory database, whichever way the URL spells it, in every command that looks for the file" do
    ["sqlite3::memory:", "sqlite3:///:memory:", "sqlite3://:memory:", "sqlite3:"].each do |url|
      with_sqlite_project.call(sqlite_shards, -> {
        ENV["DATABASE_URL"] = url
        begin
          expect_raises(Exception, /in-memory/) { AzuCLI::Commands::DB::Create.new.execute }
          drop = AzuCLI::Commands::DB::Drop.new
          drop.parse_args(["--force"])
          expect_raises(Exception, /in-memory/) { drop.execute }
          Dir.glob("**/*.db").should be_empty
        ensure
          ENV.delete("DATABASE_URL")
        end
      })
    end
  end
end
