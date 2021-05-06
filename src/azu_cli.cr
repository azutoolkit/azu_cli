require "topia"
require "opts"

require "./azu_cli/helpers"
require "./azu_cli/base"
require "./azu_cli/**"

module AzuCLI
  include Topia 
  VERSION = "0.1.0"

  task("project").pipe(Project.new)
  task("dev").pipe(Dev.new).watch("./**.cr")

  task("endpoint")
    .pipe(Endpoint.new)
    .command("mkdir -p #{Endpoint::PATH}")

  task("component")
    .pipe(Component.new)
    .command("mkdir -p #{Component::PATH}")

  task("request")
    .pipe(Request.new)
    .command("mkdir -p #{Request::PATH}")

  task("response")
    .pipe(Response.new)
    .command("mkdir -p #{Response::PATH}")

  task("clear.migration")
    .pipe(Migration.new)
    .command("mkdir -p #{Migration::PATH}")

  task("clear.model")
    .pipe(Migration.new)
    .pipe(Model.new)
    .command("mkdir -p #{Migration::PATH}")
    .command("mkdir -p #{Model::PATH}")

  task("clear.migrate")
    .pipe(Migrator.new)

  def self.run
    if ARGV.size > 0
      task, command = ARGV.first, ARGV[1..-1]
      run(task, command)
    else
      run("azu", ["--help"])
    end
  end
end
