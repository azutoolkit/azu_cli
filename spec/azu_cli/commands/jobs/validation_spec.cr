require "../../../spec_helper"

describe "jobs command validation" do
  it "rejects invalid worker controls without launching a compiler" do
    [["--workers", "0"], ["--workers", "no"], ["--workers", "1001"], ["--workers"],
     ["--queues", "a,,b"], ["--shutdown-timeout", "0"], ["--daemon"], ["--typo"]].each do |args|
      command = AzuCLI::Commands::Jobs::Worker.new
      command.parse_args(args)
      command.execute.exit_code.should eq(2)
    end
  end

  it "supports equals-style flags and distinguishes UI host from help" do
    worker = AzuCLI::Commands::Jobs::Worker.new
    worker.parse_args(["--workers=6", "--queues=mailers,reports"])
    worker.workers.should eq(6)
    worker.queues.should eq(["mailers", "reports"])
    ui = AzuCLI::Commands::Jobs::UI.new
    ui.parse_args(["-h", "127.0.0.1", "--port=5000"])
    ui.host.should eq("127.0.0.1")
    ui.port.should eq(5000)
  end

  it "prints help without connecting to Redis or requiring an application" do
    [AzuCLI::Commands::Jobs::Status.new, AzuCLI::Commands::Jobs::Worker.new,
     AzuCLI::Commands::Jobs::Clear.new, AzuCLI::Commands::Jobs::Retry.new,
     AzuCLI::Commands::Jobs::DLQ.new, AzuCLI::Commands::Jobs::Pause.new,
     AzuCLI::Commands::Jobs::Resume.new, AzuCLI::Commands::Jobs::UI.new].each do |command|
      output = IO::Memory.new
      command.stdout = output
      command.parse_args(["--help"])
      command.execute.success?.should be_true
      output.to_s.should contain("Usage: azu #{command.name}")
    end
  end

  it "rejects ambiguous destructive scopes and invalid DLQ limits" do
    clear = AzuCLI::Commands::Jobs::Clear.new
    clear.parse_args(["--all", "--queue=default", "--force"])
    clear.execute.exit_code.should eq(2)
    [["--limit=-1"], ["--limit=1001"], ["--all", "--limit=2"]].each do |args|
      retry_command = AzuCLI::Commands::Jobs::Retry.new
      retry_command.parse_args(args + ["--force"])
      retry_command.execute.exit_code.should eq(2)
    end
    dlq = AzuCLI::Commands::Jobs::DLQ.new
    dlq.parse_args(["--offset=-1"])
    dlq.execute.exit_code.should eq(2)
  end

  it "reports missing JoobQUI and boot files as failures" do
    ui = AzuCLI::Commands::Jobs::UI.new
    ui.parse_args(["--path=/missing/joobqui"])
    ui.execute.success?.should be_false
    status = AzuCLI::Commands::Jobs::Status.new
    status.parse_args(["--boot=/missing/initializer.cr"])
    status.execute.success?.should be_false
  end
end
