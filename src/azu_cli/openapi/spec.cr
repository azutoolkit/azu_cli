require "yaml"
require "json"

module AzuCLI
  module OpenAPI
    # OpenAPI 3.1 Specification data structures
    class Spec
      include JSON::Serializable
      include YAML::Serializable

      property openapi : String
      property info : Info
      property servers : Array(Server)?
      property paths : Hash(String, PathItem)?
      property components : Components?
      property security : Array(Hash(String, Array(String)))?
      property tags : Array(Tag)?

      def initialize(@openapi = "3.1.0", @info = Info.new, @paths = nil, @components = nil)
      end
    end

    class Info
      include JSON::Serializable
      include YAML::Serializable

      property title : String
      property description : String?
      property version : String
      property contact : Contact?
      property license : License?

      def initialize(@title = "API", @version = "1.0.0")
      end
    end

    class Contact
      include JSON::Serializable
      include YAML::Serializable

      property name : String?
      property email : String?
      property url : String?
    end

    class License
      include JSON::Serializable
      include YAML::Serializable

      property name : String
      property url : String?
    end

    class Server
      include JSON::Serializable
      include YAML::Serializable

      property url : String
      property description : String?

      def initialize(@url : String, @description : String? = nil)
      end
    end

    class PathItem
      include JSON::Serializable
      include YAML::Serializable

      property get : Operation?
      property post : Operation?
      property put : Operation?
      property patch : Operation?
      property delete : Operation?
      property options : Operation?
      property head : Operation?
      property trace : Operation?
      property parameters : Array(Parameter)?

      @[JSON::Field(key: "$ref")]
      @[YAML::Field(key: "$ref")]
      property ref : String?

      def initialize
      end
    end

    class Operation
      include JSON::Serializable
      include YAML::Serializable

      property summary : String?
      property description : String?
      property operationId : String?
      property tags : Array(String)?
      property parameters : Array(Parameter)?
      property requestBody : RequestBody?
      property responses : Hash(String, Response)?
      property security : Array(Hash(String, Array(String)))?
      property deprecated : Bool?

      def initialize
        @responses = {} of String => Response
      end
    end

    class Parameter
      include JSON::Serializable
      include YAML::Serializable

      property name : String
      property in : String # "query", "header", "path", "cookie"
      property description : String?
      property required : Bool?
      property schema : Schema?
      property deprecated : Bool?

      @[JSON::Field(key: "$ref")]
      @[YAML::Field(key: "$ref")]
      property ref : String?
    end

    class RequestBody
      include JSON::Serializable
      include YAML::Serializable

      property description : String?
      property content : Hash(String, MediaType)?
      property required : Bool?

      @[JSON::Field(key: "$ref")]
      @[YAML::Field(key: "$ref")]
      property ref : String?

      def initialize
      end
    end

    class Response
      include JSON::Serializable
      include YAML::Serializable

      property description : String
      property content : Hash(String, MediaType)?
      property headers : Hash(String, Header)?

      @[JSON::Field(key: "$ref")]
      @[YAML::Field(key: "$ref")]
      property ref : String?

      def initialize(@description = "Success")
      end
    end

    class MediaType
      include JSON::Serializable
      include YAML::Serializable

      property schema : Schema?
      property example : String?
      property examples : Hash(String, Example)?

      def initialize
      end
    end

    class Header
      include JSON::Serializable
      include YAML::Serializable

      property description : String?
      property schema : Schema?
    end

    class Example
      include JSON::Serializable
      include YAML::Serializable

      property summary : String?
      property description : String?
      property value : String?
    end

    class Schema
      include JSON::Serializable
      include YAML::Serializable

      property type : String?
      property format : String?
      property description : String?
      property nullable : Bool?
      property enum : Array(String)?
      property default : String?

      # Object properties
      property properties : Hash(String, Schema)?
      property required : Array(String)?
      property additionalProperties : Bool | Schema?

      # Array properties
      property items : Schema?
      property minItems : Int32?
      property maxItems : Int32?

      # String properties
      property minLength : Int32?
      property maxLength : Int32?
      property pattern : String?

      # Numeric properties
      property minimum : Float64?
      property maximum : Float64?
      property multipleOf : Float64?

      # Composition
      property allOf : Array(Schema)?
      property oneOf : Array(Schema)?
      property anyOf : Array(Schema)?
      property not : Schema?

      @[JSON::Field(key: "$ref")]
      @[YAML::Field(key: "$ref")]
      property ref : String?

      def initialize
      end
    end

    class Components
      include JSON::Serializable
      include YAML::Serializable

      property schemas : Hash(String, Schema)?
      property responses : Hash(String, Response)?
      property parameters : Hash(String, Parameter)?
      property requestBodies : Hash(String, RequestBody)?
      property securitySchemes : Hash(String, SecurityScheme)?

      def initialize
      end
    end

    class SecurityScheme
      include JSON::Serializable
      include YAML::Serializable

      property type : String # "apiKey", "http", "oauth2", "openIdConnect"
      property description : String?
      property name : String?
      property in : String?     # "query", "header", "cookie"
      property scheme : String? # "bearer", "basic"
      property bearerFormat : String?
    end

    class Tag
      include JSON::Serializable
      include YAML::Serializable

      property name : String
      property description : String?

      def initialize(@name : String, @description : String? = nil)
      end
    end
  end
end
