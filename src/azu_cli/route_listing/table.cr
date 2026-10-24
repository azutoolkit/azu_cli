require "json"
require "./entry"

module AzuCLI
  module RouteListing
    # Filtering and rendering of a list of routes.
    class Table
      HEADERS = {"METHOD", "PATH", "ENDPOINT", "REQUEST", "RESPONSE", "HELPERS"}

      getter entries : Array(Entry)

      def initialize(@entries : Array(Entry))
      end

      # HEAD and OPTIONS routes Azu adds for the routes you declare, hidden unless that method is asked for.
      IMPLICIT_METHODS = ["HEAD", "OPTIONS"]

      # Keeps the routes of an HTTP method (any case) whose path contains `path`, ordered by path.
      def filter(method : String? = nil, path : String? = nil) : Table
        verb = method.try(&.upcase)
        kept = entries.select do |entry|
          next false if verb ? entry.method != verb : IMPLICIT_METHODS.includes?(entry.method)
          next false if path && !entry.path.includes?(path)
          true
        end
        Table.new(kept.sort_by { |entry| {entry.path, entry.method} })
      end

      def to_json : String
        JSON.build(indent: 2) do |json|
          json.array { entries.each(&.to_json(json)) }
        end
      end

      def to_text : String
        return "No routes match.\n" if entries.empty?

        rows = entries.map { |entry| {entry.method, entry.path, entry.endpoint, dash(entry.request), dash(entry.response), dash(entry.helpers.join(", "))} }
        widths = HEADERS.to_a.map_with_index { |header, column| ([header] + rows.map(&.[column])).max_of(&.size) }
        String.build do |io|
          write_row(io, HEADERS, widths)
          rows.each { |row| write_row(io, row, widths) }
          io << '\n' << entries.size << (entries.size == 1 ? " route\n" : " routes\n")
        end
      end

      private def dash(text : String) : String
        text.empty? ? "-" : text
      end

      private def write_row(io : IO, row : Tuple, widths : Array(Int32))
        line = row.map_with_index { |cell, column| cell.ljust(widths[column]) }.join("  ")
        io << line.rstrip << '\n'
      end
    end
  end
end
