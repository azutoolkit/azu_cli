module AzuCLI
  # A short-lived Crystal file `azu routes` and `azu console` compile or interpret. It is created exclusively with a
  # random name (never through an existing file or symlink, not guessable), readable by its owner only, and removed
  # when the block ends, when it raises, and when the command is interrupted or terminated.
  module ScratchFile
    # Yields the path of a new file holding `content`. `ignore_interrupt` keeps Ctrl-C for a child that owns the
    # terminal (the interpreter) instead of ending the CLI; SIGTERM and SIGHUP still clean up and exit.
    def self.with(prefix : String, content : String, dir : String = Dir.current, ignore_interrupt : Bool = false, & : String -> T) : T forall T
      file = File.tempfile(prefix, ".cr", dir: dir) { |io| io.print(content) }
      path = file.path
      File.chmod(path, 0o600)
      Process.on_terminate do |reason|
        next if ignore_interrupt && reason.interrupted?

        File.delete?(path)
        exit(130)
      end
      begin
        yield path
      ensure
        File.delete?(path)
      end
    end
  end
end
