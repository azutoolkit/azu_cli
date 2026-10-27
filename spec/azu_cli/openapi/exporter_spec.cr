require "../../spec_helper"

describe AzuCLI::OpenAPI::Exporter do
  describe ".parse" do
    it "reads the document from the marker line among the app's own output" do
      output = <<-OUT
        [12:00:00] [INFO ] Connected to the database
        AZU_OPENAPI_JSON:{"openapi":"3.1.0","paths":{}}
        bye
        OUT

      JSON.parse(AzuCLI::OpenAPI::Exporter.parse(output))["openapi"].should eq "3.1.0"
    end

    it "fails when the app printed no document" do
      expect_raises(AzuCLI::OpenAPI::Exporter::Error, "did not report its OpenAPI document") do
        AzuCLI::OpenAPI::Exporter.parse("nothing\n")
      end
    end

    it "fails on output that is not a JSON object" do
      expect_raises(AzuCLI::OpenAPI::Exporter::Error, "not valid JSON") do
        AzuCLI::OpenAPI::Exporter.parse("AZU_OPENAPI_JSON:[1\n")
      end
    end
  end

  describe "#script" do
    it "requires the app without starting it and asks Azu::OpenAPI for the default app's document" do
      script = AzuCLI::OpenAPI::Exporter.new("./src/blog.cr").script

      script.should contain(%(require "./src/blog.cr"))
      script.should contain("Azu::OpenAPI.document(Azu::App.default")
      script.should contain(%(ENV["AZU_OPENAPI_TITLE"]))
      script.should contain("AZU_OPENAPI_JSON:")
      script.should_not contain(".start")
    end
  end
end
