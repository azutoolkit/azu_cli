require "../database"

module AzuCLI
  module Commands
    module DB
      # Load schema from file (fast alternative to running migrations)
      class SchemaLoad < Database
        property schema_file : String?
        property force : Bool = false

        def initialize
          super("db:schema:load", "Load schema from file")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_options
        end

        def execute : Result
          parse_options

          db_name = @database_name || infer_database_name

          unless database_exists?(db_name)
            return error("Database '#{db_name}' does not exist. Run 'azu db:create' first.")
          end

          schema_path = @schema_file || default_schema_file

          unless File.exists?(schema_path)
            return error("Schema file not found: #{schema_path}")
          end

          Logger.info("Loading schema from: #{schema_path}")
          show_database_info

          begin
            case File.extname(schema_path).downcase
            when ".cr"
              load_crystal_schema(schema_path)
            when ".sql"
              load_sql_schema(schema_path)
            else
              return error("Unsupported schema file format. Supported: .cr, .sql")
            end

            Logger.info("✓ Schema loaded successfully")
            success("Schema load completed")
          rescue ex
            error("Schema load failed: #{ex.message}")
          end
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--file", "-f"
              if file = args[index + 1]?
                @schema_file = file
              end
            when "--force"
              @force = true
            when "--env", "-e"
              if env = args[index + 1]?
                @environment = env
              end
            end
          end
        end

        # Get default schema file path
        private def default_schema_file : String
          "./src/db/schema.cr"
        end

        # Load Crystal schema file
        private def load_crystal_schema(schema_path : String)
          Logger.info("Loading Crystal schema file...")

          # For Crystal schema files, we need to execute the schema definition
          # This is more complex and would require loading the schema file
          # and executing the table creation commands

          Logger.warn("Crystal schema loading not fully implemented")
          Logger.info("Consider using 'azu db:migrate' instead")
        end

        # Load SQL schema file
        private def load_sql_schema(schema_path : String)
          Logger.info("Loading SQL schema file...")

          sql_content = File.read(schema_path)

          # Split SQL into individual statements
          statements = sql_content.split(";")
            .map(&.strip)
            .reject(&.empty?)
            .reject { |stmt| stmt.starts_with?("--") }

          Logger.info("Executing #{statements.size} SQL statements...")

          statements.each_with_index do |statement, index|
            next if statement.strip.empty?

            begin
              Logger.debug("Executing statement #{index + 1}/#{statements.size}")
              execute_on_database(statement)
            rescue ex
              Logger.error("Failed to execute statement #{index + 1}: #{ex.message}")
              Logger.error("Statement: #{statement[0, 100]}...")

              unless @force
                raise ex
              end
            end
          end
        end
      end
    end
  end
end
