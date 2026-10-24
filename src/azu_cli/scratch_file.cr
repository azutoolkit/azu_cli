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

    @@running = [] of Process

    # Yields the path of a new file holding `content`. `ignore_interrupt` keeps Ctrl-C for a child that owns the
    # terminal (the interpreter) instead of ending the CLI; SIGTERM and SIGHUP still clean up and exit. Processes
    # given to `watch` inside the block are terminated (with their children) when the command is interrupted.
    def self.with(prefix : String, content : String, dir : String = Dir.current, ignore_interrupt : Bool = false, & : String -> T) : T forall T
      path = create(prefix, content, dir)
      Process.on_terminate do |reason|
        next if ignore_interrupt && reason.interrupted?

        @@running.each { |process| ProcessTree.terminate(process) }
        File.delete?(path)
        exit(reason.interrupted? ? 130 : 143)
      end
      begin
        yield path
      ensure
        File.delete?(path)
        @@running.clear
        {Signal::INT, Signal::TERM, Signal::HUP}.each(&.reset)
      end
    end

    # Registers a process started inside `with`, so an interrupt stops it too.
    def self.watch(process : Process) : Process
      @@running << process
      process
    end

    # Creates the file with O_CREAT|O_EXCL (fails if anything, even a dangling symlink, has the name) and 0600.
    def self.create(prefix : String, content : String, dir : String) : String
      EXCLUSIVE_ATTEMPTS.times do
        path = File.join(dir, "#{prefix}#{name_part.call}.cr")
        fd = LibC.open(path, LibC::O_WRONLY | LibC::O_CREAT | LibC::O_EXCL | LibC::O_CLOEXEC, 0o600)
        if fd >= 0
          IO::FileDescriptor.new(fd).tap(&.print(content)).close
          return path
        end
        raise File::Error.from_errno("Unable to create a scratch file", file: path) unless Errno.value.eexist?
      end
      raise File::Error.new("Unable to find an unused scratch file name in #{dir}", file: dir)
    end
  end
end
