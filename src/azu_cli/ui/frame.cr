module AzuCLI
  module UI
    # Styles are interned: a cell stores a UInt16 and each style's escape sequence is built once.
    class StyleTable
      getter theme : Theme
      @ids = {} of Style => UInt16
      @sgr = [] of String

      def initialize(@theme : Theme, @background : Token? = nil)
        id(Style.new) # 0: the reset style
      end

      def id(style : Style) : UInt16
        style = style.copy_with(bg: style.bg || @background)
        @ids[style] ||= begin
          @sgr << @theme.sgr(style)
          (@sgr.size - 1).to_u16
        end
      end

      def sgr(id : UInt16) : String
        @sgr[id]
      end
    end

    record Cell, char : Char = ' ', style : UInt16 = 0_u16

    # A text run in one style; a line is an array of them.
    record Seg, text : String, style : Style = Style.new do
      def self.[](text : String, fg : Token? = nil, attrs : Attr = Attr::None) : Seg
        new(text, Style.new(fg, attrs: attrs))
      end
    end

    record Rect, x : Int32, y : Int32, w : Int32, h : Int32 do
      def right : Int32
        x + w
      end

      def bottom : Int32
        y + h
      end

      def empty? : Bool
        w <= 0 || h <= 0
      end

      def inset(dx : Int32, dy : Int32) : Rect
        Rect.new(x + dx, y + dy, Math.max(0, w - 2 * dx), Math.max(0, h - 2 * dy))
      end

      # `count` columns of equal width (the last takes the remainder) with `gap` columns between them.
      def columns(count : Int32, gap : Int32 = 0) : Array(Rect)
        width = (w - gap * (count - 1)) // count
        Array.new(count) do |index|
          left = x + index * (width + gap)
          Rect.new(left, y, index == count - 1 ? right - left : width, h)
        end
      end

      # The top `rows` rows, and what is left below them.
      def split_top(rows : Int32) : {Rect, Rect}
        rows = rows.clamp(0, h)
        {Rect.new(x, y, w, rows), Rect.new(x, y + rows, w, h - rows)}
      end

      def split_left(cols : Int32, gap : Int32 = 0) : {Rect, Rect}
        cols = cols.clamp(0, w)
        {Rect.new(x, y, cols, h), Rect.new(x + cols + gap, y, Math.max(0, w - cols - gap), h)}
      end
    end

    # A grid of cells a screen draws into; renderers turn it into escape codes, specs into text.
    class Frame
      getter width : Int32
      getter height : Int32
      getter styles : StyleTable
      @cells : Array(Cell)

      def initialize(@width : Int32, @height : Int32, @styles : StyleTable)
        @cells = Array.new(width * height, Cell.new)
      end

      def theme : Theme
        styles.theme
      end

      def glyphs : Glyphs
        theme.glyphs
      end

      def area : Rect
        Rect.new(0, 0, width, height)
      end

      def [](x : Int32, y : Int32) : Cell
        @cells[y * width + x]
      end

      def put(x : Int32, y : Int32, char : Char, style : UInt16) : Nil
        return unless 0 <= x < width && 0 <= y < height
        @cells[y * width + x] = Cell.new(char, style)
      end

      def style(fg : Token? = nil, attrs : Attr = Attr::None, bg : Token? = nil) : UInt16
        styles.id(Style.new(fg, bg, attrs))
      end

      # Writes `text` from (x, y) clipped to `max` columns; returns the column after it. Characters that are not one
      # column wide are replaced by '?' so they never shift a border.
      def text(x : Int32, y : Int32, text : String, style : UInt16 = 0_u16, max : Int32 = Int32::MAX) : Int32
        limit = Math.min(width, x.to_i64 + max).to_i
        text.each_char do |char|
          break if x >= limit
          columns = Width.of(char)
          next if columns == 0
          put(x, y, columns == 1 ? char : '?', style)
          x += 1
        end
        x
      end

      def text(x : Int32, y : Int32, text : String, fg : Token, attrs : Attr = Attr::None, max : Int32 = Int32::MAX) : Int32
        text(x, y, text, style(fg, attrs), max)
      end

      # A line of segments; truncated with … when it does not fit `max`.
      def line(x : Int32, y : Int32, segs : Array(Seg), max : Int32) : Int32
        total = segs.sum { |seg| Width.of(seg.text) }
        if total > max
          remaining = max
          segs = segs.compact_map do |seg|
            next if remaining <= 0
            cut = Width.of(seg.text) > remaining ? Width.truncate(seg.text, remaining) : seg.text
            remaining -= Width.of(cut)
            Seg.new(cut, seg.style)
          end
        end
        segs.each { |seg| x = text(x, y, seg.text, styles.id(seg.style)) }
        x
      end

      # `text` on the cyan → purple gradient.
      def gradient(x : Int32, y : Int32, text : String, attrs : Attr = Attr::None) : Int32
        chars = text.chars
        chars.each_with_index do |char, index|
          put(x + index, y, char, styles.id(theme.gradient(index, chars.size, attrs)))
        end
        x + chars.size
      end

      def fill(rect : Rect, char : Char = ' ', style : UInt16 = 0_u16) : Nil
        rect.h.times { |dy| rect.w.times { |dx| put(rect.x + dx, rect.y + dy, char, style) } }
      end

      def hline(x : Int32, y : Int32, length : Int32, style : UInt16) : Nil
        length.times { |offset| put(x + offset, y, glyphs.horizontal, style) }
      end

      # A card: a rounded border, a title in the top edge, an optional badge at its right end. Returns the inside
      # (one column of padding on each side).
      def card(rect : Rect, title : String, badge : String? = nil, border : Token = Token::Faint, title_color : Token = Token::Purple, badge_color : Token = Token::Muted) : Rect
        return rect if rect.w < 4 || rect.h < 2

        edge = style(border)
        g = glyphs
        put(rect.x, rect.y, g.top_left, edge)
        put(rect.right - 1, rect.y, g.top_right, edge)
        put(rect.x, rect.bottom - 1, g.bottom_left, edge)
        put(rect.right - 1, rect.bottom - 1, g.bottom_right, edge)
        hline(rect.x + 1, rect.y, rect.w - 2, edge)
        hline(rect.x + 1, rect.bottom - 1, rect.w - 2, edge)
        (rect.y + 1).upto(rect.bottom - 2) do |row|
          put(rect.x, row, g.vertical, edge)
          put(rect.right - 1, row, g.vertical, edge)
        end
        room = rect.w - 6
        if badge && room > Width.of(badge) + 4
          label = " #{badge} "
          text(rect.right - 2 - Width.of(label), rect.y, label, badge_color)
          room -= Width.of(label) + 1
        end
        text(rect.x + 2, rect.y, " #{Width.truncate(title, room)} ", title_color) unless title.empty?
        Rect.new(rect.x + 2, rect.y + 1, Math.max(0, rect.w - 4), Math.max(0, rect.h - 2))
      end

      # The frame as plain text, one line per row, trailing spaces removed: golden files and the plain fallback.
      def to_text : String
        String.build do |io|
          height.times do |row|
            io << String.build { |line| width.times { |column| line << self[column, row].char } }.rstrip
            io << '\n' unless row == height - 1
          end
        end
      end

      # Each row with its escape codes, trailing blanks removed: what the inline renderer prints.
      def ansi_lines : Array(String)
        Array.new(height) do |row|
          last = width - 1
          while last >= 0 && self[last, row].char == ' ' && self[last, row].style == 0
            last -= 1
          end
          String.build do |io|
            current = 0_u16
            0.upto(last) do |column|
              cell = self[column, row]
              io << styles.sgr(cell.style) if cell.style != current
              current = cell.style
              io << cell.char
            end
            io << "\e[0m" if current != 0 && theme.color?
          end
        end
      end
    end
  end
end
