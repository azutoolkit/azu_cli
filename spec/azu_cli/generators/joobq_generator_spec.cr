require "../../spec_helper"
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
end
