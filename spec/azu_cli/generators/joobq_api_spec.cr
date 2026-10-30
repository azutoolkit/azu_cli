require "../../spec_helper"
require "file_utils"
require "teeplate"

# The JoobQ code the generators write must use the API of the release generated projects pin (joobq ~> 0.5.0).
# scripts/e2e_generated_app.sh compiles it; these catch the calls 0.5.0 does not have before a compile does.
private def render_joobq_code(&)
  dir = File.tempname("azu_joobq_api")
  Dir.mkdir_p(dir)
  AzuCLI::Generate::Project.new("blog", "Blog", "Jane", "jane@example.com", project_type: "web").render(File.join(dir, "new"))
  AzuCLI::Generate::JoobQ.new("blog").render(File.join(dir, "joobq"))
  AzuCLI::Generate::Job.new("SendEmail", {"to" => "string"}).render(File.join(dir, "job"))
  AzuCLI::Generate::Job.new("Cleanup").render(File.join(dir, "job"))
  AzuCLI::Generate::Mailer.new("User", ["welcome"]).render(File.join(dir, "mailer"))
  files = Dir.glob("#{dir}/**/*.cr").to_h { |file| {file.sub(dir, ""), File.read(file)} }
  yield files.select { |path, _| path.matches?(/job|joobq|worker|mailer/) }
ensure
  FileUtils.rm_rf(dir) if dir
end

describe "Generated JoobQ code" do
  it "calls only what joobq 0.5.0 has" do
    render_joobq_code do |files|
      files.keys.any?(&.ends_with?("worker.cr")).should be_true
      files.keys.any?(&.ends_with?("send_email_job.cr")).should be_true
      files.each do |path, code|
        {"schedule(in:", ".redis_url", "Worker.start", "perform_later", "perform_async", "JoobQ.start", "total_seconds.to_i", "def initialize()"}.each do |call|
          fail "#{path} calls #{call}" if code.includes?(call)
        end
      end
    end
  end

  it "starts the workers with JoobQ.forge and expires jobs at a Unix time in milliseconds" do
    render_joobq_code do |files|
      files.select { |path, _| path.ends_with?("worker.cr") }.each_value(&.should(contain("JoobQ.forge")))
      files.select { |path, _| path.ends_with?("_job.cr") }.each_value(&.should(match(/@expires = \d+\.\w+\.from_now\.to_unix_ms/)))
      files.find! { |path, _| path.ends_with?("send_email_job.cr") }[1].should contain("SendEmailJob.delay(for: 5.minutes, to: value)")
    end
  end

  # JoobQ.forge starts QueueFactory.queues, built from config.queue_configs; the `queue` macro of JoobQ.configure
  # fills config.queues, which forge never reads. Every store (enqueue, delay, the workers) reads REDIS_HOST/PORT/PASS.
  it "gives the workers queues that forge starts, and one Redis, set before joobq builds a store" do
    render_joobq_code do |files|
      initializers = files.select { |path, _| path.ends_with?("initializers/joobq.cr") }
      initializers.size.should eq(2)
      initializers.each do |path, code|
        code.should_not match(/^\s*queue\s+"/m)
        code.should_not contain("config.store =")
        code.should_not contain(%(URI.parse(ENV["REDIS_URL"])))
      end
      files.find! { |path, _| path.ends_with?("/joobq/src/initializers/joobq.cr") }[1].should contain(%(JoobQ.config.queue_configs["default"] = {job_class_name: "ExampleJob", workers: 3, throttle: nil}))
      files.select { |path, _| path.ends_with?("worker.cr") }.each_value do |code|
        code.should contain("JoobQ.forge")
        code.should_not contain("signal.trap")
      end
    end
  end

  it "refuses a --redis URL it would have to write a password or garbage for" do
    AzuCLI::Generate::JoobQ.redis_url_error("redis://cache:6380").should be_nil
    AzuCLI::Generate::JoobQ.redis_url_error("redis://:secret@cache:6380").not_nil!.should contain("password")
    AzuCLI::Generate::JoobQ.redis_url_error("redis://user:secret@cache").not_nil!.should contain("password")
    AzuCLI::Generate::JoobQ.redis_url_error("cache:6379").not_nil!.should contain("Invalid Redis URL")
  end

  it "pins joobq to the release the generated code is written for" do
    dir = File.tempname("azu_joobq_pin")
    AzuCLI::Generate::Project.new("blog", "Blog", "Jane", "jane@example.com").render(dir)
    File.read(File.join(dir, "shard.yml")).should contain("  joobq:\n    github: azutoolkit/joobq\n    version: ~> 0.5.0\n")
  ensure
    FileUtils.rm_rf(dir) if dir
  end
end
