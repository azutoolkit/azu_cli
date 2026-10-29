require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe "Spark generators" do
  cli = File.expand_path("../../../bin/azu", __DIR__)

  it "creates a live component from the documented scaffold --spark command" do
    in_generated_project do
      output = IO::Memory.new
      status = Process.run(cli, %w(generate scaffold Product name:string price_cents:int32 active:bool --spark),
        env: {"AZU_UI" => "plain"}, output: output, error: output)
      status.success?.should be_true
      File.read("src/components/products/live_component.cr").should contain("< Azu::Spark::Component")
      File.read("src/services/products/create_service.cr").should contain("Azu::PubSub.broadcast")
    end
  end

  it "preserves Spark switches in a dry-run without writing to the project" do
    in_generated_project do
      output = IO::Memory.new
      status = Process.run(cli, %w(generate scaffold Product name:string price_cents:int32 active:bool --spark --dry-run),
        output: output, error: output)
      status.success?.should be_true
      output.to_s.should contain("src/components/products/live_component.cr")
      output.to_s.should contain("src/services/products/live_service.cr")
      File.exists?("src/components/products/live_component.cr").should be_false
      File.exists?("src/models/product.cr").should be_false
      File.exists?(".env").should be_false
    end
  end

  it "preserves --page and valued options in previews" do
    in_generated_project do
      output = IO::Memory.new
      status = Process.run(cli, %w(generate spark Counter count:int32 --page --dry-run), output: output, error: output)
      status.success?.should be_true
      output.to_s.should contain("src/endpoints/counters/live_endpoint.cr")
      File.exists?("src/endpoints/counters/live_endpoint.cr").should be_false

      output = IO::Memory.new
      status = Process.run(cli, %w(generate seed Products --env production --dry-run), output: output, error: output)
      status.success?.should be_true
      output.to_s.should contain("src/db/seeds/production/")
      output.to_s.should_not contain("src/db/seeds/development/")
    end
  end

  it "rejects incompatible Spark options even through a preview" do
    in_generated_project do
      output = IO::Memory.new
      status = Process.run(cli, %w(generate scaffold Product name:string --spark --api-only --dry-run), output: output, error: output)
      status.success?.should be_false
      output.to_s.should contain("Spark scaffolds need a web project")
      File.exists?("src/models/product.cr").should be_false
    end
  end

  it "validates names/types before writing and explains unsupported fields" do
    AzuCLI::Generate::Spark.attributes_error({"count" => "int32"}, true).should be_nil
    AzuCLI::Generate::Spark.attributes_error({"render" => "string"}, true).not_nil!.should contain("reserved")
    AzuCLI::Generate::Spark.attributes_error({"increment_count" => "int32"}, true).not_nil!.should contain("reserved")
    AzuCLI::Generate::Spark.attributes_error({"bad-name" => "string"}).not_nil!.should contain("Invalid field")
    AzuCLI::Generate::Spark.attributes_error({"title" => "string?"}).not_nil!.should contain("standard scaffold")
    AzuCLI::Generate::Spark.attributes_error({"tags" => "json"}).not_nil!.should contain("standard scaffold")
  end

  it "keeps static components distinct from real Spark state/events" do
    in_generated_project do
      AzuCLI::Generate::Spark.new("Counter").render(".")
      File.read("src/components/counter_spark.cr").not_nil!.should contain("< Azu::Spark::Component")
      File.read("src/components/counter_spark.cr").not_nil!.should contain("event def increment_count")
      File.exists?("src/endpoints/counters/live_endpoint.cr").should be_false
      File.exists?("spec/components/counter_spark_spec.cr").should be_true
    end
  end

  it "adds the optional page/nav and preserves existing Spark setup/secrets" do
    in_generated_project do
      Dir.mkdir_p("public/templates/helpers")
      File.write(AzuCLI::Generate::Navigation::PARTIAL, AzuCLI::Generate::Navigation::ANCHOR)
      Dir.mkdir_p("src/initializers")
      File.write(AzuCLI::Generate::SparkWiring::INITIALIZER, "# custom Spark setup\n")
      File.write(".env", "SPARK_SECRET=keep-this-key\n")
      generator = AzuCLI::Generate::Spark.new("Counter", {"count" => "int32"}, demo_page: true)
      generator.render(".", force: true)
      generator.render(".", force: true)
      File.read(AzuCLI::Generate::Navigation::PARTIAL).scan(%(href="/counters/live")).size.should eq(1)
      File.read(".env").should eq("SPARK_SECRET=keep-this-key\n")
      File.read(AzuCLI::Generate::SparkWiring::INITIALIZER).should eq("# custom Spark setup\n")
      File.read("src/pages/counters/live_page.cr").not_nil!.should contain("Azu::Spark.script_tag")
    end
  end

  it "generates a bounded live controller plus a separate persistence boundary" do
    in_generated_project do
      AzuCLI::Generate::SparkScaffold.new("Product", "index", {"name" => "string"}).render(".")
      component = File.read("src/components/products/live_component.cr")
      component.should contain("request.valid?")
      component.should contain("socket.subscribe(TOPIC)")
      AzuCLI::Generate::Service.new("Product", "create", {"name" => "string"}, broadcast: true).render("src/services")
      File.read("src/services/products/create_service.cr").should contain("Azu::PubSub.broadcast(\"blog:products:changed\", \"changed\")")
      component.should contain("delivery: \"at-most-once\"")
      component.should contain("event def confirm_delete")
      File.read("src/services/products/live_service.cr").not_nil!.should contain("limit(PAGE_SIZE + 1)")
      File.read("src/endpoints/products/index_endpoint.cr").should_not contain("Product.all")
      File.info(".env").permissions.value.should eq(0o600)
    end
  end

  it "rejects incompatible modes without writing files" do
    in_generated_project do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(%w(scaffold Product name:string --spark --api-only))
      command.execute.success?.should be_false
      File.exists?("src/models/product.cr").should be_false
      command = AzuCLI::Commands::Generate.new
      command.parse_args(%w(spark Counter count:int32?))
      command.execute.success?.should be_false
      File.exists?("src/components/counter_spark.cr").should be_false
    end
  end
end
