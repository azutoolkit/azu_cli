require "../../spec_helper"

private alias TUI = AzuCLI::UI
private alias Ev = AzuCLI::DevServer::Events
private alias Console = AzuCLI::DevServer::Console

private record Evaluation, snippets : Array(AzuCLI::DevServer::Console::Snippet), prelude : Array(String), kept : Array(String) do
  def code : String
    snippets.last.code
  end

  def declaration : Bool
    snippets.last.declaration
  end
end

private def console_hud(evaluations : Array(Evaluation), history = Console::History.new(nil), interpreter_runs = [] of Array(String))
  screen = AzuCLI::DevServer::Hud.new("blog", "4000", "development", "watching src", directory: "/work/blog", commands: [] of AzuCLI::DevServer::Control::Command,
    history: history,
    on_eval: ->(snippets : Array(Console::Snippet), prelude : Array(String), kept : Array(String)) { evaluations << Evaluation.new(snippets, prelude, kept); nil },
    on_interpreter: ->(prelude : Array(String)) { interpreter_runs << prelude; nil })
  screen.update(TUI::Key.new(TUI::KeyCode::Char, '3'))
  screen
end

private def type(screen, text : String)
  text.each_char { |char| screen.update(TUI::Key.new(TUI::KeyCode::Char, char)) }
end

private def enter(screen)
  screen.update(TUI::Key.new(TUI::KeyCode::Enter))
end

# What a batch of one snippet prints when it runs: its value line after the start marker.
private def finished(id : Int32, value : String)
  Ev::ConsoleFinished.new([id], 0, "#{Console::START}\n#{Console::BEGIN}#{id}\n\n#{Console::MARKER}#{id}:#{value}\n", 1.5, Console::Ranges.new)
end

private def render(screen, width = 110, height = 30) : String
  frame = TUI::Frame.new(width, height, TUI::StyleTable.new(TUI::Theme.new(TUI::ColorDepth::None)))
  screen.view(frame)
  frame.to_text
end

describe AzuCLI::DevServer::Console do
  it "puts a batch in one script: declarations first, then the kept assignments, then each expression with its value" do
    snippets = [Console::Snippet.new(1, "post = Post.first", false), Console::Snippet.new(2, "def titles\n  [] of String\nend", true), Console::Snippet.new(3, "post.title", false)]
    script, ranges = Console.script("./src/blog.cr", ["def answer = 42"], ["user = User.first"], snippets)
    lines = script.lines
    lines[0].should eq "require \"./src/blog.cr\""
    lines.index("def answer = 42").not_nil!.should be < lines.index("def titles").not_nil!
    lines.index("def titles").not_nil!.should be < lines.index("user = User.first").not_nil!
    lines.index("user = User.first").not_nil!.should be < lines.index("puts \"#{Console::START}\"").not_nil!
    lines.index("post = Post.first").not_nil!.should be < lines.index("post.title").not_nil!
    ranges.to_h[3].should eq (lines.index("post.title").not_nil! + 1)..(lines.index("post.title").not_nil! + 1)
    ranges.to_h[2].size.should eq 3
  end

  it "tells declarations, assignments and writes apart" do
    Console.declaration?("def titles(n = 3)\n  1\nend").should be_true
    Console.declaration?("# a helper\nclass Report\nend").should be_true
    Console.declaration?("Post.count").should be_false
    Console.assignment?("post = Post.first").should be_true
    Console.assignment?("a, b = 1, 2").should be_true
    Console.assignment?("post == other").should be_false
    Console.assignment?("Post.count").should be_false
    Console.writes?("post = Post.create!(title: \"x\")").should be_true
    Console.writes?("post.save").should be_true
    Console.writes?("post = Post.first").should be_false
  end

  it "reads each snippet's value and what it printed, from one run" do
    output = "app log\n#{Console::START}\n#{Console::MARKER}2:declared\n#{Console::BEGIN}1\nhello\n\n#{Console::MARKER}1:42\n#{Console::BEGIN}3\n\n#{Console::MARKER}3:\"x\"\n"
    outcomes = Console.outcomes(0, output, Console::SCRIPT, Console::Ranges.new, [1, 2, 3])
    outcomes[1].should eq Console::Outcome.new(true, ["hello"], "42", nil)
    outcomes[2].not_nil!.value.should eq "declared"
    outcomes[3].not_nil!.value.should eq "\"x\""
  end

  it "fails the snippet that crashed and runs the ones after it again" do
    output = "#{Console::START}\n#{Console::BEGIN}1\n\n#{Console::MARKER}1:1\n#{Console::BEGIN}2\nbefore\nUnhandled exception: Not found (CQL::RecordNotFound)\n  from x.cr:1\n"
    outcomes = Console.outcomes(1, output, Console::SCRIPT, Console::Ranges.new, [1, 2, 3])
    outcomes[1].not_nil!.ok.should be_true
    outcomes[2].should eq Console::Outcome.new(false, ["before"], nil, "Not found (CQL::RecordNotFound)")
    outcomes[3].should be_nil
  end

  it "puts a compile error on the snippet it is in, at that snippet's line, and runs the others again" do
    ranges = Console::Ranges.new
    ranges << {1, 4..4} << {2, 9..10}
    error = "In #{Console::SCRIPT}:10:3\n\n 10 | nope\n     ^---\nError: undefined local variable or method 'nope' for top-level\n"
    outcomes = Console.outcomes(1, error, Console::SCRIPT, ranges, [1, 2])
    outcomes[1].should be_nil
    outcomes[2].not_nil!.error.should eq "line 2: undefined local variable or method 'nope' for top-level"

    app = Console.outcomes(1, "In src/models/post.cr:12:3\n\nError: undefined method 'titel'\n", Console::SCRIPT, ranges, [1, 2])
    app.values.map(&.try(&.error)).should eq ["src/models/post.cr:12: undefined method 'titel'"] * 2
  end

  it "keeps the history in a file, without repeating the last entry" do
    path = File.join(Dir.tempdir, "azu_console_history_#{Random.rand(1_000_000)}")
    history = Console::History.new(path)
    history.add("Post.count")
    history.add("Post.count")
    history.add("post = Post.first")
    Console::History.new(path).entries.should eq ["Post.count", "post = Post.first"]
  ensure
    File.delete?(path) if path
  end
end

describe "AzuCLI::DevServer::Hud console panel" do
  it "runs finished code on Enter and starts a new line for unfinished code" do
    evaluations = [] of Evaluation
    screen = console_hud(evaluations)
    screen.tab.console?.should be_true
    type(screen, "def titles(n = 3)")
    enter(screen)
    evaluations.should be_empty
    type(screen, "Post.all.map(&.title)")
    enter(screen)
    type(screen, "end")
    enter(screen)
    evaluations.size.should eq 1
    evaluations[0].declaration.should be_true
    evaluations[0].code.should eq "def titles(n = 3)\n  Post.all.map(&.title)\nend"
    screen.editor.empty?.should be_true
  end

  it "shows => value, keeps declarations and assignments for the next runs, and refuses to keep a write" do
    evaluations = [] of Evaluation
    screen = console_hud(evaluations)
    type(screen, "def answer = 42")
    enter(screen)
    screen.update(finished(1, "declared"))
    type(screen, "post = Post.first")
    enter(screen)
    screen.update(finished(2, "#<Post id=1>"))
    type(screen, "extra = Post.create!(title: \"x\")")
    enter(screen)
    screen.update(finished(3, "#<Post id=2>"))
    type(screen, "post.title")
    enter(screen)

    evaluations.last.prelude.should eq ["def answer = 42"]
    evaluations.last.kept.should eq ["post = Post.first"]
    text = render(screen)
    text.should contain "blog(dev)> post = Post.first"
    text.should contain "=> #<Post id=1>"
    text.should contain "post kept for the next snippets"
    text.should contain "extra not kept: running it again would write"
    text.should contain "compiling with the app"
    text.should contain "1 kept · 1 declared"
  end

  it "walks the history with up and down, and leaves the keyboard to the panels with Esc" do
    evaluations = [] of Evaluation
    history = Console::History.new(nil)
    history.add("Post.count")
    history.add("post = Post.first")
    screen = console_hud(evaluations, history)
    screen.update(TUI::Key.new(TUI::KeyCode::Up))
    screen.editor.text.should eq "post = Post.first"
    screen.update(TUI::Key.new(TUI::KeyCode::Up))
    screen.editor.text.should eq "Post.count"
    screen.update(TUI::Key.new(TUI::KeyCode::Down))
    screen.update(TUI::Key.new(TUI::KeyCode::Down))
    screen.editor.empty?.should be_true

    type(screen, "q")
    screen.editor.text.should eq "q" # q types while the console has the keyboard
    screen.update(TUI::Key.new(TUI::KeyCode::Esc))
    screen.console_focus?.should be_false
    screen.update(TUI::Key.new(TUI::KeyCode::Char, 'q')).should eq TUI::Action::Quit
  end

  it "answers help, locals and forget itself, without running anything" do
    evaluations = [] of Evaluation
    screen = console_hud(evaluations)
    type(screen, "help")
    enter(screen)
    evaluations.should be_empty
    render(screen).should contain "like rails console"
  end

  it "hands the terminal to crystal i with the declarations when the compiler has it, and explains when not" do
    evaluations = [] of Evaluation
    runs = [] of Array(String)
    screen = console_hud(evaluations, interpreter_runs: runs)
    screen.update(Ev::InterpreterProbe.new(false))
    screen.update(TUI::Key.new(TUI::KeyCode::CtrlO)).should eq TUI::Action::Redraw
    render(screen).should contain "This Crystal has no interpreter"

    screen.update(Ev::InterpreterProbe.new(true))
    screen.update(TUI::Key.new(TUI::KeyCode::CtrlO)).should eq TUI::Action::Handoff
    screen.handoff.not_nil!.call
    runs.size.should eq 1
    screen.handoff.should be_nil
  end
end

describe "AzuCLI::DevServer::Hud console queue" do
  it "queues what is typed while a compile runs, and sends it all in the next one" do
    evaluations = [] of Evaluation
    screen = console_hud(evaluations)
    type(screen, "Post.count")
    enter(screen)
    type(screen, "post = Post.first")
    enter(screen)
    type(screen, "post.title")
    enter(screen)
    evaluations.size.should eq 1 # the second and third wait for the first compile
    render(screen).should contain "waits: runs with the next compile"

    screen.update(finished(1, "2"))
    evaluations.size.should eq 2
    evaluations[1].snippets.map(&.code).should eq ["post = Post.first", "post.title"]
  end

  it "runs a snippet again when another one of its batch kept it from running" do
    evaluations = [] of Evaluation
    screen = console_hud(evaluations)
    type(screen, "1")
    enter(screen)
    type(screen, "nope")
    enter(screen)
    type(screen, "2")
    enter(screen)
    screen.update(finished(1, "1"))
    ranges = Console::Ranges.new
    ranges << {2, 5..5} << {3, 9..9}
    screen.update(Ev::ConsoleFinished.new([2, 3], 1, "In #{Console::SCRIPT}:5:1\n\nError: undefined local variable or method 'nope' for top-level\n", 3.0, ranges))
    screen.transcript.find! { |entry| entry.id == 2 }.status.fail?.should be_true
    evaluations.last.snippets.map(&.code).should eq ["2"]
  end

  it "warms the compiler up after the app's first build, once, and says so" do
    warmed = 0
    screen = AzuCLI::DevServer::Hud.new("blog", "4000", "development", "watching src", directory: "/work/blog", commands: [] of AzuCLI::DevServer::Control::Command,
      on_prewarm: -> { warmed += 1; nil })
    screen.update(TUI::Key.new(TUI::KeyCode::Char, '3'))
    render(screen).should contain "waits for the first build"
    screen.update(Ev::BuildFinished.new(true, 4.0, ""))
    screen.update(Ev::BuildFinished.new(true, 4.0, ""))
    warmed.should eq 1
    render(screen).should contain "warming up"
    screen.update(Ev::ConsoleWarm.new(true, 19.0, nil))
    screen.warm.ready?.should be_true
  end

  it "shows the compiler's progress for the running snippets and cancels waiting ones with Esc" do
    evaluations = [] of Evaluation
    cancelled = false
    screen = AzuCLI::DevServer::Hud.new("blog", "4000", "development", "watching src", directory: "/work/blog", commands: [] of AzuCLI::DevServer::Control::Command,
      on_eval: ->(snippets : Array(Console::Snippet), prelude : Array(String), kept : Array(String)) { evaluations << Evaluation.new(snippets, prelude, kept); nil },
      on_cancel_eval: -> { cancelled = true; nil })
    screen.update(TUI::Key.new(TUI::KeyCode::Char, '3'))
    type(screen, "Post.count")
    enter(screen)
    type(screen, "Post.first")
    enter(screen)
    screen.update(Ev::ConsoleProgress.new(AzuCLI::DevServer::CompilerProgress.parse("[9/13] Codegen (bc+obj)").not_nil!, 5.0))
    render(screen).should contain "codegen"
    render(screen).should contain "Codegen (bc+obj)"
    screen.update(TUI::Key.new(TUI::KeyCode::Esc))
    cancelled.should be_true
    screen.transcript.find! { |entry| entry.id == 2 }.error.should eq "cancelled"
    screen.update(Ev::ConsoleFinished.new([1], -1, "#{Console::START}\n#{Console::BEGIN}1\n", 4.0, Console::Ranges.new))
    screen.transcript.find! { |entry| entry.id == 1 }.error.should eq "cancelled"
    screen.evaluating?.should be_false
  end
end
