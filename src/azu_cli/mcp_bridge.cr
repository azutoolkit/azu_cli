require "./generate_plan"
require "digest/sha256"
require "./mcp_operations"
require "./joobq/source"

module AzuCLI
  module MCPBridge
    MAX_BYTES = 1_048_576

    def self.run(args : Array(String), output : IO) : Nil
      case args.shift?
      when "catalog"
        output.puts({version: 1, generators: Commands::Generate::GENERATOR_TYPES,
                     examples: Commands::Generate::MENU.map { |item| {name: item[0], description: item[1], example: item[2]} },
                     no_name: Commands::Generate::NAMELESS_GENERATORS}.to_json)
      when "generate-plan"
        args.shift if args.first? == "--"
        output.puts(generate_plan(args).to_json)
      when "generate-apply"
        body = STDIN.gets('\0', MAX_BYTES + 1) || ""
        raise "Generator plan exceeds 1 MiB" if body.bytesize > MAX_BYTES
        output.puts(apply(JSON.parse(body)).to_json)
      when "jobs-inspect"
        DotEnv.load_all(Dir.current)
        JoobQDashboard::ProcessSource.open("src/initializers/joobq.cr", output: STDERR) do |source|
          output.puts(source.snapshot.to_json)
        end
      when "routes-inspect"
        DotEnv.load_all(Dir.current)
        command = Commands::Routes.new
        command.parse_args(["--format", "json"])
        command.stdout = output
        result = command.execute
        raise result.error unless result.success?
      when "precondition"
        output.puts(operation(args, false).to_json)
      when "execute"
        output.puts(operation(args, true).to_json)
      else
        raise "Unknown MCP bridge command"
      end
    end

    def self.generate_plan(args : Array(String), project = Dir.current, executable = Process.executable_path || "azu") : JSON::Any
      raise "Generator type required" unless Commands::Generate::GENERATOR_TYPES.includes?(args.first?)
      raise "Preview control flags are managed by MCP" if args.any? { |arg| %w(--yes --check --dry-run --help --ui).includes?(arg) || arg.starts_with?("--ui=") }
      args.each do |argument|
        value = argument.starts_with?("--") ? argument.split('=', 2).last : argument
        raise "Generator paths must stay inside the project" if Path[value].absolute? || value.split('/').includes?("..")
      end
      validate_shadow_tree(project)
      built = GeneratePlan.build(args, project, executable)
      raise built if built.is_a?(String)
      begin
        files = built.entries.map do |entry|
          path = safe_path(project, entry.path)
          content = File.read(safe_path(built.shadow, entry.path))
          raise "Generated file exceeds limit" if content.bytesize > MAX_BYTES
          {path: entry.path, before_sha256: File.file?(path) ? Digest::SHA256.hexdigest(File.read(path)) : nil,
           after_sha256: Digest::SHA256.hexdigest(content), content: content, kind: entry.kind.to_s.downcase}
        end
        value = JSON.parse({version: 1, files: files, arguments: args, project: File.realpath(project)}.to_json)
        raise "Generator plan exceeds 1 MiB" if value.to_json.bytesize > MAX_BYTES
        value
      ensure
        built.cleanup
      end
    end

    # cp_r can preserve nested symlinks. Reject them before a generator runs in
    # the shadow, otherwise a preview could write through to the real project.
    private def self.validate_shadow_tree(root : String) : Nil
      directories = [root]
      visited = 0
      until directories.empty?
        directory = directories.pop
        Dir.each_child(directory) do |name|
          next if directory == root && (GeneratePlan::SKIP.includes?(name) || name.ends_with?(".db") || name.ends_with?(".sqlite3"))
          path = File.join(directory, name)
          raise "Generator preview refuses symlinks in copied project files: #{Path[path].relative_to(root)}" if File.symlink?(path)
          visited += 1
          raise "Generator preview exceeds 20,000 project entries" if visited > 20_000
          directories << path if File.directory?(path)
        end
      end
    end

    def self.apply(plan : JSON::Any, project = Dir.current) : JSON::Any
      raise "Unsupported plan" unless plan["version"].as_i == 1 && plan["project"].as_s == File.realpath(project)
      files = plan["files"].as_a
      raise "Too many files" if files.size > 500
      raise "Duplicate paths" unless files.map(&.["path"].as_s).uniq.size == files.size
      files.each do |file|
        path = safe_path(project, file["path"].as_s)
        current = File.file?(path) ? Digest::SHA256.hexdigest(File.read(path)) : nil
        raise "Project changed: #{file["path"]}" unless current == file["before_sha256"].as_s?
        raise "Plan content changed" unless Digest::SHA256.hexdigest(file["content"].as_s) == file["after_sha256"].as_s
      end
      shadow = File.join(Dir.tempdir, "azu-mcp-#{Random::Secure.hex(8)}")
      Dir.mkdir_p(shadow, 0o700)
      begin
        entries = files.map do |file|
          relative = file["path"].as_s
          path = safe_path(shadow, relative)
          Dir.mkdir_p(File.dirname(path))
          File.write(path, file["content"].as_s)
          GeneratePlan::Entry.new(relative, file["before_sha256"].raw.nil? ? GeneratePlan::Kind::New : GeneratePlan::Kind::Changed, 0, [] of GeneratePlan::DiffLine)
        end
        built = GeneratePlan.new(shadow, project, entries, "")
        undo = built.apply("azu mcp reviewed generator plan")
        JSON.parse({status: "applied", files: entries.map(&.path), undo: undo}.to_json)
      ensure
        FileUtils.rm_rf(shadow)
      end
    end

    def self.safe_path(root : String, relative : String) : String
      raise "Unsafe generated path" if Path[relative].absolute? || relative.split('/').any? { |part| part == ".." || part == ".git" || part == "lib" } || relative.includes?('\0')
      base = File.realpath(root)
      path = File.expand_path(relative, base)
      current = path
      until File.exists?(current) || File.symlink?(current)
        current = File.dirname(current)
      end
      resolved = File.realpath(current)
      raise "Generated path escapes project" unless resolved == base || resolved.starts_with?(base + "/")
      path
    end
  end
end
