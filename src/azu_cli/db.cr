require "clear"

module AzuCLI
  class DB
    include Builder

    PATH        = Migration::PATH
    ARGS        = "migrate"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Clear Migration"} - Database Commands

      Allows you to evolve your database schema and perform changes to 
      your database 

      seed     - Call the seeds data
      redo     - Redo latest database migration 
      status   - Return the current state of the database
      migrate  - Applies all pending database migrations
      rollback - Rollback the last up migration or number of steps
      up       - Upgrade your database to a specific migration version
      down     - Downgrade your database to a specific migration version  

      Note: if no subcommand provided it applies all pending migrations.
    DESC

    struct Format < Log::StaticFormatter
      def run
        string " clear ".colorize.back(:black).fore(:white).mode(:bold)
        severity
        string ": "
        message
      end
    end

    backend = Log::IOBackend.new(formatter: Format)
    Log.setup(sources: "clear.migration", backend: backend)

    DATABASE_URL = ENV["DATABASE_URL"]? || ""

    private getter migrator : Clear::Migration::Manager? = nil
    private getter migrations : Array(Int64)? = nil

    def run
      init

      command, version = args.first, args.last?
      validate! command
      puts "\n"
      puts migrate(command, version)
      exit 1
    end

    def init
      Clear::SQL.init(DATABASE_URL)
      @migrator = Clear::Migration::Manager.instance
      @migrations = migrator.migrations_up.to_a.sort
    end

    def migrator
      @migrator.not_nil!
    end

    def migrations
      @migrations.not_nil!
    end

    def validate!(command)
      if Dir["#{PATH}/*__*.cr"].empty? && !command != "status"
        error "Migrations directory is empty, nothing to run!"
        exit 1
      end

      if ["up", "down"].includes? command && version.nil?
        error "Migration version is required!"
        exit 1
      end
    end

    def migrate(command : String = "", version : String? = nil)
      case command
      when "seed"     then Clear.apply_seeds
      when "migrate"  then migrator.apply_all
      when "rollback" then rollback
      when "redo"     then redo
      when "status"   then migrator.print_status
      when "up"       then migrator.up version.not_nil!.to_i64
      when "down"     then migrator.down version.not_nil!.to_i64
      else                 error "Unsupported database command"
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
  end
end
