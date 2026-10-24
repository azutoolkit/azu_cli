require "json"
require "./entry"

module AzuCLI
  module RouteListing
    # Asks the application for its routes: compiles and runs a small script that requires the app (without
    # starting its server) and prints `Router#route_info` as JSON. A script has to be compiled because the
    # routes only exist once the application's code is loaded.
    class Runner
      MARKER = "AZU_ROUTES_JSON:"

      class Error < Exception
      end

      getter app_file : String

      def initialize(@app_file : String)
      end

      # The script. `Router#route_info` knows the method, the path and the endpoint class; the request
      # and response types are the type arguments of the `Azu::Endpoint(Request, Response)` each endpoint includes,
      # collected at compile time.
      def script : String
        <<-CRYSTAL
          require "json"
          require #{app_file.inspect}

          ENDPOINT_TYPES = Hash(String, {String, String}).new
          {% for type in Struct.all_subclasses + Reference.all_subclasses %}
            {% for ancestor in type.ancestors %}
              {% if ancestor.name(generic_args: false).stringify == "Azu::Endpoint" && ancestor.type_vars.size == 2 %}
                ENDPOINT_TYPES[{{type.name.stringify}}] = { {{ancestor.type_vars[0].stringify}}, {{ancestor.type_vars[1].stringify}} }
              {% end %}
            {% end %}
          {% end %}

          routes = Azu::CONFIG.router.route_info.map do |route|
            request, response = ENDPOINT_TYPES[route["handler"]]? || {"", ""}
            {method: route["method"], path: route["path"], endpoint: route["handler"], request: request, response: response}
          end
          puts "#{MARKER}\#{routes.to_json}"
        CRYSTAL
      end

      # Entries from the output of the script; the app may log around the marker line.
      def self.parse(output : String) : Array(Entry)
        line = output.lines.reverse!.find(&.starts_with?(MARKER))
        raise Error.new("the application did not report its routes") unless line

        Array(Entry).from_json(line.lchop(MARKER))
      rescue ex : JSON::ParseException
        raise Error.new("the routes the application reported are not valid JSON: #{ex.message}")
      end

      # Compiles and runs the script from the project directory (its requires and `lib/` are relative to it).
      def run(dir : String = Dir.current) : Array(Entry)
        ScratchFile.with("tmp_routes_", script, dir) do |path|
          output = IO::Memory.new
          error = IO::Memory.new
          process = ScratchFile.watch(Process.new("crystal", ["run", path], chdir: dir, output: output, error: error))
          status = process.wait
          raise Error.new(failure_message(error.to_s)) unless status.success?

          self.class.parse(output.to_s)
        end
      end

      private def failure_message(stderr : String) : String
        lines = stderr.strip.lines
        "the application could not be loaded to list its routes:\n#{lines.last(20).join('\n')}"
      end
    end
  end
end
