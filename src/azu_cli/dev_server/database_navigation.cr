module AzuCLI::DevServer
  class MissionControl
    DATABASE_VIEWS = {Tab::Database, Tab::SQL, Tab::DB, Tab::Migrations}

    private def database_view? : Bool
      DATABASE_VIEWS.includes?(tab)
    end

    private def draw_database_nav(frame : Frame, area : Rect) : Rect
      header, body = area.split_top(2)
      frame.text(header.x, header.y, "Database · [ / ] Summary | SQL & pool | Schema | Migrations", Token::Blue, max: header.w)
      body
    end
  end
end
