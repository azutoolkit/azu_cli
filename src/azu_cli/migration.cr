module AzuCLI
  class Migration
    include Topia::Plugin
    include Helpers

    PATH = "./db/migrations"
    getter spinner : Topia::Spinner = Topia::Spinner.new("Waiting...")

    def run(input, params)
      migration_name = params.first
      migration_uid = Time.local.to_unix.to_s.rjust(10, '0')
      file_name = "#{migration_uid}__#{migration_name}.cr"
      check_path = "#{PATH}/*__#{migration_name}.cr".underscore.downcase
      path = "#{PATH}/#{file_name}.cr".underscore.downcase

      return false if exists? check_path

      File.open(path, "w") do |file|
        file.puts content(params)
      end

      true
    rescue e
      error e.message.to_s
      e
    end

    def on(event : String)
    end

    private def content(params)
      return empty_template(params) if params.size == 1
      filled_template(params)
    end

    private def empty_template(params : Array(String))
      migration_name = params.first
      class_name = "#{migration_name.camelcase}Migration"

      <<-CONTENT
      class #{params.first}
        include Clear::Migration

        def change(direction)
          direction.up do
          # TODO: Fill migration
          end

          # direction.down do
          # # TODO: Fill migration
          # end
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
      
        def change(direction.up do)
          direction.up do
            create_table :#{table} do |t|
              #{render_columns(columns)}
              t.timestamps
            end
          end

          # direction.down do
          # end
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
