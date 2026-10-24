require "../../spec_helper"

describe AzuCLI::DevServer::Builder do
  it "streams the compiler's output as it comes and keeps it" do
    sink = IO::Memory.new
    result = AzuCLI::DevServer::Builder.new("sh", ["-c", "echo compiling; echo 'Error: boom' >&2; exit 0"]).build(sink: sink)

    result.success.should be_true
    sink.to_s.should contain("compiling")
    sink.to_s.should contain("Error: boom")
    result.output.should eq sink.to_s
    result.seconds.should be >= 0
  end

  it "reports a failed build with its output" do
    sink = IO::Memory.new
    result = AzuCLI::DevServer::Builder.new("sh", ["-c", "echo 'In src/a.cr:1' >&2; exit 1"]).build(sink: sink)

    result.success.should be_false
    result.output.should contain("In src/a.cr:1")
  end

  it "stops a build in progress when cancelled" do
    builder = AzuCLI::DevServer::Builder.new("sh", ["-c", "sleep 30; true"])
    spawn do
      sleep 200.milliseconds
      builder.cancel
    end
    started = Time.instant
    result = builder.build(sink: IO::Memory.new)

    result.success.should be_false
    (Time.instant - started).should be < 10.seconds
  end

  it "does not start a build that was cancelled before it began" do
    builder = AzuCLI::DevServer::Builder.new("sh", ["-c", "touch #{File.join(Dir.tempdir, "azu_cancelled_#{Process.pid}")}"])
    builder.cancel
    result = builder.build(sink: IO::Memory.new)

    result.cancelled.should be_true
    result.success.should be_false
    File.exists?(File.join(Dir.tempdir, "azu_cancelled_#{Process.pid}")).should be_false
  end

  it "reports a command that cannot be run instead of raising" do
    result = AzuCLI::DevServer::Builder.new("azu-no-such-command", [] of String).build(sink: IO::Memory.new)

    result.success.should be_false
    result.output.should contain("could not run azu-no-such-command")
  end
end

describe AzuCLI::DevServer::Child do
  it "starts a process with the given environment and stops it with SIGTERM" do
    dir = File.join(Dir.tempdir, "azu_child_#{Process.pid}")
    Dir.mkdir_p(dir)
    script = File.join(dir, "app.sh")
    File.write(script, "#!/bin/sh\necho \"$PORT\" > #{dir}/port\ntrap 'echo term > #{dir}/term; exit 0' TERM\nwhile true; do sleep 0.1; done\n")
    File.chmod(script, 0o755)

    child = AzuCLI::DevServer::Child.new(script, {"PORT" => "4321"})
    child.pid.should be_nil
    child.start
    child.running?.should be_true
    child.pid.should_not be_nil
    sleep 500.milliseconds
    File.read(File.join(dir, "port")).strip.should eq "4321"

    child.stop
    child.running?.should be_false
    # it got SIGTERM and could clean up
    File.read(File.join(dir, "term")).strip.should eq "term"
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  it "kills a process that ignores SIGTERM once the grace time is over" do
    dir = File.join(Dir.tempdir, "azu_child_kill_#{Process.pid}")
    Dir.mkdir_p(dir)
    script = File.join(dir, "stubborn.sh")
    File.write(script, "#!/bin/sh\ntrap '' TERM\nwhile true; do sleep 0.1; done\n")
    File.chmod(script, 0o755)

    child = AzuCLI::DevServer::Child.new(script, {} of String => String, grace: 300.milliseconds)
    child.start
    sleep 200.milliseconds
    started = Time.instant
    child.stop

    child.running?.should be_false
    (Time.instant - started).should be < 5.seconds
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  it "reports once that the app exited by itself, with its exit code" do
    child = AzuCLI::DevServer::Child.new("sh", {} of String => String)
    child.start # `sh` with no input (stdin closed) exits right away
    sleep 300.milliseconds

    status = child.exited
    status.should_not be_nil
    child.exited.should be_nil
  end

  it "restarts: the old process is gone before the new one starts" do
    child = AzuCLI::DevServer::Child.new("sleep", {} of String => String, ["30"])
    child.start
    first = child.pid
    child.restart

    child.running?.should be_true
    child.pid.should_not eq first
    child.stop
  end
end

# A process that was killed but not yet reaped (its parent is gone and PID 1 of a container may never wait for it)
# still has a /proc entry, in state Z; it is not running. Only a missing entry (or the zombie state) means gone: a
# read that is merely refused (hidepid) says nothing.
private def gone?(pid : Int64) : Bool
  return !Process.exists?(pid) unless Dir.exists?("/proc/self")

  stat = File.read("/proc/#{pid}/stat")
  stat[(stat.rindex(')') || 0) + 1..].split[0]? == "Z"
rescue File::NotFoundError
  true
rescue File::Error
  false
end

private def gone_within?(pids : Array(Int64), timeout : Time::Span) : Bool
  deadline = Time.instant + timeout
  until pids.all? { |pid| gone?(pid) }
    return false if Time.instant > deadline

    sleep 50.milliseconds
  end
  true
end

describe AzuCLI::ProcessTree do
  it "terminates a process together with the processes it started" do
    parent = Process.new("sh", ["-c", "sleep 30; true"])
    sleep 300.milliseconds
    children = AzuCLI::ProcessTree.descendants(parent.pid)
    AzuCLI::ProcessTree.terminate(parent)
    parent.wait

    children.should_not be_empty
    gone_within?(children, 5.seconds).should be_true
  end

  it "reaches grandchildren" do
    parent = Process.new("sh", ["-c", "sh -c 'sleep 30; true'; true"])
    sleep 500.milliseconds
    descendants = AzuCLI::ProcessTree.descendants(parent.pid)
    AzuCLI::ProcessTree.terminate(parent)
    parent.wait

    descendants.size.should be >= 2
    gone_within?(descendants, 5.seconds).should be_true
  end

  it "never walks from init or from pid 0" do
    AzuCLI::ProcessTree.descendants(0_i64).should be_empty
    AzuCLI::ProcessTree.descendants(1_i64).should be_empty
    AzuCLI::ProcessTree.children_of(1_i64).should be_empty
  end

  it "reads the children out of `ps -A -o pid=,ppid=` for hosts without pgrep and /proc" do
    text = "    1     0\n  100     1\n  200   100\n  300   100\n  400   200\njunk\n"
    AzuCLI::ProcessTree.parse_ps(text, 100_i64).should eq [200_i64, 300_i64]
  end

  {% if flag?(:linux) %}
    it "finds the children of a process through /proc, for hosts without pgrep" do
      parent = Process.new("sh", ["-c", "sleep 5; true"])
      sleep 300.milliseconds
      found = AzuCLI::ProcessTree.proc_children_of(parent.pid)
      parent.terminate
      found.should_not be_empty
      found.each { |pid| Process.signal(Signal::TERM, pid) rescue nil }
      parent.wait
    end
  {% end %}
end
