require "../../../spec_helper"

describe AzuCLI::Commands::DB::Validate do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::Validate.new
      command.name.should eq("db:validate")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::Validate.new
      command.description.should contain("Validate")
    end

    it "has check_connection set to true by default" do
      command = AzuCLI::Commands::DB::Validate.new
      command.check_connection.should be_true
    end

    it "has check_permissions set to true by default" do
      command = AzuCLI::Commands::DB::Validate.new
      command.check_permissions.should be_true
    end

    it "has check_migrations set to true by default" do
      command = AzuCLI::Commands::DB::Validate.new
      command.check_migrations.should be_true
    end
  end

  describe "option parsing" do
    it "parses --no-connection option" do
      command = AzuCLI::Commands::DB::Validate.new
      command.parse_args(["--no-connection"])

      command.check_connection.should be_false
    end

    it "parses --no-permissions option" do
      command = AzuCLI::Commands::DB::Validate.new
      command.parse_args(["--no-permissions"])

      command.check_permissions.should be_false
    end

    it "parses --no-migrations option" do
      command = AzuCLI::Commands::DB::Validate.new
      command.parse_args(["--no-migrations"])

      command.check_migrations.should be_false
    end

    it "parses --env option" do
      command = AzuCLI::Commands::DB::Validate.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "parses -e short option" do
      command = AzuCLI::Commands::DB::Validate.new
      command.parse_args(["-e", "staging"])

      command.environment.should eq("staging")
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::DB::Validate.new
      command.parse_args(["--no-connection", "--no-permissions", "--no-migrations", "--env", "test"])

      command.check_connection.should be_false
      command.check_permissions.should be_false
      command.check_migrations.should be_false
      command.environment.should eq("test")
    end
  end

end
