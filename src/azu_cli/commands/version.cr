require "./base"

module AzuCLI
  module Commands
    # Version command to display CLI version information
    class Version < Base
      def initialize
        super("version", "Show Azu CLI version information")
      end

      def execute : Result
        puts "Azu CLI v#{AzuCLI::VERSION}"
        puts "Crystal #{Crystal::VERSION}"
        puts "Topia CLI Framework"
        puts

        # Show plugin versions if available
        show_plugin_versions

        success("Version information displayed")
      end

      private def show_plugin_versions
        # This would show loaded plugin versions
        # For now, just show a placeholder
        puts "Plugins:"
        puts "  - Generator Plugin v1.0.0"
        puts "  - Database Plugin v1.0.0"
        puts "  - Development Plugin v1.0.0"
      end
    end
  end
end
