require "clear"

module AzuCLI
  class Migrator
    include Base
    include Helpers

    ARGS = "subcommand version"
    DESCRIPTION = <<-DESC
    Azu - Clear Migration

    Generates a clear migration. If only the `name` is provided will generate 
    an empty migration.

    Clear offers a migration system. Migration allow you to handle state update 
    of your database. Migration is a list of change going through a direction, 
    up (commit changes) or down (rollback changes).

    Docs: https://clear.gitbook.io/project/migrations/call-migration-script

    Subcommands:

      seed     - Call the seeds data
      redo     -  re-run the latest database migration 
      status   - Return the current state of the database
      migrate  - Applies all pending database migrations
      rollback - Rollback the last up migration or number of steps
      up       - Upgrade your database to a specific migration version
      down     - Downgrade your database to a specific migration version  

      Note: if no subcommand provided it applies all pending migrations.

    Examples:

      azu db seed
      azu db redo
      azu db status
      azu db migrate
      azu db [down or up] version
      azu db rollback
      
    DESC

    DATABASE_URL = ENV["DATABASE_URL"]
    ::Clear::SQL.init(DATABASE_URL)

    getter migrations : Array(Int64) = migrator.migrations_up.to_a.sort

    def run(input, params)
      command, version = params.first, params.last?

      if ["up", "down"].includes? command && version.nil?
        error "Migration version is required!"
        exit 1
      end

      puts "\n", migrate(command, version), "\n"

      true
    rescue e
      error "Clear migrator failed! #{e.message}"
      false
    end

    def migrate(command : String = "", version : Int64? = nil)
      case command
      when "seed" then :Clear.apply_seeds
      when "migrate" then migrator.apply_all
      when "rollback" then rollback
      when "redo" then redo
      when "status" then migrator.print_status
      when "up" then migrator.up version
      when "down" then migrator.down version
      else 
        error "Unsupported database command"
      end
    end

    private def redo
      rollback
      migrator.apply_all
    end

    private def rollback(steps : Int64 = 2)
      steps = migrations.size - 1 if (steps > migrations.size)
      migrator.apply_to(migrations[-steps], direction: :down)
    end

    private def migrator
      ::Clear::Migration::Manager.instance
    end
  end
end
