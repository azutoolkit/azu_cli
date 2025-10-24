module AzuCLI
  module Validators
    # Jinja template validator to detect and report common syntax errors
    class JinjaValidator
      # Validation error with line number and suggestion
      class ValidationError
        getter line : Int32
        getter column : Int32
        getter message : String
        getter suggestion : String?

        def initialize(@line : Int32, @column : Int32, @message : String, @suggestion : String? = nil)
        end

        def to_s : String
          result = "Line #{@line}, Column #{@column}: #{@message}"
          result += "\n  Suggestion: #{@suggestion}" if @suggestion
          result
        end
      end

      # Validation result containing errors and warnings
      class ValidationResult
        getter errors : Array(ValidationError)
        getter warnings : Array(ValidationError)
        getter valid : Bool

        def initialize(@errors : Array(ValidationError) = [] of ValidationError, @warnings : Array(ValidationError) = [] of ValidationError)
          @valid = @errors.empty?
        end

        def add_error(error : ValidationError)
          @errors << error
          @valid = false
        end

        def add_warning(warning : ValidationError)
          @warnings << warning
        end

        def to_s : String
          result = [] of String

          unless @errors.empty?
            result << "Errors:"
            @errors.each { |error| result << "  #{error.to_s}" }
          end

          unless @warnings.empty?
            result << "Warnings:"
            @warnings.each { |warning| result << "  #{warning.to_s}" }
          end

          result.join("\n")
        end
      end

      # Validate a Jinja template string
      def self.validate(template_content : String, filename : String = "template.jinja") : ValidationResult
        result = ValidationResult.new
        lines = template_content.split('\n')

        lines.each_with_index do |line, index|
          line_number = index + 1
          validate_line(line, line_number, result)
        end

        result
      end

      # Validate a Jinja template file
      def self.validate_file(file_path : String) : ValidationResult
        unless File.exists?(file_path)
          result = ValidationResult.new
          result.add_error(ValidationError.new(0, 0, "File not found: #{file_path}"))
          return result
        end

        content = File.read(file_path)
        validate(content, File.basename(file_path))
      end

      # Validate multiple template files
      def self.validate_files(file_paths : Array(String)) : Hash(String, ValidationResult)
        results = {} of String => ValidationResult

        file_paths.each do |file_path|
          results[file_path] = validate_file(file_path)
        end

        results
      end

      private def self.validate_line(line : String, line_number : Int32, result : ValidationResult)
        # Check for invalid ternary operators
        validate_ternary_operators(line, line_number, result)

        # Check for function calls in expressions
        validate_function_calls(line, line_number, result)

        # Check for other common issues
        validate_common_issues(line, line_number, result)
      end

      private def self.validate_ternary_operators(line : String, line_number : Int32, result : ValidationResult)
        # Pattern: {{ variable if condition }}
        if match = line.match(/\{\{\s*([^}]+?)\s+if\s+([^}]+?)\s*\}\}/)
          variable = match[1].strip
          condition = match[2].strip

          suggestion = "Use block conditionals instead: {% if #{condition} %}{{ #{variable} }}{% endif %}"
          result.add_error(ValidationError.new(
            line_number,
            line.index!(match[0]) + 1,
            "Invalid ternary operator syntax: '#{match[0]}'",
            suggestion
          ))
        end

        # Pattern: {{ variable if condition else default }}
        if match = line.match(/\{\{\s*([^}]+?)\s+if\s+([^}]+?)\s+else\s+([^}]+?)\s*\}\}/)
          variable = match[1].strip
          condition = match[2].strip
          default = match[3].strip

          suggestion = "Use block conditionals instead: {% if #{condition} %}{{ #{variable} }}{% else %}{{ #{default} }}{% endif %}"
          result.add_error(ValidationError.new(
            line_number,
            line.index!(match[0]) + 1,
            "Invalid ternary operator with else: '#{match[0]}'",
            suggestion
          ))
        end
      end

      private def self.validate_function_calls(line : String, line_number : Int32, result : ValidationResult)
        # Pattern: {{ function() }}
        if match = line.match(/\{\{\s*(\w+)\(\)\s*\}\}/)
          function_name = match[1]

          suggestion = "Use variable instead: {{ #{function_name} }}"
          result.add_error(ValidationError.new(
            line_number,
            line.index!(match[0]) + 1,
            "Function call in template expression: '#{match[0]}'",
            suggestion
          ))
        end

        # Pattern: {{ function() with parameters }}
        if match = line.match(/\{\{\s*(\w+)\([^)]+\)\s*\}\}/)
          function_name = match[1]

          suggestion = "Function calls are not supported in Jinja expressions. Use variables instead."
          result.add_error(ValidationError.new(
            line_number,
            line.index!(match[0]) + 1,
            "Function call with parameters: '#{match[0]}'",
            suggestion
          ))
        end
      end

      private def self.validate_common_issues(line : String, line_number : Int32, result : ValidationResult)
        # Check for common CSRF token issues
        if line.includes?("csrf_token()")
          suggestion = "Use variable instead: {{ csrf_token }}"
          result.add_warning(ValidationError.new(
            line_number,
            line.index!("csrf_token()") + 1,
            "CSRF token function call detected",
            suggestion
          ))
        end

        # Check for unclosed blocks
        if line.includes?("{% if") && !line.includes?("{% endif %}")
          # This is a warning, not an error, as the block might be closed on another line
          result.add_warning(ValidationError.new(
            line_number,
            line.index!("{% if") + 1,
            "If block opened but not closed on same line",
            "Ensure {% endif %} is present to close the block"
          ))
        end

        # Check for potential issues with complex expressions
        if line.scan(/\{\{.*\{\{/).size > 1
          result.add_warning(ValidationError.new(
            line_number,
            1,
            "Nested template expressions detected",
            "Consider simplifying complex expressions"
          ))
        end
      end

      # Get a summary of validation results
      def self.summary(results : Hash(String, ValidationResult)) : String
        total_files = results.size
        valid_files = results.count { |_, result| result.valid }
        error_count = results.sum { |_, result| result.errors.size }
        warning_count = results.sum { |_, result| result.warnings.size }

        summary = [] of String
        summary << "Jinja Template Validation Summary:"
        summary << "  Files processed: #{total_files}"
        summary << "  Valid files: #{valid_files}"
        summary << "  Files with errors: #{total_files - valid_files}"
        summary << "  Total errors: #{error_count}"
        summary << "  Total warnings: #{warning_count}"

        summary.join("\n")
      end

      # Validate templates in a directory
      def self.validate_directory(directory_path : String, pattern : String = "*.jinja") : Hash(String, ValidationResult)
        unless Dir.exists?(directory_path)
          result = {} of String => ValidationResult
          result[directory_path] = ValidationResult.new
          result[directory_path].add_error(ValidationError.new(0, 0, "Directory not found: #{directory_path}"))
          return result
        end

        template_files = Dir.glob(File.join(directory_path, "**", pattern))
        validate_files(template_files)
      end
    end
  end
end
