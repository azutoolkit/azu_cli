require "topia"
require "opts"
require "cadmium_inflector"

require "./azu_cli/helpers"
require "./azu_cli/builder"
require "./azu_cli/**"

def light_blue(v)
  "#{v}".colorize.light_blue
end

def underline(v)
  "#{v}".colorize.underline
end

def bold(v)
  "#{v}".colorize.bold
end

module AzuCLI
  VERSION = Shard.version

  Topia.task("azu").pipe(Help.new)
  Topia.task("tasks").pipe(Tasks.new)
  Topia.task("project").pipe(Project.new)
  Topia.task("dev").pipe(Dev.new).watch("./**/*.cr")

  Topia
    .task("db")
    .pipe(DB.new)

  Topia
    .task("endpoint")
    .pipe(Endpoint.new)
    .command("mkdir -p #{Endpoint::PATH}")

  Topia
    .task("component")
    .pipe(Component.new)
    .command("mkdir -p #{Component::PATH}")

  Topia
    .task("request")
    .pipe(Request.new)
    .command("mkdir -p #{Request::PATH}")

  Topia
    .task("response")
    .pipe(Response.new)
    .command("mkdir -p #{Response::PATH}")

  Topia
    .task("clear.migration")
    .pipe(Migration.new)
    .command("mkdir -p #{Migration::PATH}")

  Topia
    .task("clear.model")
    .pipe(Model.new)
    .pipe(Migration.new)
    .command("mkdir -p #{Migration::PATH}")
    .command("mkdir -p #{Model::PATH}")

  def self.run
    Help.run
  end
end

AzuCLI.run
