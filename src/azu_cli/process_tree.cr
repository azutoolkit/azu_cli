module AzuCLI
  # Stopping a command together with everything it started (`shards build` runs the compiler as a child; `crystal run`
  # runs the program it compiled), which a signal to the parent alone leaves running.
  module ProcessTree
    # SIGTERM to the process and every process below it.
    def self.terminate(process : Process) : Nil
      return unless process.exists?

      (descendants(process.pid) + [process.pid]).each { |pid| Process.signal(Signal::TERM, pid) rescue nil }
    end

    # Every process below pid, deepest first.
    def self.descendants(pid : Int64) : Array(Int64)
      children_of(pid).flat_map { |child| descendants(child) + [child] }
    end

    # `pgrep -P`, or without pgrep a scan of /proc (Linux), so a missing tool cannot leave the compiler running.
    def self.children_of(pid : Int64) : Array(Int64)
      output = IO::Memory.new
      Process.run("pgrep", ["-P", pid.to_s], output: output, error: Process::Redirect::Close)
      output.to_s.split.compact_map(&.to_i64?)
    rescue IO::Error
      proc_children_of(pid)
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
