require "./hud"
require "./command_composer"
require "./auth_tab"
require "./shared_telemetry"
require "./dashboard_state"
require "../joobq/screen"

module AzuCLI::DevServer
  # The dev workspace shell. Build, console and command components share this
  # navigation and frame; their controller retains lifecycle and callbacks.
  class MissionControl < UI::Screen
    include UI

    enum Tab
      Dashboard
      Server
      Jobs
      DB
      SQL
      Auth
      Logs
      Build
      Errors
      Commands
      Console
      Config
      Migrations
      Tracing
      Profiler
      Database
      Cache
      JoobQ
      Components
      Mailers
      Runtime
    end

    # Stable keys follow the sidebar, even when an optional integration is hidden.
    NAVIGATION = {Tab::Dashboard, Tab::Errors, Tab::Tracing, Tab::Logs, Tab::Profiler,
                  Tab::Auth, Tab::Database, Tab::Cache, Tab::JoobQ, Tab::Jobs,
                  Tab::Components, Tab::Mailers}
    SHORTCUTS = {
      Tab::Dashboard => '1', Tab::Errors => '2', Tab::Tracing => '3',
      Tab::Logs => '4', Tab::Profiler => '5', Tab::Auth => '6',
      Tab::Database => '7', Tab::Cache => '8', Tab::JoobQ => '9', Tab::Jobs => '0',
      Tab::Components => 'c', Tab::Mailers => 'm',
      Tab::SQL => 's', Tab::DB => 'u', Tab::Migrations => 'i',
      Tab::Console => '`', Tab::Build => 'd', Tab::Commands => 'x',
      Tab::Config => 'v', Tab::Server => 'a', Tab::Runtime => 'w',
    }

    getter tab = Tab::Dashboard
    getter query = ""
    getter? searching = false
    getter? menu_open = false
    @menu_query = ""
    @menu_selected = 0
    @menu_viewport = Viewport.new
    @sidebar = true
    @log_sequence = 0
    @follow_logs = true
    @shared_logs = false
    @output_logs = [] of Inspector::Item
    @request_logs = [] of Inspector::Item
    @help_open = false
    @help_viewport = Viewport.new
    SQL_COLOR = ->(line : String) { Highlight.sql(line) }
    LOG_COLOR = ->(line : String) { Highlight.log(line) }
    @previous_tab = Tab::Dashboard
    @nav_viewport = Viewport.new
    @rows = {} of Tab => Array(Inspector::Item)
    @inspectors = {} of Tab => Inspector
    @snapshot : JSON::Any?
    @received : Time::Instant?
    @jobs_received : Time::Instant?
    @jobs : Events::JobsSample?
    @second = -1_i64
    @notice = "Ctrl-P navigate · ? help"
    @now = Time.instant
    @composer : CommandComposer
    @auth = AuthTab.new
    @dashboard = DashboardState.new
    @joobq : JoobQDashboard::Screen

    def initialize(@workspace : Hud, @project : String, @reduced_motion : Bool = false,
                   @clock : Proc(Time::Instant) = -> { Time.instant },
                   @read_only : Bool = false,
                   @sample_data : Bool = false,
                   @on_jobs : Proc(Nil) = -> { },
                   on_replay : Proc(String, Nil) = ->(_id : String) { },
                   on_command : Proc(Control::Command, Bool) = ->(_command : Control::Command) { false })
      @composer = CommandComposer.new(on_command)
      @joobq = JoobQDashboard::Screen.new(on_replay)
      @notice = read_only_notice if @read_only
      Tab.each do |tab|
        @rows[tab] = [] of Inspector::Item
        @inspectors[tab] = Inspector.new
      end
    end

    def summary : String
      @workspace.summary
    end

    def handoff : Proc(Nil)?
      return nil if @read_only
      @workspace.handoff
    end

    # Ticks also expire telemetry. Idle ticks update nothing visible until the
    # next second; reduced motion disables the busy spinner, not freshness checks.
    def animating? : Bool
      true
    end

    def update(event : Event) : Action
      @now = @clock.call
      @joobq.update(event) if event.is_a?(JoobQDashboard::Snapshot) || event.is_a?(JoobQDashboard::Notice)
      @composer.update(event) unless event.is_a?(Key)
      return key(event) if event.is_a?(Key)
      # Independent auth publishers must not replace the main app snapshot or
      # clear SQL/errors in the embedded workspace on every auth heartbeat.
      if event.is_a?(Events::Telemetry) && field(event.data, "stream").try(&.as_s?) == "auth"
        unless @read_only
          @auth.update(event.data, @now)
          replace(Tab::Auth, @auth.items(field(@snapshot, "requests")))
        end
        return Action::Redraw
      end
      @workspace.update(event) unless @read_only
      case event
      when Events::AppStarted
        @auth.reset
        @dashboard.reset
        @output_logs.clear
        @request_logs.clear
        @snapshot = nil
        @received = nil
        ingest
      when Events::Telemetry
        @received = @now
        return Action::Continue unless @dashboard.update(event.data)
        @snapshot = event.data
        ingest
      when Events::RemoteStatus
        @notice = "#{read_only_notice} · #{event.message}"
        @received = nil unless event.connected
        @jobs_received = nil unless event.connected
      when Events::JobsSample
        @jobs = event
        @jobs_received = @now
        replace(Tab::Jobs, event.queues.first(200).map do |queue|
          Inspector::Item.new(queue.name, "#{queue.name}  wait #{queue.pending}  processing #{queue.processing}  failed #{queue.failed}  completed #{queue.completed || "--"}",
            ["Queue: #{queue.name}", "Pending: #{queue.pending}", "Processing: #{queue.processing}", "Failed (DLQ): #{queue.failed}",
             "Completed (cumulative): #{queue.completed || "not supplied"}",
             "", "Redis connectivity does not confirm a worker is running.", "Processing is not a process-wide fiber count.",
             "If the worker logs 0 queues, register the job class and queue_configs.",
             "Use azu joobq for worker/DAG/DLQ inspection and confirmed replay."])
        end)
      when Events::LogLine
        @log_sequence += 1
        line = event.line[0, 2048]
        item = Inspector::Item.new(@log_sequence.to_s, line, [line])
        @output_logs = ([item] + @output_logs).first(200)
        refresh_logs
        @inspectors[Tab::Logs].key(Key.new(KeyCode::Home)) if @follow_logs
      when Tick
        second = (@now - Widgets::EPOCH).total_seconds.to_i64
        return Action::Continue if second == @second && (@reduced_motion || !@workspace.animating?)
        @second = second
      end
      Action::Redraw
    end

    private def key(key : Key) : Action
      if key.code.ctrl_c?
        return @workspace.panel_key(Hud::Tab::Console, key) if tab.console? && !menu_open?
        return Action::Quit
      end
      return @composer.update(key) if @composer.active?
      if @help_open
        return Action::Quit if key.char?('q')
        if key.code.esc? || key.char?('h') || key.char?('?')
          @help_open = false
        elsif key.code.ctrl_p?
          @help_open = false
          @menu_open = true
          @menu_query = ""
          @menu_selected = 0
        else
          @help_viewport.key(key)
        end
        return Action::Redraw
      end
      if key.code.ctrl_p?
        @menu_open = !menu_open?
        @menu_query = ""
        @menu_selected = 0
        return Action::Redraw
      end
      return menu_key(key) if menu_open?
      if tab.console?
        if key.code.esc?
          @workspace.panel_key(Hud::Tab::Console, key)
          select_tab(@previous_tab)
          return Action::Redraw
        end
        if @workspace.console_focus? || key.code.enter? || key.char?('i') || key.code.ctrl_o?
          return @workspace.panel_key(Hud::Tab::Console, key)
        end
      end
      if tab.commands? && @workspace.confirming
        return @workspace.panel_key(Hud::Tab::Commands, key)
      end
      if searching?
        case key.code
        when .esc?       then @searching = false; @query = ""
        when .enter?     then @searching = false
        when .backspace? then @query = query[0, Math.max(0, query.size - 1)]
        when .char?      then @query += key.char.to_s if query.size < 64
        end
        filter
        return Action::Redraw
      end
      return Action::Quit if key.char?('q')
      if tab.joob_q? && @joobq.confirming
        return @joobq.update(key) unless @read_only
      end
      if key.code.alt_left? || key.code.alt_right?
        sections = navigation_tabs
        unless sections.empty?
          index = sections.index(tab) || 0
          select_tab(sections[(index + (key.code.alt_right? ? 1 : -1)) % sections.size])
        end
      elsif key.char?('h') || key.char?('?')
        @help_open = true
        @help_viewport.reset
      elsif (tab.logs? || tab.dashboard?) && key.char?('t')
        @shared_logs = !using_shared_logs?
        refresh_logs
      elsif @read_only && (key.char?('`') || key.char?('2') || key.char?('x') || key.char?('r') || key.char?(':') || key.char?('g') || key.char?('d') || key.char?('v'))
        @notice = read_only_notice
      elsif key.char?(':') || key.char?('g')
        @composer.open(key.char?('g'))
      elsif key.char?('/') && panel.nil? && !tab.joob_q?
        @searching = true
      elsif key.code.esc?
        @query = ""
        filter
      elsif database_view? && (key.char?('[') || key.char?(']'))
        index = DATABASE_VIEWS.index(tab) || 0
        select_tab(DATABASE_VIEWS[(index + (key.char?(']') ? 1 : -1)) % DATABASE_VIEWS.size])
      elsif key.char?('b')
        @sidebar = !@sidebar
      elsif key.char?('n')
        select_tab(Tab::SQL)
        @query = "N+1"
        filter
      elsif key.char?('l')
        select_tab(Tab::Logs)
      elsif (tab.logs? || (tab.dashboard? && overview_feed == Tab::Logs)) && key.char?('f')
        @follow_logs = true
        @overview_logs.reset
        @inspectors[Tab::Logs].key(Key.new(KeyCode::Home))
      elsif chosen = tabs.find { |item| key.char?(shortcut(item)) }
        select_tab(chosen)
      elsif tab.joob_q?
        return @joobq.update(key) unless @read_only && key.char?('r')
      elsif key.char?('r')
        @workspace.panel_key(Hud::Tab::Overview, key)
      elsif tab.dashboard?
        overview_key(key)
      elsif active = panel
        return @workspace.panel_key(active, key)
      else
        @follow_logs = false if tab.logs?
        @inspectors[tab].key(key)
      end
      Action::Redraw
    end

    private def menu_items : Array({String, Char})
      sections = navigation_tabs + [Tab::SQL, Tab::DB, Tab::Migrations] + tabs.reject { |item| NAVIGATION.includes?(item) || {Tab::SQL, Tab::DB, Tab::Migrations}.includes?(item) }
      entries = sections.select { |item| tabs.includes?(item) }.map do |item|
        label = item.sql? ? "Open SQL inspector" : item.db? ? "Open SQL schema explorer" : "Open #{section_name(item)}"
        {label, shortcut(item)}
      end
      sql_index = entries.index { |entry| entry[1] == 's' }
      entries.insert(sql_index + 1, {"Inspect N+1 SQL queries", 'n'}) if sql_index
      entries << {"Keyboard hints", '?'}
      unless @read_only
        entries.concat([{"Run azu command", ':'}, {"Generate code", 'g'}])
      end
      entries.select { |entry| self.class.matches?(entry[0], @menu_query) }
    end

    private def menu_key(event : Key) : Action
      case event.code
      when .esc?  then @menu_open = false
      when .up?   then @menu_selected -= 1
      when .down? then @menu_selected += 1
      when .backspace?
        @menu_query = @menu_query[0, Math.max(0, @menu_query.size - 1)]
        @menu_selected = 0
      when .char?
        @menu_query += event.char.to_s if @menu_query.size < 64
        @menu_selected = 0
      when .enter?
        if chosen = menu_items[@menu_selected]?
          @menu_open = false
          if chosen[1] == '?'
            @help_open = true
            @help_viewport.reset
          elsif chosen[1] == 'n'
            select_tab(Tab::SQL)
            @query = "N+1"
            filter
          elsif section = tabs.find { |item| shortcut(item) == chosen[1] }
            select_tab(section)
          elsif !@read_only
            @composer.open(chosen[1] == 'g')
          end
          return Action::Redraw
        end
      end
      @menu_selected = @menu_selected.clamp(0, Math.max(0, menu_items.size - 1))
      Action::Redraw
    end

    private def tabs : Array(Tab)
      @read_only ? Tab.values.reject { |t| t.build? || t.commands? || t.console? || t.config? || t.errors? } : Tab.values
    end

    private def shortcut(section : Tab) : Char
      SHORTCUTS[section]
    end

    private def panel : Hud::Tab?
      case tab
      when .build?    then Hud::Tab::Overview
      when .errors?   then Hud::Tab::Errors
      when .commands? then Hud::Tab::Commands
      when .console?  then Hud::Tab::Console
      when .config?   then Hud::Tab::Config
      end
    end

    private def select_tab(section : Tab) : Nil
      return unless tabs.includes?(section)
      @on_jobs.call if section.joob_q? && !@read_only
      @previous_tab = tab if tab != section
      @tab = section
      @query = ""
      @searching = false
      filter
      @workspace.open_panel(panel || Hud::Tab::Overview)
    end

    private def replace(tab : Tab, rows : Array(Inspector::Item)) : Nil
      @rows[tab] = rows
      @inspectors[tab].replace(rows.select { |row| self.class.matches?(row.label, query) })
    end

    private def using_shared_logs? : Bool
      @shared_logs || @output_logs.empty?
    end

    private def refresh_logs : Nil
      replace(Tab::Logs, using_shared_logs? ? @request_logs : @output_logs)
      @inspectors[Tab::Logs].key(Key.new(KeyCode::Home)) if @follow_logs
    end

    private def filter : Nil
      @rows.each { |tab, rows| @inspectors[tab].replace(rows.select { |row| self.class.matches?(row.label, query) }) }
    end

    # Bounded subsequence search; no user-supplied regular expressions.
    def self.matches?(label : String, query : String) : Bool
      text = label.downcase
      position = 0
      query.downcase.each_char do |char|
        found = text.index(char, position)
        return false unless found
        position = found + 1
      end
      true
    end

    private def field(value : JSON::Any?, key : String) : JSON::Any?
      DiagnosticData.field(value, key)
    end

    private def text(value : JSON::Any?, key : String) : String
      DiagnosticData.text(value, key, "--")[0, 512]
    end

    private def ingest : Nil
      {Tab::Tracing => "tracing", Tab::Profiler => "profiler", Tab::Database => "database",
       Tab::Cache => "cache", Tab::Components => "components", Tab::Mailers => "mailers", Tab::Runtime => "process"}.each do |section, name|
        replace(section, @dashboard.items(name))
      end
      requests = field(@snapshot, "requests")
      @request_logs = SharedTelemetry.request_logs(@snapshot)
      refresh_logs
      replace(Tab::Server, DiagnosticData.rows(requests, "recent", 200).map do |row|
        label = "#{text(row, "method")} #{text(row, "path")}  #{text(row, "status")}  #{text(row, "ms")}ms"
        Inspector::Item.new(text(row, "at") + label, label,
          [label, "Time: #{text(row, "at")}", "Endpoint: #{text(row, "endpoint")}", "Trace ID: #{text(row, "id")}"])
      end)
      sql = field(@snapshot, "sql")
      replace(Tab::SQL, SQLTab.items(sql))
      # Extension contracts: no database credentials, SQL parameters or auth tokens.
      database = field(@snapshot, "database")
      replace(Tab::DB, DiagnosticData.rows(database, "tables", 200).map do |row|
        name = text(row, "name")
        columns = DiagnosticData.rows(row, "columns", 100).map { |column| "#{text(column, "name")} : #{text(column, "type")}" }
        Inspector::Item.new(name, name, [name, "Schema version: #{text(database, "migration_version")}"] + columns)
      end)
      replace(Tab::Migrations, DiagnosticData.rows(database, "migrations", 200).map do |row|
        version = text(row, "version")
        label = "#{version} #{text(row, "name")} #{text(row, "status")}"
        Inspector::Item.new(version, label, [label, "Applied at: #{text(row, "applied_at")}", "Read-only history from the application adapter."])
      end)
      @snapshot.try { |snapshot| @auth.update(snapshot, @now) } unless @read_only
      replace(Tab::Auth, @read_only ? [] of Inspector::Item : @dashboard.items("sessions") + @auth.items(requests))
    end

    private def freshness(at : Time::Instant?) : String
      return "not connected" unless at
      @now - at > 5.seconds ? "stale" : "connected"
    end

    private def read_only_notice : String
      "PRODUCTION · READ ONLY · commands, console and rebuild disabled"
    end
  end
end

require "./workspace_layout"
