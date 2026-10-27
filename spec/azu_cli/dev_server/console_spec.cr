require "../../spec_helper"

private alias TUI = AzuCLI::UI
private alias Ev = AzuCLI::DevServer::Events
private alias Console = AzuCLI::DevServer::Console

private record Evaluation, id : Int32, code : String, prelude : Array(String), declaration : Bool, kept : Array(String)

private def console_hud(evaluations : Array(Evaluation), history = Console::History.new(nil), interpreter_runs = [] of Array(String))
  screen = AzuCLI::DevServer::Hud.new("blog", "4000", "development", "watching src", directory: "/work/blog", commands: [] of AzuCLI::DevServer::Control::Command,
    history: history,
    on_eval: ->(id : Int32, code : String, prelude : Array(String), declaration : Bool, kept : Array(String)) { evaluations << Evaluation.new(id, code, prelude, declaration, kept); nil },
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

private def finished(id : Int32, output : String, exit_code = 0)
  script, offset = Console.script("./src/blog.cr", [] of String, "x", false)
  Ev::ConsoleFinished.new(id, exit_code, "#{Console::START}\n#{output}", 1.5, Console::SCRIPT, offset)
end

private def render(screen, width = 110, height = 30) : String
  frame = TUI::Frame.new(width, height, TUI::StyleTable.new(TUI::Theme.new(TUI::ColorDepth::None)))
  screen.view(frame)
  frame.to_text
end

describe AzuCLI::DevServer::Console do
  it "wraps an expression so the run answers its value, after the declarations and the kept assignments" do
    script, offset = Console.script("./src/blog.cr", ["def titles\n  [] of String\nend"], "Post.count", false, ["post = Post.first"])
    script.should start_with "require \"./src/blog.cr\"\ndef titles"
    script.should contain "post = Post.first\nputs \"#{Console::START}\"\n__azu_console_value = begin\nPost.count\nend\n"
    script.should contain "__azu_console_value.inspect"
    script.lines[offset].should eq "Post.count"
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

  it "reads the value, what the snippet printed, a crash, and a compile error at the snippet's line" do
    output = "#{Console::START}\nhello\n\n#{Console::MARKER}42\n"
    Console.outcome(0, "kept code print\n" + output, Console::SCRIPT, 3).should eq Console::Outcome.new(true, ["hello"], "42", nil)
    crash = Console.outcome(1, "#{Console::START}\nUnhandled exception: Not found (CQL::RecordNotFound)\n  from x.cr:1", Console::SCRIPT, 3)
    crash.error.should eq "Not found (CQL::RecordNotFound)"
    compile = Console.outcome(1, "In #{Console::SCRIPT}:5:1\n\n 5 | nope\n     ^---\nError: undefined local variable or method 'nope' for top-level\n", Console::SCRIPT, 4)
    compile.error.should eq "line 1: undefined local variable or method 'nope' for top-level"
    app = Console.outcome(1, "In src/models/post.cr:12:3\n\nError: undefined method 'titel'\n", Console::SCRIPT, 4)
    app.error.should eq "src/models/post.cr:12: undefined method 'titel'"
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
    screen.update(finished(1, "#{Console::MARKER}declared"))
    type(screen, "post = Post.first")
    enter(screen)
    screen.update(finished(2, "#{Console::MARKER}#<Post id=1>"))
    type(screen, "extra = Post.create!(title: \"x\")")
    enter(screen)
    screen.update(finished(3, "#{Console::MARKER}#<Post id=2>"))
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
