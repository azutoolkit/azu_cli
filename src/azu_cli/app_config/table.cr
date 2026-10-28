require "json"
require "./setting"

module AzuCLI
  module AppConfig
    # Filtering and rendering of the settings of an application.
    class Table
      getter settings : Array(Setting)

      def initialize(@settings : Array(Setting))
      end

      # The sections, in the order the application reported them.
      def sections : Array(String)
        settings.map(&.section).uniq!
      end

      # Keeps the settings of one section (any case).
      def filter(section : String? = nil) : Table
        return self unless section

        Table.new(settings.select { |setting| setting.section.compare(section, case_insensitive: true) == 0 })
      end

      # `{"server": {"port": "4000"}}`: every value is a string, as it was printed.
      def to_json : String
        JSON.build(indent: 2) do |json|
          json.object do
            sections.each do |section|
              json.field section do
                json.object { settings.each { |setting| json.field(setting.key, setting.value) if setting.section == section } }
              end
            end
          end
        end
      end

      def to_text : String
        return "No settings match.\n" if settings.empty?

        width = settings.max_of(&.key.size)
        String.build do |io|
          sections.each_with_index do |section, index|
            io.puts if index > 0
            io.puts section.upcase
            settings.each { |setting| io.puts "  #{setting.key.ljust(width)}  #{setting.value}" if setting.section == section }
          end
        end
      end
    end
  end
end
