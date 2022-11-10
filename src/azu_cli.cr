require "topia"
require "opts"
require "cadmium_inflector"
require "teeplate"
require "jennifer"
require "inflector"

require "./azu_cli/templates/**"
require "./azu_cli/generators/**"
require "./azu_cli/utils"
require "./azu_cli/command"
require "./azu_cli/**"

module AzuCLI
  VERSION = Shard.version

  Topia.task("azu").pipe(Help.new)
  Topia.task("tasks").pipe(Tasks.new)
  Topia.task("project").pipe(Project.new)
  Topia.task("dev").pipe(Dev.new)
  Topia.task("db").pipe(Database.new)
  Topia.task("scaffold").pipe(Scaffold.new)
  Topia.task("migration").pipe(Migration.new)
  Topia.task("model").pipe(Model.new)

  def self.run
    Help.run
  end
end

AzuCLI.run
