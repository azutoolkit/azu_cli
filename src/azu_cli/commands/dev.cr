require "./serve"

module AzuCLI::Commands
  # Dev command - alias for the serve command
  class Dev < Serve
    def self.command_name : String
      "dev"
    end

    def command_name : String
      "dev"
    end

    def self.description : String
      "Alias for serve command - start development server with hot reloading"
    end

    def description : String
      "Alias for serve command - start development server with hot reloading"
    end

    def self.usage : String
      "dev [options]"
    end

    def usage : String
      "dev [options]"
    end

    def show_command_specific_help
      puts "This is an alias for the 'serve' command.".colorize(:cyan)
      puts
      super
    end
  end
end
