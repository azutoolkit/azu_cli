require "./process_tree"

module AzuCLI
  # A short-lived Crystal file `azu routes` and `azu console` compile or interpret. It is created with O_EXCL under a
  # random name from the system's secure random source (so never through an existing file or symlink, and not
  # guessable), readable by its owner only, and removed when the block ends, when it raises, and when the command is
  # interrupted or terminated. The process running from it is stopped with the command.
  module ScratchFile
    EXCLUSIVE_ATTEMPTS = 20

    # The random part of a name; replaced in specs.
    class_property name_part : -> String = -> { Random::Secure.hex(8) }

    private record Scope, ignore_interrupt : Bool, processes : Array(Process), paths : Array(String)

    @@scopes = [] of Scope

    # Yields the path of a new file holding `content`. `ignore_interrupt` keeps Ctrl-C for a child that owns the
    # terminal (the interpreter) instead of ending the CLI; SIGTERM and SIGHUP still clean up and exit. Processes
    # given to `watch` inside the block are terminated (with their children) when the command is terminated. The
    # handler is installed before the file exists, so a signal cannot leave it behind; scopes nest, and the
    # innermost one decides.
    def self.with(prefix : String, content : String, dir : String = Dir.current, ignore_interrupt : Bool = false, & : String -> T) : T forall T
      scope = Scope.new(ignore_interrupt, [] of Process, [] of String)
      enter(scope)
      begin
        path = create(prefix, content, dir)
        scope.paths << path
        yield path
      ensure
        scope.paths.each { |file| File.delete?(file) }
        leave(scope)
      end
    end

    private def self.enter(scope : Scope) : Nil
      @@scopes << scope
      Process.on_terminate do |reason|
        current = @@scopes.last?
        next if current.nil? || (current.ignore_interrupt && reason.interrupted?)

        @@scopes.each do |open|
          open.processes.each { |process| ProcessTree.terminate(process) }
          open.paths.each { |file| File.delete?(file) }
        end
        exit(reason.interrupted? ? 130 : (reason.terminal_disconnected? ? 129 : 143))
      end
    end

    # Back to the enclosing scope's handling, or to the default signals when this was the outermost one.
    private def self.leave(scope : Scope) : Nil
      @@scopes.delete(scope)
      {Signal::INT, Signal::TERM, Signal::HUP}.each(&.reset) if @@scopes.empty?
    end

    # Registers a process started inside `with`, so SIGTERM/SIGHUP (and Ctrl-C, unless `ignore_interrupt`) stops it too.
    def self.watch(process : Process) : Process
      @@scopes.last?.try(&.processes.<<(process))
      process
    end

    private def self.write(fd : Int32, path : String, content : String) : Nil
      io = IO::FileDescriptor.new(fd)
      begin
        io.print(content)
      rescue ex
        File.delete?(path) # the disk is full or the like: do not leave an empty scratch file behind
        raise ex
      ensure
        io.close
      end
    end

    # Creates the file with O_CREAT|O_EXCL (fails if anything, even a dangling symlink, has the name) and 0600.
    def self.create(prefix : String, content : String, dir : String) : String
      EXCLUSIVE_ATTEMPTS.times do
        path = File.join(dir, "#{prefix}#{name_part.call}.cr")
        fd = LibC.open(path, LibC::O_WRONLY | LibC::O_CREAT | LibC::O_EXCL | LibC::O_CLOEXEC, 0o600)
        if fd >= 0
          write(fd, path, content)
          return path
        end
        raise File::Error.from_errno("Unable to create a scratch file", file: path) unless Errno.value.eexist?
      end
      raise File::Error.new("Unable to find an unused scratch file name in #{dir}", file: dir)
    end
  end
end
