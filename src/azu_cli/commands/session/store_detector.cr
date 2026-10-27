module AzuCLI
  module Commands
    module Session
      # Reads which of the session shard's stores an initializer sets, without running it. `session:clear` deletes
      # data on its answer, so it is fail-closed: it reads a store only in the plain forms the generators write,
      #
      #     Session.use_store(Session::RedisStore(UserSession))
      #     config.store = Session::RedisStore(UserSession).new(...)
      #
      # at the top level or inside `do ... end` blocks, and reports anything else that sets a store (another value,
      # `||=`, a store behind an `if`, inside a `def` or `{ }`, ...) and any code it cannot read (an unterminated
      # literal, unbalanced `end`s, macro conditionals, `=begin`) as an entry that is not a backend. Strings, chars,
      # heredocs, `%` literals, regexes and comments are not code, so a store named there does not count.
      class StoreDetector
        BACKENDS = %w[cookie redis memory]
        STORES   = {"CookieStore" => "cookie", "RedisStore" => "redis", "MemoryStore" => "memory"}

        class Unreadable < Exception
        end

        enum Kind
          Word
          Punct
          Newline
          Literal
        end

        record Token, kind : Kind, text : String, line : Int32, space_before : Bool

        # Keywords that always open a block closed by `end` (`def` unless `abstract def`).
        OPENERS = %w[class module struct lib enum annotation union def macro fun case begin select]
        # Keywords that open a block only at the start of an expression; elsewhere they are modifiers.
        CONDITIONALS = %w[if unless while until]
        # Words after which an expression starts (a `/` there begins a regex, an `if` there opens a block).
        EXPRESSION_KEYWORDS = %w[if unless while until when case then else elsif do begin return and or not in puts p yield]
        OPERATORS           = %w[**= <=> === ... ||= &&= <<= >>= == != =~ !~ => -> :: || && <= >= << >> += -= *= /= %= |= &= ^= ** .. &.]
        PERCENT_PAIRS       = {'(' => ')', '[' => ']', '{' => '}', '<' => '>', '|' => '|'}

        # The backends the initializer sets, in order and without repeats; an entry that is not one of BACKENDS
        # describes a store it cannot read (an empty list: no store is set).
        def self.backends(source : String) : Array(String)
          new(source).backends
        rescue ex : Unreadable
          [ex.message.to_s]
        end

        def initialize(source : String)
          @bytes = source.to_slice
          @pos = 0
          @line = 1
          @space = false
          @tokens = [] of Token
          @heredocs = [] of {String, Int32}
        end

        def backends : Array(String)
          lex
          found = [] of String
          stack = [] of Symbol
          @tokens.each_index do |index|
            track_block(index, stack)
            if store = store_at(index)
              found << (stack.all?(:do) ? store : unreadable_store(index))
            end
          end
          raise Unreadable.new("a block without its `end`") unless stack.empty?
          found.uniq
        end

        # ---- stores

        # The backend a store write at `index` sets, a description of a store write it cannot read, or nil.
        private def store_at(index : Int32) : String?
          token = @tokens[index]
          return unless token.kind.word?
          if token.text == "use_store"
            use_store_at(index)
          elsif token.text == "store" && {".", "&."}.includes?(text_at(index - 1))
            assignment_at(index)
          elsif token.text == "store" && text_at(index + 1) == ":" && !@tokens[index + 1].space_before
            unreadable_store(index)
          end
        end

        private def use_store_at(index : Int32) : String
          if text_at(index + 1) == "("
            backend, after = store_value(skip_newlines(index + 2), instance: false)
            after = skip_newlines(after)
            return unreadable_store(index) unless backend && text_at(after) == ")"
            statement_end?(after + 1) ? backend : unreadable_store(index)
          else
            backend, after = store_value(index + 1, instance: false)
            backend && statement_end?(after) ? backend : unreadable_store(index)
          end
        end

        private def assignment_at(index : Int32) : String?
          operator = text_at(index + 1)
          return unless operator
          return unless @tokens[index + 1].kind.punct? && operator.ends_with?('=')
          return if {"==", "===", "!=", "<=", ">="}.includes?(operator)
          return unreadable_store(index) unless operator == "="

          backend, after = store_value(skip_newlines(index + 2), instance: true)
          backend && statement_end?(after) ? backend : unreadable_store(index)
        end

        # `[::]Session::<Store>[(Type)]` (and `[.new[(...)]]` when `instance`): the backend and the index after it.
        private def store_value(index : Int32, instance : Bool) : {String?, Int32}
          index += 1 if text_at(index) == "::"
          return {nil, index} unless text_at(index) == "Session" && text_at(index + 1) == "::"
          backend = STORES[text_at(index + 2)]?
          return {nil, index} unless backend
          index += 3
          if text_at(index) == "("
            index = constant_path_end(index + 1)
            return {nil, index} unless text_at(index) == ")"
            index += 1
          end
          if instance && text_at(index) == "." && text_at(index + 1) == "new"
            index += 2
            index = balanced_end(index) if text_at(index) == "(" && !@tokens[index].space_before
          end
          {backend, index}
        end

        # The index after `[::]Const(::Const)*` at `index`, or `index` when there is none.
        private def constant_path_end(index : Int32) : Int32
          start = index
          index += 1 if text_at(index) == "::"
          while (token = @tokens[index]?) && token.kind.word? && token.text[0].uppercase?
            return index + 1 unless text_at(index + 1) == "::"
            index += 2
          end
          start
        end

        # The index after the `)` that closes the `(` at `index`.
        private def balanced_end(index : Int32) : Int32
          depth = 0
          while token = @tokens[index]?
            depth += 1 if token.text == "(" && token.kind.punct?
            depth -= 1 if token.text == ")" && token.kind.punct?
            return index + 1 if depth == 0
            index += 1
          end
          index
        end

        private def statement_end?(index : Int32) : Bool
          token = @tokens[index]?
          token.nil? || token.kind.newline? || token.text == ";"
        end

        private def skip_newlines(index : Int32) : Int32
          while @tokens[index]?.try(&.kind.newline?)
            index += 1
          end
          index
        end

        private def unreadable_store(index : Int32) : String
          "a store it cannot read on line #{@tokens[index].line}"
        end

        private def text_at(index : Int32) : String?
          index >= 0 ? @tokens[index]?.try(&.text) : nil
        end

        # ---- blocks

        # Pushes and pops the blocks around each token: `:do` (`do ... end`), `:brace` and `:block` (any other).
        private def track_block(index : Int32, stack : Array(Symbol)) : Nil
          token = @tokens[index]
          if token.kind.punct?
            stack << :brace if token.text == "{"
            close(stack, :brace, token) if token.text == "}"
          elsif token.kind.word? && keyword?(index)
            case token.text
            when "do"  then stack << :do
            when "end" then close(stack, nil, token)
            when .in?(OPENERS)
              stack << :block unless token.text == "def" && text_at(index - 1) == "abstract"
            when .in?(CONDITIONALS)
              stack << :block if expression_start?(index)
            end
          end
        end

        private def close(stack : Array(Symbol), brace : Symbol?, token : Token) : Nil
          top = stack.pop?
          valid = brace ? top == :brace : (top && top != :brace)
          raise Unreadable.new("an unbalanced `#{token.text}` on line #{token.line}") unless valid
        end

        # A word used as a keyword: not a method (`.end`), a symbol (`:if`) or a named argument (`if:`).
        private def keyword?(index : Int32) : Bool
          return false if {".", "&.", ":", "::", "@", "$"}.includes?(text_at(index - 1))
          following = @tokens[index + 1]?
          !(following && following.text == ":" && !following.space_before)
        end

        private def expression_start?(index : Int32) : Bool
          previous = @tokens[index - 1]? if index > 0
          return true if previous.nil? || previous.kind.newline?
          return EXPRESSION_KEYWORDS.includes?(previous.text) if previous.kind.word?
          previous.kind.punct? && !{")", "]", "}", "?"}.includes?(previous.text)
        end

        # ---- lexer

        private def lex : Nil
          while @pos < @bytes.size
            lex_token
          end
          raise Unreadable.new("an unterminated heredoc on line #{@heredocs.first[1]}") unless @heredocs.empty?
        end

        private def lex_token : Nil
          byte = @bytes[@pos]
          case byte
          when '\n'.ord
            newline
          when ' '.ord, '\t'.ord, '\r'.ord, '\f'.ord, '\v'.ord
            @pos += 1
            @space = true
          when '\\'.ord
            lex_backslash
          when '#'.ord
            advance_while { |byte| byte != '\n'.ord }
          when '"'.ord, '`'.ord
            literal { skip_quoted(byte, byte, interpolation: true) }
          when '\''.ord
            literal { skip_quoted(byte, byte, interpolation: false) }
          when '='.ord
            raise Unreadable.new("=begin text on line #{@line}") if line_start? && word_follows?("begin")
            punct
          else
            lex_other(byte)
          end
        end

        private def lex_other(byte : UInt8) : Nil
          if byte == '/'.ord && literal_start?
            literal { skip_quoted(byte, byte, interpolation: true) }
            advance_while(&.unsafe_chr.in?('i', 'm', 'x'))
          elsif byte == '%'.ord && literal_start? && percent_literal
          elsif byte == '<'.ord && heredoc
          elsif byte == '{'.ord && @bytes[@pos + 1]? == '%'.ord
            raise Unreadable.new("a macro conditional on line #{@line}")
          elsif word_byte?(byte) && !digit?(byte)
            word
          elsif digit?(byte)
            literal { advance_while { |byte| word_byte?(byte) } }
          else
            punct
          end
        end

        private def newline : Nil
          push(Kind::Newline, "\n")
          @pos += 1
          @line += 1
          skip_heredoc_bodies unless @heredocs.empty?
        end

        # `\` then a line end continues the line; any other `\` is punctuation.
        private def lex_backslash : Nil
          if @bytes[@pos + 1]? == '\n'.ord
            @pos += 2
            @line += 1
            @space = true
          elsif @bytes[@pos + 1]? == '\r'.ord && @bytes[@pos + 2]? == '\n'.ord
            @pos += 3
            @line += 1
            @space = true
          else
            punct
          end
        end

        private def word : Nil
          start = @pos
          advance_while { |byte| word_byte?(byte) }
          if (suffix = @bytes[@pos]?) && (suffix == '?'.ord || suffix == '!'.ord) && @bytes[@pos + 1]? != '='.ord
            @pos += 1
          end
          push(Kind::Word, String.new(@bytes[start, @pos - start]))
        end

        private def punct : Nil
          operator = OPERATORS.find { |op| matches?(op) } || @bytes[@pos].unsafe_chr.to_s
          @pos += operator.bytesize
          push(Kind::Punct, operator)
        end

        private def literal(&) : Nil
          line = @line
          yield
          @tokens << Token.new(Kind::Literal, "", line, @space)
          @space = false
        end

        private def push(kind : Kind, text : String) : Nil
          @tokens << Token.new(kind, text, @line, @space)
          @space = false
        end

        # Skips from the opening delimiter at `@pos` past the matching `close`, honouring `\` escapes, nested
        # `open`/`close` pairs and (when `interpolation`) `#{...}`.
        private def skip_quoted(open : UInt8, close : UInt8, interpolation : Bool) : Nil
          start_line = @line
          @pos += 1
          depth = 0
          loop do
            raise Unreadable.new("an unterminated literal from line #{start_line}") if @pos >= @bytes.size
            byte = @bytes[@pos]
            if byte == '\\'.ord
              @line += 1 if @bytes[@pos + 1]? == '\n'.ord
              @pos += 2
              next
            end
            @line += 1 if byte == '\n'.ord
            if interpolation && byte == '#'.ord && @bytes[@pos + 1]? == '{'.ord
              @pos += 1
              skip_interpolation(start_line)
              next
            end
            if byte == close && depth == 0
              @pos += 1
              return
            end
            depth += 1 if byte == open && open != close
            depth -= 1 if byte == close
            @pos += 1
          end
        end

        # Skips the code of a `#{...}` from its `{`, with the strings and chars in it (never read as code).
        private def skip_interpolation(start_line : Int32) : Nil
          depth = 0
          loop do
            raise Unreadable.new("an unterminated literal from line #{start_line}") if @pos >= @bytes.size
            byte = @bytes[@pos]
            case byte
            when '"'.ord, '`'.ord
              skip_quoted(byte, byte, interpolation: true)
              next
            when '\''.ord
              skip_quoted(byte, byte, interpolation: false)
              next
            when '{'.ord
              depth += 1
            when '}'.ord
              depth -= 1
              if depth == 0
                @pos += 1
                return
              end
            when '\n'.ord
              @line += 1
            end
            @pos += 1
          end
        end

        # `%q(...)`, `%w[...]`, `%(...)` and the like; false (nothing consumed) when `%` is an operator.
        private def percent_literal : Bool
          kind = @bytes[@pos + 1]?.try(&.unsafe_chr)
          offset = kind && kind.in?('q', 'Q', 'w', 'W', 'i', 'I', 'r', 'x') ? 2 : 1
          open = @bytes[@pos + offset]?.try(&.unsafe_chr)
          close = open.try { |char| PERCENT_PAIRS[char]? }
          return false unless open && close
          @pos += offset
          literal { skip_quoted(open.ord.to_u8, close.ord.to_u8, interpolation: !(offset == 2 && kind.in?('q', 'w', 'i'))) }
          true
        end

        # `<<-ID`, `<<~ID`, `<<ID` (ID bare or quoted): records the heredoc, whose body starts on the next line.
        private def heredoc : Bool
          return false unless @bytes[@pos + 1]? == '<'.ord
          offset = 2
          dashed = @bytes[@pos + 2]?.try { |byte| byte == '-'.ord || byte == '~'.ord }
          offset += 1 if dashed
          first = @bytes[@pos + offset]?
          return false unless first && (word_byte?(first) && !digit?(first) || first == '"'.ord || first == '\''.ord)
          return false unless dashed || literal_start?

          @pos += offset
          if first == '"'.ord || first == '\''.ord
            start = @pos + 1
            literal { skip_quoted(first, first, interpolation: false) }
            id = String.new(@bytes[start, @pos - start - 1])
          else
            start = @pos
            advance_while { |byte| word_byte?(byte) }
            id = String.new(@bytes[start, @pos - start])
            literal { }
          end
          @heredocs << {id, @line}
          true
        end

        private def skip_heredoc_bodies : Nil
          @heredocs.each do |(id, line)|
            loop do
              raise Unreadable.new("an unterminated heredoc on line #{line}") if @pos >= @bytes.size
              start = @pos
              advance_while { |byte| byte != '\n'.ord }
              body_line = String.new(@bytes[start, @pos - start])
              @pos += 1 if @pos < @bytes.size
              @line += 1
              break if body_line.strip == id
            end
          end
          @heredocs.clear
        end

        # Whether a literal (regex, `%` literal, `<<ID` heredoc) can start here rather than an operator.
        private def literal_start? : Bool
          previous = @tokens.last?
          return true if previous.nil? || previous.kind.newline?
          return false if previous.kind.literal?
          if previous.kind.punct?
            return !{")", "]", "}"}.includes?(previous.text)
          end
          return true if EXPRESSION_KEYWORDS.includes?(previous.text)
          # `foo /x/` is a call with a regex, `foo / x` a division (the rule Crystal and Ruby use).
          following = @bytes[@pos + 1]?
          @space && !following.nil? && following != ' '.ord && following != '='.ord
        end

        private def advance_while(&) : Nil
          while @pos < @bytes.size && yield @bytes[@pos]
            @pos += 1
          end
        end

        private def matches?(operator : String) : Bool
          return false if @pos + operator.bytesize > @bytes.size
          operator.to_slice == @bytes[@pos, operator.bytesize]
        end

        private def line_start? : Bool
          @pos == 0 || @bytes[@pos - 1] == '\n'.ord
        end

        private def word_follows?(text : String) : Bool
          @pos + 1 + text.bytesize <= @bytes.size && @bytes[@pos + 1, text.bytesize] == text.to_slice
        end

        private def word_byte?(byte : UInt8) : Bool
          byte >= 0x80 || byte.unsafe_chr.ascii_alphanumeric? || byte == '_'.ord
        end

        private def digit?(byte : UInt8) : Bool
          byte.unsafe_chr.ascii_number?
        end
      end
    end
  end
end
