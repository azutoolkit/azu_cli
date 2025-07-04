require "teeplate"

module AzuCLI
  module Generate
    # Component generator that creates Azu::Component classes
    class Component < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/components"
      OUTPUT_DIR = "./src/components"

      property name : String
      property properties : Hash(String, String)
      property events : Array(String)
      property snake_case_name : String

      def initialize(@name : String, @properties : Hash(String, String) = {} of String => String, @events : Array(String) = [] of String)
        @snake_case_name = @name.underscore
      end

      # Convert name to component class name
      def class_name : String
        @name.camelcase + "Component"
      end

      # Get property declarations
      def property_declarations : String
        properties = [] of String

        @properties.each do |name, type|
          crystal_type = crystal_type(type)
          if has_default_value?(type)
            default_value = default_value(type)
            properties << "property #{name} : #{crystal_type} = #{default_value}"
          else
            properties << "property #{name} : #{crystal_type}"
          end
        end

        properties.join("\n  ")
      end

      # Get constructor parameters
      def constructor_params : String
        params = [] of String

        @properties.each do |name, type|
          crystal_type = crystal_type(type)
          params << "@#{name} : #{crystal_type}"
        end

        params.join(", ")
      end

      # Get Crystal type for property
      def crystal_type(prop_type : String) : String
        case prop_type.downcase
        when "string", "text"
          "String"
        when "int32", "integer"
          "Int32"
        when "int64"
          "Int64"
        when "float32"
          "Float32"
        when "float64", "float"
          "Float64"
        when "bool", "boolean"
          "Bool"
        when "time", "datetime"
          "Time"
        when "date"
          "Date"
        when "array"
          "Array(String)"
        when "hash"
          "Hash(String, String)"
        when "json"
          "JSON::Any"
        else
          "String"
        end
      end

      # Check if type has a default value
      def has_default_value?(prop_type : String) : Bool
        case prop_type.downcase
        when "array"
          true
        when "hash"
          true
        when "int32", "integer"
          true
        when "bool", "boolean"
          true
        else
          false
        end
      end

      # Get default value for property type
      def default_value(prop_type : String) : String
        case prop_type.downcase
        when "array"
          "[] of String"
        when "hash"
          "{} of String => String"
        when "int32", "integer"
          "0"
        when "bool", "boolean"
          "false"
        else
          "\"\""
        end
      end

      # Get event handling method
      def event_handling_method : String
        return "" if @events.empty?

        event_cases = [] of String
        @events.each do |event|
          event_cases << "when \"#{event}\"\n      # Handle #{event} event\n      # Add your logic here"
        end

        <<-EVENT_METHOD
  def on_event(name, data)
    case name
#{event_cases.join("\n    ")}
    end
  end
EVENT_METHOD
      end

      # Check if component has events
      def has_events? : Bool
        !@events.empty?
      end

      # Check if component has properties
      def has_properties? : Bool
        !@properties.empty?
      end
    end
  end
end
