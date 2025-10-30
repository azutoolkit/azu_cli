require "yaml"
require "log"

module AzuCLI
  # Configuration management system for Azu CLI
  # Supports environment-aware configuration with sensible defaults
  class Config
    INSTANCE = new

    # Exit codes for consistent CLI behavior
    EXIT_SUCCESS       = 0
    EXIT_FAILURE       = 1
    EXIT_INVALID_USAGE = 2
    EXIT_NOT_FOUND     = 3

    # Default configuration file paths (searched in order)
    DEFAULT_CONFIG_PATHS = [
      "./config/azu.yml",
      "./azu.yml",
      "~/.config/azu/config.yml",
      "~/.azu.yml",
    ]

    # Standard project directory structure
    module Paths
      SRC        = "src"
      SPEC       = "spec"
      CONFIG     = "config"
      PUBLIC     = "public"
      TEMPLATES  = "public/templates"
      LIB        = "lib"
      BIN        = "bin"
      DB         = "db"
      MIGRATIONS = "db/migrations"
      MODELS     = "src/models"
      ENDPOINTS  = "src/endpoints"
      SERVICES   = "src/services"
      MIDDLEWARE = "src/middleware"
      VALIDATORS = "src/validators"
      JOBS       = "src/jobs"
      MAILERS    = "src/mailers"
    end

    # File patterns for watching and scanning
    module Patterns
      CRYSTAL_SOURCE = "**/*.cr"
      CRYSTAL_SPEC   = "**/*_spec.cr"
      JINJA_TEMPLATE = "**/*.jinja"
      HTML_TEMPLATE  = "**/*.html"
      ECR_TEMPLATE   = "**/*.ecr"
      YAML_CONFIG    = "**/*.yml"
      JSON_CONFIG    = "**/*.json"

      # Combined patterns for common use cases
      ALL_CRYSTAL   = "#{CRYSTAL_SOURCE}"
      ALL_TEMPLATES = "{#{JINJA_TEMPLATE},#{HTML_TEMPLATE},#{ECR_TEMPLATE}}"
      ALL_CONFIGS   = "{#{YAML_CONFIG},#{JSON_CONFIG}}"
    end

    # File extensions
    module Extensions
      CRYSTAL  = ".cr"
      JINJA    = ".jinja"
      HTML     = ".html"
      ECR      = ".ecr"
      YAML     = ".yml"
      JSON     = ".json"
      MARKDOWN = ".md"
    end

    # Default ports for various services
    module Ports
      DEV_SERVER     = 4000
      TEST_SERVER    = 4001
      PREVIEW_SERVER = 4002
      DATABASE_PG    = 5432
      DATABASE_MYSQL = 3306
      REDIS          = 6379
    end

    # Default host names
    module Hosts
      LOCALHOST      = "localhost"
      LOCAL_IPV4     = "127.0.0.1"
      LOCAL_IPV6     = "::1"
      ALL_INTERFACES = "0.0.0.0"
    end

    # Database adapters
    module Adapters
      POSTGRESQL = "postgresql"
      MYSQL      = "mysql"
      SQLITE     = "sqlite"
      SQLITE3    = "sqlite3"
    end

    # Template engines
    module TemplateEngines
      JINJA = "jinja"
      ECR   = "ecr"
    end

    # Common HTTP status codes
    module HttpStatus
      OK                    = 200
      CREATED               = 201
      NO_CONTENT            = 204
      BAD_REQUEST           = 400
      UNAUTHORIZED          = 401
      FORBIDDEN             = 403
      NOT_FOUND             = 404
      UNPROCESSABLE_ENTITY  = 422
      INTERNAL_SERVER_ERROR = 500
    end

    # Error severity levels for consistent error handling
    module ErrorSeverity
      DEBUG = 0 # Debug information only
      INFO  = 1 # Informational message
      WARN  = 2 # Warning that doesn't prevent operation
      ERROR = 3 # Error that prevents operation
      FATAL = 4 # Fatal error requiring immediate termination
    end

    # Error categories for better error classification
    module ErrorCategory
      # User input errors
      INVALID_INPUT    = "invalid_input"
      MISSING_ARGUMENT = "missing_argument"
      INVALID_OPTION   = "invalid_option"

      # File system errors
      FILE_NOT_FOUND    = "file_not_found"
      FILE_EXISTS       = "file_exists"
      PERMISSION_DENIED = "permission_denied"
      IO_ERROR          = "io_error"

      # Compilation and build errors
      COMPILATION_FAILED = "compilation_failed"
      BUILD_FAILED       = "build_failed"
      SYNTAX_ERROR       = "syntax_error"

      # Database errors
      DATABASE_ERROR    = "database_error"
      MIGRATION_FAILED  = "migration_failed"
      CONNECTION_FAILED = "connection_failed"

      # Configuration errors
      CONFIG_ERROR   = "config_error"
      INVALID_CONFIG = "invalid_config"
      MISSING_CONFIG = "missing_config"

      # Runtime errors
      RUNTIME_ERROR  = "runtime_error"
      TIMEOUT        = "timeout"
      RESOURCE_ERROR = "resource_error"

      # General
      UNKNOWN = "unknown"
    end

    # Global configuration
    property debug_mode : Bool = false
    property verbose : Bool = false
    property quiet : Bool = false
    property config_file_path : String?
    property environment : String = ENV.fetch("AZU_ENV", "development")

    # Project configuration
    property project_name : String = ""
    property project_path : String = Dir.current
    property database_adapter : String = Adapters::POSTGRESQL
    property template_engine : String = TemplateEngines::JINJA

    # Development server configuration
    property dev_server_host : String = Hosts::LOCALHOST
    property dev_server_port : Int32 = Ports::DEV_SERVER
    property? dev_server_watch : Bool = true
    property? dev_server_rebuild : Bool = true

    # Database configuration
    property database_url : String?
    property database_name : String?
    property database_host : String = Hosts::LOCALHOST
    property database_port : Int32 = 5432
    property database_user : String = "postgres"
    property database_password : String = ""

    # File system configuration
    property templates_path : String = "./src/azu_cli/templates"
    property output_path : String = "."

    # Logging configuration
    property log_level : Log::Severity = Log::Severity::Info
    property log_format : String = "default"

    # CLI configuration
    property? show_help_on_empty : Bool = true
    property? colored_output : Bool = true

    def self.instance
      INSTANCE
    end

    def self.load!(config_path : String? = nil)
      instance.load!(config_path)
    end

    def load!(config_path : String? = nil)
      # Load configuration from file if exists
      config_file = find_config_file(config_path)
      load_from_file(config_file) if config_file

      # Override with environment variables
      load_from_environment

      # Set derived configuration
      configure_logging
      configure_environment
    end

    # Load configuration from YAML file
    private def load_from_file(file_path : String)
      return unless File.exists?(file_path)

      begin
        yaml_content = File.read(file_path)
        config_data = YAML.parse(yaml_content)

        # Ensure the config_data is a Hash-like structure
        unless config_data.as_h?
          # If it's not a hash, skip this file (it might be shard.yml or another type of YAML)
          return
        end

        # Load environment-specific configuration
        env_config = config_data[environment]? || config_data

        # Parse configuration sections
        load_global_config(env_config)
        load_general_config(env_config)
        load_filesystem_config(env_config)
        load_database_config(env_config)
        load_server_config(env_config)
        load_logging_config(env_config)

        @config_file_path = file_path
      rescue ex : YAML::ParseException
        # Skip files that aren't valid YAML or aren't Azu config files
        return
      rescue ex : Exception
        # Only raise for actual Azu config files, not other YAML files
        if file_path.includes?("azu")
          raise "Failed to load configuration from #{file_path}: #{ex.message}"
        end
        # Otherwise, just skip the file
        return
      end
    end

    # Load configuration from environment variables
    private def load_from_environment
      @debug_mode = ENV.has_key?("AZU_DEBUG") || ENV.has_key?("DEBUG")
      @verbose = ENV.has_key?("AZU_VERBOSE") || @debug_mode
      @quiet = ENV.has_key?("AZU_QUIET")

      @database_url = ENV["DATABASE_URL"]?
      @database_name = ENV["AZU_DB_NAME"]?
      @database_host = ENV["AZU_DB_HOST"]? || @database_host
      @database_port = ENV["AZU_DB_PORT"]?.try(&.to_i) || @database_port
      @database_user = ENV["AZU_DB_USER"]? || @database_user
      @database_password = ENV["AZU_DB_PASSWORD"]? || @database_password

      @dev_server_host = ENV["AZU_HOST"]? || @dev_server_host
      @dev_server_port = ENV["AZU_PORT"]?.try(&.to_i) || @dev_server_port

      @templates_path = ENV["AZU_TEMPLATES_PATH"]? || @templates_path
      @output_path = ENV["AZU_OUTPUT_PATH"]? || @output_path
    end

    # Find configuration file from default paths or specified path
    private def find_config_file(specified_path : String? = nil) : String?
      if specified_path
        return specified_path if File.exists?(specified_path)
        return nil
      end

      DEFAULT_CONFIG_PATHS.find { |path| File.exists?(expand_path(path)) }
        .try { |path| expand_path(path) }
    end

    # Expand tilde in file paths
    private def expand_path(path : String) : String
      if path.starts_with?("~/")
        home_dir = ENV["HOME"]? || ENV["USERPROFILE"]? || "."
        path.gsub(/^~/, home_dir)
      else
        path
      end
    end

    # Load global configuration section
    private def load_global_config(config : YAML::Any)
      if global = config["global"]?
        @debug_mode = global["debug_mode"]?.try(&.as_bool) || @debug_mode
        @verbose = global["verbose"]?.try(&.as_bool) || @verbose
        @quiet = global["quiet"]?.try(&.as_bool) || @quiet
        @show_help_on_empty = global["show_help_on_empty"]?.try(&.as_bool) || @show_help_on_empty
      end
    end

    # Load general configuration section
    private def load_general_config(config : YAML::Any)
      if general = config["general"]?
        @project_name = general["project_name"]?.try(&.as_s) || @project_name
        @project_path = general["project_path"]?.try(&.as_s) || @project_path
        @database_adapter = general["database_adapter"]?.try(&.as_s) || @database_adapter
        @template_engine = general["template_engine"]?.try(&.as_s) || @template_engine
        @colored_output = general["colored_output"]?.try(&.as_bool) || @colored_output
      end
    end

    # Load file system configuration section
    private def load_filesystem_config(config : YAML::Any)
      if filesystem = config["filesystem"]?
        @templates_path = filesystem["templates_path"]?.try(&.as_s) || @templates_path
        @output_path = filesystem["output_path"]?.try(&.as_s) || @output_path
      end
    end

    # Load database configuration section
    private def load_database_config(config : YAML::Any)
      if database = config["database"]?
        @database_url = database["url"]?.try(&.as_s) || @database_url
        @database_name = database["name"]?.try(&.as_s) || @database_name
        @database_host = database["host"]?.try(&.as_s) || @database_host
        @database_port = database["port"]?.try(&.as_i) || @database_port
        @database_user = database["user"]?.try(&.as_s) || @database_user
        @database_password = database["password"]?.try(&.as_s) || @database_password
      end
    end

    # Load development server configuration section
    private def load_server_config(config : YAML::Any)
      if server = config["server"]?
        @dev_server_host = server["host"]?.try(&.as_s) || @dev_server_host
        @dev_server_port = server["port"]?.try(&.as_i) || @dev_server_port
        @dev_server_watch = server["watch"]?.try(&.as_bool) != false
        @dev_server_rebuild = server["rebuild"]?.try(&.as_bool) != false
      end
    end

    # Load logging configuration section
    private def load_logging_config(config : YAML::Any)
      if logging = config["logging"]?
        if level_str = logging["level"]?.try(&.as_s)
          @log_level = case level_str.downcase
                       when "debug"           then Log::Severity::Debug
                       when "info"            then Log::Severity::Info
                       when "warn", "warning" then Log::Severity::Warn
                       when "error"           then Log::Severity::Error
                       when "fatal"           then Log::Severity::Fatal
                       else                        Log::Severity::Info
                       end
        end
        @log_format = logging["format"]?.try(&.as_s) || @log_format
      end
    end

    # Configure logging based on current settings
    private def configure_logging
      if @quiet
        @log_level = Log::Severity::Error
      elsif @debug_mode || @verbose
        @log_level = Log::Severity::Debug
      end
    end

    # Configure environment-specific settings
    private def configure_environment
      case @environment
      when "development"
        @debug_mode = true unless ENV.has_key?("AZU_DEBUG")
        @dev_server_watch = true
        @dev_server_rebuild = true
      when "test"
        @quiet = true unless @debug_mode
        @log_level = Log::Severity::Warn unless @debug_mode
      when "production"
        @debug_mode = false
        @dev_server_watch = false
        @dev_server_rebuild = false
      end
    end

    # Check if running in development environment
    def development?
      @environment == "development"
    end

    # Check if running in test environment
    def test?
      @environment == "test"
    end

    # Check if running in production environment
    def production?
      @environment == "production"
    end

    # Get file watch patterns for development server
    def watch_patterns : Array(String)
      [
        "#{Paths::SRC}/#{Patterns::CRYSTAL_SOURCE}",
        "#{Paths::CONFIG}/#{Patterns::CRYSTAL_SOURCE}",
        "#{Paths::TEMPLATES}/#{Patterns::JINJA_TEMPLATE}",
        "#{Paths::TEMPLATES}/#{Patterns::HTML_TEMPLATE}",
      ]
    end

    # Get file watch patterns for test runner
    def test_watch_patterns : Array(String)
      [
        "#{Paths::SRC}/#{Patterns::CRYSTAL_SOURCE}",
        "#{Paths::SPEC}/#{Patterns::CRYSTAL_SOURCE}",
      ]
    end

    # Build path from segments
    def self.build_path(*segments : String) : String
      File.join(segments)
    end

    # Get full database URL
    def full_database_url : String
      if url = @database_url
        url
      else
        name = @database_name || @project_name
        "#{@database_adapter}://#{@database_user}:#{@database_password}@#{@database_host}:#{@database_port}/#{name}"
      end
    end

    # Validate configuration
    def validate!
      errors = [] of String

      # Validate paths
      unless Dir.exists?(@templates_path)
        errors << "Templates path does not exist: #{@templates_path}"
      end

      unless Dir.exists?(@output_path)
        errors << "Output path does not exist: #{@output_path}"
      end

      # Validate database configuration if database operations are needed
      if @database_adapter.empty?
        errors << "Database adapter is required"
      end

      # Validate server configuration
      if @dev_server_port < 1 || @dev_server_port > 65535
        errors << "Invalid server port: #{@dev_server_port}"
      end

      unless errors.empty?
        raise "Configuration validation failed:\n  #{errors.join("\n  ")}"
      end
    end

    # Generate sample configuration file
    def self.generate_sample_config(path : String = "./azu.yml")
      config_content = <<-YAML
      # Azu CLI Configuration File
      # This file configures the Azu CLI tool for your project
      #
      # Configuration is loaded in this order:
      # 1. Default values (defined in code)
      # 2. Configuration file (this file)
      # 3. Environment variables (override file values)
      #
      # Environment variables take precedence over file configuration.
      # See the Environment Variables section below for available options.

      # Environment: development, test, production
      # Can be overridden with AZU_ENV environment variable
      environment: development

      # Global configuration
      # These settings affect CLI behavior globally
      global:
        debug_mode: false     # Enable debug output (AZU_DEBUG)
        verbose: false        # Enable verbose output (AZU_VERBOSE)
        quiet: false          # Suppress non-error output (AZU_QUIET)
        show_help_on_empty: true  # Show help when no command provided

      # General project configuration
      general:
        project_name: "my_azu_project"
        project_path: "."                    # Project root directory
        database_adapter: "postgresql"       # postgresql, mysql, sqlite
        template_engine: "jinja"             # jinja, ecr
        colored_output: true                 # Enable colored terminal output

      # File system configuration
      filesystem:
        templates_path: "./src/azu_cli/templates"  # Path to template files (AZU_TEMPLATES_PATH)
        output_path: "."                            # Default output directory (AZU_OUTPUT_PATH)

      # Database configuration
      database:
        host: "localhost"                    # Database host (AZU_DB_HOST)
        port: 5432                          # Database port (AZU_DB_PORT)
        user: "postgres"                    # Database user (AZU_DB_USER)
        password: ""                        # Database password (AZU_DB_PASSWORD)
        name: "my_azu_project_development"  # Database name (AZU_DB_NAME)
        # Alternatively, use a full URL (overrides individual settings):
        # url: "postgresql://user:password@localhost:5432/database"  # (DATABASE_URL)

      # Development server configuration
      server:
        host: "localhost"    # Server host (AZU_HOST)
        port: 4000          # Server port (AZU_PORT)
        watch: true         # Watch for file changes
        rebuild: true       # Rebuild on changes

      # Logging configuration
      logging:
        level: "info"       # Log level: debug, info, warn, error, fatal
        format: "default"   # Log format

      # Environment-specific overrides
      # These sections override the base configuration for specific environments

      test:
        global:
          quiet: true
        database:
          name: "my_azu_project_test"
        logging:
          level: "warn"

      production:
        global:
          debug_mode: false
        server:
          watch: false
          rebuild: false
        logging:
          level: "info"

      # Environment Variables Reference
      # The following environment variables can be used to override configuration:
      #
      # Global Settings:
      #   AZU_ENV          - Set environment (development, test, production)
      #   AZU_DEBUG        - Enable debug mode (any value)
      #   AZU_VERBOSE      - Enable verbose output (any value)
      #   AZU_QUIET        - Suppress output (any value)
      #
      # Database Settings:
      #   DATABASE_URL     - Full database connection URL
      #   AZU_DB_HOST      - Database host
      #   AZU_DB_PORT      - Database port
      #   AZU_DB_USER      - Database user
      #   AZU_DB_PASSWORD  - Database password
      #   AZU_DB_NAME      - Database name
      #
      # Server Settings:
      #   AZU_HOST         - Server host
      #   AZU_PORT         - Server port
      #
      # File System Settings:
      #   AZU_TEMPLATES_PATH - Path to template files
      #   AZU_OUTPUT_PATH    - Default output directory
      YAML

      File.write(path, config_content)
    end
  end
end
