module AzuCLI
  module UI
    # Puts frames on the terminal.
    abstract class Renderer
      SYNC_BEGIN = "\e[?2026h" # synchronized output: terminals that know it never show half a frame
      SYNC_END   = "\e[?2026l"

      abstract def flush(frame : Frame) : Nil
      abstract def full_screen? : Bool
    end

    # Full-screen (alternate screen) renderer: writes only the cells that changed since the previous frame, in one write.
    class FullScreenRenderer < Renderer
      @previous : Frame?

      def initialize(@io : IO)
      end

      def full_screen? : Bool
        true
      end

      def flush(frame : Frame) : Nil
        previous = @previous.try { |last| last if last.width == frame.width && last.height == frame.height && last.styles.same?(frame.styles) }
        output = String.build(frame.width * 4) do |buffer|
          buffer << SYNC_BEGIN
          buffer << "\e[0m\e[2J" unless previous
          style = UInt16::MAX
          frame.height.times do |y|
            cursor = -1
            frame.width.times do |x|
              cell = frame[x, y]
              next if previous && previous[x, y] == cell

              buffer << "\e[" << y + 1 << ';' << x + 1 << 'H' unless cursor == x
              buffer << frame.styles.sgr(cell.style) unless cell.style == style
              buffer << cell.char
              style = cell.style
              cursor = x + 1
            end
          end
          buffer << "\e[0m" << SYNC_END
        end
        @io.write(output.to_slice)
        @io.flush
        @previous = frame
      end

      # Forget the last frame: the next one is drawn whole (after a resize, or when something else wrote to the screen).
      def invalidate : Nil
        @previous = nil
      end
    end

    # Inline renderer: redraws its own block of lines below the cursor and leaves the last frame in the scrollback.
    class InlineRenderer < Renderer
      getter drawn = 0

      def initialize(@io : IO, @color : Bool = true)
      end

      def full_screen? : Bool
        false
      end

      def flush(frame : Frame) : Nil
        lines = @color ? frame.ansi_lines : frame.to_text.split('\n')
        output = String.build do |buffer|
          buffer << SYNC_BEGIN if @color
          buffer << "\e[" << @drawn << 'F' if @drawn > 0
          buffer << "\e[J" if @drawn > 0
          lines.each { |line| buffer << line << "\r\n" } # \r: raw mode does not return the carriage on \n
          buffer << SYNC_END if @color
        end
        @io.write(output.to_slice)
        @io.flush
        @drawn = lines.size
      end

      # Removes the block (a wizard moving on to its next screen).
      def clear : Nil
        return if @drawn == 0

        @io << "\e[" << @drawn << "F\e[J"
        @io.flush
        @drawn = 0
      end

      # The next flush starts a new block below this one, which stays as printed.
      def commit : Nil
        @drawn = 0
      end
    end
  end
end
