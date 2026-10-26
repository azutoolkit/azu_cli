require "file_utils"

# A scratch project directory for command specs: shard.yml plus any files, and the working directory
# switched to it for the block (commands read `./shard.yml`).
module CommandHelpers
  SHARD_YML = <<-YAML
    name: blog
    version: 0.1.0
    crystal: ">= 1.22.1"
    dependencies:
      cql:
        github: azutoolkit/cql
    YAML

  def in_tmp_project(shard_yml : String? = SHARD_YML, files : Hash(String, String) = {} of String => String, &)
    dir = File.join(Dir.tempdir, "azu_cli_spec_#{Process.pid}_#{Random.rand(1_000_000)}")
    Dir.mkdir_p(dir)
    File.write(File.join(dir, "shard.yml"), shard_yml) if shard_yml
    files.each do |path, content|
      Dir.mkdir_p(File.dirname(File.join(dir, path)))
      File.write(File.join(dir, path), content)
    end
    Dir.cd(dir) { yield dir }
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  # Runs a command class with the given arguments, the way the CLI does, and returns {result, stdout}.
  def run_command(command : AzuCLI::Commands::Base, args : Array(String)) : {AzuCLI::Commands::Result, String}
    output = IO::Memory.new
    command.stdout = output
    command.parse_args(args)
    {command.execute, output.to_s}
  end
end
