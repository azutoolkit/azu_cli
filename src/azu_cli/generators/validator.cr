require "teeplate"

module AzuCLI
  module Generate
    # Validator generator that creates Azu::Validator classes
    class Validator < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/validators"
      OUTPUT_DIR = "./src/validators"

      property name : String
      property record_type : String
      property validation_rules : Array(String)
      property snake_case_name : String

      def initialize(@name : String, @record_type : String = "User", @validation_rules : Array(String) = [] of String)
        @snake_case_name = @name.underscore
      end

      # Convert name to validator class name
      def class_name : String
        @name.camelcase + "Validator"
      end

      # Get validation rules as comments
      def validation_rules_comments : String
        return "# Custom logic here" if @validation_rules.empty?

        comments = [] of String
        @validation_rules.each do |rule|
          comments << "# #{rule}"
        end

        comments.join("\n    ")
      end

      # Get validation logic based on rules
      def validation_logic : String
        return "# Custom logic here" if @validation_rules.empty?

        logic = [] of String
        @validation_rules.each do |rule|
          case rule.downcase
          when "email"
            logic << "if @record.email? && !@record.email!.includes?(\"@\")\n      errors << Schema::Error.new(\"email\", \"Invalid email format\")\n    end"
          when "presence"
            logic << "if @record.name?.try(&.empty?)\n      errors << Schema::Error.new(\"name\", \"Name is required\")\n    end"
          when "length"
            logic << "if @record.name? && @record.name!.size < 2\n      errors << Schema::Error.new(\"name\", \"Name must be at least 2 characters\")\n    end"
          when "uniqueness"
            logic << "if User.where(name: @record.name).exists?\n      errors << Schema::Error.new(\"name\", \"Name must be unique\")\n    end"
          when "format"
            logic << "if @record.email? && !@record.email!.match(/^[\\w\\-\\.]+@[\\w\\-\\.]+\\.[a-zA-Z]{2,}$/)\n      errors << Schema::Error.new(\"email\", \"Invalid email format\")\n    end"
          when "range"
            logic << "if @record.age? && (@record.age! < 0 || @record.age! > 150)\n      errors << Schema::Error.new(\"age\", \"Age must be between 0 and 150\")\n    end"
          else
            logic << "# Custom validation for #{rule}"
          end
        end

        logic.join("\n    ")
      end

      # Check if validator has validation rules
      def has_validation_rules? : Bool
        !@validation_rules.empty?
      end

      # Get common validation patterns
      def common_validations : String
        <<-COMMON_VALIDATIONS
        # Common validation patterns:
        #
        # Presence validation:
        # if @record.field?.try(&.empty?)
        #   errors << Schema::Error.new("field", "Field is required")
        # end
        #
        # Format validation:
        # if @record.email? && !@record.email!.match(/^[\\w\\-\\.]+@[\\w\\-\\.]+\\.[a-zA-Z]{2,}$/)
        #   errors << Schema::Error.new("email", "Invalid email format")
        # end
        #
        # Length validation:
        # if @record.name? && @record.name!.size < 2
        #   errors << Schema::Error.new("name", "Name must be at least 2 characters")
        # end
        #
        # Uniqueness validation:
        # if #{@record_type}.where(field: @record.field).exists?
        #   errors << Schema::Error.new("field", "Field must be unique")
        # end
        #
        # Range validation:
        # if @record.age? && (@record.age! < 0 || @record.age! > 150)
        #   errors << Schema::Error.new("age", "Age must be between 0 and 150")
        # end
        COMMON_VALIDATIONS
      end
    end
  end
end
