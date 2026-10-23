require "teeplate"
require "./resource"

module AzuCLI
  module Generate
    # Migration generator that creates CQL::Migration classes
    class Migration < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/migrations"
      OUTPUT_DIR = "./#{AzuCLI::Config::Paths::MIGRATIONS}"
      # Migration configuration properties
      property name : String
      property attributes : Hash(String, String)
      property timestamps : Bool
      property snake_case_name : String
      property timestamp : String
      property table_name : String
      property action_prefix : String
      property table_name_for_template : String
      property file_stem : String
      property id_type : String

      # `table` names the table when the generator knows it; otherwise it is read from the migration name.
      def initialize(@name : String, @attributes : Hash(String, String), @timestamps : Bool = true, @id_type : String = "Int64", table : String? = nil)
        @snake_case_name = to_snake_case(@name)
        @timestamp = generate_timestamp
        @table_name = table || extract_table_name(@snake_case_name)
        @action_prefix = get_action_prefix
        @table_name_for_template = get_table_name_for_filename
        @file_stem = build_file_stem
      end

      def fields : Array(Field)
        Field.columns(@attributes)
      end

      # The `table :name do ... end` block, as the migration creates it (`schema.table`) and
      # `src/db/schema.cr` mirrors it (`table`).
      def table_definition(indent : String = "", receiver : String = "") : String
        lines = ["#{receiver}table :#{table_name} do", "  primary :id, #{@id_type}, auto_increment: true"]
        fields.each { |field| lines << "  #{field.column}" }
        lines << "  timestamps" if @timestamps
        fields.each { |field| field.foreign_key.try { |foreign_key| lines << "  #{foreign_key}" } }
        lines << "end"
        lines.map { |line| "#{indent}#{line}" }.join("\n")
      end

      # Renders the migration; a create-table migration also declares its table in `src/db/schema.cr`,
      # where the models look their columns up.
      def render(output_dir : String, force : Bool = false, interactive : Bool = true, list : Bool = false, color : Bool = false)
        super
        register_table(File.join(File.dirname(output_dir), "schema.cr")) if migration_type == "create_table"
      end

      private def register_table(schema_file : String)
        return unless File.exists?(schema_file)

        schema = File.read(schema_file)
        return if schema.matches?(/^\s*table :#{table_name} do/m)

        closing = schema.rindex(/^end\s*\z/m) || return
        File.write(schema_file, "#{schema[0...closing].rstrip}\n\n#{table_definition("  ")}\n#{schema[closing..]}")
      end

      NAME_PREFIXES = [/^create_/, /^update_/, /^delete_/, /^drop_/, /^add_.*_to_/, /^remove_.*_from_/, /^change_.*_in_/]

      # The table a migration name is about: its name without the one prefix that says what it does
      # (`create_update_logs` is about `update_logs`).
      private def extract_table_name(name : String) : String
        prefix = NAME_PREFIXES.find { |pattern| name.matches?(pattern) }
        (prefix ? name.sub(prefix, "") : name).singularize.pluralize
      end

      # Detect migration type based on name pattern
      def migration_type : String
        case @snake_case_name
        when /^add_index_to_/
          "add_index"
        when /^remove_index_from_/
          "remove_index"
        when /^add_.*_to_/
          "add_columns"
        when /^remove_.*_from_/
          "remove_columns"
        when /^change_.*_in_/
          "change_columns"
        when /^create_/
          "create_table"
        when /^update_/
          "update_table"
        when /^delete_/
          "delete_table"
        when /^drop_/
          "drop_table"
        else
          "create_table" # Default fallback
        end
      end

      # Extract table name from migration name for add/remove operations
      def target_table_name : String
        case migration_type
        when "add_columns", "remove_columns", "change_columns"
          # Extract table name from "AddXToY" or "add_x_to_y"
          parts = @snake_case_name.split(/_/)
          if parts.size >= 3 && parts[-2] == "to"
            parts.last
          else
            @table_name
          end
        when "add_index", "remove_index"
          # Extract table name from "AddIndexToX" or "add_index_to_x"
          parts = @snake_case_name.split(/_/)
          if parts.size >= 4 && parts[-2] == "to"
            parts.last
          else
            @table_name
          end
        else
          @table_name
        end
      end

      # Extract column names from migration name
      def column_names : Array(String)
        case migration_type
        when "add_columns", "remove_columns", "change_columns"
          # Extract column names from "AddXToY" or "add_x_to_y"
          parts = @snake_case_name.split(/_/)
          if parts.size >= 3 && parts[-2] == "to"
            # For "add_name_and_email_to_users", extract ["name", "email"]
            parts[1..-3].reject { |p| p == "and" }
          else
            @attributes.keys
          end
        else
          @attributes.keys
        end
      end

      # Convert name to snake_case for file naming
      def snake_case_name : String
        # Convert to snake_case first, then singularize to avoid singularize lowercasing issues
        to_snake_case(@name).singularize
      end

      # Convert a string to snake_case
      private def to_snake_case(str : String) : String
        str.gsub(/([A-Z\d]+)([A-Z][a-z])/) { "#{$1}_#{$2}" }
          .gsub(/([a-z\d])([A-Z])/) { "#{$1}_#{$2}" }
          .tr("-", "_")
          .downcase
      end

      # Timestamp for the migration version: now, or one second after the newest migration already
      # in the project. Two migrations generated within the same second would otherwise share a
      # version, and `db:migrate` skips a migration whose version is already recorded.
      private def generate_timestamp : String
        format = "%Y%m%d%H%M%S"
        time = Time.utc
        newest = Dir.glob(File.join(OUTPUT_DIR, "*.cr")).compact_map { |path| File.basename(path)[/\A\d{14}/]? }.max?
        if newest && (last = Time.parse_utc(newest, format)) && last >= time.at_beginning_of_second
          time = last + 1.second
        end
        time.to_s(format)
      end

      # Name that follows the timestamp in the file name, and that the class is named after.
      # Create/update/delete migrations are named after their table (`create_posts`); the others keep
      # the whole name (`add_slug_to_posts`), so two of them on one table do not collide.
      private def build_file_stem : String
        case migration_type
        when "add_columns", "remove_columns", "change_columns", "add_index", "remove_index"
          to_snake_case(@name)
        else
          "#{get_action_prefix}_#{get_table_name_for_filename}"
        end
      end

      # Get migration filename
      def migration_filename : String
        "#{@timestamp}_#{file_stem}.cr"
      end

      # Get action prefix for filename based on migration type
      private def get_action_prefix : String
        case migration_type
        when "create_table"
          "create"
        when "update_table"
          "update"
        when "delete_table", "drop_table"
          "delete"
        when "add_columns"
          "add"
        when "remove_columns"
          "remove"
        when "change_columns"
          "change"
        when "add_index"
          "add_index"
        when "remove_index"
          "remove_index"
        else
          "create"
        end
      end

      # Get table name for filename
      private def get_table_name_for_filename : String
        case migration_type
        when "add_columns", "remove_columns", "change_columns", "add_index", "remove_index"
          target_table_name
        else
          @table_name
        end
      end

      # Get migration class name
      def migration_class_name : String
        file_stem.camelcase
      end
    end
  end
end
