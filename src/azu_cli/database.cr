module AzuCLI
  class Database
    include Command

    PATH        = Migration::PATH
    ARGS        = "setup"
    DESCRIPTION = <<-DESC
    #{bold "Azu"} - Jennifer Database Commands

      Allows you to evolve your database schema and perform changes to 
      your database 

      seed     - Seeds the database with data Eg. azu seed
      step     - Migrates one step
      migrate  - Runs all pending migrations
      rollback - Rolls back the last migration
      create   - Creates the database
      drop     - Drops the database
      version  - Prints latest migrated version
      setup    - Creates, migrates and seeds the database
      schema   - Loads database schema definition into a sql file
    DESC

    option action : String, "--action=Action", "-a Action", "Eg. migrate, rollback, create or drop", ""
    option count : Int32, "--count=1", "-c 3", "Eg. azu db -a rollback -c 2", 1

    def run
      case action
      when "seed"
        Topia.run("seed")
      when "step"
        Jennifer::Migration::Runner.migrate(count)
      when "migrate"
        Jennifer::Migration::Runner.migrate
      when "rollback"
        Jennifer::Migration::Runner.rollback({:count => count})
      when "create"
        Jennifer::Migration::Runner.create
      when "drop"
        Jennifer::Migration::Runner.drop
      when "schema"
        Jennifer::Migration::Runner.load_schema
      when "version"
        version = Jennifer::Migration::Version.all.last

        if version
          announce version.not_nil!.version
        else
          error "DB has no ran migration yet."
        end
        sleep 2
      when "setup"
        Jennifer::Migration::Runner.create
        Jennifer::Migration::Runner.migrate
      else error "Unsupported database command"
      end
      exit 1
    end
  end
end
