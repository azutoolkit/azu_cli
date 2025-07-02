require "yaml"

module AzuCLI::Generator::Core
  # Configuration loader following SOLID principles
  class Configuration
    property data : Hash(String, YAML::Any)

    def initialize(@type : String, @config_path : String = "src/azu_cli/generators/config")
      @data = {} of String => YAML::Any
    end

    # Template method pattern - defines the algorithm structure
    def load! : self
      base_config = load_base_config
      type_config = load_type_config

      @data = merge_configurations(base_config, type_config)
      self
    end

    # Single responsibility - loads base configuration
    private def load_base_config : Hash(String, YAML::Any)
      base_file = File.join(@config_path, "base.yml")
      yaml_to_hash(load_yaml_file(base_file))
    end

    # Single responsibility - loads type-specific configuration
    private def load_type_config : Hash(String, YAML::Any)
      type_file = File.join(@config_path, "#{@type}.yml")

      if File.exists?(type_file)
        config = load_yaml_file(type_file)
        yaml_to_hash(resolve_inheritance(config))
      else
        {} of String => YAML::Any
      end
    end

    # Resolves 'extends' directive for configuration inheritance
    private def resolve_inheritance(config : YAML::Any) : YAML::Any
      if config.as_h? && config["extends"]? && config["extends"].as_s?
        extends = config["extends"].as_s
        parent_config = load_parent_config(extends)
        merge_yaml_configs(parent_config, config)
      else
        config
      end
    end

    # Loads parent configuration for inheritance
    private def load_parent_config(extends : String) : YAML::Any
      parent_file = File.join(@config_path, extends)
      load_yaml_file(parent_file)
    end

    # Deep merges two YAML configurations
    private def merge_yaml_configs(base : YAML::Any, override : YAML::Any) : YAML::Any
      return override unless base.as_h?
      return base unless override.as_h?

      merged = {} of YAML::Any => YAML::Any
      base.as_h.each { |k, v| merged[k] = v }

      override.as_h.each do |key, value|
        if merged.has_key?(key) && merged[key].as_h? && value.as_h?
          merged[key] = merge_yaml_configs(merged[key], value)
        else
          merged[key] = value
        end
      end

      YAML::Any.new(merged)
    end

    # Merges two hash configurations
    private def merge_configurations(base : Hash(String, YAML::Any), override : Hash(String, YAML::Any)) : Hash(String, YAML::Any)
      result = {} of String => YAML::Any
      base.each { |k, v| result[k] = v }
      override.each { |k, v| result[k] = v }
      result
    end

    # Converts YAML::Any to Hash
    private def yaml_to_hash(yaml : YAML::Any) : Hash(String, YAML::Any)
      result = {} of String => YAML::Any
      if hash = yaml.as_h?
        hash.each do |k, v|
          result[k.as_s] = v
        end
      end
      result
    end

    # Loads and parses YAML file with error handling
    private def load_yaml_file(file_path : String) : YAML::Any
      unless File.exists?(file_path)
        raise ArgumentError.new("Configuration file not found: #{file_path}")
      end

      content = File.read(file_path)
      YAML.parse(content)
    rescue ex : YAML::ParseException
      raise ArgumentError.new("Invalid YAML in #{file_path}: #{ex.message}")
    end

    # Convenience methods for accessing configuration values
    def get(key : String, default : String? = nil) : String?
      if value = get_nested(key)
        value.as_s?
      else
        default
      end
    end

    def get_array(key : String) : Array(String)
      if value = get_nested(key)
        if array = value.as_a?
          array.map(&.as_s)
        else
          [] of String
        end
      else
        [] of String
      end
    end

    def get_hash(key : String) : Hash(String, String)
      result = {} of String => String
      if value = get_nested(key)
        if hash = value.as_h?
          hash.each do |k, v|
            result[k.as_s] = v.as_s
          end
        end
      end
      result
    end

    # Supports nested key access like "validation_types.email.pattern"
    def get_nested(key : String) : YAML::Any?
      keys = key.split(".")
      current_key = keys.first

      return nil unless @data.has_key?(current_key)
      current = @data[current_key]

      keys[1..].each do |k|
        if current.as_h? && current.as_h.has_key?(k)
          current = current[k]
        else
          return nil
        end
      end

      current
    end

    # Factory method for creating loaded configurations
    def self.load(type : String, config_path : String = "src/azu_cli/generators/config") : Configuration
      new(type, config_path).load!
    end
  end
end
