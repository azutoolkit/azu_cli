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

  it "uses the file named by DATABASE_URL" do
    with_sqlite_project.call("  sqlite3:\n    github: crystal-lang/crystal-sqlite3\n", -> {
      ENV["DATABASE_URL"] = "sqlite3://./data/app.db"
      begin
        AzuCLI::Commands::DB::Create.new.execute.success?.should be_true
        File.exists?("data/app.db").should be_true
      ensure
        ENV.delete("DATABASE_URL")
      end
    })
  end
end
