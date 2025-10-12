require "../../../spec_helper"

describe AzuCLI::Commands::DB::Create do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::Create.new
      command.name.should eq("db:create")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::Create.new
      command.description.should contain("Create")
    end

    it "has force set to false by default" do
      command = AzuCLI::Commands::DB::Create.new
      command.force.should be_false
    end
  end

  describe "option parsing" do
    it "parses --force option" do
      command = AzuCLI::Commands::DB::Create.new
      command.parse_args(["--force"])

      command.force.should be_true
    end

    it "parses -f short option" do
      command = AzuCLI::Commands::DB::Create.new
      command.parse_args(["-f"])

      command.force.should be_true
    end

    it "parses --database option" do
      command = AzuCLI::Commands::DB::Create.new
      command.parse_args(["--database", "my_test_db"])

      command.database_name.should eq("my_test_db")
    end

    it "parses -d short option" do
      command = AzuCLI::Commands::DB::Create.new
      command.parse_args(["-d", "another_db"])

      command.database_name.should eq("another_db")
    end

    it "parses --env option" do
      command = AzuCLI::Commands::DB::Create.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "parses -e short option" do
      command = AzuCLI::Commands::DB::Create.new
      command.parse_args(["-e", "production"])

      command.environment.should eq("production")
    end
  end
end
