module AzuCLI
  module UI
    record Resize, columns : Int32, rows : Int32
    record Tick, at : Time::Instant

    # Data from a source (a build, telemetry, a sampler). Screens match on the concrete type.
    abstract struct Message
    end

    alias Event = Key | Resize | Tick | Message

    enum Action
      # Nothing visible changed.
      Continue
      Redraw
      Quit
      # The screen has work that needs the terminal to itself (an interpreter): `Screen#handoff`
      Handoff
    end

    # An interactive screen: a state machine (update) and a pure drawing of its state (view), so specs drive it with
    # events and compare frames without a terminal.
    abstract class Screen
      abstract def update(event : Event) : Action
      abstract def view(frame : Frame) : Nil

      # Ticks only arrive while this is true (a spinner is on screen): an idle screen draws nothing.
      def animating? : Bool
        false
      end

      # The work an `Action::Handoff` asked for, taken once: the program leaves the terminal to it, then draws again.
      def handoff : Proc(Nil)?
        nil
      end

      # The rows an inline screen needs at `columns` wide; full-screen screens take the whole window.
      def height(columns : Int32, rows : Int32) : Int32
        rows
      end
    end

    # The event loop: keys, ticks, resizes and messages from sources all arrive on one channel, and one fiber owns
    # the frame, so drawing needs no locks. A burst of messages (log lines, telemetry) is drawn as one frame.
    class Program
      TICK = 80.milliseconds

      getter events = Channel(Event).new(1024)
      @stopped = false

      def initialize(@screen : Screen, @terminal : Terminal, @renderer : Renderer)
        @styles = StyleTable.new(@terminal.theme)
      end

      # Sources call this from their own fibers. Dropped when the program has ended.
      def send(message : Message) : Nil
        return if @stopped
        if @suspended
          # While another program has the terminal nothing drains the channel: drop what does not fit
          select
          when events.send(message)
          else
          end
        else
          events.send(message)
        end
      rescue Channel::ClosedError
      end

      @suspended = false
      @reader : IO::FileDescriptor?

      def run(input : IO::FileDescriptor = Terminal.open_input) : Nil
        @terminal.session(input, full_screen: @renderer.full_screen?) do
          start_reader(input)
          spawn tick
          Signal::WINCH.trap { send_event(Resize.new(*@terminal.size)) }
          draw
          loop do
            redraw = false
            event = events.receive
            while event
              case @screen.update(event)
              in .quit?     then return
              in .redraw?   then redraw = true
              in .continue? then nil
              in .handoff?
                hand_off(input)
                redraw = true
              end
              event = poll
            end
            draw if redraw
          end
        end
      ensure
        @stopped = true
        Signal::WINCH.reset
        events.close
        input.try(&.close) rescue nil
      end

      # Draws the current state once without a loop: the last frame an inline screen leaves behind.
      def draw : Nil
        columns, rows = @terminal.size
        height = @renderer.full_screen? ? rows : Math.min(@screen.height(columns, rows), rows - 1)
        # Inline frames leave the last column free: writing into it makes some terminals wrap early.
        frame = Frame.new(@renderer.full_screen? ? columns : columns - 1, Math.max(1, height), @styles)
        @renderer.as?(FullScreenRenderer).try(&.invalidate) if @size != {columns, rows}
        @size = {columns, rows}
        @screen.view(frame)
        @renderer.flush(frame)
      end

      @size : {Int32, Int32}?

      private def send_event(event : Event) : Nil
        events.send(event) unless @stopped
      rescue Channel::ClosedError
      end

      private def poll : Event?
        select
        when event = events.receive?
          event
        else
          nil
        end
      end

      # Keys are read from a duplicate of the terminal's descriptor: closing it ends the reader (so another program can
      # read the keys) without closing the terminal.
      private def start_reader(input : IO::FileDescriptor) : Nil
        reader = IO::FileDescriptor.new(LibAzuTerm.dup(input.fd))
        @reader = reader
        spawn read_keys(reader)
      end

      # Leaves the terminal, as it was before the program, to the screen's handoff work, then takes it back.
      private def hand_off(input : IO::FileDescriptor) : Nil
        work = @screen.handoff || return
        full_screen = @renderer.full_screen?
        @suspended = true
        @reader.try { |reader| reader.close rescue nil }
        @terminal.restore(full_screen)
        input.cooked!
        begin
          work.call
        ensure
          input.raw!
          @terminal.output << "\e[?1049h" if full_screen
          @terminal.output << "\e[?25l\e[?2004h"
          @terminal.output.flush
          @renderer.as?(FullScreenRenderer).try(&.invalidate)
          @suspended = false
          start_reader(input)
        end
      end

      private def read_keys(input : IO::FileDescriptor) : Nil
        bytes = Bytes.new(256)
        until @stopped
          count = input.read(bytes)
          break if count == 0
          Input.parse(bytes[0, count]).each { |key| send_event(key) }
        end
      rescue IO::Error
        # the terminal went away or the program ended
      end

      private def tick : Nil
        until @stopped
          sleep TICK
          send_event(Tick.new(Time.instant)) if @screen.animating?
        end
      end
    end
  end
end
