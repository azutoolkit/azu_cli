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

    # Standard project directory structure
    module Paths
      SRC        = "src"
      SPEC       = "spec"
      CONFIG     = "config"
      PUBLIC     = "public"
      TEMPLATES  = "public/templates"
      LIB        = "lib"
      BIN        = "bin"
      DB         = "src/db"
      MIGRATIONS = "src/db/migrations"
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
      DEV_SERVER     = 4000 # azu's default PORT: the generated app, `azu serve`/`dev`/`doctor`, the hints
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
    property environment : String = ENV["AZU_ENV"]?.presence || ENV["CRYSTAL_ENV"]?.presence || "development"

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

    def self.load!
      instance.load!
    end

    # The CLI is configured by environment variables only (the AZU_* ones, DATABASE_URL and CRYSTAL_ENV).
    def load!
      load_from_environment

      # Set derived configuration
      configure_logging
      configure_environment
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

  end
end
