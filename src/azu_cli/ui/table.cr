module AzuCLI
  module UI
    # Rows of cells laid out in columns that fit a width, as panel lines. The widest column gives up room first, and
    # a cell that does not fit ends with an ellipsis. The header row is muted.
    class Table
      GAP = 2

      getter headers : Array(String)
      getter rows : Array(Array(Seg))

      def initialize(@headers : Array(String), @rows : Array(Array(Seg)))
      end

      def lines(width : Int32) : Array(Array(Seg))
        widths = fit(width)
        header = headers.map_with_index { |text, column| Seg[cell(text, widths[column], column), Token::Muted] }
        [header] + rows.map { |row| row.map_with_index { |seg, column| Seg.new(cell(seg.text, widths[column], column), seg.style) } }
      end

      # Column widths that add up (with the gaps) to no more than `width`; no column below 3.
      def fit(width : Int32) : Array(Int32)
        widths = headers.map_with_index do |header, column|
          ([Width.of(header)] + rows.map { |row| Width.of(row[column]?.try(&.text) || "") }).max
        end
        room = width - GAP * (widths.size - 1)
        while widths.sum > room
          widest = widths.index(widths.max).not_nil!
          break if widths[widest] <= 3
          widths[widest] -= 1
        end
        widths
      end

      private def cell(text : String, width : Int32, column : Int32) : String
        fitted = Width.truncate(text, width)
        column == headers.size - 1 ? fitted : Width.pad(fitted, width + GAP)
      end
    end
  end
end
