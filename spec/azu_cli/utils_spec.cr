require "../spec_helper"
require "teeplate"

describe AzuCLI::Utils do
  describe ".project_module_name" do
    # `azu new blog --module BlogApp` declares `module BlogApp` in src/blog.cr; the generators run later in the
    # project (scaffold, auth, channel) must write that module, not one derived from the shard name
    it "reads the module the generated app file declares" do
      %w[web api cli].each do |type|
        TestHelpers::TestSetup.with_temp_project do
          AzuCLI::Generate::Project.new("blog", "BlogApp", "Jane", "jane@example.com", project_type: type).render(".")
          AzuCLI::Utils.project_module_name.should eq("BlogApp")
        end
      end
    end

    it "is the shard name in PascalCase when the app file declares no module" do
      TestHelpers::TestSetup.with_temp_project do
        File.write("shard.yml", "name: my-blog\nversion: 0.1.0\n")
        AzuCLI::Utils.project_module_name.should eq("MyBlog")
        Dir.mkdir_p("src")
        File.write("src/my-blog.cr", %(require "azu"\n\nmodule MyBlog::Web\nend\n))
        AzuCLI::Utils.project_module_name.should eq("MyBlog")
      end
    end
  end
end
