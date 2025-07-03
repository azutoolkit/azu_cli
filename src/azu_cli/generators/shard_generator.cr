require "./base"

module AzuCLI
  module Generators
    # Database types supported by the shard generator
    enum DatabaseType
      PostgreSQL
      MySQL
      SQLite

      def to_s(io : IO) : Nil
        case self
        when .postgre_sql?
          io << "postgresql"
        when .my_sql?
          io << "mysql"
        when .sq_lite?
          io << "sqlite"
        end
      end

      def self.from_string(db : String) : DatabaseType
        case db.downcase
        when "postgresql", "postgres", "pg"
          PostgreSQL
        when "mysql"
          MySQL
        when "sqlite", "sqlite3"
          SQLite
        else
          raise ArgumentError.new("Unsupported database type: #{db}. Supported: postgresql, mysql, sqlite")
        end
      end
    end

    # Configuration for Crystal shard generation
    struct ShardConfiguration
      getter version : String
      getter crystal_version : String
      getter license : String
      getter authors : Array(String)
      getter dependencies : Hash(String, String)
      getter dev_dependencies : Hash(String, String)
      getter targets : Hash(String, String)
      getter database : DatabaseType

      def initialize(@version : String = "0.1.0",
                     @crystal_version : String = ">= 1.16.0",
                     @license : String = "MIT",
                     @authors : Array(String) = ["Your Name <your@email.com>"],
                     @dependencies : Hash(String, String) = Hash(String, String).new,
                     @dev_dependencies : Hash(String, String) = ShardConfiguration.default_dev_dependencies,
                     @targets : Hash(String, String) = Hash(String, String).new,
                     @database : DatabaseType = DatabaseType::PostgreSQL)
                 # Merge base dependencies with database-specific dependencies
         @dependencies = default_dependencies.merge(@dependencies)
         add_database_dependencies!
       end

      def has_dependencies?
        !@dependencies.empty?
      end

      def has_dev_dependencies?
        !@dev_dependencies.empty?
      end

      def has_targets?
        !@targets.empty?
      end

      # Add database-specific dependencies based on selected database
      private def add_database_dependencies!
        case @database
        when .postgre_sql?
          @dependencies["pg"] = "will/crystal-pg"
        when .my_sql?
          @dependencies["mysql"] = "crystal-lang/crystal-mysql"
        when .sq_lite?
          @dependencies["sqlite3"] = "crystal-lang/crystal-sqlite3"
        end
      end

      def database_name : String
        @database.to_s
      end

      def database_shard_name : String
        case @database
        when .postgre_sql?
          "pg"
        when .my_sql?
          "mysql"
        when .sq_lite?
          "sqlite3"
        else
          "pg" # Default fallback
        end
      end

      private def default_dependencies
        {
          "azu"     => "azutoolkit/azu",
          "topia"   => "azutoolkit/topia",
          "cql"     => "azutoolkit/cql",
          "session" => "azutoolkit/session",
        }
      end

      private def self.default_dependencies
        {
          "azu"     => "azutoolkit/azu",
          "topia"   => "azutoolkit/topia",
          "cql"     => "azutoolkit/cql",
          "session" => "azutoolkit/session",
        }
      end

      def self.default_dev_dependencies
        {
          "webmock" => "manastech/webmock.cr",
          "ameba"   => "crystal-ameba/ameba",
        }
      end
    end

    class ShardGenerator < Base
      directory "#{__DIR__}/../templates/generators/shard"

      # Instance variables expected by Teeplate from template scanning
      @app_name : String
      @app_name_kebabcase : String
      @version : String
      @crystal_version : String
      @license : String
      @authors : Array(String)
      @dependencies : Hash(String, String)
      @dev_dependencies : Hash(String, String)
      @targets : Hash(String, String)

      getter configuration : ShardConfiguration

            def initialize(app_name : String,
                     output_dir : String = ".",
                     generate_specs : Bool = true,
                     version : String = "0.1.0",
                     crystal_version : String = ">= 1.16.0",
                     license : String = "MIT",
                     authors : Array(String) = ["Your Name <your@email.com>"],
                     dependencies : Hash(String, String) = Hash(String, String).new,
                     dev_dependencies : Hash(String, String) = Hash(String, String).new,
                     database : String | DatabaseType = DatabaseType::PostgreSQL)
        super(app_name, output_dir, generate_specs)

        # Convert string database to enum if needed
        db_type = database.is_a?(String) ? DatabaseType.from_string(database) : database

                 # Merge with defaults if empty
         final_dev_deps = dev_dependencies.empty? ? ShardConfiguration.default_dev_dependencies : dev_dependencies

         @configuration = ShardConfiguration.new(version, crystal_version, license, authors, dependencies, final_dev_deps, Hash(String, String).new, db_type)

        @app_name = app_name
        @app_name_kebabcase = name_kebabcase
        @version = version
        @crystal_version = crystal_version
        @license = license
        @authors = authors
        @dependencies = @configuration.dependencies
        @dev_dependencies = @configuration.dev_dependencies
        @targets = build_default_targets
      end

      def template_directory : String
        "#{__DIR__}/../templates/generators/shard"
      end

      def build_output_path : String
        File.join(@output_dir, "shard.yml")
      end

      # Override spec template - shard.yml doesn't need specs
      protected def generate_spec_file!
        # No spec file for shard.yml
      end

      # Template methods for accessing shard properties
      def app_name
        @app_name
      end

      def app_name_kebabcase
        @app_name_kebabcase
      end

      def version
        @version
      end

      def crystal_version
        @crystal_version
      end

      def license
        @license
      end

      def authors
        @authors
      end

      def dependencies
        @dependencies
      end

      def dev_dependencies
        @dev_dependencies
      end

      def targets
        @targets
      end

      def has_dependencies?
        @configuration.has_dependencies?
      end

      def has_dev_dependencies?
        @configuration.has_dev_dependencies?
      end

      def has_targets?
        @configuration.has_targets?
      end

      def database
        @configuration.database_name
      end

      def database_shard
        @configuration.database_shard_name
      end

      # Build default targets based on app name
      private def build_default_targets
        {
          @app_name_kebabcase => "src/#{@app_name}.cr"
        }
      end

      # Validation methods
      protected def validate_preconditions!
        super
        validate_shard_configuration!
      end

      private def validate_shard_configuration!
        raise ArgumentError.new("Version cannot be empty") if @version.empty?
        raise ArgumentError.new("Crystal version cannot be empty") if @crystal_version.empty?
        raise ArgumentError.new("License cannot be empty") if @license.empty?
        raise ArgumentError.new("Authors cannot be empty") if @authors.empty?

        @authors.each do |author|
          raise ArgumentError.new("Author cannot be empty") if author.empty?
        end

        validate_dependencies!(@dependencies, "dependency")
        validate_dependencies!(@dev_dependencies, "dev_dependency")
      end

      private def validate_dependencies!(deps : Hash(String, String), type : String)
        deps.each do |name, source|
          raise ArgumentError.new("#{type.capitalize} name cannot be empty") if name.empty?
          raise ArgumentError.new("#{type.capitalize} source cannot be empty") if source.empty?

          # Validate GitHub repository format
          if source.includes?("/") && !source.starts_with?("http")
            parts = source.split("/")
            raise ArgumentError.new("Invalid GitHub repository format for #{name}: #{source}") if parts.size != 2
          end
        end
      end

      protected def post_generation_hook
        super
        AzuCLI::Logger.info("Generated shard.yml for #{@app_name}")
        AzuCLI::Logger.info("Run 'shards install' to install dependencies")
      end
    end
  end
end
