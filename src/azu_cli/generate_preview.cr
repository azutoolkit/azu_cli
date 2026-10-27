require "./ui"
require "./generate_plan"

module AzuCLI
  # The files a generator would write, before it writes them: the list on the left, the selected file (or its
  # diff) on the right, and whether the project still type-checks with them.
  class GeneratePreview < UI::Screen
    include UI

    struct TypeChecked < UI::Message
      getter error : String?

      def initialize(@error : String?)
      end
    end

    enum Check
      Off
      Running
      Passed
      Failed
    end

    getter selected = 0
    getter outcome : Bool? = nil
    getter check : Check
    @check_error : String?

    def initialize(@plan : GeneratePlan, @title : String, checking : Bool = false)
      @check = checking ? Check::Running : Check::Off
    end

    def animating? : Bool
      check.running?
    end

    def confirmed? : Bool
      @outcome == true
    end

    def height(columns : Int32, rows : Int32) : Int32
      Math.min(rows - 1, Math.max(@plan.entries.size + 6, 22))
    end

    def update(event : Event) : UI::Action
      case event
      when TypeChecked
        @check_error = event.error
        @check = event.error ? Check::Failed : Check::Passed
        UI::Action::Redraw
      when Tick
        UI::Action::Redraw
      when Key
        key(event)
      else
        UI::Action::Continue
      end
    end

    private def key(key : Key) : UI::Action
      case
      when key.code.ctrl_c?, key.code.esc?, key.char?('n'), key.char?('q')
        @outcome = false
        UI::Action::Quit
      when key.code.enter?, key.char?('y'), key.code.ctrl_s?
        @outcome = true
        UI::Action::Quit
      when key.code.up?, key.char?('k')
        move(-1)
      when key.code.down?, key.char?('j'), key.code.tab?
        move(1)
      else
        UI::Action::Continue
      end
    end

    private def move(by : Int32) : UI::Action
      target = (selected + by).clamp(0, Math.max(0, @plan.entries.size - 1))
      return UI::Action::Continue if target == selected
      @selected = target
      UI::Action::Redraw
    end

    def view(frame : Frame) : Nil
      width = Math.min(frame.width, 120)
      g = frame.glyphs
      x = frame.gradient(1, 0, g.brand, Attr::Bold)
      x = frame.text(x, 0, "  generate #{g.dot} ", Token::Muted)
      frame.text(x, 0, @title, Token::Text, max: width - x - 30)
      counts = [Seg["#{@plan.new_files.size} new", Token::Green], Seg[" #{g.dot} ", Token::Muted], Seg["#{@plan.changed_files.size} changed", Token::Amber]]
      count_width = counts.sum { |seg| Width.of(seg.text) }
      frame.line(width - 2 - count_width, 0, counts, count_width)

      body = Rect.new(0, 1, width, frame.height - 3)
      list_width = Math.min(48, width // 2 - 1)
      left, right = body.split_left(list_width, 1)
      files(frame, left)
      preview(frame, right)
      status(frame, 1, frame.height - 2, width - 2)
      writes = "Write #{@plan.entries.size} file#{@plan.entries.size == 1 ? "" : "s"}"
      Widgets.key_bar(frame, 1, frame.height - 1, [{"↑/↓", "File"}, {"Enter", writes}, {"Esc", "Cancel"}], width - 2)
    end

    private def files(frame : Frame, rect : Rect) : Nil
      inner = frame.card(rect, "Files")
      first = Math.max(0, selected - inner.h + 1)
      @plan.entries[first..].first(inner.h).each_with_index do |entry, row|
        index = first + row
        y = inner.y + row
        on = index == selected
        mark, tone = entry.kind.new? ? {"+", Token::Green} : {"~", Token::Amber}
        frame.text(inner.x, y, on ? frame.glyphs.pointer : " ", Token::Purple)
        frame.text(inner.x + 2, y, mark, tone)
        note = entry.kind.new? ? "#{entry.lines}" : "edit"
        frame.text(inner.x + 4, y, entry.path, on ? Token::Cyan : Token::Text, on ? Attr::Bold : Attr::None, max: inner.w - 6 - note.size)
        frame.text(inner.right - note.size, y, note, Token::Muted)
      end
    end

    private def preview(frame : Frame, rect : Rect) : Nil
      entry = @plan.entries[selected]?
      return frame.card(rect, "Preview") && nil unless entry

      title = "#{entry.kind.new? ? "+" : "~"} #{entry.path}"
      inner = frame.card(rect, title, "#{selected + 1} of #{@plan.entries.size}", title_color: entry.kind.new? ? Token::Green : Token::Amber)
      entry.diff.first(inner.h).each_with_index do |line, row|
        y = inner.y + row
        tone = case line.op
               when '+' then Token::Green
               when '-' then Token::Red
               when '~' then Token::Faint
               else          Token::Muted
               end
        frame.text(inner.x, y, line.op == ' ' || line.op == '~' ? " " : line.op.to_s, tone)
        frame.text(inner.x + 2, y, (line.number.try(&.to_s) || "").rjust(4), Token::Faint)
        frame.text(inner.x + 7, y, line.text.gsub('\t', "  "), line.op == '+' && entry.kind.changed? ? Token::Green : (line.op == '-' ? Token::Red : Token::Text), max: inner.w - 7)
      end
    end

    private def status(frame : Frame, x : Int32, y : Int32, max : Int32) : Nil
      g = frame.glyphs
      case check
      in .off?
        frame.text(x, y, "Not type-checked (--check runs crystal build --no-codegen on the result)", Token::Muted, max: max)
      in .running?
        frame.text(x, y, "#{Widgets.spinner(g)} type-checking the project with these files…", Token::Cyan, max: max)
      in .passed?
        frame.text(x, y, "#{g.ok} the project type-checks with these files", Token::Green, max: max)
      in .failed?
        first = @check_error.to_s.lines.find(&.starts_with?("Error:")) || @check_error.to_s.lines.last? || ""
        frame.text(x, y, "#{g.fail} does not compile: #{first.lchop("Error:").strip}", Token::Red, max: max)
      end
    end
  end
end
