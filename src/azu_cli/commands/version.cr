require "./base"

module AzuCLI
  module Commands
    # Version command to display CLI version information
    class Version < Base
      def initialize
        super("version", "Show Azu CLI version information")
      end

      def execute : Result
        return show_card if rich?

        puts "Azu CLI v#{AzuCLI::VERSION}"
        puts "Crystal #{Crystal::VERSION}"
        puts "Topia CLI Framework"
        puts

        # Show plugin versions if available
        show_plugin_versions

        success("Version information displayed")
      end

      # The CLI, the Crystal it was built with, and, inside a project, the azu and cql it is locked to.
      private def show_card : Result
        g = ui.as(UI::Rich).terminal.glyphs
        rows = [{"Azu CLI", "v#{AzuCLI::VERSION}"}, {"Crystal", "#{Crystal::VERSION} (built with)"}]
        locked = Version.locked_shards
        {"azu", "cql", "joobq"}.each { |shard| locked[shard]?.try { |version| rows << {shard, "#{version} (shard.lock)"} } }
        lines = rows.map { |(label, value)| [UI::Seg[label.ljust(10), UI::Token::Muted], UI::Seg[value]] }
        ui.panel("#{g.brand} CLI", lines, "v#{AzuCLI::VERSION}")
        success("Version information displayed")
      end

      # name => version from the shard.lock of the current directory ({} without one).
      def self.locked_shards(path : String = "shard.lock") : Hash(String, String)
        locked = {} of String => String
        return locked unless File.exists?(path)
        shards = YAML.parse(File.read(path))["shards"]?.try(&.as_h?) || return locked
        shards.each { |name, info| info["version"]?.try { |version| locked[name.as_s] = version.as_s } }
        locked
      rescue YAML::ParseException
        {} of String => String
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
