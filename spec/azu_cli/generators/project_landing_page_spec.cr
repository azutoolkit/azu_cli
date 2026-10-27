require "../../spec_helper"
require "file_utils"
require "teeplate"

private def render_landing_project(type : String, project : String = "blog", module_name : String = "Blog", &)
  dir = File.join(Dir.tempdir, "azu_landing_#{type}_#{Time.utc.to_unix_ms}_#{Random.rand(100000)}")
  FileUtils.mkdir_p(dir)
  begin
    AzuCLI::Generate::Project.new(project, module_name, "Jane", "jane@example.com", project_type: type).render(dir)
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

# The landing page served at "/" by a freshly generated project. It shares its design tokens,
# theme toggle and layout with the Azu example app (azutoolkit/azu playground).
describe "Generated project landing page" do
  describe "web project" do
    it "generates the layout, landing template and same-origin assets" do
      render_landing_project("web") do |dir|
        %w[
          public/templates/app_layout.jinja
          public/templates/blog/welcome/index_page.jinja
          public/assets/app.css
          public/assets/theme.js
          public/assets/app.js
          public/assets/favicon.svg
          src/pages/welcome/index_page.cr
        ].each { |path| File.exists?(File.join(dir, path)).should be_true }
      end
    end

    # Azu finds a page's template by the page's type name (`Azu::Templates::Renderable#page_path`), so the landing
    # template sits under the module name underscored, also when that is not the project name
    it "puts the landing template where Azu looks for the welcome page" do
      {"blog" => "BlogApp", "blog-app" => "BlogApp", "myapp" => "MyApp", "shop" => "Shop"}.each do |project, module_name|
        render_landing_project("web", project, module_name) do |dir|
          File.read(File.join(dir, "src/pages/welcome/index_page.cr")).should contain("module #{module_name}\n  struct Welcome::IndexPage\n")
          page_path = "#{module_name}::Welcome::IndexPage".split("::").join("/").underscore.downcase
          Dir.glob(File.join(dir, "public/templates/*/welcome/index_page.jinja")).should eq([File.join(dir, "public/templates/#{page_path}.jinja")])
        end
      end
    end

    it "shows what Azu is, the next steps, docs links and the versions" do
      render_landing_project("web") do |dir|
        page = File.read(File.join(dir, "public/templates/blog/welcome/index_page.jinja"))
        page.should contain("Typed contracts")
        page.should contain("Real-time")
        page.should contain("azu generate scaffold Post title:string")
        page.should contain("azu db:migrate")
        page.should contain("azu serve")
        page.should contain("https://azutoolkit.org")
        page.should contain("{{ azu_version }}")
        page.should contain("{{ crystal_version }}")
        page.should contain("Welcome::IndexEndpoint")
        page.should contain("GET")
      end
    end

    it "passes the versions and environment to the template" do
      render_landing_project("web") do |dir|
        source = File.read(File.join(dir, "src/pages/welcome/index_page.cr"))
        source.should contain("module Blog")
        source.should contain("shard.lock")
        source.should contain(%("crystal_version" => Crystal::VERSION))
        source.should contain(%("azu_version"     => AZU_VERSION))
        source.should contain("Blog::VERSION")
        source.should contain("Azu.current_config.env.to_s")
      end
    end

    it "keeps the design tokens of the Azu example app" do
      render_landing_project("web") do |dir|
        css = File.read(File.join(dir, "public/assets/app.css"))
        {"--accent: #1d4ed8", "--accent: #7ba4ff", "--bg: #f3f5f9", "--bg: #0a0d13",
         ":root[data-theme=\"dark\"]", "prefers-color-scheme: dark", "prefers-reduced-motion: reduce",
         ":focus-visible", ".skip-link"}.each { |token| css.should contain(token) }

        theme = File.read(File.join(dir, "public/assets/theme.js"))
        theme.should contain("azu-theme")
        File.read(File.join(dir, "public/assets/app.js")).should contain("azu-theme")
      end
    end

    it "is safe under a strict CSP and needs no CDN" do
      render_landing_project("web") do |dir|
        files = %w[public/templates/app_layout.jinja public/templates/blog/welcome/index_page.jinja
          public/assets/app.css public/assets/app.js public/assets/theme.js]
        files.each do |path|
          content = File.read(File.join(dir, path))
          content.should_not match(/https?:\/\/(cdn|unpkg|fonts)\./)
          content.should_not match(/\sstyle\s*=/)
          content.should_not match(/\son[a-z]+\s*=/)
          content.should_not contain("@import")
        end

        html = File.read(File.join(dir, "public/templates/app_layout.jinja")) +
               File.read(File.join(dir, "public/templates/blog/welcome/index_page.jinja"))
        # Every script tag is an external same-origin file; none has an inline body.
        html.scan(/<script\b[^>]*>/).each { |tag| tag[0].should contain("src=\"/assets/") }
        html.should_not match(/<script\b[^>]*>\s*[^<\s]/)
        html.should_not contain("<style")
      end
    end

    it "is responsive and accessible" do
      render_landing_project("web") do |dir|
        layout = File.read(File.join(dir, "public/templates/app_layout.jinja"))
        layout.should contain(%(name="viewport"))
        layout.should contain(%(lang="en"))
        layout.should contain("skip-link")
        layout.should contain(%(<main class="shell" id="main"))
        layout.should contain("data-theme-toggle")

        css = File.read(File.join(dir, "public/assets/app.css"))
        css.should contain("@media (max-width: 40rem)")
      end
    end
  end
end
