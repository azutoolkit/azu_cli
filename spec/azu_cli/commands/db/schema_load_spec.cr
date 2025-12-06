require "../../../spec_helper"

describe AzuCLI::Commands::DB::SchemaLoad do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::SchemaLoad.new
      command.name.should eq("db:schema:load")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::SchemaLoad.new
      command.description.should contain("Load schema")
    end

    it "has schema_file set to nil by default" do
      command = AzuCLI::Commands::DB::SchemaLoad.new
      command.schema_file.should be_nil
    end

    it "has force set to false by default" do
      command = AzuCLI::Commands::DB::SchemaLoad.new
      command.force.should be_false
    end
  end

  describe "option parsing" do
    it "parses --file option" do
      command = AzuCLI::Commands::DB::SchemaLoad.new
      command.parse_args(["--file", "./custom/schema.cr"])

      command.schema_file.should eq("./custom/schema.cr")
    end

    it "parses -f short option" do
      command = AzuCLI::Commands::DB::SchemaLoad.new
      command.parse_args(["-f", "./custom/schema.sql"])

      command.schema_file.should eq("./custom/schema.sql")
    end

    it "parses --force option" do
      command = AzuCLI::Commands::DB::SchemaLoad.new
      command.parse_args(["--force"])

      command.force.should be_true
    end

    it "parses --env option" do
      command = AzuCLI::Commands::DB::SchemaLoad.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "parses -e short option" do
      command = AzuCLI::Commands::DB::SchemaLoad.new
      command.parse_args(["-e", "staging"])

      command.environment.should eq("staging")
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::DB::SchemaLoad.new
      command.parse_args(["--force", "--file", "./schema.sql", "--env", "test"])

      command.force.should be_true
      command.schema_file.should eq("./schema.sql")
      command.environment.should eq("test")
    end
  end

end
