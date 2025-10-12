require "../../spec_helper"

describe AzuCLI::OpenAPI::SchemaMapper do
  describe ".to_crystal_type" do
    it "maps string type to Crystal String" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "string"

      result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
      result.should eq("String")
    end

    it "maps string with date-time format to Time" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "string"
      schema.format = "date-time"

      result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
      result.should eq("Time")
    end

    it "maps string with uuid format to UUID" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "string"
      schema.format = "uuid"

      result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
      result.should eq("UUID")
    end

    it "maps integer with int32 format to Int32" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "integer"
      schema.format = "int32"

      result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
      result.should eq("Int32")
    end

    it "maps integer with int64 format to Int64" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "integer"
      schema.format = "int64"

      result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
      result.should eq("Int64")
    end

    it "maps number with float format to Float32" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "number"
      schema.format = "float"

      result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
      result.should eq("Float32")
    end

    it "maps number with double format to Float64" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "number"
      schema.format = "double"

      result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
      result.should eq("Float64")
    end

    it "maps boolean to Bool" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "boolean"

      result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
      result.should eq("Bool")
    end

    it "adds ? suffix for nullable types" do
      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "string"
      schema.nullable = true

      result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
      result.should eq("String?")
    end

    it "maps array type to Array(T)" do
      item_schema = AzuCLI::OpenAPI::Schema.new
      item_schema.type = "string"

      schema = AzuCLI::OpenAPI::Schema.new
      schema.type = "array"
      schema.items = item_schema

      result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
      result.should eq("Array(String)")
    end
  end

  describe ".to_openapi_type" do
    it "maps String to string" do
      type, format = AzuCLI::OpenAPI::SchemaMapper.to_openapi_type("String")
      type.should eq("string")
      format.should be_nil
    end

    it "maps Int32 to integer with int32 format" do
      type, format = AzuCLI::OpenAPI::SchemaMapper.to_openapi_type("Int32")
      type.should eq("integer")
      format.should eq("int32")
    end

    it "maps Int64 to integer with int64 format" do
      type, format = AzuCLI::OpenAPI::SchemaMapper.to_openapi_type("Int64")
      type.should eq("integer")
      format.should eq("int64")
    end

    it "maps Float32 to number with float format" do
      type, format = AzuCLI::OpenAPI::SchemaMapper.to_openapi_type("Float32")
      type.should eq("number")
      format.should eq("float")
    end

    it "maps Float64 to number with double format" do
      type, format = AzuCLI::OpenAPI::SchemaMapper.to_openapi_type("Float64")
      type.should eq("number")
      format.should eq("double")
    end

    it "maps Bool to boolean" do
      type, format = AzuCLI::OpenAPI::SchemaMapper.to_openapi_type("Bool")
      type.should eq("boolean")
      format.should be_nil
    end

    it "maps Time to string with date-time format" do
      type, format = AzuCLI::OpenAPI::SchemaMapper.to_openapi_type("Time")
      type.should eq("string")
      format.should eq("date-time")
    end

    it "maps UUID to string with uuid format" do
      type, format = AzuCLI::OpenAPI::SchemaMapper.to_openapi_type("UUID")
      type.should eq("string")
      format.should eq("uuid")
    end
  end

  describe ".nullable?" do
    it "returns true for types ending with ?" do
      AzuCLI::OpenAPI::SchemaMapper.nullable?("String?").should be_true
      AzuCLI::OpenAPI::SchemaMapper.nullable?("Int32?").should be_true
    end

    it "returns false for non-nullable types" do
      AzuCLI::OpenAPI::SchemaMapper.nullable?("String").should be_false
      AzuCLI::OpenAPI::SchemaMapper.nullable?("Int32").should be_false
    end
  end

  describe ".extract_array_item_type" do
    it "extracts item type from Array(T)" do
      result = AzuCLI::OpenAPI::SchemaMapper.extract_array_item_type("Array(String)")
      result.should eq("String")
    end

    it "extracts complex item type" do
      result = AzuCLI::OpenAPI::SchemaMapper.extract_array_item_type("Array(Hash(String, Int32))")
      result.should eq("Hash(String, Int32)")
    end

    it "returns nil for non-array types" do
      result = AzuCLI::OpenAPI::SchemaMapper.extract_array_item_type("String")
      result.should be_nil
    end
  end
end
