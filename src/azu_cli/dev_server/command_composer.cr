require "./control"

module AzuCLI::DevServer
  # A local argv editor, not a shell. Execution remains in the serialized runner.
  class CommandComposer
    include UI
    getter? active = false
    getter? busy = false
    getter draft = ""
    @pending : Control::Command?
    @output = ["Type generate scaffold Product name:string price_cents:int32 --spark"]
    @viewport = Viewport.new

    def initialize(@submit : Proc(Control::Command, Bool), @directory : String = Dir.current)
    end

    def open(generator : Bool = false) : Nil
      @active = true
      @draft = "generate " if generator && !busy?
    end

    def self.parse(line : String) : Control::Command
      raise ArgumentError.new("Command is limited to 1024 characters") if line.size > 1024
      raise ArgumentError.new("Use one command; shell operators are not supported") if line.matches?(/[\x00-\x1f\x7f;|&<>`$]/)
      args = Process.parse_arguments_posix(line)
      args.shift if args.first? == "azu"
      args[0] = "generate" if args.first? == "g"
      raise ArgumentError.new("Enter an azu command") if args.empty?
      if args.first == "generate"
        raise ArgumentError.new("Provide a generator type, name and fields") if args.size < 2
        raise ArgumentError.new("The HUD manages --ui; omit that option") if args.any? { |arg| arg == "--ui" || arg.starts_with?("--ui=") }
        return Control::Command.new("interactive", "Local", args, confirm: true)
      end
      command = Control.catalog(jobs: true).find { |entry| entry.args == args }
      raise ArgumentError.new("Use generate with arguments, or a command from ? Commands (exact arguments)") unless command
      Control::Command.new("interactive", "Local", args, confirm: true)
    end

    def update(event : Event) : Action
      case event
      when Events::ControlQueued
        @busy = true if event.id == "interactive"
      when Events::ControlStarted
        @output = ["Running locally in #{@directory}…"] if event.id == "interactive"
      when Events::ControlFinished
        if event.id == "interactive"
          @busy = false
          @output = ["Exit #{event.exit_code} · #{event.seconds.round(2)}s"] + event.output.lines.last(500)
        end
      when Key
        if event.code.esc?
          @pending = nil
          @active = false
        elsif pending = @pending
          if event.char?('y')
            @busy = @submit.call(pending)
            @output = [busy? ? "Queued: #{pending.line}" : "Command already queued or runner stopped"]
            @pending = nil
          elsif event.char?('n')
            @pending = nil
          else
            @viewport.key(event)
          end
        elsif !busy?
          case event.code
          when .enter?
            begin
              @pending = self.class.parse(draft)
              @viewport.reset
            rescue ex : ArgumentError
              @output = [ex.message || "Invalid command"]
            end
          when .backspace? then @draft = draft[0, Math.max(0, draft.size - 1)]
          when .char?      then @draft += event.char.to_s if draft.size < 1024
          when .paste?
            pasted = event.text || ""
            @draft += pasted.gsub(/[\x00-\x1f\x7f]/, " ")[0, Math.max(0, 1024 - draft.size)]
          else
            @viewport.key(event)
          end
        else
          @viewport.key(event)
        end
      end
      Action::Redraw
    end

    def view(frame : Frame) : Nil
      box = frame.area.inset(2, 2)
      style = frame.style(bg: Token::Backplate)
      box.y.upto(box.bottom - 1) { |y| box.x.upto(box.right - 1) { |x| frame.put(x, y, ' ', style) } }
      inner = frame.card(box, "Local command · #{busy? ? "running" : "azu"}", "Esc closes", border: Token::Cyan)
      frame.text(inner.x, inner.y, "Directory: #{@directory}", Token::Muted, max: inner.w)
      frame.text(inner.x, inner.y + 1, "Environment: #{ENV["CRYSTAL_ENV"]? || "development"} · uses configured services", Token::Amber, max: inner.w)
      if pending = @pending
        frame.text(inner.x, inner.y + 3, pending.line, Token::Cyan, max: inner.w)
        frame.text(inner.x, inner.y + 4, "Run this command? y executes · n edits · Esc cancels", Token::Amber, max: inner.w)
      else
        frame.text(inner.x, inner.y + 3, "> #{Width.truncate(draft.reverse, Math.max(1, inner.w - 4)).reverse}▏", Token::Cyan, max: inner.w)
        frame.text(inner.x, inner.y + 4, "Enter reviews · PgUp/PgDn scroll output · no shell expansion", Token::Muted, max: inner.w)
      end
      _, output = inner.split_top(6)
      lines = Viewport.wrap(@pending.try { |command| ["Full command:", command.line] } || @output, output.w - 1)
      @viewport.draw(frame, output, lines)
    end
  end
end
