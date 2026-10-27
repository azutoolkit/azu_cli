require "../../spec_helper"

describe AzuCLI::AppConfig::Runner do
  describe ".parse" do
    it "reads the settings from the marker line among the app's own output" do
      output = <<-OUT
        [12:00:00] [INFO ] Connected to the database
        AZU_CONFIG_JSON:[{"section":"server","key":"port","value":"4000"}]
        goodbye
        OUT

      settings = AzuCLI::AppConfig::Runner.parse(output)

      settings.size.should eq 1
      settings[0].section.should eq "server"
      settings[0].value.should eq "4000"
    end

    it "fails when the app printed no configuration" do
      expect_raises(AzuCLI::AppConfig::Runner::Error, "did not report its configuration") do
        AzuCLI::AppConfig::Runner.parse("nothing to see\n")
      end
    end

    it "fails on JSON that is not a list of settings, without echoing it" do
      expect_raises(AzuCLI::AppConfig::Runner::Error, "not valid JSON") do
        AzuCLI::AppConfig::Runner.parse("AZU_CONFIG_JSON:{\"oops\":1}\n")
      end
    end
  end

  describe "#script" do
    script = AzuCLI::AppConfig::Runner.new("./src/blog.cr").script

    it "requires the app file and prints the marker line" do
      script.should contain(%(require "./src/blog.cr"))
      script.should contain("AZU_CONFIG_JSON:")
    end

    it "reports no secret value: the database password is masked and the secrets are only set or not set" do
      script.should contain(%(ENV["CSRF_SECRET"]?.presence ? "set" : "not set"))
      script.should contain(%(ENV["SESSION_SECRET"]?.presence ? "set" : "not set"))
      script.should contain("***@")
      script.should_not contain(%(ENV["CSRF_SECRET"]?.to_s))
    end
  end
end
