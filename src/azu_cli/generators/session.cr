require "teeplate"

module AzuCLI
  module Generate
    # Session generator
    class Session < Teeplate::FileTree
      directory "#{__DIR__}/../templates/session"
      OUTPUT_DIR = "."

      property project : String
      property backend : String # redis, memory, database
      property secret : String

      def initialize(@project : String, @backend : String = "redis", @secret : String = Random::Secure.hex(32))
      end

      # Get backend type for conditional requires
      def backend : String
        @backend
      end

      # Get required dependencies
      def dependencies : String
        case @backend
        when "redis"
          "redis"
        when "database"
          "cql"
        else
          ""
        end
      end

      # Check if migration is needed
      def needs_migration? : Bool
        @backend == "database"
      end

      # Get migration content for database backend
      def migration_content : String
        <<-MIGRATION
          schema.create :sessions do
            primary :id, Int64, auto: true
            column :session_id, String, unique: true, null: false
            column :data, String, null: false
            column :created_at, Time, default: "NOW()"
            column :updated_at, Time, default: "NOW()"
            column :expires_at, Time, null: false

            add_index :sessions, :session_id
            add_index :sessions, :expires_at
          end
        MIGRATION
      end
    end
  end
end

