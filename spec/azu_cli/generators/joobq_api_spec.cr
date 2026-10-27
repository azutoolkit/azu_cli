require "../../spec_helper"
require "file_utils"
require "teeplate"

# The JoobQ code the generators write must use the API of the release generated projects pin (joobq ~> 0.4.2).
# scripts/e2e_generated_app.sh compiles it; these catch the calls 0.4.2 does not have before a compile does.
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
  it "calls only what joobq 0.4.2 has" do
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

  it "starts the queues of JoobQ.queues and of JoobQ.config.queues, and expires jobs at a Unix time in milliseconds" do
    render_joobq_code do |files|
      # JoobQ.forge (0.4.2) starts only JoobQ.queues, so a queue declared with `queue` would never run
      files.select { |path, _| path.ends_with?("worker.cr") }.each_value do |code|
        code.should contain("JoobQ.queues.merge(JoobQ.config.queues).each_value(&.start)")
        code.should contain("Signal::TERM.trap")
        code.should_not contain("JoobQ.forge")
      end
      # REDIS_URL reaches both the store and RedisStore.instance (the delayed-job scheduler) through the environment
      files.select { |path, _| path.ends_with?("initializers/joobq.cr") }.each_value do |code|
        code.should contain(%(ENV["REDIS_PORT"]))
        code.should_not contain("RedisStore.new")
      end
      files.select { |path, _| path.ends_with?("_job.cr") }.each_value(&.should(match(/@expires = \d+\.\w+\.from_now\.to_unix_ms/)))
      files.find! { |path, _| path.ends_with?("send_email_job.cr") }[1].should contain("SendEmailJob.delay(for: 5.minutes, to: value)")
    end
  end

  it "pins joobq to the release the generated code is written for" do
    dir = File.tempname("azu_joobq_pin")
    AzuCLI::Generate::Project.new("blog", "Blog", "Jane", "jane@example.com").render(dir)
    File.read(File.join(dir, "shard.yml")).should contain("  joobq:\n    github: azutoolkit/joobq\n    version: ~> 0.4.2\n")
  ensure
    FileUtils.rm_rf(dir) if dir
  end
end
