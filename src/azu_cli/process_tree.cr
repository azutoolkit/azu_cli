module AzuCLI
  # Stopping a command together with everything it started (`shards build` runs the compiler as a child; `crystal run`
  # runs the program it compiled), which a signal to the parent alone leaves running.
  module ProcessTree
    # SIGTERM to the process and every process below it. There is no SIGKILL afterwards: a process that traps SIGTERM
    # survives, and the tree is listed and signalled in separate steps (a process started in between is missed).
    def self.terminate(process : Process) : Nil
      return unless process.exists?

      (descendants(process.pid) + [process.pid]).each { |pid| Process.signal(Signal::TERM, pid) rescue nil }
    end

    # Every process below pid, deepest first.
    def self.descendants(pid : Int64) : Array(Int64)
      return [] of Int64 if pid <= 1 # never walk from init or the whole system

      children_of(pid).flat_map { |child| descendants(child) + [child] }
    end

    # `pgrep -P`, or without pgrep a scan of /proc (Linux), or `ps` (macOS, BSD), so a missing tool cannot leave
    # the compiler running.
    def self.children_of(pid : Int64) : Array(Int64)
      return [] of Int64 if pid <= 1

      output = IO::Memory.new
      Process.run("pgrep", ["-P", pid.to_s], output: output, error: Process::Redirect::Close)
      output.to_s.split.compact_map(&.to_i64?)
    rescue IO::Error
      Dir.exists?("/proc/self") ? proc_children_of(pid) : ps_children_of(pid)
    end

    def self.ps_children_of(pid : Int64) : Array(Int64)
      output = IO::Memory.new
      Process.run("ps", ["-A", "-o", "pid=,ppid="], output: output, error: Process::Redirect::Close)
      parse_ps(output.to_s, pid)
    rescue IO::Error
      [] of Int64
    end

    # The pids whose parent is `pid` in the output of `ps -A -o pid=,ppid=`.
    def self.parse_ps(text : String, pid : Int64) : Array(Int64)
      text.lines.compact_map do |line|
        child, parent = line.split.map(&.to_i64?)
        child if child && parent == pid
      rescue
        nil
      end
    end

    def self.proc_children_of(pid : Int64) : Array(Int64)
      return [] of Int64 unless Dir.exists?("/proc/self")

      Dir.children("/proc").compact_map do |name|
        candidate = name.to_i64?
        next unless candidate

        stat = File.read("/proc/#{name}/stat") rescue next
        # "pid (name) S ppid ...": the name may hold spaces and parentheses, so count from the last ")"
        parent = stat[(stat.rindex(')') || 0) + 1..].split[1]?.try(&.to_i64?)
        candidate if parent == pid
      end
    end
  end
end
