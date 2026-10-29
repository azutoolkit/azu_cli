require "./source"
require "./screen"

module AzuCLI::JoobQDashboard
  # One fiber owns the source: polling and mutations cannot overlap or race replies.
  class Controller
    @commands = Channel(String).new(1)
    @stopped = false

    def initialize(@source : Source, @emit : Proc(UI::Message, Nil), @interval = 1.second)
    end

    def replay(id : String) : Nil
      select
      when @commands.send(id)
      else
        @emit.call(Notice.new("Another replay is pending"))
      end
    end

    def start : Nil
      spawn do
        until @stopped
          begin
            @emit.call(Snapshot.new(@source.snapshot))
          rescue ex
            @emit.call(Notice.new("Disconnected: #{ex.message}")) unless @stopped
          end
          select
          when id = @commands.receive?
            break unless id
            begin
              result = @source.replay(id)
              @emit.call(Notice.new("Replay #{id}: #{result.to_json}", completed: true))
            rescue ex
              @emit.call(Notice.new("Replay outcome requires checking: #{ex.message}", completed: true)) unless @stopped
            end
          when timeout(@interval)
          end
        end
      end
    end

    def stop : Nil
      @stopped = true
      @commands.close
      @source.close
    end
  end
end
