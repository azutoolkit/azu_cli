require "clear"
require "../src/azu_cli.cr"

module Example
  include AzuCLI

  def self.run
    AzuCLI.run
  end
end

Example.run
