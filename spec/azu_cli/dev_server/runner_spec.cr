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
    File.read(File.join(dir, "term")).strip.should eq "term" # it got SIGTERM and could clean up
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
