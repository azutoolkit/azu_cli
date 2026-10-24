require "../../spec_helper"

private def entry(method, path, endpoint = "Blog::Posts::IndexEndpoint", request = "Blog::Posts::IndexRequest", response = "Blog::Posts::IndexPage")
  AzuCLI::RouteListing::Entry.new(method, path, endpoint, request, response)
end

private ROUTES = [
  entry("POST", "/posts", "Blog::Posts::CreateEndpoint", "Blog::Posts::CreateRequest", "Azu::Response::Empty"),
  entry("GET", "/posts"),
  entry("HEAD", "/posts"),
  entry("OPTIONS", "/posts"),
  entry("GET", "/"),
  entry("DELETE", "/posts/:id", "Blog::Posts::DestroyEndpoint", "Blog::Posts::DestroyRequest", "Azu::Response::Empty"),
  entry("WEBSOCKET", "/chat", "Blog::ChatChannel", "", ""),
]

describe AzuCLI::RouteListing::Table do
  describe "#filter" do
    it "hides the HEAD and OPTIONS routes Azu adds and orders by path, then method" do
      rows = AzuCLI::RouteListing::Table.new(ROUTES).filter.entries.map { |route| "#{route.method} #{route.path}" }

      rows.should eq ["GET /", "WEBSOCKET /chat", "GET /posts", "POST /posts", "DELETE /posts/:id"]
    end

    it "keeps one method, in any case, and shows HEAD when asked for it" do
      table = AzuCLI::RouteListing::Table.new(ROUTES)

      table.filter(method: "post").entries.map(&.path).should eq ["/posts"]
      table.filter(method: "HEAD").entries.map(&.method).should eq ["HEAD"]
    end

    it "keeps the routes whose path contains the text" do
      AzuCLI::RouteListing::Table.new(ROUTES).filter(path: "/posts/").entries.map(&.path).should eq ["/posts/:id"]
      AzuCLI::RouteListing::Table.new(ROUTES).filter(path: "nothing").entries.should be_empty
    end
  end

  describe "#to_text" do
    it "aligns the columns and counts the routes" do
      text = AzuCLI::RouteListing::Table.new([entry("GET", "/posts"), entry("DELETE", "/posts/:id", "Blog::Posts::DestroyEndpoint", "Blog::Posts::DestroyRequest", "Azu::Response::Empty")]).to_text
      lines = text.lines

      lines[0].should start_with("METHOD  PATH ")
      lines[0].should end_with("HELPERS")
      lines[1].should eq ["GET   ", "/posts    ", "Blog::Posts::IndexEndpoint".ljust(28), "Blog::Posts::IndexRequest".ljust(27), "Blog::Posts::IndexPage".ljust(22), "link_to_get_posts_index"].join("  ")
      lines[2].should contain("button_to_delete_posts_destroy")
      lines.last.should eq "2 routes"
    end

    it "shows a dash where a route has no request, response or helpers" do
      text = AzuCLI::RouteListing::Table.new([entry("WEBSOCKET", "/chat", "Blog::ChatChannel", "", "")]).to_text

      text.lines[1].should eq ["WEBSOCKET", "/chat", "Blog::ChatChannel", "-".ljust(7), "-".ljust(8), "-"].join("  ")
      text.should contain("1 route\n")
    end

    it "says so when no route matches" do
      AzuCLI::RouteListing::Table.new([] of AzuCLI::RouteListing::Entry).to_text.should eq "No routes match.\n"
    end
  end

  describe "#to_json" do
    it "round-trips the routes with their fields" do
      json = AzuCLI::RouteListing::Table.new([entry("GET", "/posts")]).to_json
      parsed = JSON.parse(json)

      parsed.as_a.size.should eq 1
      parsed[0]["method"].as_s.should eq "GET"
      parsed[0]["endpoint"].as_s.should eq "Blog::Posts::IndexEndpoint"
      parsed[0]["response"].as_s.should eq "Blog::Posts::IndexPage"
    end
  end
end

describe AzuCLI::RouteListing::Entry do
  it "names the helpers Azu registers: link for every verb, form for the writes, button for delete" do
    entry("GET", "/posts").helpers.should eq ["link_to_get_posts_index"]
    entry("POST", "/posts", "Blog::Posts::CreateEndpoint", "R", "S").helpers.should eq ["link_to_post_posts_create", "form_for_post_posts_create"]
    entry("DELETE", "/posts/:id", "Blog::Posts::DestroyEndpoint", "R", "S").helpers.should eq ["link_to_delete_posts_destroy", "form_for_delete_posts_destroy", "button_to_delete_posts_destroy"]
  end

  it "uses the last two segments of the class name, or the only one, minus _endpoint" do
    AzuCLI::RouteListing::Entry.helper_resource("Blog::Admin::Users::ShowEndpoint").should eq "users_show"
    AzuCLI::RouteListing::Entry.helper_resource("HealthEndpoint").should eq "health"
  end

  it "has no helpers for implicit HEAD and OPTIONS routes or for routes that are not endpoints" do
    entry("OPTIONS", "/posts").helpers.should be_empty
    entry("HEAD", "/posts").helpers.should be_empty
    entry("WEBSOCKET", "/chat", "Blog::ChatChannel", "", "").helpers.should be_empty
  end
end
