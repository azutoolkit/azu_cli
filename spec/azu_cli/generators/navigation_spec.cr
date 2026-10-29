require "../../spec_helper"
require "file_utils"

private def with_navigation(&)
  root = File.join(Dir.tempdir, "azu-navigation-#{Random::Secure.hex(6)}")
  Dir.mkdir_p(File.join(root, "public/templates/helpers"))
  path = File.join(root, AzuCLI::Generate::Navigation::PARTIAL)
  File.write(path, %(<li><a href="/custom">My custom page</a></li>\n#{AzuCLI::Generate::Navigation::ANCHOR}\n))
  yield root, path
ensure
  FileUtils.rm_rf(root) if root
end

describe AzuCLI::Generate::Navigation do
  it "adds sections once without overwriting manual labels or custom links" do
    with_navigation do |root, path|
      AzuCLI::Generate::Navigation.register(root, "Products", "/products")
      AzuCLI::Generate::Navigation.register(root, "Different label", "/products")
      contents = File.read(path)
      contents.scan(%(href="/products")).size.should eq(1)
      contents.should contain("My custom page")
      contents.should contain(">Products</a>")
      contents.should_not contain("Different label")
      Dir.glob("#{path}.*.tmp").should be_empty
    end
  end

  it "escapes labels and declines parameterized, unsafe or external destinations" do
    with_navigation do |root, path|
      AzuCLI::Generate::Navigation.register(root, "Books & <Reviews>", "/books")
      File.read(path).should contain("Books &amp; &lt;Reviews&gt;")
      before = File.read(path)
      ["/books/:id", "//example.com", "javascript:alert(1)", "/books\"onclick=\"alert(1)"].each do |route|
        AzuCLI::Generate::Navigation.register(root, "Unsafe", route)
      end
      File.read(path).should eq(before)
    end
  end

  it "leaves fully customized or older layouts alone" do
    with_navigation do |root, path|
      File.write(path, "custom navigation")
      AzuCLI::Generate::Navigation.register(root, "Products", "/products")
      File.read(path).should eq("custom navigation")
      File.delete(path)
      AzuCLI::Generate::Navigation.register(root, "Products", "/products")
      File.exists?(path).should be_false
    end
  end

  it "registers collection web endpoints, never API, member or write endpoints" do
    with_navigation do |root, path|
      output = File.join(root, "src/endpoints")
      Dir.mkdir_p(output)
      AzuCLI::Generate::Endpoint.new("Product", "index", "web").render(output)
      File.read(path).should contain(%(href="/products"))
      before = File.read(path)
      AzuCLI::Generate::Endpoint.new("Invoice", "index", "api").render(output)
      %w(new show edit create update destroy).each do |action|
        AzuCLI::Generate::Endpoint.new("Invoice", action, "web").render(output)
      end
      File.read(path).should eq(before)
    end
  end
end
