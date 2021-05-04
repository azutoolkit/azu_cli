require "topia"
require "./azu_cli/helpers"
require "./azu_cli/*"

module AzuCLI
  VERSION = "0.1.0"

  Topia.task("endpoint").pipe(Endpoint.new).command("mkdir -p #{Endpoint::PATH}")
  Topia.task("component").pipe(Component.new).command("mkdir -p #{Component::PATH}")
  Topia.task("request").pipe(Request.new).command("mkdir -p #{Request::PATH}")
  Topia.task("response").pipe(Response.new).command("mkdir -p #{Response::PATH}")
  Topia.task("dev").pipe(Dev.new).watch("./src/**.cr")

  puts "This is fun!"
  
  def self.run
    Topia::CLI.run
  end
end

AzuCLI.run
