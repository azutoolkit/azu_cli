module AzuCLI
  class Migration
    include Builder

    PATH        = "./db/migrations"
    ARGS        = "name table_name column:psqltype column:psqltype ..."
    DESCRIPTION = <<-DESC
    #{bold "Azu - Clear"} - Migration Generator

      Generates a clear migration. If only the `name` is provided will generate 
      an empty migration.

      Clear offers a migration system. Migration allow you to handle state update 
      of your database. Migration is a list of change going through a direction, 
      up (commit changes) or down (rollback changes).

      Docs - https://clear.gitbook.io/project/migrations/call-migration-script
    DESC

    option name : String, "--name=Name", "-n Name", "Name for the migrarion", ""
    option table : String, "--table=Table", "-t Table", "Database table", ""
    option columns : String, "--columns=Name:Type", "-c Name:Type", "Table Columns [Name:Type ...]", ""

    def run
      validate

      file_name = "#{migration_id}__#{name}.cr"
      check_path = "#{PATH}/*__#{name}.cr".underscore.downcase
      path = "#{PATH}/#{file_name}".underscore.downcase

      not_exists?(check_path) do
        File.open(path, "w") do |file|
          file.puts content
        end
      end

      success "Created #{PROGRAM} for #{name} in #{path}"
      exit 1
    end

    private def content
      return empty_template unless table && columns
      filled_template
    end

    private def migration_id
      Time.local.to_unix.to_s.rjust(10, '0')
    end

    private def validate
      errors = [] of String

      errors << "Missing option: name" if name.empty?
      errors << "Missing option: table" if table.empty?
      errors << "Missing option: columsn" if columns.empty?

      return if errors.empty?

      error errors.join("\n")
      exit 1
    end

    private def empty_template
      <<-CONTENT
      class #{name.camelcase}
        include Clear::Migration

        def change(direction)
          direction.up do
          # TODO: Fill migration
          end

          direction.down do
          # TODO: Fill migration
          end
        end
      end
      CONTENT
    end

    private def filled_template
      <<-CONTENT
      class Create#{name.camelcase}
        include Clear::Migration
      
        def change(direction)
          direction.up do
            create_table :#{table.pluralize.downcase} do |t|
              #{render_columns(columns.split(" "))}
              t.timestamps
            end
          end

          direction.down do
            execute "DROP TABLE IF EXISTS #{table.pluralize.downcase};"
          end
        end
      end
      CONTENT
    end

    private def render_columns(columns)
      String.build do |str|
        columns.reject(&.empty?).each do |col|
          name, type = col.split(":").map(&.underscore)
          nullable = (type =~ /\?$/)
          type ||= "string"
          type = type.gsub(/\?$/, "")

          if type == "references"
            str << %Q(t.references to: "#{name}", on_delete: "restrict", null: #{nullable})
          else
            str << %Q(t.column :#{name}, "#{type}", null: #{nullable ? "true" : "false"})
          end
          str << "\n\t\t\t"
        end
      end
    end
  end
end
