require "../../spec_helper"

private alias TUI = AzuCLI::UI

private def key(code : TUI::KeyCode, char : Char? = nil)
  TUI::Key.new(code, char)
end

private def render(screen : TUI::Screen, width = 100) : String
  frame = TUI::Frame.new(width, screen.height(width, 40), TUI::StyleTable.new(TUI::Theme.new(TUI::ColorDepth::None)))
  screen.view(frame)
  frame.to_text
end

private def new_command(args : Array(String) = [] of String) : AzuCLI::Commands::New
  command = AzuCLI::Commands::New.new
  command.parse_args(["blog"] + args)
  command.project_name = "blog"
  command
end

describe AzuCLI::UI::Wizard do
  it "walks the steps, skips those that do not apply, and confirms from the review" do
    wizard = AzuCLI::Commands::NewWizard.new(new_command)
    screen = wizard.screen
    4.times { screen.update(key(TUI::KeyCode::Enter)) } # module, author, email, license
    screen.steps[screen.current].label.should eq "Type"
    2.times { screen.update(key(TUI::KeyCode::Down)) } # cli
    screen.update(key(TUI::KeyCode::Enter))
    screen.steps[screen.current].label.should eq "Tests" # a cli project has no database or jobs step
    screen.update(key(TUI::KeyCode::Enter))
    screen.update(key(TUI::KeyCode::Enter))
    screen.reviewing?.should be_true
    screen.update(key(TUI::KeyCode::Enter)).should eq TUI::Action::Quit
    screen.outcome.confirmed?.should be_true
  end

  it "goes back with Shift-Tab and cancels with Esc" do
    screen = AzuCLI::Commands::NewWizard.new(new_command).screen
    screen.update(key(TUI::KeyCode::Enter))
    screen.update(key(TUI::KeyCode::BackTab))
    screen.steps[screen.current].label.should eq "Module"
    screen.update(key(TUI::KeyCode::Esc)).should eq TUI::Action::Quit
    screen.outcome.cancelled?.should be_true
  end

  it "refuses to move on from text that does not validate" do
    screen = AzuCLI::Commands::NewWizard.new(new_command).screen
    6.times { screen.update(key(TUI::KeyCode::Backspace)) } # "Blog" -> ""
    screen.update(key(TUI::KeyCode::Char, 'x'))
    screen.update(key(TUI::KeyCode::Enter))
    screen.steps[screen.current].label.should eq "Module"
    render(screen).should contain "Start with a capital letter"
  end

  it "draws the step, the answers so far and the keys" do
    screen = AzuCLI::Commands::NewWizard.new(new_command).screen
    4.times { screen.update(key(TUI::KeyCode::Enter)) }
    text = render(screen)
    text.should contain "▲ AZU  new · blog"
    text.should contain "step 5 of 9"
    text.should contain "╭─ Wizard "
    text.should contain "● web"
    text.should contain "○ api"
    text.should contain "✔ Module    Blog"
    text.should contain "◆ Type"
    text.should contain "[↑/↓] Move"
  end

  it "applies the answers to the command and writes them as one command line" do
    command = new_command(["--no-git"])
    wizard = AzuCLI::Commands::NewWizard.new(command)
    screen = wizard.screen
    5.times { screen.update(key(TUI::KeyCode::Enter)) } # through the type: web
    2.times { screen.update(key(TUI::KeyCode::Down)) }  # sqlite
    wizard.apply
    command.database.should eq "sqlite"
    command.git_init.should be_false
    line = wizard.command_line
    line.should start_with "azu new blog --module Blog"
    line.should contain "--db sqlite"
    line.should contain "--no-git"
    line.should end_with "--yes"
  end
end
