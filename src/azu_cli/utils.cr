require "yaml"
require "file_utils"
require "./config"

module AzuCLI
  # Centralized utilities module to eliminate code duplication
  # Provides common functionality used across commands and generators
  module Utils
    extend self

    # ========================================
    # Project Information Utilities
    # ========================================

    # Get project name from shard.yml
    # Returns project name or "app" as fallback
    def project_name : String
      shard_data = parse_shard_yml
      return "app" unless shard_data

      shard_data["name"]?.try(&.as_s) || "app"
    end

    # Get project module name from shard.yml
    # Returns PascalCase module name (e.g., "MyProject")
    def project_module_name : String
      pascal_case(project_name)
    end

    # Get project version from shard.yml
    def project_version : String
      shard_data = parse_shard_yml
      return "0.1.0" unless shard_data

      shard_data["version"]?.try(&.as_s) || "0.1.0"
    end

    # Get project description from shard.yml
    def project_description : String?
      shard_data = parse_shard_yml
      return nil unless shard_data

      shard_data["description"]?.try(&.as_s)
    end

    # Get project authors from shard.yml
    def project_authors : Array(String)
      shard_data = parse_shard_yml
      return [] of String unless shard_data

      authors = shard_data["authors"]?
      return [] of String unless authors

      authors.as_a.map(&.as_s)
    rescue
      [] of String
    end

    # Get binary name from shard.yml targets
    # Used by serve command to determine what to run
    def binary_name : String
      shard_data = parse_shard_yml
      return "server" unless shard_data

      targets = shard_data["targets"]?
      return "server" unless targets && targets.as_h?

      first_target = targets.as_h.keys.first?
      first_target ? first_target.as_s : "server"
    rescue
      "server"
    end

    # Check if current directory is an Azu project
    def azu_project? : Bool
      File.exists?("shard.yml") && File.exists?("src")
    end

    # Check if shard.yml exists
    def has_shard_yml? : Bool
      File.exists?("./shard.yml")
    end

    # Parse shard.yml file
    # Returns YAML::Any or nil if file doesn't exist or is invalid
    private def parse_shard_yml : YAML::Any?
      return nil unless has_shard_yml?

      begin
        content = File.read("./shard.yml")
        YAML.parse(content)
      rescue ex : YAML::ParseException
        Logger.warn("Failed to parse shard.yml: #{ex.message}") if Config.instance.verbose
        nil
      rescue ex : Exception
        Logger.warn("Error reading shard.yml: #{ex.message}") if Config.instance.verbose
        nil
      end
    end

    # ========================================
    # Database Schema Utilities
    # ========================================

    # Detect schema name from database configuration
    # Returns tuple of {schema_name, schema_symbol}
    def detect_schema_info : {String, String}
      schema_file_path = schema_file_path()
      return {"Schema", "Schema"} unless File.exists?(schema_file_path)

      content = File.read(schema_file_path)
      
      # Look for: schema :SchemaName do
      if match = content.match(/schema\s+:(\w+)\s+do/)
        schema_name = match[1]
        return {schema_name, schema_name}
      end

      # Fallback to default
      {"Schema", "Schema"}
    rescue
      {"Schema", "Schema"}
    end

    # Get schema file path
    def schema_file_path : String
      Config.build_path(Config::Paths::DB, "schema.cr")
    end

    # Get schema name from project
    def schema_name : String
      detect_schema_info[0]
    end

    # ========================================
    # String Case Conversion Utilities
    # ========================================

    # Convert string to snake_case
    # "MyClass" => "my_class"
    def snake_case(str : String) : String
      str.gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
        .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
        .tr("-", "_")
        .downcase
    end

    # Convert string to PascalCase
    # "my_class" => "MyClass"
    def pascal_case(str : String) : String
      str.split(/[_\-\s]/)
        .reject(&.empty?)
        .map(&.capitalize)
        .join
    end

    # Convert string to camelCase
    # "my_class" => "myClass"
    def camel_case(str : String) : String
      parts = str.split(/[_\-\s]/).reject(&.empty?)
      return str if parts.empty?

      first = parts[0].downcase
      rest = parts[1..].map(&.capitalize).join
      first + rest
    end

    # Convert string to kebab-case
    # "MyClass" => "my-class"
    def kebab_case(str : String) : String
      snake_case(str).tr("_", "-")
    end

    # Convert string to SCREAMING_SNAKE_CASE
    # "myClass" => "MY_CLASS"
    def screaming_snake_case(str : String) : String
      snake_case(str).upcase
    end

    # Pluralize a word (simple implementation)
    # Handles common cases, may not be perfect for all words
    def pluralize(word : String) : String
      return word if word.empty?

      # Already plural?
      return word if word.ends_with?("s") && !word.ends_with?("ss")

      # Common irregular plurals
      irregular = {
        "person" => "people",
        "child"  => "children",
        "foot"   => "feet",
        "tooth"  => "teeth",
        "goose"  => "geese",
        "mouse"  => "mice",
        "man"    => "men",
        "woman"  => "women",
      }
      return irregular[word.downcase].capitalize if irregular.has_key?(word.downcase)

      # Ending rules
      if word.ends_with?("y") && !word[-2].in?('a', 'e', 'i', 'o', 'u')
        word[0..-2] + "ies"
      elsif word.ends_with?("s") || word.ends_with?("ss") || word.ends_with?("sh") ||
            word.ends_with?("ch") || word.ends_with?("x") || word.ends_with?("z")
        word + "es"
      elsif word.ends_with?("f")
        word[0..-2] + "ves"
      elsif word.ends_with?("fe")
        word[0..-3] + "ves"
      else
        word + "s"
      end
    end

    # Singularize a word (simple implementation)
    def singularize(word : String) : String
      return word if word.empty?

      # Irregular plurals
      irregular = {
        "people"   => "person",
        "children" => "child",
        "feet"     => "foot",
        "teeth"    => "tooth",
        "geese"    => "goose",
        "mice"     => "mouse",
        "men"      => "man",
        "women"    => "woman",
      }
      return irregular[word.downcase].capitalize if irregular.has_key?(word.downcase)

      # Ending rules (reverse of pluralize)
      if word.ends_with?("ies")
        word[0..-4] + "y"
      elsif word.ends_with?("ves")
        word[0..-4] + "f"
      elsif word.ends_with?("ses") || word.ends_with?("shes") || word.ends_with?("ches") ||
            word.ends_with?("xes") || word.ends_with?("zes")
        word[0..-3]
      elsif word.ends_with?("s") && !word.ends_with?("ss")
        word[0..-2]
      else
        word
      end
    end

    # ========================================
    # File and Path Utilities
    # ========================================

    # Ensure directory exists, create if not
    def ensure_directory(path : String)
      Dir.mkdir_p(path) unless Dir.exists?(path)
    end

    # Check if a file is a Crystal source file
    def crystal_file?(path : String) : Bool
      File.file?(path) && path.ends_with?(Config::Extensions::CRYSTAL)
    end

    # Check if a file is a template file
    def template_file?(path : String) : Bool
      File.file?(path) && (
        path.ends_with?(Config::Extensions::JINJA) ||
        path.ends_with?(Config::Extensions::ECR) ||
        path.ends_with?(Config::Extensions::HTML)
      )
    end

    # Get file extension
    def file_extension(path : String) : String
      File.extname(path)
    end

    # Get file basename without extension
    def file_basename(path : String) : String
      File.basename(path, file_extension(path))
    end

    # Safely read file with error handling
    def safe_read_file(path : String) : String?
      return nil unless File.exists?(path)
      File.read(path)
    rescue ex
      Logger.warn("Failed to read file #{path}: #{ex.message}") if Config.instance.verbose
      nil
    end

    # ========================================
    # Input Sanitization Utilities
    # ========================================

    # Sanitize user input for use as Crystal identifier
    # Removes/replaces invalid characters, ensures valid start
    # This is critical for security - prevents code injection
    def sanitize_identifier(name : String) : String
      return "unnamed" if name.empty?

      # Remove any path components (security: prevent path traversal)
      name = File.basename(name)

      # Replace invalid characters with underscore
      sanitized = name.gsub(/[^A-Za-z0-9_]/, "_")

      # Remove leading numbers (Crystal identifiers can't start with number)
      sanitized = sanitized.gsub(/^[0-9]+/, "")

      # Remove leading/trailing underscores
      sanitized = sanitized.gsub(/^_+/, "").gsub(/_+$/, "")

      # Collapse multiple underscores to single
      sanitized = sanitized.gsub(/_+/, "_")

      # If empty after sanitization, use default
      sanitized = "unnamed" if sanitized.empty?

      # If starts with underscore after removing numbers, that's OK
      # But ensure it's not all underscores
      sanitized = "unnamed" if sanitized.chars.all?('_')

      sanitized
    end

    # Sanitize user input for use as file/directory name
    # More restrictive than identifier - prevents path traversal
    # This is CRITICAL for security
    def sanitize_filename(name : String) : String
      return "unnamed" if name.empty?

      # SECURITY: Remove any path components - prevents ../../../ attacks
      name = File.basename(name)

      # SECURITY: Remove any remaining path separators
      name = name.gsub(/[\/\\]/, "_")

      # Remove dangerous characters
      # Keep: letters, numbers, underscore, hyphen, dot
      sanitized = name.gsub(/[^A-Za-z0-9._-]/, "_")

      # Don't allow files starting with dot (hidden files)
      sanitized = sanitized.gsub(/^\.+/, "")

      # Collapse multiple special chars
      sanitized = sanitized.gsub(/[._-]+/, "_")

      # Remove leading/trailing underscores
      sanitized = sanitized.gsub(/^_+/, "").gsub(/_+$/, "")

      # Maximum length for filesystem compatibility
      sanitized = sanitized[0...255] if sanitized.size > 255

      sanitized = "unnamed" if sanitized.empty?
      sanitized
    end

    # Sanitize path - prevents directory traversal attacks
    # CRITICAL for security when dealing with user-provided paths
    def sanitize_path(path : String, base_dir : String = ".") : String?
      return nil if path.empty?

      # Expand to absolute path to catch .. tricks
      begin
        absolute_path = File.expand_path(path, base_dir)
        absolute_base = File.expand_path(base_dir)

        # SECURITY: Ensure path is within base directory
        unless absolute_path.starts_with?(absolute_base)
          Logger.warn("Path traversal attempt blocked: #{path}") if Config.instance.debug_mode
          return nil
        end

        absolute_path
      rescue ex
        Logger.warn("Invalid path: #{path} - #{ex.message}") if Config.instance.debug_mode
        nil
      end
    end

    # Validate and sanitize path component
    # Use this for user-provided directory/file names in paths
    def sanitize_path_component(component : String) : String?
      return nil if component.empty?

      # SECURITY: Reject any path separators
      return nil if component.includes?("/") || component.includes?("\\")

      # SECURITY: Reject relative path components
      return nil if component == "." || component == ".."

      # SECURITY: Reject if it starts with .
      return nil if component.starts_with?(".")

      # Sanitize as filename
      sanitized = sanitize_filename(component)

      # Verify it didn't get mangled too much
      sanitized.empty? ? nil : sanitized
    end

    # ========================================
    # Validation Utilities
    # ========================================

    # Check if string is a valid Crystal identifier
    def valid_identifier?(name : String) : Bool
      return false if name.empty?
      # Must start with letter or underscore
      return false unless name[0].ascii_letter? || name[0] == '_'
      # Rest can be letters, numbers, or underscores
      name.chars.all? { |c| c.ascii_alphanumeric? || c == '_' }
    end

    # Check if string is a reserved Crystal keyword
    def reserved_keyword?(name : String) : Bool
      reserved = %w[
        abstract alias as asm begin break case class def do else elsif end
        ensure enum extend false for fun if include instance_sizeof is_a?
        lib macro module next nil of out pointerof private protected require
        rescue responds_to? return select self sizeof struct super then true
        type typeof union uninitialized unless until verbatim when while with yield
      ]
      reserved.includes?(name.downcase)
    end

    # Validate Crystal class/module name
    def valid_class_name?(name : String) : Bool
      return false if name.empty?
      return false unless name[0].ascii_uppercase?
      valid_identifier?(name)
    end

    # Validate and sanitize user input for use as identifier
    # Returns sanitized name or nil if invalid
    # Use this when you need a guaranteed valid identifier
    def safe_identifier(name : String) : String?
      return nil if name.empty?

      sanitized = sanitize_identifier(name)
      return nil unless valid_identifier?(sanitized)
      return nil if reserved_keyword?(sanitized)

      sanitized
    end

    # ========================================
    # Timestamp Utilities
    # ========================================

    # Generate timestamp for migrations (YYYYMMDDHHmmSS format)
    def generate_timestamp : String
      Time.local.to_s("%Y%m%d%H%M%S")
    end

    # Generate timestamp with microseconds for unique IDs
    def generate_unique_timestamp : String
      now = Time.local
      "#{now.to_s("%Y%m%d%H%M%S")}#{now.nanosecond // 1000}"
    end

    # Parse migration timestamp from filename
    # "20240101120000_create_users.cr" => "20240101120000"
    def parse_migration_timestamp(filename : String) : String?
      match = filename.match(/^(\d{14})_/)
      match ? match[1] : nil
    end

    # ========================================
    # Template Variable Utilities
    # ========================================

    # Build template context hash with common variables
    def build_template_context(
      name : String,
      attributes : Hash(String, String) = {} of String => String,
      options : Hash(String, String) = {} of String => String
    ) : Hash(String, String | Array(String) | Hash(String, String))
      {
        # Name variations
        "name"              => name,
        "snake_case_name"   => snake_case(name),
        "camel_case_name"   => camel_case(name),
        "pascal_case_name"  => pascal_case(name),
        "kebab_case_name"   => kebab_case(name),
        "plural_name"       => pluralize(snake_case(name)),
        "singular_name"     => singularize(snake_case(name)),

        # Project info
        "project_name"        => project_name,
        "project_module_name" => project_module_name,
        "project_version"     => project_version,

        # Timestamps
        "timestamp"       => generate_timestamp,
        "generated_at"    => Time.local.to_s("%Y-%m-%d %H:%M:%S"),

        # Attributes and options
        "attributes" => attributes.to_s,
        "options"    => options.to_s,
      } of String => String | Array(String) | Hash(String, String)
    end

    # ========================================
    # Process Utilities
    # ========================================

    # Run shell command and capture output
    def run_command(command : String, args : Array(String) = [] of String) : {success: Bool, output: String, error: String}
      output = IO::Memory.new
      error = IO::Memory.new
      
      status = Process.run(
        command,
        args,
        output: output,
        error: error
      )

      {
        success: status.success?,
        output:  output.to_s,
        error:   error.to_s,
      }
    rescue ex
      {
        success: false,
        output:  "",
        error:   ex.message || "Command failed",
      }
    end

    # Check if command exists in PATH
    def command_exists?(command : String) : Bool
      Process.run("which", [command], output: Process::Redirect::Close, error: Process::Redirect::Close).success?
    rescue
      false
    end

    # ========================================
    # Dependency Checking
    # ========================================

    # Check if a shard dependency exists in shard.yml
    def has_dependency?(shard_name : String) : Bool
      shard_data = parse_shard_yml
      return false unless shard_data

      dependencies = shard_data["dependencies"]?
      return false unless dependencies

      dependencies.as_h.has_key?(shard_name)
    rescue
      false
    end

    # Get dependency version from shard.yml
    def dependency_version(shard_name : String) : String?
      shard_data = parse_shard_yml
      return nil unless shard_data

      dependencies = shard_data["dependencies"]?
      return nil unless dependencies

      dep = dependencies.as_h[shard_name]?
      return nil unless dep

      # Handle different dependency formats
      if dep.as_h?
        dep["version"]?.try(&.as_s) || dep["branch"]?.try(&.as_s)
      else
        dep.as_s
      end
    rescue
      nil
    end

    # ========================================
    # Color and Formatting Utilities
    # ========================================

    # Wrap text at specified width
    def wrap_text(text : String, width : Int32 = 80) : String
      words = text.split(/\s+/)
      lines = [] of String
      current_line = [] of String
      current_length = 0

      words.each do |word|
        if current_length + word.size + 1 > width
          lines << current_line.join(" ")
          current_line = [word]
          current_length = word.size
        else
          current_line << word
          current_length += word.size + 1
        end
      end

      lines << current_line.join(" ") unless current_line.empty?
      lines.join("\n")
    end

    # Indent text by specified spaces
    def indent(text : String, spaces : Int32 = 2) : String
      prefix = " " * spaces
      text.split("\n").map { |line| "#{prefix}#{line}" }.join("\n")
    end

    # ========================================
    # Comparison and Sorting
    # ========================================

    # Compare semantic versions
    # Returns -1 if v1 < v2, 0 if equal, 1 if v1 > v2
    def compare_versions(v1 : String, v2 : String) : Int32
      parts1 = v1.split(".").map(&.to_i? || 0)
      parts2 = v2.split(".").map(&.to_i? || 0)

      max_length = [parts1.size, parts2.size].max
      parts1 += [0] * (max_length - parts1.size)
      parts2 += [0] * (max_length - parts2.size)

      parts1.zip(parts2).each do |p1, p2|
        return -1 if p1 < p2
        return 1 if p1 > p2
      end

      0
    end
  end
end

