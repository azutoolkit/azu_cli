module AzuCLI
  module UI
    # Display width of characters in a terminal: 0 for control and combining characters, 2 for East Asian wide and
    # emoji, 1 for the rest. Frames only hold width-1 characters (two-column glyphs break the borders), so `Text`
    # helpers measure with this and truncate before drawing.
    module Width
      ZERO = [
        {0x0300, 0x036F}, {0x0483, 0x0489}, {0x0591, 0x05BD}, {0x0610, 0x061A}, {0x064B, 0x065F},
        {0x200B, 0x200F}, {0x202A, 0x202E}, {0x2060, 0x2064}, {0x20D0, 0x20FF}, {0xFE00, 0xFE0F},
        {0xFE20, 0xFE2F}, {0xFEFF, 0xFEFF}, {0xE0100, 0xE01EF},
      ]

      WIDE = [
        {0x1100, 0x115F}, {0x231A, 0x231B}, {0x2329, 0x232A}, {0x23E9, 0x23EC}, {0x23F0, 0x23F0},
        {0x23F3, 0x23F3}, {0x25FD, 0x25FE}, {0x2614, 0x2615}, {0x2648, 0x2653}, {0x267F, 0x267F},
        {0x2693, 0x2693}, {0x26A1, 0x26A1}, {0x26AA, 0x26AB}, {0x26BD, 0x26BE}, {0x26C4, 0x26C5},
        {0x26CE, 0x26CE}, {0x26D4, 0x26D4}, {0x26EA, 0x26EA}, {0x26F2, 0x26F3}, {0x26F5, 0x26F5},
        {0x26FA, 0x26FA}, {0x26FD, 0x26FD}, {0x2705, 0x2705}, {0x270A, 0x270B}, {0x2728, 0x2728},
        {0x274C, 0x274C}, {0x274E, 0x274E}, {0x2753, 0x2755}, {0x2757, 0x2757}, {0x2795, 0x2797},
        {0x27B0, 0x27B0}, {0x27BF, 0x27BF}, {0x2B1B, 0x2B1C}, {0x2B50, 0x2B50}, {0x2B55, 0x2B55},
        {0x2E80, 0x303E}, {0x3041, 0x33FF}, {0x3400, 0x4DBF}, {0x4E00, 0x9FFF}, {0xA000, 0xA4CF},
        {0xA960, 0xA97F}, {0xAC00, 0xD7A3}, {0xF900, 0xFAFF}, {0xFE10, 0xFE19}, {0xFE30, 0xFE6F},
        {0xFF00, 0xFF60}, {0xFFE0, 0xFFE6}, {0x1F004, 0x1F004}, {0x1F0CF, 0x1F0CF}, {0x1F18E, 0x1F18E},
        {0x1F191, 0x1F19A}, {0x1F200, 0x1F251}, {0x1F300, 0x1F64F}, {0x1F680, 0x1F6FF}, {0x1F7E0, 0x1F7EB},
        {0x1F90C, 0x1F9FF}, {0x1FA70, 0x1FAFF}, {0x20000, 0x2FFFD}, {0x30000, 0x3FFFD},
      ]

      def self.of(char : Char) : Int32
        code = char.ord
        return 0 if code < 0x20 || (0x7F <= code < 0xA0)
        return 1 if code < 0x0300
        return 0 if in?(ZERO, code)
        in?(WIDE, code) ? 2 : 1
      end

      def self.of(text : String) : Int32
        text.each_char.sum { |char| of(char) }
      end

      # `text` cut to at most `columns` display columns, ending in `…` when something was cut.
      def self.truncate(text : String, columns : Int32) : String
        return "" if columns <= 0
        return text if of(text) <= columns

        used = 0
        String.build do |io|
          text.each_char do |char|
            width = of(char)
            break if used + width > columns - 1
            io << char
            used += width
          end
          io << '…'
        end
      end

      # `text` padded with spaces (or truncated) to exactly `columns`.
      def self.pad(text : String, columns : Int32) : String
        cut = truncate(text, columns)
        cut + " " * (columns - of(cut))
      end

      private def self.in?(ranges : Array({Int32, Int32}), code : Int32) : Bool
        ranges.any? { |(low, high)| low <= code <= high }
      end
    end
  end
end
