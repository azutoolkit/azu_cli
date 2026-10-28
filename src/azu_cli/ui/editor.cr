module AzuCLI
  module UI
    # A multi-line text being typed: lines and a cursor, changed by keys. No drawing and no I/O, so specs drive it.
    class Editor
      getter lines = [""]
      getter row = 0
      getter column = 0

      def text : String
        lines.join('\n')
      end

      def empty? : Bool
        lines.size == 1 && lines[0].empty?
      end

      def text=(value : String) : Nil
        @lines = value.split('\n')
        @lines = [""] if @lines.empty?
        @row = @lines.size - 1
        @column = @lines[@row].size
      end

      def clear : Nil
        self.text = ""
      end

      def first_row? : Bool
        row == 0
      end

      def last_row? : Bool
        row == lines.size - 1
      end

      def insert(value : String) : Nil
        value.each_char { |char| char == '\n' ? newline : insert(char) }
      end

      def insert(char : Char) : Nil
        line = lines[row]
        lines[row] = line[0, column] + char + line[column..]
        @column += 1
        dedent_closer
      end

      # `end` (and `else`, `when`, ...) typed on an indented line moves back one level, like an editor would.
      private def dedent_closer : Nil
        line = lines[row]
        return unless column == line.size && line.starts_with?("  ") && line.strip.in?("end", "else", "elsif", "when", "in", "rescue", "ensure", "}")
        lines[row] = line[2..]
        @column -= 2
      end

      # Splits the line at the cursor, and indents the new line like the one above (two more after an opener).
      def newline : Nil
        line = lines[row]
        before, after = line[0, column], line[column..]
        indent = before[/\A */]
        indent += "  " if Editor.opens_block?(before)
        lines[row] = before
        lines.insert(row + 1, indent + after.lstrip)
        @row += 1
        @column = indent.size
      end

      def backspace : Nil
        if column > 0
          line = lines[row]
          lines[row] = line[0, column - 1] + line[column..]
          @column -= 1
        elsif row > 0
          @column = lines[row - 1].size
          lines[row - 1] += lines.delete_at(row)
          @row -= 1
        end
      end

      def delete : Nil
        line = lines[row]
        if column < line.size
          lines[row] = line[0, column] + line[column + 1..]
        elsif row < lines.size - 1
          lines[row] += lines.delete_at(row + 1)
        end
      end

      def left : Nil
        if column > 0
          @column -= 1
        elsif row > 0
          @row -= 1
          @column = lines[row].size
        end
      end

      def right : Nil
        if column < lines[row].size
          @column += 1
        elsif row < lines.size - 1
          @row += 1
          @column = 0
        end
      end

      def up : Nil
        return if row == 0
        @row -= 1
        @column = Math.min(column, lines[row].size)
      end

      def down : Nil
        return if row == lines.size - 1
        @row += 1
        @column = Math.min(column, lines[row].size)
      end

      def home : Nil
        @column = 0
      end

      def end_of_line : Nil
        @column = lines[row].size
      end

      # Deletes from the cursor to the end of the line (Ctrl-K).
      def kill : Nil
        lines[row] = lines[row][0, column]
      end

      OPENERS = /\A\s*(def|class|module|struct|enum|lib|macro|annotation|if|unless|while|until|case|begin)\b|\bdo(\s*\|[^|]*\|)?\s*\z|[{(\[]\s*\z/

      def self.opens_block?(line : String) : Bool
        line.matches?(OPENERS) && !line.matches?(/\bend\s*\z/)
      end

      # Whether the code reads as finished: every block it opens is closed, every bracket and string too. Enter runs
      # finished code and starts a new line otherwise, like irb.
      def self.complete?(code : String) : Bool
        depth = 0
        brackets = 0
        code.each_line do |line|
          stripped = line.gsub(/"(\\.|[^"\\])*"|'(\\.|[^'\\])*'/, "\"\"").sub(/#.*\z/, "")
          return false if stripped.count('"').odd?
          depth += 1 if stripped.matches?(/\A\s*(def|class|module|struct|enum|lib|macro|annotation|if|unless|while|until|case|begin)\b/) && !stripped.matches?(/\A\s*def\s+[\w.]+[?!]?(\([^)]*\))?\s*=[^=]/) && !stripped.matches?(/\bend\s*\z/)
          depth += 1 if stripped.matches?(/\bdo(\s*\|[^|]*\|)?\s*\z/)
          depth -= stripped.scan(/(?:\A|[\s;])end\b/).size
          brackets += stripped.count("({[") - stripped.count(")}]")
        end
        depth <= 0 && brackets <= 0
      end
    end
  end
end
