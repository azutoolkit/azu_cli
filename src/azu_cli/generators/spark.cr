require "./resource"
require "./navigation"

module AzuCLI
  module Generate
    # Shared wiring is emitted once, including during a preview's shadow run.
    module SparkWiring
      INITIALIZER = "src/initializers/spark.cr"

      def self.install(root : String) : Nil
        path = File.join(root, INITIALIZER)
        unless File.exists?(path)
          Dir.mkdir_p(File.dirname(path))
          File.write(path, "# Spark serves its client locally and verifies SPARK_SECRET in production.\nAzu::Spark.install\n")
        end
        env = File.join(root, ".env")
        if File.symlink?(env)
          Logger.warn("#{env} is a symlink; set SPARK_SECRET in your environment")
          return
        end
        content = File.exists?(env) ? File.read(env) : ""
        return if content.matches?(/^\s*(?:export\s+)?SPARK_SECRET\s*=/m)
        separator = content.empty? || content.ends_with?('\n') ? "" : "\n"
        File.write(env, "#{content}#{separator}SPARK_SECRET=#{Random::Secure.hex(32)}\n", perm: 0o600)
        File.chmod(env, 0o600)
      end
    end

    class Spark < Resource
      directory "#{__DIR__}/../templates/spark_component"
      OUTPUT_DIR = "."
      TYPES      = %w(string text email url int32 integer int64 float32 float64 float bool boolean)
      RESERVED   = %w(id socket render mount unmount assigns handle_event handle_info initialize errors_on reset)

      getter demo_page : Bool

      def initialize(name : String, attributes = {} of String => String, @demo_page = false)
        super(name, "index", attributes.empty? ? {"count" => "int32"} : attributes)
      end

      def class_name : String
        "#{model_name}Spark"
      end

      def self.attributes_error(attributes : Hash(String, String), component : Bool = false) : String?
        attributes.each do |name, type|
          if error = Field.name_error(name)
            return error
          end
          field = Field.new(name, type)
          unless TYPES.includes?(field.kind) && !field.nilable? && field.modifiers.empty?
            return "Spark generators support required scalar fields: #{TYPES.join(", ")}. Use a standard scaffold for nullable fields, associations, dates, JSON or column modifiers."
          end
          if component && (RESERVED.includes?(name) || name.starts_with?("__spark_") || name.starts_with?("increment_") || name.starts_with?("change_"))
            return "Spark property '#{name}' is reserved; choose another name."
          end
        end
        nil
      end

      def default_value(field : Field) : String
        case field.crystal_type
        when "String"  then %("")
        when "Bool"    then "false"
        when "Int64"   then "0_i64"
        when "Float32" then "0_f32"
        when "Float64" then "0_f64"
        else                "0"
        end
      end

      def rendered_file_entries
        file_entries.select do |entry|
          @demo_page || entry.path.starts_with?("src/components/") || entry.path.starts_with?("spec/")
        end
      end

      def render(out_dir : String, force : Bool = false, interactive : Bool = false, list : Bool = false, color : Bool = false)
        super
        SparkWiring.install(out_dir)
        Navigation.register(out_dir, "#{model_name} demo", "/#{resource_plural}/live") if @demo_page
      end
    end

    class SparkScaffold < Resource
      directory "#{__DIR__}/../templates/spark_scaffold"
      OUTPUT_DIR = "."

      def rendered_file_entries
        file_entries
      end

      def render(out_dir : String, force : Bool = false, interactive : Bool = false, list : Bool = false, color : Bool = false)
        super
        SparkWiring.install(out_dir)
        Navigation.register(out_dir, resource_plural.split('_').map(&.capitalize).join(' '), "/#{resource_plural}")
      end
    end
  end
end
