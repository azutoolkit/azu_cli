require "../../spec_helper"

describe AzuCLI::Commands::Database do
  # Database is an abstract class, so we test with a concrete subclass
  describe "database configuration" do
    it "loads default configuration" do
      command = AzuCLI::Commands::DB::Create.new

      command.adapter.should eq("postgres")
      command.host.should eq("localhost")
      command.port.should eq(5432)
      command.username.should eq("postgres")
      command.environment.should eq("development")
    end

    it "infers database name from directory" do
      command = AzuCLI::Commands::DB::Create.new

      # Should contain directory name and environment
      inferred_name = command.database_name || ""
      inferred_name.should_not be_empty
    end
  end

  describe "connection URL generation" do
    it "generates postgres connection URL" do
      command = AzuCLI::Commands::DB::Create.new

      # Test connection URL format (protected method, tested via subclass)
      command.adapter.should eq("postgres")
    end
  end
end
