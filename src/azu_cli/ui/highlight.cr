require "./frame"

module AzuCLI::UI
  # Visual lexer, not a SQL parser. Bounded, linear scanning preserves every
  # character. Terminal escaping is always owned by Frame, never by log input.
  module Highlight
    SQL_WORDS = %w(SELECT FROM WHERE JOIN INNER LEFT RIGHT FULL ON AS AND OR NOT NULL TRUE FALSE ORDER BY GROUP HAVING LIMIT OFFSET INSERT INTO VALUES UPDATE SET DELETE RETURNING WITH RECURSIVE UNION ALL DISTINCT CASE WHEN THEN ELSE END ASC DESC CREATE TABLE INDEX ALTER DROP BEGIN COMMIT ROLLBACK)

    def self.sql(source : String) : Array(Seg)
      chars = source[0, 4096].chars
      result = [] of Seg
      index = 0
      while index < chars.size
        start = index
        char = chars[index]
        color = Token::Text
        if char == '-' && chars[index + 1]? == '-'
          index = chars.size
          color = Token::Muted
        elsif char == '\'' || char == '"' || char == '`'
          quote = char
          index += 1
          while index < chars.size
            current = chars[index]
            index += 1
            next unless current == quote
            if chars[index]? == quote
              index += 1
            else
              break
            end
          end
          color = quote == '\'' ? Token::Green : Token::Blue
        elsif char.ascii_letter? || char == '_'
          index += 1
          while (next_char = chars[index]?) && (next_char.alphanumeric? || next_char == '_')
            index += 1
          end
          word = chars[start...index].join
          color = SQL_WORDS.includes?(word.upcase) ? Token::Pink : Token::Blue
        elsif char.ascii_number? || char == '$' || char == '?'
          index += 1
          while (next_char = chars[index]?) && (next_char.ascii_number? || next_char == '.')
            index += 1
          end
          color = Token::Amber
        else
          index += 1
        end
        result << Seg[chars[start...index].join, color]
      end
      result
    end

    def self.log(source : String) : Array(Seg)
      source[0, 4096].split(/(\s+)/).map do |word|
        color = case word
                when "ERROR", "FATAL", "500", "503"                  then Token::Red
                when "WARN", "WARNING", "401", "403", "429"          then Token::Amber
                when "DEBUG", "TRACE"                                then Token::Purple
                when "INFO", "GET", "POST", "PUT", "PATCH", "DELETE" then Token::Blue
                when "200", "201", "204", "OK"                       then Token::Green
                else
                  if word.matches?(/\A\d\d:\d\d:\d\d/)
                    Token::Muted
                  elsif word.ends_with?("ms") || word.starts_with?("req_")
                    Token::Cyan
                  else
                    Token::Text
                  end
                end
        Seg[word, color]
      end
    end
  end
end
