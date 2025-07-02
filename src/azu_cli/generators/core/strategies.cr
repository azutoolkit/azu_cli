module AzuCLI::Generator::Core
  # Strategy pattern interfaces for different generation approaches

  # Template rendering strategy interface
  abstract class TemplateStrategy
    abstract def render(template_path : String, variables : Hash(String, String)) : String
    abstract def supports?(template_type : String) : Bool
  end

  # ECR template strategy implementation
  class EcrTemplateStrategy < TemplateStrategy
    def render(template_path : String, variables : Hash(String, String)) : String
      unless File.exists?(template_path)
        raise ArgumentError.new("Template not found: #{template_path}")
      end

      content = File.read(template_path)

      # Replace template variables
      variables.each do |key, value|
        content = content.gsub("{{#{key}}}", value)
      end

      content
    end

    def supports?(template_type : String) : Bool
      template_type == "ecr" || template_type.ends_with?(".ecr")
    end
  end

  # File creation strategy interface
  abstract class FileCreationStrategy
    abstract def create_file(path : String, content : String, options : Hash(String, String)) : Bool
    abstract def create_directory(path : String) : Bool
  end

  # Standard file creation strategy
  class StandardFileCreationStrategy < FileCreationStrategy
    def initialize(@force : Bool = false, @verbose : Bool = true)
    end

    def create_file(path : String, content : String, options : Hash(String, String) = {} of String => String) : Bool
      if File.exists?(path) && !@force
        puts "  ⚠️  File exists: #{path} (use --force to overwrite)".colorize(:yellow) if @verbose
        return false
      end

      create_directory(File.dirname(path))
      File.write(path, content)

      description = options["description"]? || ""
      desc_text = description.empty? ? "" : " (#{description})"
      puts "  ✅ Created: #{path}#{desc_text}".colorize(:green) if @verbose
      true
    end

    def create_directory(path : String) : Bool
      unless Dir.exists?(path)
        puts "  📁 Creating directory: #{path}".colorize(:blue) if @verbose
        Dir.mkdir_p(path)
        true
      else
        false
      end
    end
  end

  # Validation strategy interface
  abstract class ValidationStrategy
    abstract def validate(name : String, options : Hash(String, String)) : Array(String)
  end

  # Standard validation strategy
  class StandardValidationStrategy < ValidationStrategy
    def initialize(@config : Configuration)
    end

    def validate(name : String, options : Hash(String, String) = {} of String => String) : Array(String)
      errors = [] of String

      # Name validation
      name_pattern = @config.get("validations.name.pattern")
      if name_pattern && !Regex.new(name_pattern).matches?(name)
        message = @config.get("validations.name.message") || "Invalid name format"
        errors << message
      end

      # Additional validations can be added here based on configuration
      errors
    end
  end

  # Naming strategy interface
  abstract class NamingStrategy
    abstract def class_name(name : String) : String
    abstract def snake_case_name(name : String) : String
    abstract def kebab_case_name(name : String) : String
    abstract def plural_name(name : String) : String
    abstract def module_name(project_name : String) : String
  end

  # Standard naming strategy using Cadmium inflector
  class StandardNamingStrategy < NamingStrategy
    def class_name(name : String) : String
      classify(name)
    end

    def snake_case_name(name : String) : String
      underscore(name)
    end

    def kebab_case_name(name : String) : String
      snake_case_name(name).gsub("_", "-")
    end

    def plural_name(name : String) : String
      pluralize(snake_case_name(name))
    end

    def module_name(project_name : String) : String
      classify(project_name)
    end

    # String inflection helpers
    private def classify(str : String) : String
      str.split(/[-_\s]/).map(&.capitalize).join
    end

    private def underscore(str : String) : String
      str.gsub(/::/, '/')
        .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
        .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
        .downcase
    end

    private def pluralize(str : String) : String
      # Simple pluralization rules
      case str
      when /s$/, /sh$/, /ch$/, /x$/, /z$/
        str + "es"
      when /[^aeiou]y$/
        str[0..-2] + "ies"
      when /f$/
        str[0..-2] + "ves"
      when /fe$/
        str[0..-3] + "ves"
      else
        str + "s"
      end
    end
  end
end
