module AzuCLI
  module UI
    # One question of a wizard. Every step maps to a command-line flag, so a wizard is only a way of building flags.
    abstract class Step
      getter label : String
      getter question : String
      getter explanation : String
      @skip : Proc(Bool)

      def initialize(@label : String, @question : String, @explanation : String = "", skip : Proc(Bool)? = nil)
        @skip = skip || -> { false }
      end

      def skip? : Bool
        @skip.call
      end

      # Handles a key; true when the step changed.
      abstract def handle(key : Key) : Bool
      abstract def draw(frame : Frame, area : Rect) : Nil
      # The answer, as the "Stack so far" card shows it.
      abstract def summary : String

      # Why the step would not accept Enter now (a text that does not validate), or nil.
      def error : String?
        nil
      end

      # What the highlighted option means, under the options.
      def hint : String
        explanation
      end

      # The rows the step needs, without the hint.
      abstract def rows : Int32
    end

    record Option, value : String, label : String, description : String = "", hint : String = ""

    # Pick one: ● the highlighted option, ○ the others.
    class ChoiceStep < Step
      getter options : Array(Option)
      getter index : Int32

      def initialize(label : String, question : String, @options : Array(Option), selected : String? = nil, explanation : String = "", skip : Proc(Bool)? = nil)
        super(label, question, explanation, skip)
        @index = selected.try { |value| @options.index { |option| option.value == value } } || 0
      end

      def value : String
        options[index].value
      end

      def summary : String
        options[index].label
      end

      def hint : String
        options[index].hint.presence || explanation
      end

      def rows : Int32
        options.size
      end

      def handle(key : Key) : Bool
        case key.code
        when .up?, .back_tab? then move(-1)
        when .down?           then move(1)
        when .home?           then move(-index)
        when .end?            then move(options.size - 1 - index)
        when .char?
          char = key.char
          if char == 'k'
            move(-1)
          elsif char == 'j' || char == ' '
            move(1)
          elsif char && (found = options.index { |option| option.label.downcase.starts_with?(char.downcase) })
            changed = found != index
            @index = found
            changed
          else
            false
          end
        else false
        end
      end

      private def move(by : Int32) : Bool
        target = (index + by).clamp(0, options.size - 1)
        changed = target != index
        @index = target
        changed
      end

      def draw(frame : Frame, area : Rect) : Nil
        g = frame.glyphs
        label_width = Math.max(options.max_of { |option| Width.of(option.label) } + 3, 14)
        options.each_with_index do |option, row|
          break if row >= area.h
          y = area.y + row
          on = row == index
          x = frame.text(area.x, y, on ? g.on : g.off, on ? Token::Cyan : Token::Muted)
          frame.text(x + 1, y, option.label, on ? Token::Cyan : Token::Text, on ? Attr::Bold : Attr::None, max: area.w - 3)
          frame.text(area.x + 2 + label_width, y, option.description, Token::Muted, max: area.w - 2 - label_width) if area.w > label_width + 6
        end
      end
    end

    record Toggle, flag : String, label : String, description : String = "", on : Bool = false

    # Several on/off switches: [x] on, [ ] off; Space flips the highlighted one.
    class ToggleStep < Step
      getter toggles : Array(Toggle)
      getter index = 0

      def initialize(label : String, question : String, @toggles : Array(Toggle), explanation : String = "", skip : Proc(Bool)? = nil)
        super(label, question, explanation, skip)
      end

      def on?(flag : String) : Bool
        toggles.find { |toggle| toggle.flag == flag }.try(&.on) || false
      end

      def summary : String
        chosen = toggles.select(&.on).map(&.label)
        chosen.empty? ? "none" : chosen.join(", ")
      end

      def rows : Int32
        toggles.size
      end

      def handle(key : Key) : Bool
        case key.code
        when .up?   then move(-1)
        when .down? then move(1)
        when .char?
          case key.char
          when ' ', 'x'
            toggle = toggles[index]
            @toggles[index] = toggle.copy_with(on: !toggle.on)
            true
          when 'k' then move(-1)
          when 'j' then move(1)
          else          false
          end
        else false
        end
      end

      private def move(by : Int32) : Bool
        target = (index + by).clamp(0, toggles.size - 1)
        changed = target != index
        @index = target
        changed
      end

      def draw(frame : Frame, area : Rect) : Nil
        label_width = Math.max(toggles.max_of { |toggle| Width.of(toggle.label) } + 8, 20)
        toggles.each_with_index do |toggle, row|
          break if row >= area.h
          y = area.y + row
          focused = row == index
          x = frame.text(area.x, y, focused ? frame.glyphs.pointer : " ", Token::Purple)
          x = frame.text(x + 1, y, toggle.on ? "[x]" : "[ ]", toggle.on ? Token::Cyan : Token::Muted)
          frame.text(x + 1, y, toggle.label, focused ? Token::Cyan : Token::Text, focused ? Attr::Bold : Attr::None, max: area.w - 6)
          frame.text(area.x + label_width, y, toggle.description, Token::Muted, max: area.w - label_width) if area.w > label_width + 6
        end
      end
    end

    # A line of text with a default and a validation.
    class TextStep < Step
      getter value : String
      @validate : Proc(String, String?)

      def initialize(label : String, question : String, @value : String = "", explanation : String = "", validate : Proc(String, String?)? = nil, skip : Proc(Bool)? = nil)
        super(label, question, explanation, skip)
        @validate = validate || ->(_text : String) { nil.as(String?) }
      end

      def summary : String
        value.empty? ? "—" : value
      end

      def rows : Int32
        2
      end

      def error : String?
        @validate.call(value)
      end

      def handle(key : Key) : Bool
        case key.code
        when .backspace?
          return false if value.empty?
          @value = value[0...-1]
          true
        when .ctrl_u?
          @value = ""
          true
        when .paste?
          @value += key.text.to_s.gsub(/[\r\n\t]/, "")
          true
        when .char?
          @value += key.char.to_s
          true
        else
          false
        end
      end

      def draw(frame : Frame, area : Rect) : Nil
        x = frame.text(area.x, area.y, "#{frame.glyphs.pointer} ", Token::Purple)
        x = frame.text(x, area.y, value, Token::Cyan, Attr::Bold, max: area.w - 4)
        frame.text(x, area.y, "▌", Token::Cyan)
        if message = error
          frame.text(area.x + 2, area.y + 1, message, Token::Amber, max: area.w - 2)
        end
      end
    end

    # A multi-step wizard drawn inline: the step on the left, the answers so far on the right, then a review screen
    # before anything happens. Each answer is also a flag (`command`), so the wizard and a scripted run agree.
    class Wizard < Screen
      enum Outcome
        Pending
        Confirmed
        Cancelled
      end

      getter steps : Array(Step)
      getter current = 0
      getter outcome = Outcome::Pending
      getter? reviewing = false
      @plan : Proc(Array(Array(Seg)))
      @command : Proc(String)

      def initialize(@command_name : String, @subject : String, @steps : Array(Step), plan : Proc(Array(Array(Seg)))? = nil, command : Proc(String)? = nil)
        @plan = plan || -> { [] of Array(Seg) }
        @command = command || -> { "" }
        @current = next_index(-1, 1) || 0
      end

      def update(event : Event) : Action
        key = event.as?(Key)
        return Action::Continue unless key

        if key.code.ctrl_c? || key.code.ctrl_d? || key.code.esc?
          @outcome = Outcome::Cancelled
          return Action::Quit
        end
        reviewing? ? review_key(key) : step_key(key)
      end

      private def step_key(key : Key) : Action
        step = steps[current]
        case key.code
        when .enter?, .tab?
          return Action::Redraw if step.error
          advance
          return Action::Redraw
        when .back_tab?
          back
          return Action::Redraw
        when .left?
          return Action::Continue if step.is_a?(TextStep)
          back
          return Action::Redraw
        end
        step.handle(key) ? Action::Redraw : Action::Continue
      end

      private def review_key(key : Key) : Action
        case
        when key.code.enter?, key.char?('y')
          @outcome = Outcome::Confirmed
          Action::Quit
        when key.char?('e'), key.code.back_tab?, key.code.left?
          @reviewing = false
          Action::Redraw
        else
          Action::Continue
        end
      end

      private def advance : Nil
        if found = next_index(current, 1)
          @current = found
        else
          @reviewing = true
        end
      end

      private def back : Nil
        next_index(current, -1).try { |found| @current = found }
      end

      private def next_index(from : Int32, by : Int32) : Int32?
        index = from + by
        while 0 <= index < steps.size
          return index unless steps[index].skip?
          index += by
        end
        nil
      end

      private def visible : Array(Step)
        steps.reject(&.skip?)
      end

      def height(columns : Int32, rows : Int32) : Int32
        body = reviewing? ? Math.max(visible.size, @plan.call.size) + 1 : Math.max(steps.max_of(&.rows) + 7, visible.size + 3)
        body + 5
      end

      def view(frame : Frame) : Nil
        width = Math.min(frame.width, 100)
        title_bar(frame, width)
        body = Rect.new(0, 1, width, frame.height - 3)
        reviewing? ? draw_review(frame, body) : draw_step(frame, body)
        keys = reviewing? ? [{"Enter", "Launch"}, {"e", "Edit"}, {"Esc", "Quit"}] : step_keys
        Widgets.key_bar(frame, 1, frame.height - 1, keys, width - 2)
        if reviewing? && (command = @command.call.presence)
          frame.text(1, frame.height - 2, "as a command  ", Token::Muted)
          frame.text(15, frame.height - 2, command, Token::Text, max: width - 16)
        end
      end

      private def step_keys : Array({String, String})
        step = steps[current]
        keys = [] of {String, String}
        keys << {"↑/↓", "Move"} unless step.is_a?(TextStep)
        keys << {"Space", "Toggle"} if step.is_a?(ToggleStep)
        keys << {"Enter", "Next"}
        keys << {"⇧Tab", "Back"} if next_index(current, -1)
        keys << {"Esc", "Quit"}
        keys
      end

      private def title_bar(frame : Frame, width : Int32) : Nil
        x = frame.gradient(1, 0, frame.glyphs.brand, Attr::Bold)
        x = frame.text(x, 0, "  #{@command_name} #{frame.glyphs.dot} ", Token::Muted)
        frame.text(x, 0, @subject, Token::Text)
        shown = visible
        position = shown.index(steps[current]) || 0
        done = reviewing? ? shown.size : position
        full, empty = Widgets.meter(shown.empty? ? 1.0 : done / shown.size, shown.size, frame.glyphs.meter_full, frame.glyphs.meter_empty)
        label = reviewing? ? "review  " : "step #{position + 1} of #{shown.size}  "
        right = width - 1 - Width.of(full) - Width.of(empty)
        frame.text(right - Width.of(label), 0, label, Token::Muted)
        x = frame.text(right, 0, full, Token::Cyan)
        frame.text(x, 0, empty, Token::Faint)
      end

      private def draw_step(frame : Frame, body : Rect) : Nil
        left, right = body.columns(2)
        step = steps[current]
        inner = frame.card(left, "Wizard")
        frame.text(inner.x, inner.y + 1, step.label, Token::Text, Attr::Bold, max: inner.w)
        frame.text(inner.x, inner.y + 2, step.question, Token::Muted, max: inner.w)
        options = Rect.new(inner.x, inner.y + 4, inner.w, step.rows)
        step.draw(frame, options)
        if (hint = step.hint.presence) && options.bottom + 1 < inner.bottom
          wrap(hint, inner.w - 2).first(inner.bottom - options.bottom - 1).each_with_index do |line, index|
            frame.text(inner.x, options.bottom + 1 + index, index == 0 ? frame.glyphs.pointer : " ", Token::Purple)
            frame.text(inner.x + 2, options.bottom + 1 + index, line, Token::Muted, max: inner.w - 2)
          end
        end
        draw_stack(frame, right)
      end

      private def draw_stack(frame : Frame, rect : Rect) : Nil
        inner = frame.card(rect, "Stack so far")
        g = frame.glyphs
        label_width = Math.max(visible.max_of { |step| Width.of(step.label) } + 2, 10)
        visible.each_with_index do |step, row|
          break if row >= inner.h
          y = inner.y + row
          index = steps.index(step) || 0
          mark, tone = if reviewing? || index < current
                         {g.ok, Token::Green}
                       elsif index == current
                         {g.busy, Token::Cyan}
                       else
                         {g.off, Token::Faint}
                       end
          frame.text(inner.x, y, mark, tone)
          frame.text(inner.x + 2, y, step.label, index > current && !reviewing? ? Token::Faint : Token::Muted)
          value = index > current && !reviewing? ? "—" : step.summary
          frame.text(inner.x + 2 + label_width, y, value, index == current && !reviewing? ? Token::Cyan : (index > current ? Token::Faint : Token::Text), max: inner.w - 2 - label_width)
        end
      end

      private def draw_review(frame : Frame, body : Rect) : Nil
        left, right = body.columns(2)
        inner = frame.card(left, "Flight plan")
        label_width = Math.max(visible.max_of { |step| Width.of(step.label) } + 2, 10)
        visible.each_with_index do |step, row|
          break if row >= inner.h
          frame.text(inner.x, inner.y + row, step.label, Token::Muted)
          frame.text(inner.x + label_width, inner.y + row, step.summary, Token::Text, max: inner.w - label_width)
        end
        plan = frame.card(right, "What happens next")
        @plan.call.each_with_index do |segs, row|
          break if row >= plan.h
          frame.line(plan.x, plan.y + row, segs, plan.w)
        end
      end

      private def wrap(text : String, width : Int32) : Array(String)
        lines = [] of String
        line = ""
        text.split(' ').each do |word|
          if !line.empty? && Width.of(line) + 1 + Width.of(word) > width
            lines << line
            line = word
          else
            line = line.empty? ? word : "#{line} #{word}"
          end
        end
        lines << line unless line.empty?
        lines
      end
    end
  end
end
