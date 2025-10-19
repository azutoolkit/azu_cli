require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Service do
  it "creates a service generator with name" do
    generator = AzuCLI::Generate::Service.new("UserService")

    generator.name.should eq("UserService")
    generator.snake_case_name.should eq("user_service")
    generator.camel_case_name.should eq("UserService")
  end

  it "creates a service generator with custom action" do
    generator = AzuCLI::Generate::Service.new("UserService", "update")

    generator.action.should eq("update")
    generator.service_class_name.should eq("UpdateService")
  end

  it "initializes with create action by default" do
    generator = AzuCLI::Generate::Service.new("OrderService")

    generator.action.should eq("create")
    generator.service_class_name.should eq("CreateService")
  end

  it "converts name to snake_case" do
    generator = AzuCLI::Generate::Service.new("UserAccountService")

    generator.snake_case_name.should eq("user_account_service")
  end

  it "converts name to CamelCase" do
    generator = AzuCLI::Generate::Service.new("user_service")

    generator.camel_case_name.should eq("UserService")
  end

  describe "#param_list" do
    it "generates parameter list from attributes" do
      attributes = {"name" => "string", "email" => "string", "age" => "int32"}
      generator = AzuCLI::Generate::Service.new("UserService", "create", attributes)

      param_list = generator.param_list
      param_list.should contain("name : String")
      param_list.should contain("email : String")
      param_list.should contain("age : Int32")
    end
  end

  describe "#model_class" do
    it "generates model class name" do
      generator = AzuCLI::Generate::Service.new("UserService")

      model_class = generator.model_class
      model_class.should eq("UserService::UserServiceModel")
    end
  end

  describe "#crystal_type" do
    it "converts string type to String" do
      generator = AzuCLI::Generate::Service.new("UserService")

      generator.crystal_type("string").should eq("String")
    end

    it "converts int32 type to Int32" do
      generator = AzuCLI::Generate::Service.new("UserService")

      generator.crystal_type("int32").should eq("Int32")
    end
  end
end
