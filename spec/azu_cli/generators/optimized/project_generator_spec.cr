require "../spec_helper"

describe AzuCLI::Generator::ProjectGenerator do
  describe "initialization" do
    it "initializes with basic parameters" do
      options = create_generator_options
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      generator.name.should eq("MyApp")
      generator.project_name.should eq("my_app")
      generator.project_type.should eq("web")    # default type
      generator.database.should eq("postgresql") # default database
    end

    it "sets project type from options" do
      options = create_generator_options(custom_options: {"type" => "api"})
      generator = AzuCLI::Generator::ProjectGenerator.new("MyAPI", "my_api", options)

      generator.project_type.should eq("api")
    end

    it "sets database from options" do
      options = create_generator_options(custom_options: {"database" => "mysql"})
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      generator.database.should eq("mysql")
    end

    it "sets force flag from options" do
      options = create_generator_options(force: true)
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      generator.force_create.should be_true
    end

    it "sets skip flags from custom options" do
      options = create_generator_options(custom_options: {
        "skip-git"         => "true",
        "skip-deps"        => "true",
        "skip-interactive" => "true",
      })
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      generator.skip_git.should be_true
      generator.skip_deps.should be_true
      generator.skip_interactive.should be_true
    end
  end

  describe "generator type" do
    it "returns correct generator type" do
      options = create_generator_options
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      generator.generator_type.should eq("project")
    end
  end

  describe "validation" do
    it "validates project type" do
      options = create_generator_options(custom_options: {"type" => "invalid"})
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      expect_raises(ArgumentError, "Invalid project type") do
        generator.validate_input!
      end
    end

    it "validates database type" do
      options = create_generator_options(custom_options: {"database" => "invalid"})
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      expect_raises(ArgumentError, "Invalid database") do
        generator.validate_input!
      end
    end

    it "validates existing directory without force" do
      options = create_generator_options
      generator = AzuCLI::Generator::ProjectGenerator.new("existing_dir", "existing_dir", options)

      with_temp_directory do
        Dir.mkdir("existing_dir")

        expect_raises(ArgumentError, "already exists") do
          generator.validate_input!
        end
      end
    end

    it "allows overwriting existing directory with force" do
      options = create_generator_options(force: true)
      generator = AzuCLI::Generator::ProjectGenerator.new("existing_dir", "existing_dir", options)

      with_temp_directory do
        Dir.mkdir("existing_dir")

        # Should not raise an error
        generator.validate_input!
      end
    end
  end

  describe "template variable generation" do
    it "generates correct template variables" do
      options = create_generator_options(custom_options: {
        "type"     => "api",
        "database" => "mysql",
      })
      generator = AzuCLI::Generator::ProjectGenerator.new("MyAPI", "my_api", options)

      variables = generator.generate_template_variables

      variables["project"].should eq("MyAPI")
      variables["project_name"].should eq("my_api")
      variables["project_type"].should eq("api")
      variables["database"].should eq("mysql")
      variables["database_url"].should contain("my_api")
      variables["db_driver"].should eq("mysql")
      variables["db_adapter"].should eq("mysql")
    end

    it "handles postgresql database configuration" do
      options = create_generator_options(custom_options: {"database" => "postgresql"})
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      variables = generator.generate_template_variables

      variables["database_url"].should eq("postgresql://localhost/my_app_development")
      variables["db_driver"].should eq("pg")
      variables["db_adapter"].should eq("postgresql")
    end

    it "handles sqlite database configuration" do
      options = create_generator_options(custom_options: {"database" => "sqlite"})
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      variables = generator.generate_template_variables

      variables["database_url"].should eq("sqlite3://./db/my_app_development.db")
      variables["db_driver"].should eq("sqlite3")
      variables["db_adapter"].should eq("sqlite3")
    end
  end

  describe "output path resolution" do
    it "resolves main template path" do
      options = create_generator_options
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      path = generator.resolve_template_output_path("main", "project/project.cr.ecr")
      path.should eq("src/MyApp.cr")
    end

    it "resolves shard template path" do
      options = create_generator_options
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      path = generator.send(:resolve_template_output_path, "shard", "project/shard.yml.ecr")
      path.should eq("shard.yml")
    end

    it "resolves spec template path" do
      options = create_generator_options
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      path = generator.send(:resolve_template_output_path, "spec_main", "project/spec/{{project}}_spec.cr.ecr")
      path.should eq("spec/MyApp_spec.cr")
    end
  end

  describe "project type configuration" do
    it "identifies web project features" do
      options = create_generator_options(custom_options: {"type" => "web"})
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      info = generator.send(:get_project_type_info)
      info[:name].should eq("Full-stack Web Application")
      info[:features].should contain("Endpoints")
      info[:features].should contain("Views")
    end

    it "identifies api project features" do
      options = create_generator_options(custom_options: {"type" => "api"})
      generator = AzuCLI::Generator::ProjectGenerator.new("MyAPI", "my_api", options)

      info = generator.send(:get_project_type_info)
      info[:name].should eq("API-only Application")
      info[:features].should contain("Endpoints")
      info[:features].should_not contain("Views")
    end

    it "determines asset copying for web projects" do
      options = create_generator_options(custom_options: {"type" => "web"})
      generator = AzuCLI::Generator::ProjectGenerator.new("MyApp", "my_app", options)

      generator.send(:should_copy_assets?).should be_true
    end

    it "skips asset copying for api projects" do
      options = create_generator_options(custom_options: {"type" => "api"})
      generator = AzuCLI::Generator::ProjectGenerator.new("MyAPI", "my_api", options)

      generator.send(:should_copy_assets?).should be_false
    end
  end
end
