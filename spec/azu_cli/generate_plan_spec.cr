require "../spec_helper"

private alias TUI = AzuCLI::UI

private def with_project(&)
  root = File.join(Dir.tempdir, "azu-plan-spec-#{Random::Secure.hex(4)}")
  project = File.join(root, "project")
  shadow = File.join(root, "shadow")
  state = File.join(root, "state")
  Dir.mkdir_p(File.join(project, "src", "db"))
  File.write(File.join(project, "src", "db", "schema.cr"), "schema do\n  table :users do\n  end\nend\n")
  File.write(File.join(project, "shard.yml"), "name: blog\ntargets:\n  blog:\n    main: src/blog.cr\n")
  previous = ENV["XDG_STATE_HOME"]?
  ENV["XDG_STATE_HOME"] = state
  begin
    yield project, shadow
  ensure
    previous ? (ENV["XDG_STATE_HOME"] = previous) : ENV.delete("XDG_STATE_HOME")
    FileUtils.rm_rf(root)
  end
end

# What a generator would leave in the shadow: a new model and one more table in the schema.
private def generate_into(shadow : String) : Nil
  Dir.mkdir_p(File.join(shadow, "src", "models"))
  File.write(File.join(shadow, "src", "models", "post.cr"), "class Post\nend\n")
  File.write(File.join(shadow, "src", "db", "schema.cr"), "schema do\n  table :users do\n  end\n  table :posts do\n  end\nend\n")
end

private def plan_for(project : String, shadow : String) : AzuCLI::GeneratePlan
  AzuCLI::GeneratePlan.copy_project(project, shadow)
  generate_into(shadow)
  AzuCLI::GeneratePlan.new(shadow, project, AzuCLI::GeneratePlan.compare(shadow, project), "")
end

describe AzuCLI::GeneratePlan do
  it "lists the files the generator created and the ones it changed, with a diff" do
    with_project do |project, shadow|
      plan = plan_for(project, shadow)
      plan.new_files.map(&.path).should eq ["src/models/post.cr"]
      plan.changed_files.map(&.path).should eq ["src/db/schema.cr"]
      diff = plan.changed_files.first.diff
      diff.select(&.op.==('+')).map(&.text).should eq ["  table :posts do", "  end"]
      diff.none?(&.op.==('-')).should be_true
    end
  end

  it "does not copy dependencies, builds or git history into the shadow, and links lib/" do
    with_project do |project, shadow|
      Dir.mkdir_p(File.join(project, "lib", "azu"))
      Dir.mkdir_p(File.join(project, ".git"))
      Dir.mkdir_p(File.join(project, "bin"))
      File.write(File.join(project, "bin", "blog"), "binary")
      AzuCLI::GeneratePlan.copy_project(project, shadow)
      (File.info(shadow).permissions.value & 0o077).should eq 0 # it holds a copy of .env
      File.symlink?(File.join(shadow, "lib")).should be_true
      Dir.exists?(File.join(shadow, ".git")).should be_false
      File.exists?(File.join(shadow, "bin", "blog")).should be_false
      AzuCLI::GeneratePlan.compare(shadow, project).should be_empty
    end
  end

  it "writes what the preview showed, and undo puts the project back" do
    with_project do |project, shadow|
      before = File.read(File.join(project, "src", "db", "schema.cr"))
      plan = plan_for(project, shadow)
      plan.apply("azu generate model post")
      File.read(File.join(project, "src", "models", "post.cr")).should eq "class Post\nend\n"
      File.read(File.join(project, "src", "db", "schema.cr")).should contain "table :posts"

      records = AzuCLI::Undo.records(project)
      records.size.should eq 1
      AzuCLI::Undo.manifest(records.first).command.should eq "azu generate model post"
      steps = AzuCLI::Undo.apply(records.first, project)
      steps.all?(&.ok).should be_true
      File.exists?(File.join(project, "src", "models", "post.cr")).should be_false
      Dir.exists?(File.join(project, "src", "models")).should be_false
      File.read(File.join(project, "src", "db", "schema.cr")).should eq before
      AzuCLI::Undo.records(project).should be_empty
    end
  end

  it "leaves an existing symlink alone when the shadow generated a secret file" do
    with_project do |project, shadow|
      shared = File.join(File.dirname(project), "shared.env")
      File.write(shared, "SPARK_SECRET=managed-externally\n")
      File.symlink(shared, File.join(project, ".env"))
      AzuCLI::GeneratePlan.copy_project(project, shadow)
      AzuCLI::Generate::SparkWiring.install(shadow)
      plan = AzuCLI::GeneratePlan.new(shadow, project, AzuCLI::GeneratePlan.compare(shadow, project), "")
      plan.entries.map(&.path).should_not contain(".env")
      plan.apply("azu generate spark Counter")
      File.symlink?(File.join(project, ".env")).should be_true
      File.read(shared).should eq("SPARK_SECRET=managed-externally\n")
    end
  end

  it "preserves private generated secret file permissions when applying a preview" do
    previous_umask = LibC.umask(0o022)
    with_project do |project, shadow|
      File.write(File.join(project, ".env"), "APP_ENV=test\n", perm: 0o600)
      AzuCLI::GeneratePlan.copy_project(project, shadow)
      AzuCLI::Generate::SparkWiring.install(shadow)
      plan = AzuCLI::GeneratePlan.new(shadow, project, AzuCLI::GeneratePlan.compare(shadow, project), "")
      plan.apply("azu generate spark Counter")
      File.read(File.join(project, ".env")).should contain("SPARK_SECRET=")
      File.info(File.join(project, ".env")).permissions.value.should eq(0o600)
      AzuCLI::Undo.apply(AzuCLI::Undo.records(project).first, project)
      File.read(File.join(project, ".env")).should eq("APP_ENV=test\n")
      File.info(File.join(project, ".env")).permissions.value.should eq(0o600)
    end
  ensure
    LibC.umask(previous_umask) if previous_umask
  end

  it "leaves a file edited after it was generated" do
    with_project do |project, shadow|
      plan_for(project, shadow).apply("azu generate model post")
      File.write(File.join(project, "src", "models", "post.cr"), "class Post\n  # mine\nend\n")
      steps = AzuCLI::Undo.apply(AzuCLI::Undo.records(project).first, project)
      edited = steps.find! { |step| step.path == "src/models/post.cr" }
      edited.ok.should be_false
      edited.reason.to_s.should contain "changed since it was generated"
      File.read(File.join(project, "src", "models", "post.cr")).should contain "# mine"
    end
  end

  it "finds the main file from shard.yml" do
    with_project do |project, _shadow|
      AzuCLI::GeneratePlan.main_file(project).should eq "src/blog.cr"
    end
  end
end

describe AzuCLI::GeneratePreview do
  it "lists the files, previews the selected one, and writes on Enter" do
    with_project do |project, shadow|
      plan = plan_for(project, shadow)
      screen = AzuCLI::GeneratePreview.new(plan, "model post", checking: true)
      frame = TUI::Frame.new(110, screen.height(110, 30), TUI::StyleTable.new(TUI::Theme.new(TUI::ColorDepth::None)))
      screen.update(AzuCLI::GeneratePreview::TypeChecked.new(nil)) # the first file (schema.cr) is selected
      screen.view(frame)
      text = frame.to_text
      text.should contain "1 new · 1 changed"
      text.should contain "~ src/db/schema.cr"
      text.should contain "+ src/models/post.cr"
      text.should contain "table :posts do"
      text.should contain "✔ the project type-checks with these files"
      text.should contain "[Enter] Write 2 files"
      screen.update(TUI::Key.new(TUI::KeyCode::Enter)).should eq TUI::Action::Quit
      screen.confirmed?.should be_true
    end
  end

  it "cancels on Esc and reports a type error" do
    with_project do |project, shadow|
      screen = AzuCLI::GeneratePreview.new(plan_for(project, shadow), "model post", checking: true)
      screen.update(AzuCLI::GeneratePreview::TypeChecked.new("In src/x.cr:1:1\nError: undefined constant Pots\n"))
      screen.check.failed?.should be_true
      screen.update(TUI::Key.new(TUI::KeyCode::Esc))
      screen.confirmed?.should be_false
    end
  end
end
