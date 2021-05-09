module AzuCLI
  class Migration
    include Builder

    PATH        = "./db/migrations"
    ARGS        = "name table_name column:psqltype column:psqltype ..."
    DESCRIPTION = <<-DESC
    Azu - Clear Migration Generator

    Generates a clear migration. If only the `name` is provided will generate 
    an empty migration.

    Clear offers a migration system. Migration allow you to handle state update 
    of your database. Migration is a list of change going through a direction, 
    up (commit changes) or down (rollback changes).

    Docs: https://clear.gitbook.io/project/migrations/call-migration-script

    Command Arguments Definition:
      - *name: name for the migration eg. `UpdatePrimaryKeyType`
      - table_name: name of the database table to create eq. `users`
      - column: name of the database columns to create and the postgres type eg.
        `first_name:varchar`

      * - Required fields
    DESC

    def run
      migration_name = args.first
      migration_uid = Time.local.to_unix.to_s.rjust(10, '0')
      file_name = "#{migration_uid}__#{migration_name}.cr"
      check_path = "#{PATH}/*__#{migration_name}.cr".underscore.downcase
      path = "#{PATH}/#{file_name}".underscore.downcase

      not_exists?(check_path) do
        File.open(path, "w") do |file|
          file.puts content(args)
        end
      end

      success "Created #{PROGRAM}: #{path}"
      exit 1
    end

    private def content(params)
      return empty_template(params) if params.size == 1
      filled_template(params)
    end

    private def empty_template(params : Array(String))
      migration_name = params.first
      class_name = "#{migration_name.camelcase}"

      <<-CONTENT
      class #{class_name}
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

    private def filled_template(params : Array(String))
      name, table_name, columns = params.first, params[1], params[2..-1]

      if table_name.includes?(":")
        table = name
        columns = params[1..-1]
      else
        table = table_name
      end

      <<-CONTENT
      class Create#{name.camelcase}
        include Clear::Migration
      
        def change(direction)
          direction.up do
            create_table :#{table.pluralize.downcase} do |t|
              #{render_columns(columns)}
              t.timestamps
            end
          end

          direction.down do
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
