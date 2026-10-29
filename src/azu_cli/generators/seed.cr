require "teeplate"

module AzuCLI::Generate
  # Seed rendering shares the same preview and overwrite path as other generators.
  class Seed < Teeplate::FileTree
    directory "#{__DIR__}/../templates/seed"
    OUTPUT_DIR = "./src/db/seeds"
    getter name : String
    getter environment : String
    getter filename : String

    def initialize(@name : String, @environment : String = "development")
      raise ArgumentError.new("Seed name must be a Crystal identifier") unless name.matches?(/\A[A-Za-z][A-Za-z0-9_]*\z/)
      raise ArgumentError.new("Seed environment must contain only letters, numbers, _ or -") unless environment.matches?(/\A[a-zA-Z][a-zA-Z0-9_-]*\z/)
      @filename = "#{Time.utc.to_s("%Y%m%d%H%M%S")}_#{name.underscore}.cr"
    end
  end
end
