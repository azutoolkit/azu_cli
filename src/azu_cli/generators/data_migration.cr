require "teeplate"

module AzuCLI
  module Generate
    # Data migration generator that creates CQL::DataMigration classes
    class DataMigration < Teeplate::FileTree
      directory "#{__DIR__}/../templates/data_migration"
      OUTPUT_DIR = "./src/db/data_migrations"

      # Migration configuration properties
      property name : String
      property snake_case_name : String
      property timestamp : String
      property migration_class_name : String

      def initialize(@name : String)
        @snake_case_name = to_snake_case(@name)
        @timestamp = generate_timestamp
        @migration_class_name = to_pascal_case(@name)
      end

      # Convert name to snake_case for file naming
      def snake_case_name : String
        to_snake_case(@name)
      end

      # Convert a string to snake_case
      private def to_snake_case(str : String) : String
        str.gsub(/([A-Z\d]+)([A-Z][a-z])/) { "#{$1}_#{$2}" }
          .gsub(/([a-z\d])([A-Z])/) { "#{$1}_#{$2}" }
          .tr("-", "_")
          .downcase
      end

      # Convert a string to PascalCase
      private def to_pascal_case(str : String) : String
        str.split(/[-_\s]+/)
          .map(&.capitalize)
          .join
      end

      # Generate timestamp for migration filename
      private def generate_timestamp : String
        Time.utc.to_s("%Y%m%d%H%M%S")
      end

      # Get migration filename
      def migration_filename : String
        "#{@timestamp}_data_#{snake_case_name}.cr"
      end

      # Get migration class name
      def migration_class_name : String
        @migration_class_name
      end
    end
  end
end
