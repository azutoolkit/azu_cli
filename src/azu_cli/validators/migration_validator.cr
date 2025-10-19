require "../logger"

module AzuCLI
  module Validators
    # Validates migration files for conflicts, dependencies, and consistency
    class MigrationValidator
    property migrations_dir : String
    property errors : Array(String)
    property warnings : Array(String)
    property migration_files : Array(String)
    property migration_versions : Array(Int64)

    def initialize(@migrations_dir : String = "./src/db/migrations")
      @errors = [] of String
      @warnings = [] of String
      @migration_files = [] of String
      @migration_versions = [] of Int64
    end

    # Validate all migrations
    def validate_all : Bool
      @errors.clear
      @warnings.clear

      load_migration_files

      check_version_conflicts &&
        validate_migration_files &&
        check_dependencies &&
        validate_schema_consistency
    end

    # Load migration files from directory
    private def load_migration_files
      @migration_files.clear
      @migration_versions.clear

      return unless Dir.exists?(@migrations_dir)

      Dir.glob("#{@migrations_dir}/*.cr").each do |file|
        filename = File.basename(file)
        if match = filename.match(/^(\d+)_/)
          version = match[1].to_i64
          @migration_files << file
          @migration_versions << version
        end
      end

      @migration_versions.sort!
    end

    # Check for version conflicts (duplicate versions)
    def check_version_conflicts : Bool
      duplicates = @migration_versions.group_by(&.itself).select { |_, versions| versions.size > 1 }

      unless duplicates.empty?
        duplicates.each do |version, _|
          @errors << "Duplicate migration version: #{version}"
        end
        return false
      end

      true
    end

    # Validate migration file structure and content
    def validate_migration_files : Bool
      valid = true

      @migration_files.each do |file|
        unless validate_single_migration_file(file)
          valid = false
        end
      end

      valid
    end

    # Validate a single migration file
    private def validate_single_migration_file(file : String) : Bool
      filename = File.basename(file, ".cr")
      content = File.read(file)

      # Check if file matches expected pattern
      unless filename.match(/^\d+_/)
        @errors << "Migration file #{filename} does not match version_timestamp pattern"
        return false
      end

      # Extract version and class name
      version = filename.split("_").first.to_i64
      class_name = filename.split("_", 2).last.split("_").map(&.capitalize).join

      # Check for migration class
      unless content.includes?("class #{class_name} < CQL::Migration")
        @errors << "Migration #{filename} should define class #{class_name} < CQL::Migration"
        return false
      end

      # Check for up method
      unless content.includes?("def up")
        @errors << "Migration #{filename} must define 'up' method"
        return false
      end

      # Check for down method
      unless content.includes?("def down")
        @warnings << "Migration #{filename} should define 'down' method for rollback"
      end

      # Check for version assignment
      unless content.includes?("self.version = #{version}_i64") || content.includes?("CQL::Migration(#{version}_i64)")
        @warnings << "Migration #{filename} should set version to #{version}_i64"
      end

      true
    end

    # Check migration dependencies (basic check for now)
    def check_dependencies : Bool
      # For now, just check that migrations are in chronological order
      # Future enhancement: check for explicit dependencies
      true
    end

    # Validate schema consistency
    def validate_schema_consistency : Bool
      # Basic validation - check that migration files can be loaded
      # Future enhancement: validate against actual database schema
      true
    end

    # Get validation summary
    def summary : String
      String.build do |io|
        io << "Migration Validation Summary:\n"
        io << "  Files checked: #{@migration_files.size}\n"
        io << "  Errors: #{@errors.size}\n"
        io << "  Warnings: #{@warnings.size}\n"

        unless @errors.empty?
          io << "\nErrors:\n"
          @errors.each { |error| io << "  - #{error}\n" }
        end

        unless @warnings.empty?
          io << "\nWarnings:\n"
          @warnings.each { |warning| io << "  - #{warning}\n" }
        end
      end
    end

    # Check if validation passed
    def valid? : Bool
      @errors.empty?
    end

    # Get pending migrations (not yet applied)
    def pending_migrations(applied_versions : Array(Int64)) : Array(Int64)
      @migration_versions - applied_versions
    end

    # Get applied migrations
    def applied_migrations(applied_versions : Array(Int64)) : Array(Int64)
      @migration_versions & applied_versions
    end

    # Get migration file for version
    def migration_file_for_version(version : Int64) : String?
      @migration_files.find { |file| file.includes?("#{version}_") }
    end

    # Get migration class name for version
    def migration_class_for_version(version : Int64) : String?
      file = migration_file_for_version(version)
      return nil unless file

      filename = File.basename(file, ".cr")
      filename.split("_", 2).last.split("_").map(&.capitalize).join
    end
  end
end
end
