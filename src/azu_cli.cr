require "topia"
require "opts"

require "./azu_cli/helpers"
require "./azu_cli/base"
require "./azu_cli/**"

module AzuCLI
  VERSION = "0.1.0"

  Topia.task("azu").pipe(Azu.new)
  Topia.task("tasks").pipe(Tasks.new)
  Topia.task("project").pipe(Project.new)
  Topia.task("dev").pipe(Dev.new).watch("./**.cr")

  Topia.task("endpoint")
    .pipe(Endpoint.new)
    .command("mkdir -p #{Endpoint::PATH}")

  Topia.task("component")
    .pipe(Component.new)
    .command("mkdir -p #{Component::PATH}")

  Topia.task("request")
    .pipe(Request.new)
    .command("mkdir -p #{Request::PATH}")

  Topia.task("response")
    .pipe(Response.new)
    .command("mkdir -p #{Response::PATH}")

  Topia.task("clear.migration")
    .pipe(Migration.new)
    .command("mkdir -p #{Migration::PATH}")

  Topia.task("clear.model")
    .pipe(Migration.new)
    .pipe(Model.new)
    .command("mkdir -p #{Migration::PATH}")
    .command("mkdir -p #{Model::PATH}")

  Topia.task("db").pipe(Migrator.new)

  def self.run
    if ARGV.size > 0
      task, command = ARGV.first, ARGV[1..-1]
      Topia.run(task, command)
    else
      Topia.run("azu", ["--help"])
    end
  end
end

AzuCLI.run
