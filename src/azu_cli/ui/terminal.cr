lib LibAzuTerm
  struct Winsize
    row : UInt16
    col : UInt16
    xpixel : UInt16
    ypixel : UInt16
  end

  fun ioctl(fd : LibC::Int, request : LibC::ULong, ...) : LibC::Int
  fun dup(fd : LibC::Int) : LibC::Int
end

module AzuCLI
  module UI
    # What the terminal on `output` can do, its size, and the raw-mode session interactive screens run in.
    class Terminal
      TIOCGWINSZ = {% if flag?(:darwin) || flag?(:bsd) %} 0x40087468_u64 {% else %} 0x5413_u64 {% end %}

      getter output : IO
      getter depth : ColorDepth
      getter? unicode : Bool
      getter? tty : Bool
      getter? reduced_motion : Bool

      def initialize(@output : IO, @depth : ColorDepth, @unicode : Bool, @tty : Bool, @reduced_motion : Bool = false, @fixed_size : {Int32, Int32}? = nil)
      end

      def self.detect(output : IO::FileDescriptor = STDOUT, env = ENV) : Terminal
        tty = output.tty?
        new(output, color_depth(tty, env), unicode?(env), tty, reduced_motion?(env))
      end

      # A terminal of a fixed size writing to `output`, for specs and for rendering frames to text.
      def self.fake(output : IO = IO::Memory.new, columns : Int32 = 100, rows : Int32 = 32, depth : ColorDepth = ColorDepth::None, unicode : Bool = true) : Terminal
        new(output, depth, unicode, true, true, {columns, rows})
      end

      # NO_COLOR wins over everything; FORCE_COLOR keeps color on a pipe.
      def self.color_depth(tty : Bool, env) : ColorDepth
        return ColorDepth::None if env["NO_COLOR"]?.presence
        return ColorDepth::None unless tty || env["FORCE_COLOR"]?.presence
        term = env["TERM"]? || ""
        return ColorDepth::None if term == "dumb"
        return ColorDepth::TrueColor if {"truecolor", "24bit"}.includes?(env["COLORTERM"]?.try(&.downcase))
        return ColorDepth::Ansi256 if term.includes?("256color")
        ColorDepth::Basic16
      end

      def self.unicode?(env) : Bool
        return false if env["TERM"]? == "dumb" || env["AZU_AMBIGUOUS_WIDE"]? == "1"

        locale = env["LC_ALL"]?.presence || env["LC_CTYPE"]?.presence || env["LANG"]?.presence || ""
        return false if locale.matches?(/\A(zh|ja|ko)/i) # ambiguous-width glyphs are two columns there
        locale.empty? || locale.matches?(/utf-?8/i)
      end

      def self.reduced_motion?(env) : Bool
        env["AZU_REDUCED_MOTION"]?.presence.in?("1", "true") || !!env["CI"]?.presence
      end

      def glyphs : Glyphs
        unicode? ? Glyphs::UNICODE : Glyphs::ASCII
      end

      def theme : Theme
        Theme.new(depth, glyphs)
      end

      # {columns, rows}: the window size, else COLUMNS/LINES, else 80x24.
      def size : {Int32, Int32}
        @fixed_size.try { |fixed| return fixed }
        if (fd = output.as?(IO::FileDescriptor)) && fd.tty?
          ws = LibAzuTerm::Winsize.new
          return {ws.col.to_i, ws.row.to_i} if LibAzuTerm.ioctl(fd.fd, TIOCGWINSZ, pointerof(ws)) == 0 && ws.col > 0
        end
        {ENV["COLUMNS"]?.try(&.to_i?) || 80, ENV["LINES"]?.try(&.to_i?) || 24}
      end

      def columns : Int32
        size[0]
      end

      # Whether an interactive screen can run: a terminal on both ends that the CLI can read keys from.
      def interactive? : Bool
        tty? && File.exists?("/dev/tty") && output.as?(IO::FileDescriptor).try(&.tty?) == true
      end

      # Opens the terminal for keys (stdin may be a pipe), non-blocking, so the event loop waits on it and reading never
      # stalls the fibers that draw. `File.new` will not do: on macOS it opens files blocking, and a blocking read
      # holds the whole thread, so the screen is drawn once and every key seems ignored. The device is opened by its
      # own name (as Crystal reopens STDIN), since macOS's kqueue cannot wait on the /dev/tty alias.
      def self.open_input(path : String = terminal_path) : IO::FileDescriptor
        fd = LibC.open(path, LibC::O_RDONLY | LibC::O_NONBLOCK | LibC::O_CLOEXEC)
        raise IO::Error.from_errno("Could not open #{path}") if fd < 0
        IO::FileDescriptor.new(fd)
      end

      # The terminal's device (/dev/ttys003, /dev/pts/1) from stdin, else stdout; /dev/tty when neither is one.
      def self.terminal_path : String
        {STDIN, STDOUT}.each do |io|
          buffer = uninitialized UInt8[256]
          return String.new(buffer.to_unsafe) if io.tty? && LibC.ttyname_r(io.fd, buffer, 256) == 0
        end
        "/dev/tty"
      end

      # Raw mode on `input` for the block, and the screen put back whatever happens (an exception, Ctrl-C).
      def session(input : IO::FileDescriptor, full_screen : Bool, &)
        input.raw do
          begin
            output << "\e[?1049h" if full_screen # the alternate screen
            output << "\e[?25l\e[?2004h"         # hide the cursor, bracketed paste
            output.flush
            yield
          ensure
            restore(full_screen)
          end
        end
      end

      def restore(full_screen : Bool) : Nil
        output << "\e[?2004l\e[?25h\e[0m"
        output << "\e[?1049l" if full_screen
        output.flush
      end
    end
  end
end
