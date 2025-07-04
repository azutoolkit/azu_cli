require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Component do
  it "creates a component generator with basic properties" do
    properties = {"count" => "int32", "user_id" => "int64"}
    generator = AzuCLI::Generate::Component.new("UserCounter", properties)

    generator.name.should eq("UserCounter")
    generator.properties.should eq(properties)
    generator.snake_case_name.should eq("user_counter")
    generator.class_name.should eq("UserCounterComponent")
  end

  it "creates a component generator with events" do
    properties = {"messages" => "array", "current_user" => "string"}
    events = ["send_message", "receive_message"]
    generator = AzuCLI::Generate::Component.new("Chat", properties, events)

    generator.events.should eq(events)
    generator.has_events?.should be_true
    generator.has_properties?.should be_true
  end

  it "generates correct property declarations" do
    properties = {"count" => "int32", "user_id" => "int64", "messages" => "array"}
    generator = AzuCLI::Generate::Component.new("UserCounter", properties)

    declarations = generator.property_declarations
    declarations.should contain("property count : Int32 = 0")
    declarations.should contain("property user_id : Int64")
    declarations.should contain("property messages : Array(String) = [] of String")
  end

  it "generates correct constructor parameters" do
    properties = {"count" => "int32", "user_id" => "int64"}
    generator = AzuCLI::Generate::Component.new("UserCounter", properties)

    params = generator.constructor_params
    params.should contain("@count : Int32")
    params.should contain("@user_id : Int64")
  end

  it "maps crystal types correctly" do
    generator = AzuCLI::Generate::Component.new("Test", {} of String => String)

    generator.crystal_type("string").should eq("String")
    generator.crystal_type("int32").should eq("Int32")
    generator.crystal_type("int64").should eq("Int64")
    generator.crystal_type("array").should eq("Array(String)")
    generator.crystal_type("hash").should eq("Hash(String, String)")
    generator.crystal_type("bool").should eq("Bool")
    generator.crystal_type("time").should eq("Time")
  end

  it "generates event handling method" do
    events = ["send_message", "receive_message"]
    generator = AzuCLI::Generate::Component.new("Chat", {} of String => String, events)

    event_method = generator.event_handling_method
    event_method.should contain("def on_event(name, data)")
    event_method.should contain("when \"send_message\"")
    event_method.should contain("when \"receive_message\"")
    event_method.should contain("# Handle send_message event")
    event_method.should contain("# Handle receive_message event")
  end

  it "generates a component file with properties and events" do
    properties = {"count" => "int32", "user_id" => "int64"}
    events = ["refresh_count"]
    generator = AzuCLI::Generate::Component.new("UserCounter", properties, events)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "user_counter.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("class UserCounterComponent")
    content.should contain("include Azu::Component")
    content.should contain("property count : Int32 = 0")
    content.should contain("property user_id : Int64")
    content.should contain("def initialize(@count : Int32, @user_id : Int64)")
    content.should contain("def content")
    content.should contain("def on_event(name, data)")
    content.should contain("when \"refresh_count\"")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end

  it "generates a component file with no properties or events" do
    generator = AzuCLI::Generate::Component.new("Simple", {} of String => String, [] of String)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "simple.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("class SimpleComponent")
    content.should contain("include Azu::Component")
    content.should contain("def initialize()")
    content.should contain("def content")
    content.should_not contain("property")
    content.should_not contain("def on_event")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end

  it "generates a chat component similar to the example" do
    properties = {"messages" => "array", "current_user" => "string"}
    events = ["send_message", "receive_message"]
    generator = AzuCLI::Generate::Component.new("Chat", properties, events)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "chat.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("class ChatComponent")
    content.should contain("include Azu::Component")
    content.should contain("property messages : Array(String) = [] of String")
    content.should contain("property current_user : String")
    content.should contain("def initialize(@messages : Array(String), @current_user : String)")
    content.should contain("def on_event(name, data)")
    content.should contain("when \"send_message\"")
    content.should contain("when \"receive_message\"")
    content.should contain("end")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end
end
