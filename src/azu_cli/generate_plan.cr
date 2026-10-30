require "json"
require "digest/sha256"
require "file_utils"

module AzuCLI
  # What `azu generate` would write, worked out before anything is written: the generator runs in a copy of the
  # project (a "shadow"), and the copy is compared with the project. Applying the plan copies exactly the files the
  # preview showed, and keeps an undo record outside the project.
  class GeneratePlan
    # Not copied into the shadow: dependencies, builds, history and databases are never what a generator writes.
    SKIP       = Set{"lib", "bin", ".git", "node_modules", "tmp", "log", ".crystal", ".shards"}
    SHADOW_ENV = "AZU_GENERATE_SHADOW"

    enum Kind
      New
      Changed
    end

    record DiffLine, op : Char, number : Int32?, text : String

    record Entry, path : String, kind : Kind, lines : Int32, diff : Array(DiffLine)

    getter shadow : String
    getter project : String
    getter entries : Array(Entry)
    getter output : String

    def initialize(@shadow : String, @project : String, @entries : Array(Entry), @output : String)
    end

    def new_files : Array(Entry)
      entries.select(&.kind.new?)
    end

    def changed_files : Array(Entry)
      entries.select(&.kind.changed?)
    end

    def empty? : Bool
      entries.empty?
    end

    # Why the generator refused in the shadow (its output), or the plan.
    def self.build(args : Array(String), project : String = Dir.current, executable : String = Process.executable_path || "azu") : GeneratePlan | String
      shadow = File.join(Dir.tempdir, "azu-shadow-#{Random::Secure.hex(6)}")
      copy_project(project, shadow)
      output = IO::Memory.new
      env = {SHADOW_ENV => "1", "AZU_UI" => "plain", "NO_COLOR" => "1"}
      status = Process.run(executable, ["generate"] + args, chdir: shadow, env: env, output: output, error: output)
      unless status.success?
        FileUtils.rm_rf(shadow)
        return output.to_s
      end
      new(shadow, project, compare(shadow, project), output.to_s)
    end

    def self.copy_project(from : String, to : String) : Nil
      Dir.mkdir_p(to, 0o700) # the copy holds the project's .env: no one else may read it
      copy_entries(from, to)
      # The compiler finds the shards through lib/: link it so the shadow can be type-checked.
      shards = File.join(from, "lib")
      File.symlink(File.realpath(shards), File.join(to, "lib")) if Dir.exists?(shards)
    end

    private def self.copy_entries(from : String, to : String) : Nil
      Dir.each_child(from) do |name|
        next if SKIP.includes?(name) || storage_file?(name)
        source = File.join(from, name)
        next if File.symlink?(source)
        if File.directory?(source)
          destination = File.join(to, name)
          Dir.mkdir_p(destination)
          copy_entries(source, destination)
        else
          File.copy(source, File.join(to, name))
        end
      end
    end

    private def self.storage_file?(name : String) : Bool
      name.matches?(/\.(?:db|sqlite|sqlite3)(?:-wal|-shm|-journal)?\z/i)
    end

    def self.compare(shadow : String, project : String) : Array(Entry)
      entries = [] of Entry
      Dir.glob(File.join(shadow, "**", "*"), match: File::MatchOptions::DotFiles).sort.each do |path|
        next unless File.file?(path)
        relative = Path[path].relative_to(shadow).to_s
        next if relative.split('/').any? { |part| SKIP.includes?(part) } || storage_file?(File.basename(path))
        theirs = File.join(project, relative)
        if File.symlink?(theirs)
          Logger.warn("#{relative} is a symlink; generated changes were skipped. Configure it manually.")
          next
        end
        written = File.read(path)
        if !File.exists?(theirs)
          entries << Entry.new(relative, Kind::New, written.lines.size, written.lines.first(400).map_with_index { |line, index| DiffLine.new('+', index + 1, line) })
        elsif (before = File.read(theirs)) != written
          entries << Entry.new(relative, Kind::Changed, written.lines.size, Diff.lines(before.lines, written.lines))
        end
      end
      entries
    end

    # Type-checks the shadow's main target; nil when it compiles, else the compiler's output.
    def type_check(main : String = GeneratePlan.main_file(shadow)) : String?
      output = IO::Memory.new
      process = Process.new("crystal", ["build", main, "--no-codegen", "--no-color"], chdir: shadow, output: output, error: output)
      @checker = process
      status = process.wait
      status.success? ? nil : output.to_s
    rescue IO::Error
      "crystal not found on PATH"
    ensure
      @checker = nil
    end

    @checker : Process?

    # The main file of the first target in shard.yml, else src/<name>.cr.
    def self.main_file(directory : String) : String
      shard = File.join(directory, "shard.yml")
      if File.exists?(shard)
        yaml = YAML.parse(File.read(shard))
        if (targets = yaml["targets"]?.try(&.as_h?)) && (first = targets.values.first?)
          return first["main"].as_s.lchop("./")
        end
        return "src/#{yaml["name"].as_s}.cr" if yaml["name"]?
      end
      "src/#{File.basename(directory)}.cr"
    rescue YAML::ParseException
      "src/#{File.basename(directory)}.cr"
    end

    # Copies the plan's files into the project, after saving an undo record. Returns the record's directory.
    def apply(command : String) : String
      record = Undo.record_directory(project)
      manifest = Undo::Manifest.new(command, Time.utc.to_rfc3339, [] of Undo::FileRecord)
      entries.each do |entry|
        target = File.join(project, entry.path)
        backup = nil
        if entry.kind.changed?
          backup = File.join(record, "before", entry.path)
          Dir.mkdir_p(File.dirname(backup))
          File.copy(target, backup)
        end
        source = File.join(shadow, entry.path)
        content = File.read(source)
        write_atomically(target, content, File.info(source).permissions)
        manifest.files << Undo::FileRecord.new(entry.path, entry.kind.new?, Undo.digest(content), backup ? Path[backup].relative_to(record).to_s : nil)
      end
      File.write(File.join(record, "manifest.json"), manifest.to_pretty_json)
      record
    end

    # Removes the shadow, and stops a type-check of it that is still running.
    def cleanup : Nil
      @checker.try { |process| ProcessTree.terminate(process) rescue nil }
      FileUtils.rm_rf(shadow)
    end

    private def write_atomically(path : String, content : String, permissions : File::Permissions) : Nil
      Dir.mkdir_p(File.dirname(path))
      temporary = "#{path}.azu-#{Random::Secure.hex(4)}"
      File.write(temporary, content, perm: permissions.value)
      File.rename(temporary, path)
    ensure
      File.delete(temporary) if temporary && File.exists?(temporary)
    end

    # A line diff (longest common subsequence) shown as hunks with two lines of context; large files fall back to
    # "everything after the first difference".
    module Diff
      CONTEXT =         2
      LIMIT   = 4_000_000

      def self.lines(before : Array(String), after : Array(String)) : Array(DiffLine)
        return naive(before, after) if before.size.to_i64 * after.size > LIMIT

        ops = edit_script(before, after)
        hunks(ops)
      end

      private def self.edit_script(a : Array(String), b : Array(String)) : Array(DiffLine)
        n, m = a.size, b.size
        table = Array.new(n + 1) { Array.new(m + 1, 0) }
        (n - 1).downto(0) do |i|
          (m - 1).downto(0) do |j|
            table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : Math.max(table[i + 1][j], table[i][j + 1])
          end
        end
        ops = [] of DiffLine
        i = j = 0
        while i < n || j < m
          if i < n && j < m && a[i] == b[j]
            ops << DiffLine.new(' ', j + 1, b[j])
            i += 1
            j += 1
          elsif j < m && (i >= n || table[i][j + 1] >= table[i + 1][j])
            ops << DiffLine.new('+', j + 1, b[j])
            j += 1
          else
            ops << DiffLine.new('-', nil, a[i])
            i += 1
          end
        end
        ops
      end

      # Keeps the changed lines and CONTEXT lines around them; a gap is marked with a '~' line.
      private def self.hunks(ops : Array(DiffLine)) : Array(DiffLine)
        keep = Array.new(ops.size, false)
        ops.each_with_index do |op, index|
          next if op.op == ' '
          ((index - CONTEXT)..(index + CONTEXT)).each { |near| keep[near] = true if 0 <= near < ops.size }
        end
        result = [] of DiffLine
        skipped = false
        ops.each_with_index do |op, index|
          if keep[index]
            result << DiffLine.new('~', nil, "…") if skipped && !result.empty?
            result << op
            skipped = false
          else
            skipped = true
          end
        end
        result
      end

      private def self.naive(before : Array(String), after : Array(String)) : Array(DiffLine)
        first = (0...Math.min(before.size, after.size)).find { |index| before[index] != after[index] } || Math.min(before.size, after.size)
        after[first..].first(200).map_with_index { |line, offset| DiffLine.new('+', first + offset + 1, line) }
      end
    end
  end

  # `azu undo`: the records `azu generate` keeps, outside the project, in $XDG_STATE_HOME/azu/<project>/undo/.
  module Undo
    record FileRecord, path : String, created : Bool, digest : String, backup : String? do
      include JSON::Serializable
    end

    class Manifest
      include JSON::Serializable

      getter command : String
      getter at : String
      getter files : Array(FileRecord)

      def initialize(@command : String, @at : String, @files : Array(FileRecord))
      end
    end

    def self.state_root : String
      base = ENV["XDG_STATE_HOME"]?.presence || File.join(ENV["HOME"]? || Dir.tempdir, ".local", "state")
      File.join(base, "azu")
    end

    def self.project_directory(project : String) : String
      real = File.realpath(project)
      File.join(state_root, "#{File.basename(real)}-#{Digest::SHA256.hexdigest(real)[0, 12]}", "undo")
    end

    def self.record_directory(project : String) : String
      directory = File.join(project_directory(project), Time.utc.to_s("%Y%m%d%H%M%S%6N"))
      Dir.mkdir_p(directory, 0o700)
      directory
    end

    # Records, newest first.
    def self.records(project : String) : Array(String)
      directory = project_directory(project)
      return [] of String unless Dir.exists?(directory)
      Dir.children(directory).sort.reverse.map { |name| File.join(directory, name) }.select { |path| File.exists?(File.join(path, "manifest.json")) }
    end

    def self.digest(content : String) : String
      Digest::SHA256.hexdigest(content)
    end

    record Step, path : String, action : String, ok : Bool, reason : String? = nil

    # What undoing `record` does, file by file. A file edited since it was generated is left alone.
    def self.steps(record : String, project : String) : Array(Step)
      manifest = Manifest.from_json(File.read(File.join(record, "manifest.json")))
      manifest.files.map do |file|
        target = File.join(project, file.path)
        current = File.exists?(target) ? digest(File.read(target)) : nil
        action = file.created ? "delete" : "restore"
        if current.nil?
          Step.new(file.path, action, false, "already gone")
        elsif current != file.digest
          Step.new(file.path, action, false, "changed since it was generated: left as it is")
        else
          Step.new(file.path, action, true)
        end
      end
    end

    # Removes the directories a deleted file leaves empty, up to (not including) the project.
    private def self.prune_empty_directories(directory : String, project : String) : Nil
      root = File.realpath(project)
      while Dir.exists?(directory) && Dir.empty?(directory) && File.realpath(directory) != root && File.realpath(directory).starts_with?(root)
        Dir.delete(directory)
        directory = File.dirname(directory)
      end
    end

    def self.manifest(record : String) : Manifest
      Manifest.from_json(File.read(File.join(record, "manifest.json")))
    end

    # Applies the steps that are safe and removes the record.
    def self.apply(record : String, project : String) : Array(Step)
      manifest = manifest(record)
      steps = steps(record, project)
      steps.each_with_index do |step, index|
        next unless step.ok
        file = manifest.files[index]
        target = File.join(project, file.path)
        if file.created
          File.delete(target)
          prune_empty_directories(File.dirname(target), project)
        elsif backup = file.backup
          File.copy(File.join(record, backup), target)
        end
      end
      FileUtils.rm_rf(record)
      steps
    end
  end
end
