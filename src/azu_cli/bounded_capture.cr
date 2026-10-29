module AzuCLI
  # Keep a bounded prefix while continuing to drain subprocess pipes.
  class BoundedCapture < IO
    getter? truncated = false
    @buffer = IO::Memory.new

    def initialize(@limit : Int32)
    end

    def read(slice : Bytes) : Int32
      raise IO::Error.new("write-only")
    end

    def write(slice : Bytes) : Nil
      remaining = Math.max(0, @limit - @buffer.size)
      @buffer.write(slice[0, Math.min(remaining, slice.size)])
      @truncated = true if slice.size > remaining
    end

    def text : String
      @buffer.to_s.scrub
    end
  end
end
