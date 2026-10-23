require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

# Exposes the directory the db:* commands read migrations from.
class MigrationsDirectoryProbe < AzuCLI::Commands::DB::Migrate
  def directory : String
    migrations_dir
  end
end

private def generate(*args : String)
  command = AzuCLI::Commands::Generate.new
  command.parse_args(args.to_a)
  result = nil
  TestHelpers::TestSetup.with_captured_output { |_| result = command.execute }
  result.not_nil!.success?.should be_true
end

describe "the migrations directory" do
  it "is src/db/migrations for the generators, the validator and the db commands alike" do
    AzuCLI::Config::Paths::MIGRATIONS.should eq("src/db/migrations")
    AzuCLI::Generate::Migration::OUTPUT_DIR.should eq("./src/db/migrations")
    AzuCLI::Validators::MigrationValidator.new.migrations_dir.should eq("./src/db/migrations")
    MigrationsDirectoryProbe.new.directory.should eq("./src/db/migrations")
  end

  it "receives the scaffold's migration and nothing is written anywhere else" do
    in_generated_project do
      generate "scaffold", "Post", "title:string", "body:text"

      Dir.glob("src/db/migrations/*_create_posts.cr").size.should eq(1)
      Dir.glob("**/migrations/*.cr").should eq(Dir.glob("src/db/migrations/*.cr"))
      Dir.exists?("db").should be_false
      Dir.exists?("src/models/db").should be_false
    end
  end

  it "receives `generate migration` too" do
    in_generated_project do
      generate "migration", "create_comments", "body:text"

      Dir.glob("**/migrations/*.cr").should eq(Dir.glob("src/db/migrations/*_create_comments.cr"))
      Dir.exists?("db").should be_false
    end
  end

  it "holds migrations the validator accepts without a warning, even when generated in the same second" do
    in_generated_project do
      generate "scaffold", "Post", "title:string"
      generate "migration", "add_slug_to_posts", "slug:string"
      generate "migration", "create_comments", "body:text"

      validator = AzuCLI::Validators::MigrationValidator.new("src/db/migrations")
      validator.validate_all.should be_true
      validator.errors.should be_empty
      validator.warnings.should be_empty
      validator.migration_versions.uniq.size.should eq(3)
    end
  end
end

describe "scaffold output that needs no hand editing" do
  it "declares the table in src/db/schema.cr" do
    in_generated_project do
      generate "scaffold", "Post", "title:string", "published:bool"

      schema = File.read("src/db/schema.cr")
      schema.scan("table :posts do").size.should eq(1)
      schema.should contain("    text :title\n    boolean :published, default: false\n")
    end
  end

  it "generates services that reopen the model's class rather than a module of its name" do
    in_generated_project do
      generate "scaffold", "Post", "title:string"

      File.read("src/models/post.cr").should contain("class Post\n")
      %w(create update destroy).each do |action|
        service = File.read("src/services/posts/#{action}_service.cr")
        service.should contain("class Posts::#{action.capitalize}Service")
        service.should_not contain("module Post\n")
        service.should_not contain("module Posts\n")
      end
    end
  end
end
