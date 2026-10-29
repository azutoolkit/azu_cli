require "../../spec_helper"

private alias Composer = AzuCLI::DevServer::CommandComposer
private alias CommandUI = AzuCLI::UI

describe Composer do
  it "parses generators as argv without a shell" do
    command = Composer.parse("azu generate scaffold Product name:string price_cents:int32 active:bool --spark")
    command.args.should eq %w(generate scaffold Product name:string price_cents:int32 active:bool --spark)
    command.confirm.should be_true
    Composer.parse("g model User 'name:string'").args.should eq %w(generate model User name:string)
  end

  it "rejects shell expressions, unclosed quotes and recursive terminal commands" do
    ["generate model User; touch /tmp/owned", "generate model $(whoami)", "generate model `id`", "generate model 'User",
     "generate model User\nversion", "dev", "connect", "generate model User --ui rich"].each do |line|
      expect_raises(ArgumentError) { Composer.parse(line) }
    end
  end

  it "requires review and explicit confirmation before submitting once" do
    submitted = [] of AzuCLI::DevServer::Control::Command
    composer = Composer.new(->(command : AzuCLI::DevServer::Control::Command) { submitted << command; true })
    composer.open
    "generate model Product name:string".each_char { |char| composer.update(CommandUI::Key.new(CommandUI::KeyCode::Char, char)) }
    composer.update(CommandUI::Key.new(CommandUI::KeyCode::Enter))
    submitted.should be_empty
    composer.update(CommandUI::Key.new(CommandUI::KeyCode::Char, 'y'))
    composer.update(CommandUI::Key.new(CommandUI::KeyCode::Char, 'y'))
    submitted.size.should eq 1
    composer.busy?.should be_true
    composer.update(AzuCLI::DevServer::Events::ControlFinished.new("interactive", 0, "created model", 0.1))
    composer.busy?.should be_false
  end

  it "cancels review without executing" do
    submitted = false
    composer = Composer.new(->(_command : AzuCLI::DevServer::Control::Command) { submitted = true; true })
    composer.open
    "version".each_char { |char| composer.update(CommandUI::Key.new(CommandUI::KeyCode::Char, char)) }
    composer.update(CommandUI::Key.new(CommandUI::KeyCode::Enter))
    composer.update(CommandUI::Key.new(CommandUI::KeyCode::Esc))
    composer.active?.should be_false
    submitted.should be_false
  end
end

describe AzuCLI::BoundedCapture do
  it "caps capture while draining excess bytes and repairs a truncated UTF-8 character" do
    capture = AzuCLI::BoundedCapture.new(5)
    capture << "abcd漢" << ("x" * 10000)
    capture.truncated?.should be_true
    capture.text.should eq "abcd�"
  end
end
