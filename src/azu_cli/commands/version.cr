require "../command"

module AzuCLI::Commands
  # Version command - displays version information
  class Version < Command
    command_name "version"
    description "Show version information"
    usage "version"

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      puts
      puts "🚀 Azu CLI v#{AzuCLI::VERSION}".colorize(:cyan).bold
      puts
      puts "A Crystal toolkit for building web applications"
      puts
      puts "📦 Dependencies:"
      puts "  • Crystal: #{Crystal::VERSION}"
      puts "  • Topia: CLI framework"
      puts "  • Teeplate: Template engine"
      puts "  • Cadmium Inflector: String inflections"
      puts
      puts "🌐 Links:"
      puts "  • Documentation: https://azutopia.gitbook.io/azu/"
      puts "  • Source Code: https://github.com/azutoolkit/azu_cli"
      puts "  • Issues: https://github.com/azutoolkit/azu_cli/issues"
      puts
      puts "👨‍💻 Created by: Elias J. Perez <eliasjpr@gmail.com>"
      puts "📄 License: MIT"
      puts

      nil
    end

    def show_command_specific_help
      puts "Shows detailed version information including dependencies."
    end
  end
end
