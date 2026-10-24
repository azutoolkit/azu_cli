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

  it "picks a different name every time" do
    in_tmp_project do |dir|
      names = Set(String).new
      5.times { AzuCLI::ScratchFile.with("scratch_", "x", dir) { |path| names << File.basename(path) } }

      names.size.should eq 5
    end
  end

  it "creates exclusively: a planted file or symlink at a generated name is skipped, never written through" do
    in_tmp_project do |dir|
      victim = File.join(dir, "victim")
      File.write(victim, "keep")
      File.symlink(victim, File.join(dir, "scratch_taken.cr"))
      File.symlink(File.join(dir, "nowhere"), File.join(dir, "scratch_dangling.cr"))
      File.write(File.join(dir, "scratch_plain.cr"), "mine")
      parts = ["taken", "dangling", "plain", "fresh"]
      original = AzuCLI::ScratchFile.name_part
      AzuCLI::ScratchFile.name_part = -> { parts.shift }
      begin
        AzuCLI::ScratchFile.with("scratch_", "new", dir) do |path|
          File.basename(path).should eq "scratch_fresh.cr"
          File.read(path).should eq "new"
        end
      ensure
        AzuCLI::ScratchFile.name_part = original
      end

      File.read(victim).should eq "keep"
      File.exists?(File.join(dir, "nowhere")).should be_false
      File.read(File.join(dir, "scratch_plain.cr")).should eq "mine"
    end
  end

  it "gives up with an error when every name is taken" do
    in_tmp_project do |dir|
      File.write(File.join(dir, "scratch_same.cr"), "mine")
      original = AzuCLI::ScratchFile.name_part
      AzuCLI::ScratchFile.name_part = -> { "same" }
      begin
        expect_raises(File::Error) { AzuCLI::ScratchFile.with("scratch_", "x", dir) { } }
      ensure
        AzuCLI::ScratchFile.name_part = original
      end
    end
  end
end
