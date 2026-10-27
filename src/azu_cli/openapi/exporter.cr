require "json"
require "../scratch_file"

module AzuCLI
  module OpenAPI
    # Asks the application for its OpenAPI document: compiles and runs a small script that requires the app (without
    # starting its server) and prints `Azu::OpenAPI.document` of `Azu::App.default`, the app the endpoints' route macros
    # register on. Azu builds the document from the endpoint contracts at compile time, so it holds the routes the app
    # really has, `scope` and `mount` included, with the validations of each request.
    class Exporter
      MARKER = "AZU_OPENAPI_JSON:"

      class Error < Exception
      end

      getter app_file : String

      def initialize(@app_file : String)
      end

      # The title and version come from the environment, so no value given on the command line becomes code.
      def script : String
        <<-CRYSTAL
          require #{app_file.inspect}

          info = Azu::OpenAPI::Info.new(ENV["AZU_OPENAPI_TITLE"], ENV["AZU_OPENAPI_VERSION"])
          puts "#{MARKER}\#{Azu::OpenAPI.document(Azu::App.default, info).to_json}"
        CRYSTAL
      end

      # The document from the output of the script; the app may log around the marker line.
      def self.parse(output : String) : String
        line = output.lines.reverse!.find(&.starts_with?(MARKER))
        raise Error.new("the application did not report its OpenAPI document") unless line

        json = line.lchop(MARKER)
        raise Error.new("the document the application reported is not a JSON object") unless JSON.parse(json).as_h?
        json
      rescue ex : JSON::ParseException
        raise Error.new("the document the application reported is not valid JSON: #{ex.message}")
      end

      # Compiles and runs the script from the project directory (its requires and `lib/` are relative to it).
      def run(title : String, version : String, dir : String = Dir.current) : String
        ScratchFile.with("tmp_openapi_", script, dir) do |path|
          output = IO::Memory.new
          error = IO::Memory.new
          env = {"AZU_OPENAPI_TITLE" => title, "AZU_OPENAPI_VERSION" => version}
          process = ScratchFile.watch(Process.new("crystal", ["run", path], env: env, chdir: dir, output: output, error: error))
          raise Error.new(failure_message(error.to_s)) unless process.wait.success?

          self.class.parse(output.to_s)
        end
      end

      private def failure_message(stderr : String) : String
        hint = stderr.includes?("Azu::OpenAPI") ? "\n(Azu::OpenAPI needs azu 0.5.72 or newer: update the azu shard)" : ""
        "the application could not be loaded to build its OpenAPI document:\n#{stderr.strip.lines.last(20).join('\n')}#{hint}"
      end
    end
  end
end
