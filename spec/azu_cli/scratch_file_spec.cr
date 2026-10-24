require "../spec_helper"
require "../support/command_helpers"

include CommandHelpers

describe AzuCLI::ScratchFile do
  it "yields a new file with the content, owner-only, in the directory, and removes it afterwards" do
    in_tmp_project do |dir|
      seen = nil
      AzuCLI::ScratchFile.with("scratch_", "puts 1\n", dir) do |path|
        seen = path
        File.read(path).should eq "puts 1\n"
        File.dirname(path).should eq dir
        File.basename(path).should start_with("scratch_")
        (File.info(path).permissions.value & 0o077).should eq 0
      end

      File.exists?(seen.not_nil!).should be_false
    end
  end

  it "removes the file when the block raises" do
    in_tmp_project do |dir|
      seen = nil
      expect_raises(Exception, "boom") do
        AzuCLI::ScratchFile.with("scratch_", "x", dir) { |path| seen = path; raise "boom" }
      end

      File.exists?(seen.not_nil!).should be_false
    end
  end

  it "picks a different, unpredictable name every time and never writes through an existing symlink" do
    in_tmp_project do |dir|
      target = File.join(dir, "victim")
      File.write(target, "keep")
      File.symlink(target, File.join(dir, "scratch_#{Process.pid}.cr"))
      names = Set(String).new
      5.times { AzuCLI::ScratchFile.with("scratch_", "x", dir) { |path| names << File.basename(path) } }

      names.size.should eq 5
      names.should_not contain("scratch_#{Process.pid}.cr")
      File.read(target).should eq "keep"
    end
  end
end
