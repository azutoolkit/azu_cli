require "json"
require "./setting"

module AzuCLI
  module AppConfig
    # Asks the application for its effective configuration: compiles and runs a small script that requires the
    # app (without starting its server) and prints what `Azu::CONFIG` holds as JSON. The values only exist once the
    # application's code is loaded, because its initializers and `.env` files decide them.
    class Runner
      MARKER = "AZU_CONFIG_JSON:"

      class Error < Exception
      end

      getter app_file : String

      def initialize(@app_file : String)
      end

      # The script. It reports no secret: the password of the database URL is masked, and the secrets are reported
      # only as set or not set.
      def script : String
        <<-CRYSTAL
          require "json"
          require #{app_file.inspect}

          settings = [] of {section: String, key: String, value: String}
          add = ->(section : String, key : String, value : String) { settings << {section: section, key: key, value: value} }
          span = ->(value : Time::Span?) { value ? "\#{value.total_seconds.to_i}s" : "off" }
          list = ->(values : Array(String)) { values.empty? ? "-" : values.join(", ") }
          config = Azu::CONFIG

          add.call("server", "environment", config.env.to_s.downcase)
          add.call("server", "host", config.host)
          add.call("server", "port", config.port.to_s)
          add.call("server", "loopback only", config.loopback_host?.to_s)
          add.call("server", "port reuse", config.port_reuse?.to_s)
          add.call("server", "container", config.container?.to_s)
          add.call("server", "shutdown timeout", span.call(config.shutdown_timeout))
          add.call("tls", "enabled", config.tls?.to_s)
          add.call("tls", "mode", config.ssl_mode)
          add.call("tls", "certificate", config.ssl_cert.empty? ? "-" : config.ssl_cert)
          add.call("tls", "key", config.ssl_key.empty? ? "-" : config.ssl_key)
          add.call("tls", "ca", config.ssl_ca.empty? ? "-" : config.ssl_ca)
          add.call("templates", "hot reload", config.template_hot_reload?.to_s)
          add.call("templates", "autoescape", config.template_autoescape?.to_s)
          add.call("errors", "format", config.error_format.to_s.downcase)
          add.call("errors", "format parameter", config.format_parameter || "-")
          add.call("session", "adapter", config.session_adapter.try(&.class.name) || "none")
          add.call("secrets", "CSRF_SECRET", ENV["CSRF_SECRET"]?.presence ? "set" : "not set")
          add.call("secrets", "SESSION_SECRET", ENV["SESSION_SECRET"]?.presence ? "set" : "not set")
          add.call("database", "url", (config.database.uri || "-").sub(/(:\\/\\/[^:\\/@]+):[^@]*@/, "\\\\1:***@"))
          add.call("database", "driver", config.database.driver || "-")
          add.call("database", "lazy connect", config.database.lazy_connect?.to_s)
          add.call("database", "slow query", "\#{config.database.slow_query_ms}ms")
          add.call("database", "n+1 threshold", config.database.n_plus_one_threshold.to_s)
          add.call("database", "playground", config.database.playground?.to_s)
          add.call("limits", "header timeout", span.call(config.limits.header_timeout))
          add.call("limits", "read timeout", span.call(config.limits.read_timeout))
          add.call("limits", "write timeout", span.call(config.limits.write_timeout))
          add.call("limits", "keep-alive timeout", span.call(config.limits.keep_alive_timeout))
          add.call("limits", "min body rate", "\#{config.limits.min_body_rate} B/s")
          add.call("limits", "max connections", config.limits.max_connections.to_s)
          add.call("uploads", "max file size", config.upload.max_file_size.to_s)
          add.call("uploads", "max request size", config.upload.max_request_size.to_s)
          add.call("uploads", "max files", config.upload.max_files.to_s)
          add.call("websocket", "allowed origins", list.call(config.websocket.allowed_origins))
          add.call("websocket", "max message size", config.websocket.max_message_size.to_s)
          add.call("i18n", "default locale", config.i18n.default_locale)
          add.call("i18n", "available locales", list.call(config.i18n.available_locales))
          add.call("assets", "prefix", config.assets.prefix)
          add.call("assets", "path", config.assets.path)

          puts "#{MARKER}\#{settings.to_json}"
        CRYSTAL
      end

      # Settings from the output of the script; the app may log around the marker line.
      def self.parse(output : String) : Array(Setting)
        line = output.lines.reverse!.find(&.starts_with?(MARKER))
        raise Error.new("the application did not report its configuration") unless line

        Array(Setting).from_json(line.lchop(MARKER))
      rescue ex : JSON::ParseException
        raise Error.new("the configuration the application reported is not valid JSON: #{ex.message}")
      end

      # Compiles and runs the script from the project directory (its requires and `lib/` are relative to it).
      def run(dir : String = Dir.current) : Array(Setting)
        ScratchFile.with("tmp_config_", script, dir) do |path|
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
        "the application could not be loaded to read its configuration:\n#{lines.last(20).join('\n')}"
      end
    end
  end
end
