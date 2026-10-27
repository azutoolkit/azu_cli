module AzuCLI
  module UI
    # Small drawing helpers shared by the screens and reporters.
    module Widgets
      # Values scaled to the sparkline glyphs, the last `width` values.
      def self.sparkline(values : Array(Float64), width : Int32, glyphs : Glyphs) : String
        shown = values.last(width)
        return "" if shown.empty?

        low, high = shown.min, shown.max
        steps = glyphs.spark.size
        String.build do |io|
          shown.each do |value|
            level = high == low ? 0 : ((value - low) / (high - low) * (steps - 1)).round.to_i
            io << glyphs.spark[level.clamp(0, steps - 1)]
          end
        end
      end

      # {filled, empty} parts of a gauge `width` cells long.
      def self.meter(fraction : Float64, width : Int32, full : Char, empty : Char) : {String, String}
        filled = (fraction.clamp(0.0, 1.0) * width).round.to_i
        {full.to_s * filled, empty.to_s * (width - filled)}
      end

      def self.spinner(glyphs : Glyphs, at : Time::Instant = Time.instant, reduced_motion : Bool = false) : String
        return glyphs.busy if reduced_motion

        frames = glyphs.spinner
        frames[(at - EPOCH).total_milliseconds.to_i64 // 80 % frames.size]
      end

      EPOCH = Time.instant

      # `[Enter] Select   [Esc] Quit`: keys in cyan, actions muted.
      def self.key_bar(frame : Frame, x : Int32, y : Int32, keys : Array({String, String}), max : Int32) : Int32
        segs = [] of Seg
        keys.each_with_index do |(key, action), index|
          segs << Seg["   ", Token::Muted] if index > 0
          segs << Seg["[#{key}]", Token::Cyan]
          segs << Seg[" #{action}", Token::Muted]
        end
        frame.line(x, y, segs, max)
      end

      # 1.5 s, 312 ms, 4.0 min.
      def self.duration(seconds : Float64) : String
        return "#{(seconds * 1000).round.to_i} ms" if seconds < 1
        return "#{seconds.round(1)}s" if seconds < 60
        "#{(seconds / 60).round(1)} min"
      end

      def self.bytes(count : Int64) : String
        return "#{count} B" if count < 1024
        return "#{(count / 1024.0).round(1)} KB" if count < 1024 * 1024
        "#{(count / 1024.0 / 1024.0).round(1)} MB"
      end

      def self.clock(span : Time::Span) : String
        total = span.total_seconds.to_i
        "%02d:%02d:%02d" % {total // 3600, total % 3600 // 60, total % 60}
      end
    end
  end
end
