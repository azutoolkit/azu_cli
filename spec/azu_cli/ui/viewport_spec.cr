require "../../spec_helper"

private alias VUI = AzuCLI::UI

describe VUI::Viewport do
  it "clamps offsets after resizing and draws a block scrollbar inside the rectangle" do
    viewport = VUI::Viewport.new
    viewport.configure(100, 5)
    viewport.key(VUI::Key.new(VUI::KeyCode::End)).should be_true
    viewport.offset.should eq 95
    viewport.configure(3, 8)
    viewport.offset.should eq 0
    frame = VUI::Frame.new(20, 8, VUI::StyleTable.new(VUI::Theme.new(VUI::ColorDepth::None)))
    viewport.draw(frame, VUI::Rect.new(2, 2, 5, 3), Array.new(20) { |i| i.to_s })
    frame.to_text.should contain "█"
    frame.to_text.should contain "░"
    frame[7, 2].char.should eq ' '
  end

  it "wraps long lines and removes escape/control bytes" do
    VUI::Viewport.wrap(["abcdef", "\e[31mtrace\e[0m\r"], 3).should eq ["abc", "def", "tra", "ce"]
    VUI::Viewport.wrap(["abc"], 0).should be_empty
  end

  it "keeps a selected record stable as new records arrive" do
    inspector = VUI::Inspector.new
    items = (1..3).map { |id| VUI::Inspector::Item.new(id.to_s, id.to_s, ["trace"]) }
    inspector.replace(items)
    inspector.key(VUI::Key.new(VUI::KeyCode::Down))
    inspector.replace([VUI::Inspector::Item.new("new", "new", ["new"])] + items)
    inspector.selected_item.not_nil!.id.should eq "2"
    inspector.replace([] of VUI::Inspector::Item)
    inspector.selected.should eq 0
  end
end
