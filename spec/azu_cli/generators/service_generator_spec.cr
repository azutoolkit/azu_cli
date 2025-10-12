require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Service do
  it "creates a service generator with name" do
    generator = AzuCLI::Generate::Service.new("UserService")

    generator.name.should eq("UserService")
    generator.snake_case_name.should eq("user_service")
    generator.camel_case_name.should eq("UserService")
  end

  it "creates a service generator with custom methods" do
    methods = {"create" => "User", "update" => "User", "delete" => "Bool"}
    generator = AzuCLI::Generate::Service.new("UserService", methods)

    generator.methods.should eq(methods)
  end

  it "initializes with empty methods by default" do
    generator = AzuCLI::Generate::Service.new("OrderService")

    generator.methods.should be_empty
  end

  it "converts name to snake_case" do
    generator = AzuCLI::Generate::Service.new("UserAccountService")

    generator.snake_case_name.should eq("user_account_service")
  end

  it "converts name to CamelCase" do
    generator = AzuCLI::Generate::Service.new("user_service")

    generator.camel_case_name.should eq("UserService")
  end

  describe "#method_definitions" do
    it "generates TODO comment when no methods provided" do
      generator = AzuCLI::Generate::Service.new("UserService")

      definitions = generator.method_definitions
      definitions.should contain("TODO: Add service methods here")
      definitions.should contain("Example:")
    end

    it "generates method definitions with correct signatures" do
      methods = {"create" => "User"}
      generator = AzuCLI::Generate::Service.new("UserService", methods)

      definitions = generator.method_definitions
      definitions.should contain("def create(params : Hash) : User")
      definitions.should contain("TODO: Implement create logic")
      definitions.should contain("NotImplementedError")
    end

    it "generates multiple method definitions" do
      methods = {"create" => "User", "update" => "User", "delete" => "Bool"}
      generator = AzuCLI::Generate::Service.new("UserService", methods)

      definitions = generator.method_definitions
      definitions.should contain("def create(params : Hash) : User")
      definitions.should contain("def update(params : Hash) : User")
      definitions.should contain("def delete(params : Hash) : Bool")
    end
  end

  describe "#has_dependencies?" do
    it "returns true by default" do
      generator = AzuCLI::Generate::Service.new("UserService")

      generator.has_dependencies?.should be_true
    end
  end

  describe "#dependency_params" do
    it "generates repository dependency parameter" do
      generator = AzuCLI::Generate::Service.new("UserService")

      params = generator.dependency_params
      params.should contain("@repository")
      params.should contain("UserServiceRepository")
    end
  end

  describe "#usage_example" do
    it "generates usage example" do
      generator = AzuCLI::Generate::Service.new("UserService")

      example = generator.usage_example
      example.should contain("Usage example:")
      example.should contain("UserServiceRepository.new")
      example.should contain("UserServiceService.new")
    end
  end
end
