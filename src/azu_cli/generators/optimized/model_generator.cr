require "../core/abstract_generator"

module AzuCLI::Generator
  # Optimized Model Generator following SOLID principles
  # Uses configuration-driven approach with Template Method pattern
  class ModelGenerator < Core::AbstractGenerator
    property attributes : Hash(String, String)
    property associations : Hash(String, String)
    property auto_migration : Bool

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @attributes = options.attributes
      @associations = extract_associations(options)
      @auto_migration = options.custom_options["migration"]? != "false"
      super(name, project_name, options.force, options.skip_tests)
    end

    # Concrete implementation of abstract method
    def generator_type : String
      "model"
    end

    # Concrete implementation of abstract method
    def generate_files : Nil
      generate_model_file
      generate_migration_file if @auto_migration
    end

    # Override to add model-specific directory creation
    def create_directories : Nil
      super

      # Create model-specific directories from configuration
      models_dir = config.get("directories.source") || "src/models"
      file_strategy.create_directory(models_dir)

      if @auto_migration
        migrations_dir = config.get("directories.migrations") || "src/db/migrations"
        file_strategy.create_directory(migrations_dir)
      end

      unless skip_tests
        spec_dir = config.get("directories.spec") || "spec/models"
        file_strategy.create_directory(spec_dir)
      end
    end

    # Override to generate model tests
    def generate_tests : Nil
      return if skip_tests

      test_template = config.get("templates.spec") || "model/model_spec.cr.ecr"
      test_path = "spec/models/#{snake_case_name}_spec.cr"

      test_variables = generate_test_variables

      create_file_from_template(
        test_template,
        test_path,
        test_variables,
        "model test"
      )
    end

    # Generate the main model file
    private def generate_model_file : Nil
      template = config.get("templates.main") || "model/model.cr.ecr"
      output_path = "src/models/#{snake_case_name}.cr"

      model_variables = generate_model_variables

      create_file_from_template(
        template,
        output_path,
        model_variables,
        "model"
      )
    end

    # Generate migration file if auto_migration is enabled
    private def generate_migration_file : Nil
      return unless @auto_migration

      timestamp = Time.utc.to_s("%Y%m%d%H%M%S")
      table_name = plural_name
      filename = "#{timestamp}_create_#{table_name}_table.cr"
      output_path = File.join("src/db/migrations", filename)

      migration_variables = generate_migration_variables(timestamp.to_i64, table_name)

      create_file_from_template(
        "migration/migration.cr.ecr",
        output_path,
        migration_variables,
        "migration"
      )
    end

    # Generate template variables specific to models
    private def generate_model_variables : Hash(String, String)
      default_template_variables.merge({
        "base_class"        => config.get("cql.base_class") || "CQL::Model",
        "table_name"        => generate_table_name,
        "attributes_list"   => generate_attributes_list,
        "validations_list"  => generate_validations_list,
        "associations_list" => generate_associations_list,
        "methods_list"      => generate_methods_list,
        "timestamps"        => generate_timestamps,
      })
    end

    # Generate migration-specific template variables
    private def generate_migration_variables(version : Int64, table_name : String) : Hash(String, String)
      default_template_variables.merge({
        "version"        => version.to_s,
        "table_name"     => table_name,
        "columns_list"   => generate_migration_columns,
        "indexes_list"   => generate_migration_indexes,
        "timestamps"     => config.get("cql.timestamps.enabled") == "true" ? "timestamps" : "",
      })
    end

    # Generate test-specific template variables
    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "test_attributes"    => generate_test_attributes,
        "validation_tests"   => generate_validation_tests,
        "association_tests"  => generate_association_tests,
        "factory_attributes" => generate_factory_attributes,
      })
    end

    # Extract associations from options
    private def extract_associations(options : Core::GeneratorOptions) : Hash(String, String)
      associations = {} of String => String

      options.additional_args.each do |arg|
        if arg.includes?("belongs_to:") || arg.includes?("has_many:") || arg.includes?("has_one:")
          parts = arg.split(":", 2)
          if parts.size == 2
            associations[parts[0]] = parts[1]
          end
        end
      end

      # Auto-detect foreign key associations from attributes
      attributes.each do |attr_name, attr_type|
        if attr_name.ends_with?("_id") && attr_type.downcase.includes?("int")
          association_name = attr_name.gsub(/_id$/, "")
          associations["belongs_to"] = association_name unless associations.has_key?("belongs_to")
        end
      end

      associations
    end

    # Generate table name based on configuration
    private def generate_table_name : String
      naming_convention = config.get("cql.table_naming") || "snake_case_plural"

      case naming_convention
      when "snake_case_plural"
        plural_name
      when "snake_case"
        snake_case_name
      else
        plural_name
      end
    end

    # Generate model attributes list
    private def generate_attributes_list : String
      return "" if attributes.empty?

      lines = [] of String

      attributes.each do |attr_name, attr_type|
        crystal_type_name = get_crystal_type(attr_type)
        db_type = get_db_type(attr_type)

        lines << "  column :#{attr_name}, #{crystal_type_name}"
      end

      lines.join("\n")
    end

    # Generate validations list
    private def generate_validations_list : String
      lines = [] of String

      # Add default validations based on attribute types
      attributes.each do |attr_name, attr_type|
        validations = get_default_validations(attr_name, attr_type)
        validations.each do |validation|
          lines << "  #{validation}"
        end
      end

      lines.join("\n")
    end

    # Generate associations list
    private def generate_associations_list : String
      return "" if associations.empty?

      lines = [] of String

      associations.each do |association_type, association_name|
        case association_type
        when "belongs_to"
          foreign_key = "#{association_name}_id"
          lines << "  belongs_to :#{association_name}, foreign_key: :#{foreign_key}"
        when "has_many"
          foreign_key = "#{snake_case_name}_id"
          lines << "  has_many :#{association_name}, foreign_key: :#{foreign_key}"
        when "has_one"
          foreign_key = "#{snake_case_name}_id"
          lines << "  has_one :#{association_name}, foreign_key: :#{foreign_key}"
        end
      end

      lines.join("\n")
    end

    # Generate default model methods
    private def generate_methods_list : String
      default_methods = config.get_array("default_methods")

      lines = [] of String
      default_methods.each do |method|
        case method
        when "to_s(io : IO) : Nil"
          lines << generate_to_s_method
        when "to_h : Hash(String, String | Int32 | Int64 | Float64 | Bool | Time | Nil)"
          lines << generate_to_h_method
        end
      end

      lines.join("\n\n")
    end

    # Generate timestamps if enabled
    private def generate_timestamps : String
      if config.get("cql.timestamps.enabled") == "true"
        "  timestamps"
      else
        ""
      end
    end

    # Generate migration columns
    private def generate_migration_columns : String
      return "" if attributes.empty?

      lines = [] of String

      attributes.each do |attr_name, attr_type|
        db_type = get_db_type(attr_type)
        crystal_type_name = get_crystal_type(attr_type)

        lines << "    column :#{attr_name}, #{crystal_type_name}"
      end

      lines.join("\n")
    end

    # Generate migration indexes
    private def generate_migration_indexes : String
      lines = [] of String

      # Auto-generate indexes for foreign keys
      attributes.each do |attr_name, attr_type|
        if attr_name.ends_with?("_id") && attr_type.downcase.includes?("int")
          lines << "    index :#{attr_name}"
        end
      end

      # Add unique indexes for email fields
      if attributes.has_key?("email")
        lines << "    index :email, unique: true"
      end

      lines.join("\n")
    end

    # Get Crystal type from attribute type
    private def get_crystal_type(attr_type : String) : String
      config.get("crystal_types.#{attr_type.downcase}") ||
      config.get("attribute_types.#{attr_type.downcase}.crystal_type") ||
      "String"
    end

    # Get database type from attribute type
    private def get_db_type(attr_type : String) : String
      config.get("attribute_types.#{attr_type.downcase}.db_type") || "VARCHAR(255)"
    end

    # Get default validations for attribute
    private def get_default_validations(attr_name : String, attr_type : String) : Array(String)
      validations = [] of String

      # Check for field-specific validations
      if field_validations = config.get_array("default_validations.#{attr_name}")
        field_validations.each do |validation|
          validations << "validate :#{attr_name}, #{validation}"
        end
      end

      # Check for type-specific validations
      if type_validation = config.get("attribute_types.#{attr_type.downcase}.validation")
        validations << "validate :#{attr_name}, #{type_validation}: true"
      end

      validations
    end

    # Generate to_s method
    private def generate_to_s_method : String
      primary_field = attributes.keys.first? || "id"

      <<-CRYSTAL
      def to_s(io : IO) : Nil
        io << "#<#{class_name}:#{object_id} @#{primary_field}=#{@#{primary_field}}>"
      end
      CRYSTAL
    end

    # Generate to_h method
    private def generate_to_h_method : String
      if attributes.empty?
        <<-CRYSTAL
        def to_h : Hash(String, String | Int32 | Int64 | Float64 | Bool | Time | Nil)
          {
            "id" => @id,
            "created_at" => @created_at,
            "updated_at" => @updated_at,
          }
        end
        CRYSTAL
      else
        attribute_mappings = attributes.keys.map { |attr| "\"#{attr}\" => @#{attr}" }

        <<-CRYSTAL
        def to_h : Hash(String, String | Int32 | Int64 | Float64 | Bool | Time | Nil)
          {
            "id" => @id,
            #{attribute_mappings.join(",\n            ")},
            "created_at" => @created_at,
            "updated_at" => @updated_at,
          }
        end
        CRYSTAL
      end
    end

    # Generate test attributes
    private def generate_test_attributes : String
      return "" if attributes.empty?

      test_values = attributes.map do |attr_name, attr_type|
        value = case get_crystal_type(attr_type).gsub("?", "")
                when "String"
                  "\"test_#{attr_name}\""
                when "Int32"
                  "42"
                when "Int64"
                  "42_i64"
                when "Float64"
                  "3.14"
                when "Bool"
                  "true"
                when "Time"
                  "Time.utc"
                else
                  "\"test_#{attr_name}\""
                end
        "#{attr_name}: #{value}"
      end.join(", ")

      "let(#{snake_case_name}_attributes) { {#{test_values}} }"
    end

    # Generate validation tests
    private def generate_validation_tests : String
      return "" if attributes.empty?

      lines = [] of String

      attributes.each do |attr_name, attr_type|
        validations = get_default_validations(attr_name, attr_type)
        unless validations.empty?
          lines << <<-CRYSTAL
          it "validates #{attr_name}" do
            #{snake_case_name} = #{class_name}.new(#{snake_case_name}_attributes)
            #{snake_case_name}.#{attr_name} = nil
            #{snake_case_name}.valid?.should be_false
          end
          CRYSTAL
        end
      end

      lines.join("\n\n")
    end

    # Generate association tests
    private def generate_association_tests : String
      return "" if associations.empty?

      lines = [] of String

      associations.each do |association_type, association_name|
        lines << <<-CRYSTAL
        it "has #{association_type} association with #{association_name}" do
          #{snake_case_name} = #{class_name}.new(#{snake_case_name}_attributes)
          #{snake_case_name}.should respond_to(:#{association_name})
        end
        CRYSTAL
      end

      lines.join("\n\n")
    end

    # Generate factory attributes
    private def generate_factory_attributes : String
      return "" if attributes.empty?

      factory_values = attributes.map do |attr_name, attr_type|
        value = case get_crystal_type(attr_type).gsub("?", "")
                when "String"
                  "\"Factory #{attr_name}\""
                when "Int32"
                  "sequence(:#{attr_name}) { |n| n }"
                when "Int64"
                  "sequence(:#{attr_name}) { |n| n.to_i64 }"
                when "Float64"
                  "sequence(:#{attr_name}) { |n| n.to_f }"
                when "Bool"
                  "false"
                when "Time"
                  "Time.utc"
                else
                  "\"Factory #{attr_name}\""
                end
        "    #{attr_name} #{value}"
      end.join("\n")

      <<-CRYSTAL
      factory :#{snake_case_name} do
      #{factory_values}
      end
      CRYSTAL
    end

    # Override success message to include model-specific information
    def success_message : String
      base_message = super
      features = [] of String
      features << "#{attributes.size} attribute(s)" unless attributes.empty?
      features << "#{associations.size} association(s)" unless associations.empty?
      features << "auto-migration" if @auto_migration

      feature_text = features.empty? ? "" : " with #{features.join(", ")}"
      "#{base_message}#{feature_text}"
    end

    # Override to show model-specific next steps
    def post_generation_tasks : Nil
      super
      show_model_usage_info
    end

    # Show model usage information
    private def show_model_usage_info
      puts
      puts "📊 Model Usage:".colorize(:yellow).bold
      puts "  1. Run migration: azu db:migrate" if @auto_migration
      puts "  2. Add validations and associations as needed"
      puts "  3. Use in your services and endpoints:"
      puts "     #{class_name}.create!(#{generate_example_attributes})"
      puts "     #{class_name}.find!(id)"
      puts "     #{class_name}.where(attribute: value)"
      puts
      puts "📚 Learn more: https://github.com/azutoolkit/cql".colorize(:cyan)
    end

    # Generate example attributes for usage
    private def generate_example_attributes : String
      return "name: \"Example\"" if attributes.empty?

      example_values = attributes.first(3).map do |attr_name, attr_type|
        value = case get_crystal_type(attr_type).gsub("?", "")
                when "String"
                  "\"Example #{attr_name.capitalize}\""
                when "Int32", "Int64"
                  "1"
                when "Float64"
                  "1.0"
                when "Bool"
                  "true"
                else
                  "\"Example\""
                end
        "#{attr_name}: #{value}"
      end.join(", ")

      example_values
    end
  end
end
