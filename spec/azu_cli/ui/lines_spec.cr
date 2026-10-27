require "../../spec_helper"

private alias TUI = AzuCLI::UI

private def lines(depth = TUI::ColorDepth::None, unicode = true)
  TUI::Lines.new(TUI::Terminal.fake(columns: 20, depth: depth, unicode: unicode))
end

describe AzuCLI::UI::Lines do
  it "gives each kind of message its glyph, and no escape codes without color" do
    lines.message(TUI::Lines::Kind::Info, "Validating").should eq "▸ Validating"
    lines.message(TUI::Lines::Kind::Warn, "careful").should eq "▲ careful"
    lines.message(TUI::Lines::Kind::Error, "boom").should eq "✖ boom"
    lines.message(TUI::Lines::Kind::Success, "saved").should eq "✔ saved"
    lines.message(TUI::Lines::Kind::Created, "src/a.cr").should eq "  + src/a.cr"
    lines.message(TUI::Lines::Kind::Skipped, "src/a.cr (exists)").should eq "  · src/a.cr (exists)"
    lines(unicode: false).message(TUI::Lines::Kind::Success, "saved").should eq "[ok] saved"
  end

  it "reads the check marks older messages start with as their kind" do
    lines.message(TUI::Lines::Kind::Info, "✓ Migrations completed").should eq "✔ Migrations completed"
    lines.message(TUI::Lines::Kind::Info, "✗ Rollback test failed").should eq "✖ Rollback test failed"
  end

  it "colors the glyph and the text with the theme" do
    lines(TUI::ColorDepth::Basic16).message(TUI::Lines::Kind::Error, "boom").should eq "\e[0;31m✖\e[0m \e[0;31mboom\e[0m"
  end

  it "draws a heading with the brand over a rule one column short of the terminal" do
    lines.header("Setup").should eq " ▲ AZU  Setup\n#{"─" * 19}"
    lines.step(2, 5, "Installing").should eq "2/5 ▸ Installing"
  end
end

describe AzuCLI::UI::Table do
  it "fits the columns into the width, the widest giving up room first" do
    table = TUI::Table.new(["A", "LONG"], [[TUI::Seg["x"], TUI::Seg["abcdefghij"]]])
    table.fit(20).should eq [1, 10]
    table.fit(10).should eq [1, 7]
    table.lines(10).map(&.join(&.text)).should eq ["A  LONG", "x  abcdef…"]
  end
end
