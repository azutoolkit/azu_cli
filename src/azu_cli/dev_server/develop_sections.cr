module AzuCLI::DevServer
  class MissionControl
    @generators_viewport = Viewport.new

    private def draw_generators(frame : Frame, area : Rect) : Nil
      inner = frame.card(area, "Generators", "Enter opens editor", border: Token::Blue)
      lines = [
        "Create application code with azu generate.",
        "", "Enter opens the command editor with generate prefilled.",
        "Type a generator, name and fields; Enter reviews, y runs.",
        "", "Examples:",
        "generate scaffold Product name:string price_cents:int32 --spark",
        "generate model Category name:string",
        "generate job SendEmail to:string",
        "", "Existing files retain the generator's conflict protection.",
        "Output and validation errors appear in the editor.",
      ]
      @generators_viewport.draw(frame, inner, Viewport.wrap(lines, Math.max(1, inner.w - 1)))
    end
  end
end
