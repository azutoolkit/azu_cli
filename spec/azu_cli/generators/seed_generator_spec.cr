require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Seed do
  it "renders seeds for the runner that already loads schema and models" do
    dir = File.join(Dir.tempdir, "azu-seed-#{Random::Secure.hex(8)}")
    Dir.mkdir_p(dir)
    begin
      generator = AzuCLI::Generate::Seed.new("Audit", "test")
      generator.render(dir)
      source = File.read(File.join(dir, "test", generator.filename))
      source.should_not contain %(require "../../../models/**")
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "rejects environment traversal and source interpolation in seed names" do
    expect_raises(ArgumentError) { AzuCLI::Generate::Seed.new("Audit", "../../other") }
    expect_raises(ArgumentError) { AzuCLI::Generate::Seed.new("Bad\"Name") }
  end
end
