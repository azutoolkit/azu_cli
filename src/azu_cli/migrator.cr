module AzuCLI
  class Migrator
    include Topia::Plugin
    include Helpers

    DATABASE_URL = ENV["DATABASE_URL"]
    ::Clear::SQL.init(DATABASE_URL)

    def run(input, params)
      if params.size >= 2
        command = params[0]
        num = (params[1]? || 0).to_i64
        direction = params[2]? || "both"

        migrate(command, num, direction)
      else 
        migrate
      end

      true
    rescue e
      error "Clear migrator failed! #{e.message}"
      false
    end

    def on(event : String)
    end

    def migrate(command : String = "", num : Int64 = 0, direction = "both")
      case command
      when "seed"     then ::Clear.apply_seeds
      when "status"   then migrator.print_status
      when "up"       then migrator.up num
      when "down"     then migrator.down num
      when "rollback" then rollback num
      when "set"      then set direction, num
      else                 migrator.apply_all
      end
    end

    private def rollback(steps : Int64 = 2)
      migrations = migrator.migrations_up.to_a.sort
      if (steps > migrations.size)
        steps = migrations.size - 1
      end

      migrator.apply_to(migrations[-steps], direction: :down)
    end

    private def set(direction : String, to : Int64)
      dir_symbol = case direction
                   when "up"   then :up
                   when "down" then :down
                   when "both" then :both
                   else
                     puts "Bad argument --direction : #{direction}. Must be up|down|both"
                     exit 1
                   end

      migrator.apply_to(to, direction: dir_symbol)
    end

    private def migrator
      ::Clear::Migration::Manager.instance
    end
  end
end
