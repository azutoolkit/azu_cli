module AzuCLI
  module UI
    enum KeyCode
      Char
      Enter
      Tab
      BackTab
      Esc
      Up
      Down
      Left
      Right
      Home
      End
      PageUp
      PageDown
      Backspace
      Delete
      CtrlC
      CtrlD
      CtrlK
      CtrlS
      CtrlU
      CtrlA
      CtrlE
      CtrlL
      CtrlO
      CtrlP
      # Alt-Enter (ESC, then CR): a new line in an editor where Enter runs
      AltEnter
      AltLeft
      AltRight
      Paste
    end

    # A key press; `char` for printable keys, `text` for a bracketed paste.
    record Key, code : KeyCode, char : Char? = nil, text : String? = nil do
      def char?(value : Char) : Bool
        code.char? && char == value
      end
    end

    # Turns the bytes read from a raw-mode terminal into keys. Terminals send one escape sequence per write, so a read
    # that holds only ESC is the Escape key.
    module Input
      CSI = {
        "A" => KeyCode::Up, "B" => KeyCode::Down, "C" => KeyCode::Right, "D" => KeyCode::Left,
        "H" => KeyCode::Home, "F" => KeyCode::End, "Z" => KeyCode::BackTab, "1~" => KeyCode::Home,
        "4~" => KeyCode::End, "3~" => KeyCode::Delete, "5~" => KeyCode::PageUp, "6~" => KeyCode::PageDown,
      }
      CONTROL = {
        0x03_u8 => KeyCode::CtrlC, 0x04_u8 => KeyCode::CtrlD, 0x09_u8 => KeyCode::Tab, 0x0A_u8 => KeyCode::Enter,
        0x0B_u8 => KeyCode::CtrlK, 0x0D_u8 => KeyCode::Enter, 0x13_u8 => KeyCode::CtrlS, 0x15_u8 => KeyCode::CtrlU,
        0x08_u8 => KeyCode::Backspace, 0x7F_u8 => KeyCode::Backspace, 0x01_u8 => KeyCode::CtrlA, 0x05_u8 => KeyCode::CtrlE,
        0x0C_u8 => KeyCode::CtrlL, 0x0F_u8 => KeyCode::CtrlO, 0x10_u8 => KeyCode::CtrlP,
      }
      PASTE_START = "\e[200~"
      PASTE_END   = "\e[201~"

      def self.parse(bytes : Bytes) : Array(Key)
        parse(String.new(bytes))
      end

      def self.parse(input : String) : Array(Key)
        keys = [] of Key
        pos = 0
        while pos < input.bytesize
          rest = input.byte_slice(pos)
          if rest.byte_at(0) == 0x1B
            if rest.starts_with?(PASTE_START)
              body = rest.byte_slice(PASTE_START.bytesize)
              finish = body.index(PASTE_END)
              text = finish ? body.byte_slice(0, body.char_index_to_byte_index(finish) || 0) : body
              keys << Key.new(KeyCode::Paste, text: text)
              pos += PASTE_START.bytesize + text.bytesize + (finish ? PASTE_END.bytesize : 0)
              next
            end
            consumed, key = escape(rest)
            keys << key if key
            pos += consumed
            next
          end
          char = rest[0]
          if char.ord < 0x80 && (code = CONTROL[char.ord.to_u8]?)
            keys << Key.new(code)
          elsif char.ord >= 0x20 && char != '\u{7F}' && char != Char::REPLACEMENT
            keys << Key.new(KeyCode::Char, char)
          end
          pos += Math.max(1, char.bytesize)
        end
        keys
      end

      # {bytes consumed, key}: CSI (ESC [) and SS3 (ESC O) sequences; an unknown sequence is consumed and dropped.
      private def self.escape(rest : String) : {Int32, Key?}
        return {1, Key.new(KeyCode::Esc)} if rest.bytesize == 1
        second = rest.byte_at(1).chr
        if second == '[' || second == 'O'
          index = 2
          while index < rest.bytesize
            byte = rest.byte_at(index)
            index += 1
            break if 0x40 <= byte <= 0x7E
          end
          body = rest.byte_slice(2, index - 2)
          return {index, Key.new(KeyCode::AltLeft)} if body == "1;3D"
          return {index, Key.new(KeyCode::AltRight)} if body == "1;3C"
          body = body.sub(/\A1;\d+/, "") if body.size > 1 && body.starts_with?("1;") # modifiers: treat as the plain key
          return {index, CSI[body]?.try { |code| Key.new(code) }}
        end
        return {2, Key.new(KeyCode::Esc)} if second == '\e'
        return {2, Key.new(KeyCode::AltEnter)} if second == '\r' || second == '\n'
        {1, Key.new(KeyCode::Esc)} # Alt+key: Esc, then the key on the next round
      end
    end
  end
end
