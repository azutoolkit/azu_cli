module AzuCLI
  module UI
    # The one-line messages commands print outside a card (the CLI's log lines): a glyph and a color per kind, from
    # the theme, so they read like the cards around them. Without color they are the glyph and the text.
    class Lines
      enum Kind
        Debug
        Info
        Warn
        Error
        Fatal
        Success
        Title
        Prompt
        Command
        Created
        Modified
        Skipped
      end

      # Leading marks older messages carry themselves ("✓ Migrations completed"): the kind they stand for.
      MARKS = {"✓ " => Kind::Success, "✔ " => Kind::Success, "✗ " => Kind::Error, "✖ " => Kind::Error}

      getter terminal : Terminal

      def initialize(@terminal : Terminal)
        @theme = terminal.theme
      end

      def glyphs : Glyphs
        terminal.glyphs
      end

      def paint(text : String, token : Token, attrs : Attr = Attr::None) : String
        return text unless @theme.color?
        "#{@theme.sgr(Style.new(token, attrs: attrs))}#{text}\e[0m"
      end

      def message(kind : Kind, text : String) : String
        if kind.info?
          MARKS.each { |mark, marked| return message(marked, text.lchop(mark)) if text.starts_with?(mark) }
        end
        g = glyphs
        case kind
        in .debug?    then paint("#{g.dot} #{text}", Token::Muted)
        in .info?     then "#{paint(g.pointer, Token::Cyan)} #{text}"
        in .warn?     then "#{paint(g.warn, Token::Amber)} #{paint(text, Token::Amber)}"
        in .error?    then "#{paint(g.fail, Token::Red)} #{paint(text, Token::Red)}"
        in .fatal?    then "#{paint(g.fail, Token::Red, Attr::Bold)} #{paint(text, Token::Red, Attr::Bold)}"
        in .success?  then "#{paint(g.ok, Token::Green)} #{text}"
        in .title?    then "#{paint(g.busy, Token::Purple)} #{paint(text, Token::Purple, Attr::Bold)}"
        in .prompt?   then "#{paint("?", Token::Blue, Attr::Bold)} #{text}"
        in .command?  then "  #{paint("$", Token::Faint)} #{paint(text, Token::Muted)}"
        in .created?  then "  #{paint("+", Token::Green)} #{paint(text, Token::Blue)}"
        in .modified? then "  #{paint("~", Token::Amber)} #{paint(text, Token::Blue)}"
        in .skipped?  then "  #{paint(g.dot, Token::Muted)} #{paint(text, Token::Muted)}"
        end
      end

      # `[2/5] Installing`: the counter muted, the text plain.
      def step(number : Int32, total : Int32, text : String) : String
        "#{paint("#{number}/#{total}", Token::Muted)} #{paint(glyphs.pointer, Token::Cyan)} #{text}"
      end

      # A section heading: the brand, the title, and a cyan → purple rule under them.
      def header(title : String) : String
        width = Math.min(terminal.columns - 1, Rich::MAX_WIDTH)
        rule = String.build do |io|
          width.times do |index|
            @theme.color? ? (io << @theme.sgr(@theme.gradient(index, width)) << glyphs.horizontal) : (io << glyphs.horizontal)
          end
          io << "\e[0m" if @theme.color?
        end
        " #{paint(glyphs.brand, Token::Amber, Attr::Bold)}  #{paint(title, Token::Text, Attr::Bold)}\n#{rule}"
      end
    end
  end
end
