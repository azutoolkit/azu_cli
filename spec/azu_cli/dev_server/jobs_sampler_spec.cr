require "../../spec_helper"
require "file_utils"

# A RESP server keeps these protocol regressions independent of an installed Redis.
private def jobs_redis(replies : Array(String), &)
  server = TCPServer.new("127.0.0.1", 0)
  commands = Channel(Array(Array(String))).new(1)
  spawn do
    seen = [] of Array(String)
    socket = server.accept
    begin
      replies.each do |reply|
        count = socket.gets.not_nil![1..].to_i
        command = Array(String).new(count) do
          length = socket.gets.not_nil![1..].to_i
          value = Bytes.new(length)
          socket.read_fully(value)
          socket.gets
          String.new(value)
        end
        seen << command
        socket << reply
        socket.flush
      end
      commands.send(seen)
    ensure
      socket.close
    end
  end
  yield "redis://127.0.0.1:#{server.local_address.port}", commands
ensure
  server.try(&.close)
end

describe AzuCLI::DevServer::JobsSampler do
  it "reads actual JoobQ keys, indexed DLQ counts and cumulative completions" do
    jobs_redis([":3\r\n", ":1\r\n", "$1\r\n2\r\n", "$2\r\n42\r\n"]) do |url, commands|
      sample = AzuCLI::DevServer::JobsSampler.new(["mailers"], url).sample
      sample.error.should be_nil
      queue = sample.queues.first
      {queue.pending, queue.processing, queue.failed, queue.completed}.should eq({3, 1, 2, 42})
      commands.receive.should eq([
        ["LLEN", "mailers"], ["LLEN", "joobq:processing:mailers"],
        ["HGET", "joobq:dead_letter:counts", "mailers"], ["HGET", "joobq:stats:completed", "mailers"],
      ])
    end
  end

  it "reports zero for queues with no stored counters" do
    jobs_redis([":0\r\n", ":0\r\n", "$-1\r\n", "$-1\r\n"]) do |url, commands|
      sample = AzuCLI::DevServer::JobsSampler.new(["default"], url).sample
      sample.error.should be_nil
      sample.queues.first.completed.should eq(0)
      sample.queues.first.failed.should eq(0)
      commands.receive
    end
  end

  it "reports a failed Redis sample instead of presenting zero activity" do
    jobs_redis(["-WRONGTYPE unexpected value\r\n", ":0\r\n", "$-1\r\n", "$-1\r\n"]) do |url, commands|
      sample = AzuCLI::DevServer::JobsSampler.new(["default"], url).sample
      sample.queues.should be_empty
      sample.error.to_s.should contain("metrics unavailable")
      commands.receive
    end
  end

  it "discovers environment-specific queues before the legacy jobs manifest" do
    directory = File.join(Dir.tempdir, "azu-jobs-#{Random::Secure.hex(8)}")
    Dir.mkdir_p(File.join(directory, "config"))
    environment = ENV["JOOBQ_ENV"]? || ENV["RACK_ENV"]? || ENV["CRYSTAL_ENV"]? || "development"
    File.write(File.join(directory, "config", "jobs.yml"), "joobq:\n  queues:\n    default: {}\n")
    Dir.cd(directory) do
      AzuCLI::DevServer::JobsSampler.queues.should eq(["default"])
      File.write("config/joobq.#{environment}.yml", "joobq:\n  queues:\n    mailers: {}\n")
      AzuCLI::DevServer::JobsSampler.queues.should eq(["mailers"])
      AzuCLI::DevServer::JobsSampler.queues("config/jobs.yml").should eq(["default"])
    end
  ensure
    FileUtils.rm_rf(directory) if directory
  end

  it "renders completed jobs and distinguishes Redis connectivity from worker liveness" do
    screen = AzuCLI::DevServer::MissionControl.new(AzuCLI::DevServer::Hud.new("store", "4000", "development", ""), "store", true)
    screen.update(AzuCLI::DevServer::Events::JobsSample.new([
      AzuCLI::DevServer::Events::Queue.new("default", 0_i64, 0_i64, 0_i64, 42_i64),
    ]))
    frame = AzuCLI::UI::Frame.new(156, 46, AzuCLI::UI::StyleTable.new(AzuCLI::UI::Theme.new(AzuCLI::UI::ColorDepth::TrueColor)))
    screen.update(AzuCLI::UI::Key.new(AzuCLI::UI::KeyCode::Char, '0'))
    screen.view(frame)
    frame.to_text.should contain("Redis connected")
    frame.to_text.should contain("COMPLETED")
    screen.update(AzuCLI::UI::Key.new(AzuCLI::UI::KeyCode::Char, '0'))
    screen.view(frame)
    frame.to_text.should contain("Completed (cumulative): 42")
    screen.update(AzuCLI::DevServer::Events::JobsSample.new([] of AzuCLI::DevServer::Events::Queue, "metrics unavailable"))
    screen.view(frame)
    frame.to_text.should contain("unavailable")
    frame.to_text.should_not contain("Redis connected")
  end
end
