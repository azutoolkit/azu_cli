require "../dev_server/diagnostic_tabs"

module AzuCLI::JoobQDashboard
  struct Snapshot < UI::Message
    getter data : JSON::Any

    def initialize(@data : JSON::Any); end
  end

  struct Notice < UI::Message
    getter text : String
    getter? completed : Bool

    def initialize(@text : String, @completed : Bool = false); end
  end

  class Screen < UI::Screen
    alias Data = DevServer::DiagnosticData
    enum Tab
      Queues
      Workflows
      DLQ
    end
    getter tab = Tab::Queues
    getter queues = UI::Inspector.new
    getter workflows = UI::Inspector.new
    getter dlq = UI::Inspector.new
    getter confirming : String?
    getter? busy = false
    @queue_count = 0
    @worker_count : Int32?
    @pending = 0.0
    @processing = 0.0
    @rate : Float64?
    @replay_supported = false
    @notice = "Connecting to the project's JoobQ store"
    @last_snapshot : Time::Instant?

    def initialize(@on_replay : Proc(String, Nil) = ->(_id : String) { })
    end

    def update(event : UI::Event) : UI::Action
      case event
      when Snapshot
        @last_snapshot = Time.instant
        update_data(event.data)
      when Notice
        @notice = event.text
        @busy = false if event.completed?
      when UI::Key
        return UI::Action::Quit if event.code.ctrl_c? || event.char?('q')
        if id = @confirming
          @confirming = nil
          if event.char?('y')
            @busy = true
            @notice = "Replay requested for #{id}; waiting for store acknowledgement"
            @on_replay.call(id)
          end
        elsif event.char?('1') || event.char?('2') || event.char?('3')
          @tab = Tab.from_value(event.char.not_nil!.to_i - 1)
        elsif tab.dlq? && event.char?('r') && !busy?
          item = dlq.selected_item
          if @replay_supported && item && !item.id.starts_with?("retry:")
            @confirming = item.id
          else
            @notice = "Replay requires an atomic DLQ API and a dead-letter selection"
          end
        else
          inspector.key(event)
        end
      when UI::Resize, UI::Tick
      else
        return UI::Action::Continue
      end
      UI::Action::Redraw
    end

    def animating? : Bool
      true # stale source indicator refreshes even when the backend has stopped
    end

    private def inspector : UI::Inspector
      case tab
      in .queues?    then queues
      in .workflows? then workflows
      in .dlq?       then dlq
      end
    end

    private def update_data(data : JSON::Any) : Nil
      @replay_supported = Data.field(data, "replay_supported").try(&.as_bool?) || false
      workers = Data.rows(data, "workers")
      rows = Data.rows(data, "queues")
      @queue_count = rows.size
      @worker_count = Data.field(data, "workers").try(&.as_a?).try(&.size)
      @pending = rows.sum { |row| Data.number(row, "pending") }
      @processing = rows.sum { |row| Data.number(row, "processing") }
      @rate = rows.any? { |row| !Data.field(row, "rate").try(&.raw).nil? } ? rows.sum { |row| Data.number(row, "rate") } : nil
      queues.replace(Data.rows(data, "queues").map do |row|
        name = Data.text(row, "name")
        assigned = workers.select { |worker| Data.rows(worker, "queues").any? { |queue| queue.as_s? == name } }
        UI::Inspector::Item.new(name, "#{name} pending #{Data.text(row, "pending")} busy #{Data.text(row, "processing")}",
          ["Queue: #{name}", "Pending: #{Data.text(row, "pending")}", "Processing: #{Data.text(row, "processing")}",
           "Processed: #{Data.text(row, "processed")}", "Processing rate: #{Data.text(row, "rate")} jobs/s", "", "Workers:"] +
          assigned.map { |worker| "#{Data.text(worker, "id")} #{Data.text(worker, "status")} active #{Data.text(worker, "fibers_active")}/#{Data.text(worker, "concurrency")}" })
      end)
      workflows.replace(Data.rows(data, "workflows").map do |row|
        lines = ["#{Data.text(row, "name")} · #{Data.text(row, "status")}", "Execution #{Data.text(row, "id")}", "", "Steps:"]
        Data.rows(row, "steps", 200).each do |step|
          dependencies = Data.rows(step, "depends_on").map { |item| item.as_s? || "?" }.join(", ")
          lines << "├─ #{Data.text(step, "id")} [#{Data.text(step, "status")}] attempt #{Data.text(step, "attempt")}"
          lines << "│  after: #{dependencies}" unless dependencies.empty?
        end
        UI::Inspector::Item.new(Data.text(row, "id"), "#{Data.text(row, "name")} #{Data.text(row, "status")} #{Data.text(row, "id")}", lines)
      end)
      entries = Data.rows(data, "dlq").map do |row|
        id = Data.text(row, "jid", Data.text(row, "id"))
        UI::Inspector::Item.new(id, "#{Data.text(row, "queue")} #{id} #{Data.text(row, "error")}",
          ["Dead letter: #{id}", Data.text(row, "error"), row.to_pretty_json])
      end
      Data.rows(data, "retries").each do |row|
        id = Data.text(row, "jid", Data.text(row, "id"))
        entries << UI::Inspector::Item.new("retry:#{id}", "Scheduled retry #{id}", [row.to_pretty_json])
      end
      dlq.replace(entries)
      @notice = Data.text(data, "history", "Connected") if @notice.starts_with?("Connecting")
    end

    def view(frame : UI::Frame) : Nil
      draw(frame, UI::Rect.new(0, 0, frame.width, frame.height))
    end

    def draw(frame : UI::Frame, area : UI::Rect) : Nil
      header, body = area.split_top(2)
      frame.text(header.x, header.y, "[1] Queues & Workers  [2] Workflows  [3] DLQ & Retries", UI::Token::Blue, max: header.w)
      body, footer = body.split_top(Math.max(0, body.h - 3))
      if body.h >= 14
        metrics, body = body.split_top(4)
        values = [{"Queues · #{@queue_count}", "#{@pending.to_i64} pending"},
                  {"Workers · #{@worker_count || "unavailable"}", "#{@processing.to_i64} processing"},
                  {"Throughput", "#{@rate.try(&.round(2)) || "—"} jobs/s"}]
        metrics.columns(3, 1).each_with_index do |card, index|
          title, value = values[index]
          inner = frame.card(card, title)
          frame.text(inner.x, inner.y, value, UI::Token::Blue, max: inner.w) unless inner.empty?
        end
      end
      inspector.draw(frame, body, tab.to_s, tab.workflows? ? "No active workflows · check runtime/history adapter" : "No entries")
      stale = @last_snapshot.try { |at| Time.instant - at > 5.seconds } != false
      note = confirming.try { |id| "Replay #{id}? y confirms; any other key cancels" } || @notice
      frame.text(footer.x, footer.y, "#{stale ? "STALE · " : ""}#{note}", UI::Token::Muted, max: footer.w)
      frame.text(footer.x, footer.y + 1, "1/2/3 views · Tab details · j/k select · r replay DLQ · Ctrl-P navigate", UI::Token::Blue, max: footer.w) if footer.h > 1
    end
  end
end
