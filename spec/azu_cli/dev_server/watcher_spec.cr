require "../../spec_helper"
require "../../support/command_helpers"

include CommandHelpers

private def write(dir : String, path : String, content : String = "x", at : Time? = nil)
  full = File.join(dir, path)
  Dir.mkdir_p(File.dirname(full))
  File.write(full, content)
  File.touch(full, at) if at
end

describe AzuCLI::DevServer::Watcher do
  it "reports nothing when nothing changed" do
    in_tmp_project(files: {"src/a.cr" => "a"}) do |dir|
      AzuCLI::DevServer::Watcher.new(dir).poll.should be_empty
    end
  end

  it "reports a file whose modification time changed, once" do
    in_tmp_project(files: {"src/a.cr" => "a"}) do |dir|
      write(dir, "src/a.cr", "a", Time.utc(2020, 1, 1))
      watcher = AzuCLI::DevServer::Watcher.new(dir)
      File.touch(File.join(dir, "src/a.cr"), Time.utc(2021, 1, 1))

      watcher.poll.should eq ["src/a.cr"]
      watcher.poll.should be_empty
    end
  end

  it "reports a file whose size changed although its time did not" do
    in_tmp_project do |dir|
      stamp = Time.utc(2020, 1, 1)
      write(dir, "src/a.cr", "a", stamp)
      watcher = AzuCLI::DevServer::Watcher.new(dir)
      write(dir, "src/a.cr", "aaaa", stamp)

      watcher.poll.should eq ["src/a.cr"]
    end
  end

  it "reports new and removed files, in nested directories, sorted" do
    in_tmp_project(files: {"src/old.cr" => "a"}) do |dir|
      watcher = AzuCLI::DevServer::Watcher.new(dir)
      write(dir, "src/endpoints/posts/new.cr")
      write(dir, "public/templates/blog/index.jinja")
      File.delete(File.join(dir, "src/old.cr"))

      watcher.poll.should eq ["public/templates/blog/index.jinja", "src/endpoints/posts/new.cr", "src/old.cr"]
    end
  end

  it "watches shard.yml, shard.lock and .env files, and nothing else at the top level or elsewhere" do
    in_tmp_project do |dir|
      watcher = AzuCLI::DevServer::Watcher.new(dir)
      write(dir, "shard.lock")
      write(dir, ".env.local")
      write(dir, "README.md")
      write(dir, "lib/azu/azu.cr")
      write(dir, "bin/app")
      write(dir, "db/app.db")
      write(dir, "config/azu.yml")

      watcher.poll.should eq [".env.local", "config/azu.yml", "shard.lock"]
    end
  end

  it "survives a directory that disappears" do
    in_tmp_project(files: {"src/deep/a.cr" => "a"}) do |dir|
      watcher = AzuCLI::DevServer::Watcher.new(dir)
      FileUtils.rm_rf(File.join(dir, "src"))

      watcher.poll.should eq ["src/deep/a.cr"]
    end
  end

  it "does not follow symlinked directories, so a link back up the tree cannot loop or add files" do
    in_tmp_project(files: {"src/a.cr" => "a", "elsewhere/b.cr" => "b"}) do |dir|
      File.symlink("..", File.join(dir, "src", "loop"))
      File.symlink(File.join(dir, "elsewhere"), File.join(dir, "src", "linked"))
      watcher = AzuCLI::DevServer::Watcher.new(dir)
      File.write(File.join(dir, "elsewhere", "b.cr"), "changed and longer")

      watcher.poll.should be_empty
    end
  end
end
