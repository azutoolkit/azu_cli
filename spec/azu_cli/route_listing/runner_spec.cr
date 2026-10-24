require "../../spec_helper"

describe AzuCLI::RouteListing::Runner do
  describe ".parse" do
    it "reads the routes from the marker line among the app's own output" do
      output = <<-OUT
        [12:00:00] [INFO ] Connected to the database
        AZU_ROUTES_JSON:[{"method":"GET","path":"/","endpoint":"Blog::Welcome::IndexEndpoint","request":"Blog::Welcome::IndexRequest","response":"Blog::Welcome::IndexPage"}]
        goodbye
        OUT

      routes = AzuCLI::RouteListing::Runner.parse(output)

      routes.size.should eq 1
      routes[0].path.should eq "/"
      routes[0].request.should eq "Blog::Welcome::IndexRequest"
    end

    it "fails when the app printed no routes" do
      expect_raises(AzuCLI::RouteListing::Runner::Error, "did not report its routes") do
        AzuCLI::RouteListing::Runner.parse("nothing to see\n")
      end
    end

    it "fails on JSON that is not a list of routes, without echoing it" do
      expect_raises(AzuCLI::RouteListing::Runner::Error, "not valid JSON") do
        AzuCLI::RouteListing::Runner.parse("AZU_ROUTES_JSON:{\"oops\":1}\n")
      end
    end
  end

  describe "#script" do
    it "requires the app file without starting a server, and prints the router's route_info" do
      script = AzuCLI::RouteListing::Runner.new("./src/blog.cr").script

      script.should contain(%(require "./src/blog.cr"))
      script.should contain("Azu::CONFIG.router.route_info")
      script.should contain("AZU_ROUTES_JSON:")
      script.should contain(%("Azu::Endpoint"))
      script.should_not contain(".start")
    end
  end
end
