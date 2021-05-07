module AzuCLI
  module Helpers
    CLEAR_TYPE_MAPPING = {
      "varchar":     "String",
      "text":        "String",
      "uuid":        "UUID",
      "boolean":     "Bool",
      "byte":        "Int8",
      "short":       "Int16",
      "int":         "Int32",
      "serial":      "Int32",
      "bigint":      "Int64",
      "bigserial":   "Int64",
      "text[]":      "Array(String)",
      "uuid[]":      "Array(UUID)",
      "boolean[]":   "Array(Bool)",
      "byte[]":      "Array(Int8)",
      "short[]":     "Array(Int16)",
      "int[]":       "Array(Int32)",
      "serial[]":    "Array(Int32)",
      "bigserial[]": "Array(Int64)",
      "bigint[]":    "Array(Int64)",
      "numeric":     "BigDecimal",
      "jsonb":       "JSON::Any",
      "timestamp":   "Time",
      "timestampz":  "Time",
    }

    private def render_initialize(params : Array(String))
      size = params.size - 1
      String.build do |str|
        str << "def initialize("

        params.each_with_index do |param, i|
          field, type = param.split(":")
          str << "@#{field.downcase} : #{type.camelcase}"
          str << ", " if i < size
        end

        str << ")"
      end
    end

    private def render_field(params : Array(String))
      String.build do |str|
        params.each do |param|
          method, field, type = param.split(":")
          str << "#{method.downcase} #{field.downcase} : #{type.camelcase}"
        end
      end
    end

    def not_exists?(path)
      if File.exists? path
        error "File `#{path.underscore}` already exists"
        exit 1
      else
        yield 
      end
    end
  end
end
