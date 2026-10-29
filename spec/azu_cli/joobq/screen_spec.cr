require "../../spec_helper"

private alias JUI = AzuCLI::UI
private alias Dashboard = AzuCLI::JoobQDashboard

private def jobs_snapshot(ids : Array(String))
  Dashboard::Snapshot.new(JSON.parse({v: 1, replay_supported: true, dlq: ids.map { |id| {jid: id, queue: "mail", error: "failed"} },
                                      queues: [{name: "mail", pending: 10, processing: 2, rate: 1.0}],
                                      workers: [{id: "worker-1", queues: ["mail"], fibers_active: 2, concurrency: 3}],
                                      workflows: [{id: "w1", name: "Order", status: "Running", steps: [{id: "charge", status: "Completed", attempt: 1}, {id: "ship", status: "Running", attempt: 1, depends_on: ["charge"]}]}]}.to_json))
end

describe Dashboard::Screen do
  it "requires confirmation and replays the original selection despite new snapshots" do
    requested = [] of String
    screen = Dashboard::Screen.new(->(id : String) { requested << id; nil })
    screen.update(jobs_snapshot(["first", "second"]))
    screen.update(JUI::Key.new(JUI::KeyCode::Char, '3'))
    screen.update(JUI::Key.new(JUI::KeyCode::Char, 'r'))
    requested.should be_empty
    screen.update(jobs_snapshot(["new", "second"]))
    screen.update(JUI::Key.new(JUI::KeyCode::Char, 'y'))
    requested.should eq ["first"]
    screen.busy?.should be_true
    screen.update(JUI::Key.new(JUI::KeyCode::Char, 'r'))
    screen.confirming.should be_nil
    screen.update(Dashboard::Notice.new("Replay first succeeded", completed: true))
    screen.busy?.should be_false
  end

  it "renders worker metrics, DAG step states and bounded detail panes" do
    screen = Dashboard::Screen.new
    screen.update(jobs_snapshot(["job"]))
    frame = JUI::Frame.new(120, 28, JUI::StyleTable.new(JUI::Theme.new(JUI::ColorDepth::None)))
    screen.view(frame)
    frame.to_text.should contain "worker-1"
    frame.to_text.should contain "1.0 jobs/s"
    screen.update(JUI::Key.new(JUI::KeyCode::Char, '2'))
    screen.view(frame)
    frame.to_text.should contain "ship [Running]"
    frame.to_text.should contain "after: charge"
    screen.update(JUI::Key.new(JUI::KeyCode::CtrlC)).should eq JUI::Action::Quit
  end

  it "distinguishes unavailable worker metrics from zero workers" do
    screen = Dashboard::Screen.new
    screen.update(Dashboard::Snapshot.new(JSON.parse(%({"queues":[],"workers":null,"replay_supported":false}))))
    frame = JUI::Frame.new(120, 28, JUI::StyleTable.new(JUI::Theme.new(JUI::ColorDepth::None)))
    screen.view(frame)
    frame.to_text.should contain "Workers · unavailable"
  end

  it "registers a standalone command and quotes the boot path as Crystal source" do
    File.read("src/azu_cli/cli.cr").should contain %(register_command("joobq", Commands::JoobQ))
    script = Dashboard::ProcessSource.script("a\"b.cr")
    script.should contain "./a\"b.cr".inspect
    AzuCLI::Commands::JoobQ.new.name.should eq "joobq"
  end
end
