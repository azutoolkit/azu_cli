require "../../spec_helper"

include AzuCLI::DevServer

describe AzuCLI::DevServer::Classifier do
  it "rebuilds for source, configuration and the dependency files" do
    %w(src/blog.cr src/endpoints/posts/index_endpoint.cr src/views/page.ecr config/azu.yml config/api.yml shard.yml shard.lock).each do |path|
      Classifier.classify(path).should eq Action::Rebuild
    end
  end

  it "does not rebuild for templates" do
    %w(public/templates/layout.jinja public/templates/blog/posts/index_page.jinja public/templates/helpers/_nav.jinja).each do |path|
      Classifier.classify(path).should eq Action::Templates
    end
  end

  it "restarts without a build for .env files, but not for the example" do
    %w(.env .env.local .env.development .env.test).each { |path| Classifier.classify(path).should eq Action::Restart }
    Classifier.classify(".env.example").should eq Action::Ignore
    Classifier.classify("src/.env").should eq Action::Rebuild # under src/, everything is compiled in
  end

  it "ignores assets, specs, the build output and editor files" do
    %w(public/assets/app.css spec/blog_spec.cr bin/blog lib/azu/src/azu.cr README.md db/blog.db src/endpoints/.index.cr.swp src/blog.cr~ src/.#blog.cr src/#blog.cr# src/4913 src/blog.cr.tmp).each do |path|
      Classifier.classify(path).should eq Action::Ignore
    end
  end
end

describe AzuCLI::DevServer::Batcher do
  it "releases nothing before the files have been quiet for the debounce time" do
    start = Time.instant
    batcher = Batcher.new(300.milliseconds)
    batcher.add(["src/a.cr"], start)

    batcher.take(start + 100.milliseconds).should be_nil
    batcher.take(start + 299.milliseconds).should be_nil
    batcher.pending?.should be_true
  end

  it "releases one plan for a burst of changes and starts over" do
    start = Time.instant
    batcher = Batcher.new(300.milliseconds)
    batcher.add(["src/b.cr"], start)
    batcher.add(["src/a.cr", "public/templates/x.jinja"], start + 200.milliseconds)

    batcher.take(start + 400.milliseconds).should be_nil # 200 ms after the last change: still debouncing
    plan = batcher.take(start + 500.milliseconds).not_nil!

    plan.action.should eq Action::Rebuild
    plan.files.should eq ["public/templates/x.jinja", "src/a.cr", "src/b.cr"]
    batcher.pending?.should be_false
    batcher.take(start + 10.seconds).should be_nil
  end

  it "asks for the strongest action: a rebuild beats a restart beats templates" do
    start = Time.instant
    batcher = Batcher.new(0.milliseconds)
    batcher.add(["public/templates/x.jinja"], start)
    batcher.take(start).not_nil!.action.should eq Action::Templates

    batcher.add(["public/templates/x.jinja", ".env"], start)
    batcher.take(start).not_nil!.action.should eq Action::Restart

    batcher.add([".env", "src/a.cr"], start)
    batcher.take(start).not_nil!.action.should eq Action::Rebuild
  end

  it "does not count ignored files, so editor temp files never trigger anything" do
    start = Time.instant
    batcher = Batcher.new(0.milliseconds)
    batcher.add(["src/.a.cr.swp", "README.md"], start)

    batcher.pending?.should be_false
    batcher.take(start + 1.second).should be_nil
  end
end
