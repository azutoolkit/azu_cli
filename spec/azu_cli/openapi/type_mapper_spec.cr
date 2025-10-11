require "../../spec_helper"

describe AzuCLI::OpenAPI::TypeMapper do
  describe ".to_schema" do
    it "creates string schema for String type" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("String")
      schema.type.should eq("string")
    end

    it "creates integer schema with int32 format for Int32" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("Int32")
      schema.type.should eq("integer")
      schema.format.should eq("int32")
    end

    it "creates integer schema with int64 format for Int64" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("Int64")
      schema.type.should eq("integer")
      schema.format.should eq("int64")
    end

    it "creates number schema with float format for Float32" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("Float32")
      schema.type.should eq("number")
      schema.format.should eq("float")
    end

    it "creates number schema with double format for Float64" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("Float64")
      schema.type.should eq("number")
      schema.format.should eq("double")
    end

    it "creates boolean schema for Bool" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("Bool")
      schema.type.should eq("boolean")
    end

    it "creates string schema with date-time format for Time" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("Time")
      schema.type.should eq("string")
      schema.format.should eq("date-time")
    end

    it "creates string schema with uuid format for UUID" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("UUID")
      schema.type.should eq("string")
      schema.format.should eq("uuid")
    end

    it "sets nullable flag for nullable types" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("String?")
      schema.nullable.should be_true
    end

    it "creates array schema for Array types" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("Array(String)")
      schema.type.should eq("array")
      schema.items.should_not be_nil
    end

    it "adds description when provided" do
      schema = AzuCLI::OpenAPI::TypeMapper.to_schema("String", "User name")
      schema.description.should eq("User name")
    end
  end

  describe ".properties_to_schemas" do
    it "converts hash of properties to schemas" do
      properties = {
        "name"  => "String",
        "age"   => "Int32",
        "email" => "String?",
      }

      schemas = AzuCLI::OpenAPI::TypeMapper.properties_to_schemas(properties)

      schemas.size.should eq(3)
      schemas["name"].type.should eq("string")
      schemas["age"].type.should eq("integer")
      schemas["email"].nullable.should be_true
    end
  end

  describe ".extract_required_fields" do
    it "returns non-nullable fields as required" do
      properties = {
        "name"     => "String",
        "age"      => "Int32",
        "email"    => "String?",
        "bio"      => "String?",
        "verified" => "Bool",
      }

      required = AzuCLI::OpenAPI::TypeMapper.extract_required_fields(properties)

      required.should contain("name")
      required.should contain("age")
      required.should contain("verified")
      required.should_not contain("email")
      required.should_not contain("bio")
    end

    it "returns empty array when all fields are nullable" do
      properties = {
        "email" => "String?",
        "bio"   => "String?",
      }

      required = AzuCLI::OpenAPI::TypeMapper.extract_required_fields(properties)
      required.should be_empty
    end
  end
end

