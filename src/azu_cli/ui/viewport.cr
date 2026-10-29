module AzuCLI::UI
  # Owns only scroll state. Screens own data and selection; the renderer owns terminal IO.
  class Viewport
    getter offset = 0
    getter height = 0
    getter total = 0

    def configure(@total : Int32, height : Int32) : Nil
      @height = Math.max(0, height)
      @offset = @offset.clamp(0, last)
    end

    def last : Int32
      Math.max(0, total - height)
    end

    def reset : Nil
      @offset = 0
    end

    def reveal(index : Int32) : Nil
      @offset = index if index < offset
      @offset = index - height + 1 if height > 0 && index >= offset + height
      @offset = @offset.clamp(0, last)
    end

    def key(key : Key) : Bool
      case key.code
      when .up?        then @offset -= 1
      when .down?      then @offset += 1
      when .page_up?   then @offset -= Math.max(1, height - 1)
      when .page_down? then @offset += Math.max(1, height - 1)
      when .home?      then @offset = 0
      when .end?       then @offset = last
      else
        case key.char
        when 'k' then @offset -= 1
        when 'j' then @offset += 1
        when 'g' then @offset = 0
        when 'G' then @offset = last
        else          return false
        end
      end
      @offset = @offset.clamp(0, last)
      true
    end

    # ANSI/control bytes never reach terminal IO. Wrap by actual cell representation,
    # matching the renderer’s single-cell glyph policy for long traces and payloads.
    def self.wrap(lines : Array(String), width : Int32) : Array(String)
      return [] of String if width <= 0
      result = [] of String
      lines.each do |line|
        line.gsub(/\e\[[0-?]*[ -\/]*[@-~]/, "").split('\n').each do |part|
          chars = part.chars.compact_map do |char|
            columns = Width.of(char)
            columns == 0 ? nil : (columns == 1 ? char : '?')
          end
          if chars.empty?
            result << ""
          else
            chars.each_slice(width) { |chunk| result << chunk.join }
          end
        end
      end
      result
    end

    def draw(frame : Frame, area : Rect, lines : Array(String), selected : Int32? = nil, highlight : Proc(String, Array(Seg))? = nil) : Nil
      configure(lines.size, area.h)
      return if area.empty?
      content_width = Math.max(0, area.w - 1)
      lines.skip(offset).first(height).each_with_index do |line, row|
        active = selected == offset + row
        if painter = highlight
          frame.text(area.x, area.y + row, active ? "›" : " ", Token::Cyan, max: content_width)
          frame.line(area.x + 1, area.y + row, painter.call(line), Math.max(0, content_width - 1))
        else
          frame.text(area.x, area.y + row, line, active ? Token::Cyan : Token::Text,
            active ? Attr::Bold : Attr::None, max: content_width)
        end
      end
      return if total <= height || height == 0
      thumb = Math.max(1, height * height // total)
      start = last == 0 ? 0 : offset * (height - thumb) // last
      height.times do |row|
        frame.text(area.right - 1, area.y + row, (start <= row < start + thumb) ? "█" : "░", Token::Cyan, max: 1)
      end
    end
  end

  # Reusable master/detail pane, with selection anchored by stable IDs across snapshots.
  class Inspector
    record Item, id : String, label : String, details : Array(String)
    getter items = [] of Item
    getter selected = 0
    getter? detail_focus = false
    getter list = Viewport.new
    getter detail = Viewport.new

    def selected_item : Item?
      items[selected]?
    end

    def replace(items : Array(Item)) : Nil
      id = selected_item.try(&.id)
      @items = items
      next_index = id.try { |value| items.index { |item| item.id == value } }
      @selected = next_index || selected.clamp(0, Math.max(0, items.size - 1))
      detail.reset if id != selected_item.try(&.id)
      list.configure(items.size, list.height)
      list.reveal(selected)
    end

    def key(key : Key) : Bool
      if key.code.tab? || key.code.back_tab? || key.code.left? || key.code.right?
        @detail_focus = !detail_focus?
        return true
      end
      return detail.key(key) if detail_focus?
      previous = selected
      case key.code
      when .up?        then @selected -= 1
      when .down?      then @selected += 1
      when .page_up?   then @selected -= Math.max(1, list.height - 1)
      when .page_down? then @selected += Math.max(1, list.height - 1)
      when .home?      then @selected = 0
      when .end?       then @selected = items.size - 1
      else
        case key.char
        when 'k' then @selected -= 1
        when 'j' then @selected += 1
        when 'g' then @selected = 0
        when 'G' then @selected = items.size - 1
        else          return false
        end
      end
      @selected = selected.clamp(0, Math.max(0, items.size - 1))
      list.reveal(selected)
      detail.reset if previous != selected
      true
    end

    def draw(frame : Frame, area : Rect, title : String, empty : String, highlight : Proc(String, Array(Seg))? = nil) : Nil
      return if area.empty?
      left, right = area.split_left(area.w * 2 // 5, 1)
      if area.w < 70
        left = area
        right = area
      end
      if area.w >= 70 || !detail_focus?
        inner = frame.card(left, title, "#{items.size}", border: detail_focus? ? Token::Faint : Token::Cyan)
        if items.empty?
          frame.text(inner.x, inner.y, empty, Token::Muted, max: Math.max(0, inner.w)) unless inner.empty?
        else
          list.configure(items.size, inner.h)
          list.reveal(selected)
          list.draw(frame, inner, items.map(&.label), selected, highlight)
        end
      end
      if area.w >= 70 || detail_focus?
        inner = frame.card(right, "Details · Tab switches pane", border: detail_focus? ? Token::Cyan : Token::Faint)
        lines = Viewport.wrap(selected_item.try(&.details) || [empty], inner.w - (highlight ? 2 : 1))
        detail.draw(frame, inner, lines, highlight: highlight)
      end
    end
  end
end
