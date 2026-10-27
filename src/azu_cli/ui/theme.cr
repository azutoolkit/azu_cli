module AzuCLI
  module UI
    # How many colors the terminal shows. `None` writes no escape codes at all.
    enum ColorDepth
      None
      Basic16
      Ansi256
      TrueColor
    end

    # The design tokens: code names a role, the theme turns it into the escape code for the terminal's depth.
    enum Token
      Backplate
      Text
      Muted
      Faint
      Cyan
      Purple
      Green
      Amber
      Red
      Blue
    end

    record Rgb, r : UInt8, g : UInt8, b : UInt8 do
      def self.hex(value : Int32) : Rgb
        new(((value >> 16) & 0xFF).to_u8, ((value >> 8) & 0xFF).to_u8, (value & 0xFF).to_u8)
      end

      # The color `t` (0.0 to 1.0) of the way from self to `other`.
      def mix(other : Rgb, t : Float64) : Rgb
        Rgb.new(lerp(r, other.r, t), lerp(g, other.g, t), lerp(b, other.b, t))
      end

      private def lerp(from : UInt8, to : UInt8, t : Float64) : UInt8
        (from + (to.to_f - from) * t).round.clamp(0, 255).to_u8
      end
    end

    @[Flags]
    enum Attr : UInt8
      Bold
      Dim
      Italic
      Underline
      Reverse
    end

    # `rgb` (a gradient cell) wins over `fg`.
    record Style, fg : Token? = nil, bg : Token? = nil, attrs : Attr = Attr::None, rgb : Rgb? = nil

    class Theme
      # {true color, 256-color index, 16-color SGR foreground code}
      PALETTE = {
        Token::Backplate => {0x0B0E14, 233, 39},
        Token::Text      => {0xC9D1D9, 252, 37},
        Token::Muted     => {0x8B949E, 246, 90},
        Token::Faint     => {0x2A313C, 236, 90},
        Token::Cyan      => {0x22D3EE, 44, 36},
        Token::Purple    => {0xA78BFA, 141, 35},
        Token::Green     => {0x34D399, 42, 32},
        Token::Amber     => {0xFBBF24, 214, 33},
        Token::Red       => {0xF87171, 203, 31},
        Token::Blue      => {0x60A5FA, 75, 34},
      }

      GRADIENT_STEPS = 16

      getter depth : ColorDepth
      getter glyphs : Glyphs

      def initialize(@depth : ColorDepth, @glyphs : Glyphs = Glyphs::UNICODE)
      end

      def color? : Bool
        !depth.none?
      end

      # The SGR sequence that sets `style` from a clean state ("" without color).
      def sgr(style : Style) : String
        return "" if depth.none?

        codes = ["0"]
        codes << "1" if style.attrs.bold?
        codes << "2" if style.attrs.dim?
        codes << "3" if style.attrs.italic?
        codes << "4" if style.attrs.underline?
        codes << "7" if style.attrs.reverse?
        if rgb = style.rgb
          codes << foreground(rgb)
        elsif fg = style.fg
          codes << foreground(fg)
        end
        style.bg.try { |bg| background(bg).try { |code| codes << code } }
        "\e[#{codes.join(';')}m"
      end

      # The style of position `index` of `count` cells on the cyan → purple gradient. Quantized so that a frame full of
      # gradients interns a bounded number of styles; with 16 colors the gradient is plain cyan.
      def gradient(index : Int32, count : Int32, attrs : Attr = Attr::None) : Style
        return Style.new(Token::Cyan, attrs: attrs) unless depth.true_color? || depth.ansi256?

        steps = depth.true_color? ? GRADIENT_STEPS : 6
        t = count <= 1 ? 0.0 : index.to_f / (count - 1)
        t = (t * (steps - 1)).round / (steps - 1)
        Style.new(attrs: attrs, rgb: rgb(Token::Cyan).mix(rgb(Token::Purple), t))
      end

      def rgb(token : Token) : Rgb
        Rgb.hex(PALETTE[token][0])
      end

      private def foreground(token : Token) : String
        true_color, indexed, basic = PALETTE[token]
        case depth
        when .true_color? then foreground(Rgb.hex(true_color))
        when .ansi256?    then "38;5;#{indexed}"
        else                   basic.to_s
        end
      end

      private def foreground(rgb : Rgb) : String
        depth.true_color? ? "38;2;#{rgb.r};#{rgb.g};#{rgb.b}" : "38;5;#{cube(rgb)}"
      end

      private def background(token : Token) : String?
        true_color, indexed, _ = PALETTE[token]
        case depth
        when .true_color?
          rgb = Rgb.hex(true_color)
          "48;2;#{rgb.r};#{rgb.g};#{rgb.b}"
        when .ansi256? then "48;5;#{indexed}"
        else                nil # the 16 colors have no dark backplate: keep the terminal's own background
        end
      end

      # The nearest color of the 6x6x6 cube of the 256-color palette.
      private def cube(rgb : Rgb) : Int32
        level = ->(value : UInt8) { (value.to_f / 255 * 5).round.to_i }
        16 + 36 * level.call(rgb.r) + 6 * level.call(rgb.g) + level.call(rgb.b)
      end
    end

    # The glyphs a screen draws with; `ASCII` stands in when the locale is not UTF-8, TERM is dumb, or ambiguous-width
    # characters would be two columns wide (CJK locales, AZU_AMBIGUOUS_WIDE=1).
    record Glyphs,
      ok : String, fail : String, warn : String, on : String, off : String, busy : String, pointer : String,
      meter_full : Char, meter_empty : Char, bar_full : Char, bar_empty : Char, spark : Array(Char),
      spinner : Array(String), top_left : Char, top_right : Char, bottom_left : Char, bottom_right : Char,
      horizontal : Char, vertical : Char, brand : String, dot : String, ellipsis : String do
      UNICODE = new(
        ok: "✔", fail: "✖", warn: "▲", on: "●", off: "○", busy: "◆", pointer: "▸",
        meter_full: '▮', meter_empty: '▯', bar_full: '▰', bar_empty: '▱',
        spark: ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'],
        spinner: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
        top_left: '╭', top_right: '╮', bottom_left: '╰', bottom_right: '╯', horizontal: '─', vertical: '│',
        brand: "▲ AZU", dot: "·", ellipsis: "…")

      ASCII = new(
        ok: "[ok]", fail: "[!!]", warn: "/!\\", on: "(*)", off: "( )", busy: ">", pointer: ">",
        meter_full: '#', meter_empty: '-', bar_full: '#', bar_empty: '-',
        spark: ['_', '.', '-', '=', '*', '#'],
        spinner: ["-", "\\", "|", "/"],
        top_left: '+', top_right: '+', bottom_left: '+', bottom_right: '+', horizontal: '-', vertical: '|',
        brand: "AZU", dot: "-", ellipsis: "...")
    end
  end
end
