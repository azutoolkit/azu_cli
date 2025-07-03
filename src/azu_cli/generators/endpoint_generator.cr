require "./base"
require "file_utils"

module AzuCLI
  module Generators
    # Type aliases for endpoint definitions
    alias EndpointAction = String
    alias HttpMethod = String
    alias UrlPath = String

    # Simple pluralization helper
    module PluralizeHelper
      def self.pluralize(word : String) : String
        return word if word.empty?

        case word.downcase
        when .ends_with?("s"), .ends_with?("x"), .ends_with?("z"), .ends_with?("ch"), .ends_with?("sh")
          word + "es"
        when .ends_with?("y")
          if word.size > 1 && !"aeiou".includes?(word[-2])
            word[0..-2] + "ies"
          else
            word + "s"
          end
        when .ends_with?("f")
          word[0..-2] + "ves"
        when .ends_with?("fe")
          word[0..-3] + "ves"
        else
          word + "s"
        end
      end
    end

    # Strategy pattern for handling endpoint configuration
    struct EndpointConfiguration
      getter resource_name : String
      getter action : EndpointAction
      getter request_class : String
      getter response_class : String
      getter service_class : String
      getter namespace : String?

      # Standard REST actions and their HTTP methods
      REST_ACTIONS = {
        "index"   => "get",
        "new"     => "get",
        "create"  => "post",
        "show"    => "get",
        "edit"    => "get",
        "update"  => "patch",
        "destroy" => "delete",
      }

      def initialize(@resource_name : String,
                     @action : EndpointAction,
                     request_class : String? = nil,
                     response_class : String? = nil,
                     service_class : String? = nil,
                     @namespace : String? = nil)
        validate_action!
        @request_class = request_class || default_request_class
        @response_class = response_class || default_response_class
        @service_class = service_class || default_service_class
      end

      def http_method : HttpMethod
        REST_ACTIONS[@action]
      end

      def api_path : UrlPath
        pluralized_resource = PluralizeHelper.pluralize(@resource_name.underscore)

        case @action
        when "index", "create"
          "/api/#{pluralized_resource}"
        when "new"
          "/api/#{pluralized_resource}/new"
        when "show", "edit", "update", "destroy"
          "/api/#{pluralized_resource}/:id"
        else
          "/api/#{pluralized_resource}/#{@action}"
        end
      end

      def needs_id_param? : Bool
        ["show", "edit", "update", "destroy"].includes?(@action)
      end

      def needs_error_handling? : Bool
        ["create", "update", "destroy"].includes?(@action)
      end

      def is_collection_action? : Bool
        ["index", "new", "create"].includes?(@action)
      end

      def service_method_name : String
        pluralized_resource = PluralizeHelper.pluralize(@resource_name.underscore)

        case @action
        when "index"
          "list_#{pluralized_resource}"
        when "create"
          "create_#{@resource_name.underscore}"
        when "show"
          "find_#{@resource_name.underscore}"
        when "update"
          "update_#{@resource_name.underscore}"
        when "destroy"
          "delete_#{@resource_name.underscore}"
        else
          "#{@action}_#{@resource_name.underscore}"
        end
      end

      private def validate_action!
        unless REST_ACTIONS.has_key?(@action)
          raise ArgumentError.new("Invalid REST action: #{@action}. Valid actions: #{REST_ACTIONS.keys.join(", ")}")
        end
      end

      private def default_request_class
        case @action
        when "index", "show", "new", "edit", "destroy"
          "Azu::Request::Empty"
        when "create"
          "Create#{@resource_name.camelcase}Request"
        when "update"
          "Update#{@resource_name.camelcase}Request"
        else
          "#{@action.camelcase}#{@resource_name.camelcase}Request"
        end
      end

      private def default_response_class
        case @action
        when "index"
          "#{PluralizeHelper.pluralize(@resource_name.camelcase)}Response"
        when "destroy"
          "Azu::Response::NoContent"
        else
          "#{@resource_name.camelcase}Response"
        end
      end

      private def default_service_class
        "#{@resource_name.camelcase}Service"
      end
    end

    class EndpointGenerator < Base
      directory "#{__DIR__}/../templates/generators/endpoint"

      # Instance variables expected by Teeplate from template scanning
      @resource_name : String
      @action : String
      @endpoint_class_name : String
      @request_class_name : String
      @response_class_name : String
      @service_class_name : String
      @http_method : String
      @api_path : String
      @service_method_name : String
      @resource_name_pluralized : String

      getter configuration : EndpointConfiguration

      def initialize(resource_name : String,
                     action : EndpointAction,
                     request_class : String? = nil,
                     response_class : String? = nil,
                     service_class : String? = nil,
                     namespace : String? = nil,
                     output_dir : String = "src",
                     generate_specs : Bool = true)
        # Validate resource name before creating endpoint configuration
        if resource_name.empty?
          raise ArgumentError.new("Name cannot be empty")
        end

        endpoint_name = "#{resource_name}_#{action}_endpoint"
        super(endpoint_name, output_dir, generate_specs)
        @configuration = EndpointConfiguration.new(resource_name, action, request_class, response_class, service_class, namespace)

        # Set instance variables for Teeplate
        @resource_name = resource_name.underscore
        @action = action
        @endpoint_class_name = "#{action.camelcase}#{resource_name.camelcase}Endpoint"
        @request_class_name = @configuration.request_class
        @response_class_name = @configuration.response_class
        @service_class_name = @configuration.service_class
        @http_method = @configuration.http_method
        @api_path = @configuration.api_path
        @service_method_name = @configuration.service_method_name
        @resource_name_pluralized = PluralizeHelper.pluralize(resource_name.underscore)
      end

      def template_directory : String
        "#{__DIR__}/../templates/generators/endpoint"
      end

      def build_output_path : String
        File.join(@output_dir, "endpoints", "#{@resource_name}", "#{@action}_endpoint.cr")
      end

      # Override spec template name to match our template
      protected def spec_template_name : String
        "#{resource_name}_#{action}_endpoint_spec.cr.ecr"
      end

      # Override render_template to handle custom filename
      protected def render_template
        # Render the template to a temporary location
        temp_dir = File.join(Dir.tempdir, "azu_endpoint_#{Random.rand(100000)}")
        Dir.mkdir_p(temp_dir)
        render(temp_dir)

        # Move the generated file to the correct location with the right name
        source_file = File.join(temp_dir, "endpoint.cr")
        target_file = build_output_path

        if File.exists?(source_file)
          FileUtils.mkdir_p(File.dirname(target_file))
          File.copy(source_file, target_file)
          FileUtils.rm_rf(temp_dir)
        else
          FileUtils.rm_rf(temp_dir)
          raise "Template rendering failed - no output file generated"
        end
      end

      # Template methods for accessing endpoint properties
      def resource_name
        @resource_name
      end

      def action
        @action
      end

      def endpoint_class_name
        @endpoint_class_name
      end

      def request_class_name
        @request_class_name
      end

      def response_class_name
        @response_class_name
      end

      def service_class_name
        @service_class_name
      end

      def http_method
        @http_method
      end

      def api_path
        @api_path
      end

      def service_method_name
        @service_method_name
      end

      def resource_name_pluralized
        @resource_name_pluralized
      end

      def needs_id_param?
        @configuration.needs_id_param?
      end

      def is_collection_action?
        @configuration.is_collection_action?
      end

      # Validation methods
      protected def validate_preconditions!
        super
        validate_endpoint_configuration!
      end

      private def validate_endpoint_configuration!
        # Additional endpoint-specific validations can be added here
        if @configuration.resource_name.empty?
          raise ArgumentError.new("Resource name cannot be empty")
        end
      end
    end

    # Scaffold generator for creating complete REST resource
    class ResourceScaffoldGenerator
      getter resource_name : String
      getter output_dir : String
      getter namespace : String?
      getter generate_specs : Bool

      # All standard REST actions
      REST_ACTIONS = ["index", "new", "create", "show", "edit", "update", "destroy"]

      def initialize(@resource_name : String, @output_dir : String = "src", @namespace : String? = nil, @generate_specs : Bool = true)
      end

      def generate_all!
        generated_files = [] of String

        REST_ACTIONS.each do |action|
          generator = EndpointGenerator.new(@resource_name, action, output_dir: @output_dir, namespace: @namespace, generate_specs: @generate_specs)
          generated_files << generator.generate!
        end

        generated_files
      end

      def generate_actions!(actions : Array(String))
        generated_files = [] of String

        actions.each do |action|
          unless REST_ACTIONS.includes?(action)
            raise ArgumentError.new("Invalid REST action: #{action}. Valid actions: #{REST_ACTIONS.join(", ")}")
          end

          generator = EndpointGenerator.new(@resource_name, action, output_dir: @output_dir, namespace: @namespace, generate_specs: @generate_specs)
          generated_files << generator.generate!
        end

        generated_files
      end

      def generate_crud!
        # Generate Create, Read, Update, Delete actions
        generate_actions!(["create", "show", "update", "destroy"])
      end

      def generate_readonly!
        # Generate only read actions
        generate_actions!(["index", "show"])
      end
    end
  end
end
