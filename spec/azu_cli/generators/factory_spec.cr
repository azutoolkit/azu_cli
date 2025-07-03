require "../../spec_helper"
require "../../../src/azu_cli/generators/factory"

module AzuCLI::Generators
  describe Factory do
    describe ".create" do
      it "creates MainAppGenerator" do
        generator = Factory.create("app", "test_app")
        generator.should be_a(MainAppGenerator)
        generator.name.should eq("test_app")
      end

      it "creates ModelGenerator" do
        generator = Factory.create("model", "user")
        generator.should be_a(ModelGenerator)
        generator.name.should eq("user")
      end

      it "creates RequestGenerator" do
        generator = Factory.create("request", "user_request")
        generator.should be_a(RequestGenerator)
        generator.name.should eq("user_request")
      end

      it "creates ResponseGenerator" do
        generator = Factory.create("response", "user_response")
        generator.should be_a(ResponseGenerator)
        generator.name.should eq("user_response")
      end

      it "creates ServerGenerator" do
        generator = Factory.create("server", "test_server")
        generator.should be_a(ServerGenerator)
        generator.name.should eq("test_server")
      end

      it "creates ValidatorGenerator" do
        generator = Factory.create("validator", "user_validator", model_name: "User")
        generator.should be_a(ValidatorGenerator)
        generator.name.should eq("user_validator")
      end

      it "creates EndpointGenerator" do
        generator = Factory.create("endpoint", "user", action: "index")
        generator.should be_a(EndpointGenerator)
        generator.name.should eq("user_index_endpoint")
      end

      it "raises error for unknown generator type" do
        expect_raises(Factory::GeneratorError, "Unknown generator type: unknown") do
          Factory.create("unknown", "test")
        end
      end

      it "raises error for unsupported generator type" do
        expect_raises(Factory::GeneratorError, "Unsupported generator type: invalid") do
          Factory.create("invalid", "test")
        end
      end
    end

    describe ".available_types" do
      it "returns all available generator types" do
        types = Factory.available_types
        types.should contain("app")
        types.should contain("model")
        types.should contain("request")
        types.should contain("response")
        types.should contain("server")
        types.should contain("validator")
        types.should contain("endpoint")
      end
    end

    describe ".supports?" do
      it "returns true for supported types" do
        Factory.supports?("app").should be_true
        Factory.supports?("model").should be_true
        Factory.supports?("endpoint").should be_true
      end

      it "returns false for unsupported types" do
        Factory.supports?("unknown").should be_false
        Factory.supports?("invalid").should be_false
      end
    end

    describe "generator creation with options" do
      it "creates generator with custom output directory" do
        generator = Factory.create("app", "test_app", output_dir: "custom_src")
        generator.output_dir.should eq("custom_src")
      end

      it "creates generator with specs disabled" do
        generator = Factory.create("app", "test_app", generate_specs: false)
        generator.generate_specs.should be_false
      end

      it "creates ModelGenerator with attributes" do
        attributes = [
          {name: "name", type: "String", nullable: false}
        ]
        generator = Factory.create("model", "user", attributes: attributes)
        model_generator = generator.as(ModelGenerator)
        model_generator.attributes.size.should eq(1)
      end

      it "creates RequestGenerator with properties" do
        properties = [
          {name: "name", type: "String", default: "", validations: ["required"]}
        ]
        generator = Factory.create("request", "user_request", properties: properties)
        request_generator = generator.as(RequestGenerator)
        request_generator.properties.size.should eq(1)
      end

      it "creates ResponseGenerator with attributes" do
        attributes = [
          {name: "name", type: "String", default: ""}
        ]
        generator = Factory.create("response", "user_response", attributes: attributes)
        response_generator = generator.as(ResponseGenerator)
        response_generator.attributes.size.should eq(1)
      end

      it "creates ServerGenerator with custom handlers" do
        handlers = ["Logger", "Rescuer", "CustomHandler"]
        generator = Factory.create("server", "test_server", handlers: handlers)
        server_generator = generator.as(ServerGenerator)
        server_generator.handlers.should eq(handlers)
      end

      it "requires model_name for ValidatorGenerator" do
        expect_raises(Factory::GeneratorError, "Model name is required for validator generator") do
          Factory.create("validator", "user_validator")
        end
      end

      it "requires action for EndpointGenerator" do
        expect_raises(Factory::GeneratorError, "Action is required for endpoint generator") do
          Factory.create("endpoint", "user")
        end
      end

      it "creates EndpointGenerator with custom classes" do
        generator = Factory.create("endpoint", "user", action: "index",
                                 request_class: "CustomRequest",
                                 response_class: "CustomResponse",
                                 service_class: "CustomService",
                                 namespace: "Api")
        endpoint_generator = generator.as(EndpointGenerator)
        endpoint_generator.request_class_name.should eq("CustomRequest")
        endpoint_generator.response_class_name.should eq("CustomResponse")
        endpoint_generator.service_class_name.should eq("CustomService")
      end
    end

    describe "validation" do
      it "validates empty output directory" do
        expect_raises(Factory::GeneratorError, "Output directory cannot be empty") do
          Factory.create("app", "test_app", output_dir: "")
        end
      end
    end
  end

  describe GeneratorBuilder do
    describe "#initialize" do
      it "creates builder with type and name" do
        builder = GeneratorBuilder.new("app", "test_app")
        builder.type.should eq("app")
        builder.name.should eq("test_app")
      end
    end

    describe "fluent interface" do
      it "chains method calls" do
        builder = GeneratorBuilder.new("app", "test_app")
                                  .output_dir("custom_src")
                                  .generate_specs(false)
        builder.options[:output_dir].should eq("custom_src")
        builder.options[:generate_specs].should eq(false)
      end

      it "builds generator with chained options" do
        generator = GeneratorBuilder.new("app", "test_app")
                                   .output_dir("custom_src")
                                   .generate_specs(false)
                                   .build
        generator.should be_a(MainAppGenerator)
        generator.output_dir.should eq("custom_src")
        generator.generate_specs.should be_false
      end
    end

    describe "builder methods" do
      it "sets output_dir" do
        builder = GeneratorBuilder.new("app", "test_app")
        builder.output_dir("custom_src")
        builder.options[:output_dir].should eq("custom_src")
      end

      it "sets generate_specs" do
        builder = GeneratorBuilder.new("app", "test_app")
        builder.generate_specs(false)
        builder.options[:generate_specs].should eq(false)
      end

      it "sets attributes" do
        attributes = [
          {name: "name", type: "String", nullable: false}
        ]
        builder = GeneratorBuilder.new("model", "user")
        builder.attributes(attributes)
        builder.options[:attributes].should eq(attributes)
      end

      it "sets associations" do
        associations = [
          {type: "has_many", name: "posts", model: "Post", foreign_key: "user_id"}
        ]
        builder = GeneratorBuilder.new("model", "user")
        builder.associations(associations)
        builder.options[:associations].should eq(associations)
      end

      it "sets validations" do
        validations = [
          {field: "name", rules: ["required"]}
        ]
        builder = GeneratorBuilder.new("model", "user")
        builder.validations(validations)
        builder.options[:validations].should eq(validations)
      end

      it "sets properties" do
        properties = [
          {name: "name", type: "String", default: "", validations: ["required"]}
        ]
        builder = GeneratorBuilder.new("request", "user_request")
        builder.properties(properties)
        builder.options[:properties].should eq(properties)
      end

      it "sets response_attributes" do
        attributes = [
          {name: "name", type: "String", default: ""}
        ]
        builder = GeneratorBuilder.new("response", "user_response")
        builder.response_attributes(attributes)
        builder.options[:attributes].should eq(attributes)
      end

      it "sets handlers" do
        handlers = ["Logger", "Rescuer"]
        builder = GeneratorBuilder.new("server", "test_server")
        builder.handlers(handlers)
        builder.options[:handlers].should eq(handlers)
      end

      it "sets model_name" do
        builder = GeneratorBuilder.new("validator", "user_validator")
        builder.model_name("User")
        builder.options[:model_name].should eq("User")
      end

      it "sets action" do
        builder = GeneratorBuilder.new("endpoint", "user")
        builder.action("index")
        builder.options[:action].should eq("index")
      end

      it "sets request_class" do
        builder = GeneratorBuilder.new("endpoint", "user")
        builder.request_class("CustomRequest")
        builder.options[:request_class].should eq("CustomRequest")
      end

      it "sets response_class" do
        builder = GeneratorBuilder.new("endpoint", "user")
        builder.response_class("CustomResponse")
        builder.options[:response_class].should eq("CustomResponse")
      end

      it "sets service_class" do
        builder = GeneratorBuilder.new("endpoint", "user")
        builder.service_class("CustomService")
        builder.options[:service_class].should eq("CustomService")
      end

      it "sets namespace" do
        builder = GeneratorBuilder.new("endpoint", "user")
        builder.namespace("Api")
        builder.options[:namespace].should eq("Api")
      end

      it "sets include_json" do
        builder = GeneratorBuilder.new("response", "user_response")
        builder.include_json(false)
        builder.options[:include_json].should eq(false)
      end
    end

    describe "complex builder usage" do
      it "builds ModelGenerator with all options" do
        attributes = [
          {name: "name", type: "String", nullable: false}
        ]
        associations = [
          {type: "has_many", name: "posts", model: "Post", foreign_key: "user_id"}
        ]
        validations = [
          {field: "name", rules: ["required"]}
        ]

        generator = GeneratorBuilder.new("model", "user")
                                   .output_dir("custom_src")
                                   .generate_specs(false)
                                   .attributes(attributes)
                                   .associations(associations)
                                   .validations(validations)
                                   .build

        generator.should be_a(ModelGenerator)
        model_generator = generator.as(ModelGenerator)
        model_generator.output_dir.should eq("custom_src")
        model_generator.generate_specs.should be_false
        model_generator.attributes.size.should eq(1)
        model_generator.associations.size.should eq(1)
        model_generator.validations.size.should eq(1)
      end

      it "builds EndpointGenerator with all options" do
        generator = GeneratorBuilder.new("endpoint", "user")
                                   .output_dir("custom_src")
                                   .generate_specs(false)
                                   .action("index")
                                   .request_class("CustomRequest")
                                   .response_class("CustomResponse")
                                   .service_class("CustomService")
                                   .namespace("Api")
                                   .build

        generator.should be_a(EndpointGenerator)
        endpoint_generator = generator.as(EndpointGenerator)
        endpoint_generator.output_dir.should eq("custom_src")
        endpoint_generator.generate_specs.should be_false
        endpoint_generator.action.should eq("index")
        endpoint_generator.request_class_name.should eq("CustomRequest")
        endpoint_generator.response_class_name.should eq("CustomResponse")
        endpoint_generator.service_class_name.should eq("CustomService")
      end
    end
  end
end
