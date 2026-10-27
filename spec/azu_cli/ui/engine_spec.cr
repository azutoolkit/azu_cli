require "../../spec_helper"

private alias TUI = AzuCLI::UI

private def styles(depth = TUI::ColorDepth::None, glyphs = TUI::Glyphs::UNICODE)
  TUI::StyleTable.new(TUI::Theme.new(depth, glyphs))
end

describe AzuCLI::UI::Width do
  it "counts wide, zero-width and plain characters" do
    TUI::Width.of('a').should eq 1
    TUI::Width.of('✔').should eq 1
    TUI::Width.of('▮').should eq 1
    TUI::Width.of('⚡').should eq 2
    TUI::Width.of('漢').should eq 2
    TUI::Width.of('\u{301}').should eq 0
    TUI::Width.of("a漢b").should eq 4
  end

  it "truncates by display width with an ellipsis and pads to an exact width" do
    TUI::Width.truncate("abcdef", 4).should eq "abc…"
    TUI::Width.truncate("漢字漢字", 5).should eq "漢字…"
    TUI::Width.truncate("abc", 3).should eq "abc"
    TUI::Width.pad("ab", 4).should eq "ab  "
  end
end

describe AzuCLI::UI::Terminal do
  it "picks the color depth from the environment, NO_COLOR first" do
    TUI::Terminal.color_depth(true, {"TERM" => "xterm-256color", "COLORTERM" => "truecolor"}).should eq TUI::ColorDepth::TrueColor
    TUI::Terminal.color_depth(true, {"TERM" => "xterm-256color"}).should eq TUI::ColorDepth::Ansi256
    TUI::Terminal.color_depth(true, {"TERM" => "xterm"}).should eq TUI::ColorDepth::Basic16
    TUI::Terminal.color_depth(true, {"TERM" => "xterm-256color", "NO_COLOR" => "1"}).should eq TUI::ColorDepth::None
    TUI::Terminal.color_depth(true, {"TERM" => "dumb"}).should eq TUI::ColorDepth::None
    TUI::Terminal.color_depth(false, {"TERM" => "xterm-256color"}).should eq TUI::ColorDepth::None
    TUI::Terminal.color_depth(false, {"TERM" => "xterm", "FORCE_COLOR" => "1"}).should eq TUI::ColorDepth::Basic16
  end

  it "falls back to ASCII glyphs outside UTF-8 and in CJK locales" do
    TUI::Terminal.unicode?({"LANG" => "en_US.UTF-8"}).should be_true
    TUI::Terminal.unicode?({"LANG" => "C"}).should be_false
    TUI::Terminal.unicode?({"LANG" => "ja_JP.UTF-8"}).should be_false
    TUI::Terminal.unicode?({"LANG" => "en_US.UTF-8", "AZU_AMBIGUOUS_WIDE" => "1"}).should be_false
    TUI::Terminal.unicode?({"LANG" => "en_US.UTF-8", "TERM" => "dumb"}).should be_false
  end
end

describe AzuCLI::UI::Theme do
  it "writes the escape code of each depth and nothing without color" do
    style = TUI::Style.new(TUI::Token::Cyan, attrs: TUI::Attr::Bold)
    TUI::Theme.new(TUI::ColorDepth::TrueColor).sgr(style).should eq "\e[0;1;38;2;34;211;238m"
    TUI::Theme.new(TUI::ColorDepth::Ansi256).sgr(style).should eq "\e[0;1;38;5;44m"
    TUI::Theme.new(TUI::ColorDepth::Basic16).sgr(style).should eq "\e[0;1;36m"
    TUI::Theme.new(TUI::ColorDepth::None).sgr(style).should eq ""
  end

  it "runs gradients from cyan to purple, and keeps them cyan with 16 colors" do
    theme = TUI::Theme.new(TUI::ColorDepth::TrueColor)
    theme.gradient(0, 10).rgb.should eq theme.rgb(TUI::Token::Cyan)
    theme.gradient(9, 10).rgb.should eq theme.rgb(TUI::Token::Purple)
    TUI::Theme.new(TUI::ColorDepth::Basic16).gradient(5, 10).fg.should eq TUI::Token::Cyan
  end
end

describe AzuCLI::UI::Input do
  it "reads arrows (CSI and SS3), control keys, Shift-Tab and printable text" do
    keys = TUI::Input.parse("\e[A\eOB\e[Z\r\tx\u{3}\u{7f}é")
    keys.map(&.code).should eq [TUI::KeyCode::Up, TUI::KeyCode::Down, TUI::KeyCode::BackTab, TUI::KeyCode::Enter,
                                TUI::KeyCode::Tab, TUI::KeyCode::Char, TUI::KeyCode::CtrlC, TUI::KeyCode::Backspace, TUI::KeyCode::Char]
    keys[5].char.should eq 'x'
    keys[8].char.should eq 'é'
  end

  it "reads a lone ESC as Escape, modified arrows as arrows, and drops unknown sequences" do
    TUI::Input.parse("\e").map(&.code).should eq [TUI::KeyCode::Esc]
    TUI::Input.parse("\e[1;5C").map(&.code).should eq [TUI::KeyCode::Right]
    TUI::Input.parse("\e[99zq").map(&.code).should eq [TUI::KeyCode::Char]
  end

  it "keeps a bracketed paste as one key" do
    keys = TUI::Input.parse("\e[200~blog\napp\e[201~a")
    keys.map(&.code).should eq [TUI::KeyCode::Paste, TUI::KeyCode::Char]
    keys[0].text.should eq "blog\napp"
  end
end

describe AzuCLI::UI::Frame do
  it "draws a card with its title and badge and returns its inside" do
    frame = TUI::Frame.new(24, 4, styles)
    inner = frame.card(frame.area, "Build", "2.4s")
    frame.text(inner.x, inner.y, "built", max: inner.w)
    frame.to_text.should eq <<-TEXT
      ╭─ Build ─────── 2.4s ─╮
      │ built                │
      │                      │
      ╰──────────────────────╯
      TEXT
    inner.should eq TUI::Rect.new(2, 1, 20, 2)
  end

  it "replaces wide characters so they never shift a border, and truncates lines of segments" do
    frame = TUI::Frame.new(10, 1, styles)
    frame.text(0, 0, "a⚡b")
    frame.to_text.should eq "a?b"

    frame = TUI::Frame.new(10, 1, styles)
    frame.line(0, 0, [TUI::Seg["hello "], TUI::Seg["world"]], 8)
    frame.to_text.should eq "hello w…"
  end

  it "draws with the ASCII glyphs when unicode is off" do
    frame = TUI::Frame.new(8, 2, styles(glyphs: TUI::Glyphs::ASCII))
    frame.card(frame.area, "")
    frame.to_text.should eq "+------+\n+------+"
  end

  it "prints each row with its escape codes and no trailing blanks" do
    frame = TUI::Frame.new(10, 1, styles(TUI::ColorDepth::Basic16))
    frame.text(0, 0, "ok", TUI::Token::Green)
    frame.ansi_lines.should eq ["\e[0;32mok\e[0m"]
  end
end

describe AzuCLI::UI::Rect do
  it "splits into columns with gaps, the last taking the remainder" do
    TUI::Rect.new(0, 0, 21, 3).columns(2, 1).should eq [TUI::Rect.new(0, 0, 10, 3), TUI::Rect.new(11, 0, 10, 3)]
    TUI::Rect.new(0, 0, 10, 5).split_top(2).should eq({TUI::Rect.new(0, 0, 10, 2), TUI::Rect.new(0, 2, 10, 3)})
  end
end

describe AzuCLI::UI::FullScreenRenderer do
  it "draws the whole first frame, then only the cells that changed" do
    io = IO::Memory.new
    renderer = TUI::FullScreenRenderer.new(io)
    table = styles
    first = TUI::Frame.new(4, 2, table)
    first.text(0, 0, "ab")
    renderer.flush(first)
    io.to_s.should contain "\e[2J"

    io.clear
    second = TUI::Frame.new(4, 2, table)
    second.text(0, 0, "ac")
    renderer.flush(second)
    io.to_s.should eq "\e[?2026h\e[1;2Hc\e[0m\e[?2026l"
  end
end

describe AzuCLI::UI::InlineRenderer do
  it "redraws its own block in place" do
    io = IO::Memory.new
    renderer = TUI::InlineRenderer.new(io, color: false)
    frame = TUI::Frame.new(5, 2, styles)
    frame.text(0, 0, "one")
    renderer.flush(frame)
    io.to_s.should eq "one\r\n\r\n"
    renderer.flush(frame)
    io.to_s.should eq "one\r\n\r\n\e[2F\e[Jone\r\n\r\n"
    renderer.commit
    renderer.drawn.should eq 0
  end
end

describe AzuCLI::UI::Widgets do
  it "scales sparklines, fills meters and formats durations" do
    TUI::Widgets.sparkline([0.0, 7.0, 3.5], 10, TUI::Glyphs::UNICODE).should eq "▁█▅"
    TUI::Widgets.sparkline([1.0, 2.0, 3.0], 2, TUI::Glyphs::UNICODE).should eq "▁█"
    TUI::Widgets.meter(0.5, 4, '▮', '▯').should eq({"▮▮", "▯▯"})
    TUI::Widgets.duration(0.0123).should eq "12 ms"
    TUI::Widgets.duration(6.24).should eq "6.2s"
    TUI::Widgets.bytes(50_593_792_i64).should eq "48.2 MB"
    TUI::Widgets.clock(761.seconds).should eq "00:12:41"
  end
end

describe "AzuCLI::UI::Terminal.open_input" do
  # A blocking descriptor holds the whole thread on read: the screen is drawn once and keys seem ignored. File.new
  # opens blocking on macOS, which is how the first version of the key reader hung there.
  it "opens the terminal non-blocking, so the event loop waits on it" do
    input = TUI::Terminal.open_input("/dev/null")
    begin
      (LibC.fcntl(input.fd, LibC::F_GETFL) & LibC::O_NONBLOCK).should_not eq 0
    ensure
      input.close
    end
  end

  it "falls back to /dev/tty when neither stdin nor stdout is a terminal" do
    TUI::Terminal.terminal_path.should eq "/dev/tty" unless STDIN.tty? || STDOUT.tty?
  end
end
