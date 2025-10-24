require "../../spec_helper"
require "../../support/test_helpers"
require "teeplate"

describe AzuCLI::Generate::JoobQ do
  it "creates a JoobQ generator with default settings" do
    generator = AzuCLI::Generate::JoobQ.new("myapp")

    generator.project_name.should eq("myapp")
    generator.redis_url.should eq("redis://localhost:6379")
    generator.default_queue.should eq("default")
    generator.workers.should eq(3)
    generator.create_example_job.should be_true
  end

  it "creates a JoobQ generator with custom settings" do
    generator = AzuCLI::Generate::JoobQ.new(
      "myapp",
      "redis://production:6379",
      "high_priority",
      5,
      false
    )

    generator.project_name.should eq("myapp")
    generator.redis_url.should eq("redis://production:6379")
    generator.default_queue.should eq("high_priority")
    generator.workers.should eq(5)
    generator.create_example_job.should be_false
  end

  it "generates config file path" do
    generator = AzuCLI::Generate::JoobQ.new("myapp")

    generator.config_file_path.should eq("config/joobq.development.yml")
  end

  it "generates initializer file path" do
    generator = AzuCLI::Generate::JoobQ.new("myapp")

    generator.initializer_file_path.should eq("src/initializers/joobq.cr")
  end

  it "generates worker file path" do
    generator = AzuCLI::Generate::JoobQ.new("myapp")

    generator.worker_file_path.should eq("src/worker.cr")
  end

  it "generates jobs directory path" do
    generator = AzuCLI::Generate::JoobQ.new("myapp")

    generator.jobs_directory.should eq("src/jobs")
  end

  it "generates example job name" do
    generator = AzuCLI::Generate::JoobQ.new("myapp")

    generator.example_job_name.should eq("ExampleJob")
  end

  describe "enhanced JoobQ generator testing" do
    describe "configuration file generation" do
      it "generates JoobQ configuration files with correct content" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_config_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          # Check that config file was created
          config_file = "config/joobq.development.yml"
          File.exists?(config_file).should be_true

          content = File.read(config_file)
          content.should contain("redis_url: redis://localhost:6379")
          content.should contain("default_queue: default")
          content.should contain("workers: 3")
        end
      end

      it "generates JoobQ configuration with custom settings" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_config_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp", "redis://production:6379", "high_priority", 5, false)
          generator.render(".")

          config_file = "config/joobq.development.yml"
          content = File.read(config_file)

          content.should contain("redis_url: redis://production:6379")
          content.should contain("default_queue: high_priority")
          content.should contain("workers: 5")
        end
      end

      it "generates production configuration file" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_config_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          # Check that production config was also created
          prod_config_file = "config/joobq.production.yml"
          File.exists?(prod_config_file).should be_true

          content = File.read(prod_config_file)
          content.should contain("redis_url:")
          content.should contain("default_queue:")
          content.should contain("workers:")
        end
      end
    end

    describe "initializer file generation" do
      it "generates JoobQ initializer with correct content" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/initializers")

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          # Check that initializer file was created
          initializer_file = "src/initializers/joobq.cr"
          File.exists?(initializer_file).should be_true

          content = File.read(initializer_file)
          content.should contain("require \"joobq\"")
          content.should contain("JoobQ.configure")
          content.should contain("redis_url:")
        end
      end

      it "generates initializer with custom Redis URL" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/initializers")

          generator = AzuCLI::Generate::JoobQ.new("myapp", "redis://custom:6379")
          generator.render(".")

          initializer_file = "src/initializers/joobq.cr"
          content = File.read(initializer_file)

          content.should contain("redis_url: \"redis://custom:6379\"")
        end
      end

      it "generates initializer with custom queue settings" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/initializers")

          generator = AzuCLI::Generate::JoobQ.new("myapp", "redis://localhost:6379", "priority", 5)
          generator.render(".")

          initializer_file = "src/initializers/joobq.cr"
          content = File.read(initializer_file)

          content.should contain("default_queue: \"priority\"")
          content.should contain("workers: 5")
        end
      end
    end

    describe "worker file generation" do
      it "generates worker file with correct content" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          # Check that worker file was created
          worker_file = "src/worker.cr"
          File.exists?(worker_file).should be_true

          content = File.read(worker_file)
          content.should contain("require \"joobq\"")
          content.should contain("require \"./initializers/joobq\"")
          content.should contain("JoobQ::Worker.start")
        end
      end

      it "generates worker file with job requires" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::JoobQ.new("myapp", create_example_job: true)
          generator.render(".")

          worker_file = "src/worker.cr"
          content = File.read(worker_file)

          content.should contain("require \"./jobs/example_job\"")
        end
      end

      it "generates worker file without example job when disabled" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp", create_example_job: false)
          generator.render(".")

          worker_file = "src/worker.cr"
          content = File.read(worker_file)

          content.should_not contain("require \"./jobs/example_job\"")
        end
      end
    end

    describe "example job generation" do
      it "generates example job when enabled" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::JoobQ.new("myapp", create_example_job: true)
          generator.render(".")

          # Check that example job was created
          example_job_file = "src/jobs/example_job.cr"
          File.exists?(example_job_file).should be_true

          content = File.read(example_job_file)
          content.should contain("struct ExampleJob")
          content.should contain("include JoobQ::Job")
          content.should contain("def perform")
        end
      end

      it "does not generate example job when disabled" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::JoobQ.new("myapp", create_example_job: false)
          generator.render(".")

          # Check that example job was not created
          example_job_file = "src/jobs/example_job.cr"
          File.exists?(example_job_file).should be_false
        end
      end

      it "generates example job with proper configuration" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::JoobQ.new("myapp", create_example_job: true)
          generator.render(".")

          example_job_file = "src/jobs/example_job.cr"
          content = File.read(example_job_file)

          content.should contain("@queue = \"default\"")
          content.should contain("@retries = 3")
          content.should contain("@expires = 1.day.total_seconds.to_i")
        end
      end
    end

    describe "directory structure creation" do
      it "creates proper directory structure for JoobQ" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          # Check that all required directories exist
          Dir.exists?("src/jobs").should be_true
          Dir.exists?("src/initializers").should be_true
          Dir.exists?("config").should be_true
        end
      end

      it "creates jobs directory if it doesn't exist" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp", create_example_job: true)
          generator.render(".")

          # Check that jobs directory was created
          Dir.exists?("src/jobs").should be_true

          # Check that example job was created
          File.exists?("src/jobs/example_job.cr").should be_true
        end
      end

      it "creates initializers directory if it doesn't exist" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          # Check that initializers directory was created
          Dir.exists?("src/initializers").should be_true

          # Check that initializer file was created
          File.exists?("src/initializers/joobq.cr").should be_true
        end
      end
    end

    describe "environment-specific configuration" do
      it "generates development configuration" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_config_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          dev_config_file = "config/joobq.development.yml"
          content = File.read(dev_config_file)

          content.should contain("redis_url: redis://localhost:6379")
          content.should contain("default_queue: default")
          content.should contain("workers: 3")
        end
      end

      it "generates production configuration" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_config_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          prod_config_file = "config/joobq.production.yml"
          content = File.read(prod_config_file)

          content.should contain("redis_url:")
          content.should contain("default_queue:")
          content.should contain("workers:")
        end
      end

      it "generates test configuration" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_config_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          test_config_file = "config/joobq.test.yml"
          content = File.read(test_config_file)

          content.should contain("redis_url:")
          content.should contain("default_queue:")
          content.should contain("workers:")
        end
      end
    end

    describe "integration with Azu framework" do
      it "generates initializer that integrates with Azu" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/initializers")

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          initializer_file = "src/initializers/joobq.cr"
          content = File.read(initializer_file)

          content.should contain("require \"joobq\"")
          content.should contain("JoobQ.configure")
        end
      end

      it "generates worker that can be started independently" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp")
          generator.render(".")

          worker_file = "src/worker.cr"
          content = File.read(worker_file)

          content.should contain("JoobQ::Worker.start")
        end
      end
    end

    describe "customization and extensibility" do
      it "allows custom Redis URL configuration" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_config_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp", "redis://custom-host:6380")
          generator.render(".")

          config_file = "config/joobq.development.yml"
          content = File.read(config_file)

          content.should contain("redis_url: redis://custom-host:6380")
        end
      end

      it "allows custom queue configuration" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_config_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp", "redis://localhost:6379", "custom_queue")
          generator.render(".")

          config_file = "config/joobq.development.yml"
          content = File.read(config_file)

          content.should contain("default_queue: custom_queue")
        end
      end

      it "allows custom worker count" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_config_dir

          generator = AzuCLI::Generate::JoobQ.new("myapp", "redis://localhost:6379", "default", 10)
          generator.render(".")

          config_file = "config/joobq.development.yml"
          content = File.read(config_file)

          content.should contain("workers: 10")
        end
      end
    end
  end
end
