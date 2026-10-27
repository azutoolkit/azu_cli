require "../ui"

module AzuCLI
  module Commands
    # The `azu new` wizard: one step per flag of `azu new`, a review of what will happen, and the same choices as a
    # command line. It only reads and writes the command's options; `New` does the work.
    class NewWizard
      LICENSES = ["MIT", "Apache-2.0", "GPL-3.0", "BSD-3-Clause", "ISC"]

      getter screen : UI::Wizard

      def initialize(@command : New)
        @module_step = UI::TextStep.new("Module", "The Crystal module your code lives in (PascalCase)", command.module_name.presence || New.module_name_for(command.project_name),
          validate: ->(value : String) { value.matches?(/\A[A-Z][A-Za-z0-9]*\z/) ? nil : "Start with a capital letter; letters and digits only" })
        @author_step = UI::TextStep.new("Author", "Your name, for shard.yml and the LICENSE", command.author.presence || New.git_config("user.name") || "")
        @email_step = UI::TextStep.new("Email", "Your email, for shard.yml", command.email.presence || New.git_config("user.email") || "")
        @license_step = UI::ChoiceStep.new("License", "Which license does the project use?", LICENSES.map { |name| UI::Option.new(name, name) }, command.license)
        @type_step = UI::ChoiceStep.new("Type", "What are you building?", [
          UI::Option.new("web", "web", "pages + JSON", "Endpoints that render Jinja pages and JSON, with Spark live views, sessions and CSRF."),
          UI::Option.new("api", "api", "JSON only", "Endpoints that answer JSON: no templates, no static files."),
          UI::Option.new("cli", "cli", "a command", "A command-line program: no server, no database setup."),
        ], command.project_type)
        @database_step = UI::ChoiceStep.new("Database", "Where does CQL keep your data?", [
          UI::Option.new("sqlite", "SQLite", "a file, no server", "A file in the project: nothing to install or run."),
          UI::Option.new("postgresql", "PostgreSQL", "needs a server", "azu db:setup needs a running PostgreSQL; DATABASE_URL goes into .env.development."),
          UI::Option.new("mysql", "MySQL", "needs a server", "azu db:setup needs a running MySQL; DATABASE_URL goes into .env.development."),
        ], command.database, skip: -> { cli? })
        @tests_step = UI::ChoiceStep.new("Tests", "Which test framework?", [
          UI::Option.new("spec", "spec", "Crystal's built-in"),
          UI::Option.new("minitest", "minitest", "minitest.cr"),
        ], command.test_framework)
        @jobs_step = UI::ChoiceStep.new("Jobs", "Background jobs?", [
          UI::Option.new("joobq", "JoobQ", "Redis-backed queues", "Adds config/jobs.yml, an initializer and src/worker.cr; run workers with azu jobs:worker."),
          UI::Option.new("none", "None", "no queue"),
        ], command.include_joobq ? "joobq" : "none", skip: -> { cli? })
        @extras_step = UI::ToggleStep.new("Extras", "Space switches an option on or off", [
          UI::Toggle.new("docker", "Docker", "Dockerfile (web, api)", command.docker_support),
          UI::Toggle.new("ci", "GitHub Actions", "CI workflow", command.ci_setup != "None"),
          UI::Toggle.new("git", "Git", "init + first commit", command.git_init),
          UI::Toggle.new("example", "Example code", "a sample endpoint", command.include_example),
        ])
        steps = [@module_step, @author_step, @email_step, @license_step, @type_step, @database_step, @tests_step, @jobs_step, @extras_step] of UI::Step
        @screen = UI::Wizard.new("new", command.project_name, steps, plan: -> { plan }, command: -> { apply; command_line })
      end

      private def cli? : Bool
        @type_step.value == "cli"
      end

      # Copies the answers onto the command.
      def apply : Nil
        @command.module_name = @module_step.value
        @command.author = @author_step.value
        @command.email = @email_step.value
        @command.license = @license_step.value
        @command.project_type = @type_step.value
        @command.database = cli? ? "sqlite" : @database_step.value
        @command.test_framework = @tests_step.value
        @command.include_joobq = !cli? && @jobs_step.value == "joobq"
        @command.docker_support = !cli? && @extras_step.on?("docker")
        @command.ci_setup = @extras_step.on?("ci") ? "GitHub Actions" : "None"
        @command.git_init = @extras_step.on?("git")
        @command.include_example = @extras_step.on?("example")
      end

      # The same project as one `azu new` command.
      def command_line : String
        c = @command
        args = ["azu", "new", c.project_name, "--module", c.module_name]
        args.concat(["--author", c.author]) unless c.author.empty?
        args.concat(["--email", c.email]) unless c.email.empty?
        args.concat(["--license", c.license, "--type", c.project_type, "--db", c.database, "--test", c.test_framework])
        args.concat(c.ci_setup == "None" ? ["--no-ci"] : ["--ci", c.ci_setup])
        args << (c.docker_support ? "--docker" : "--no-docker")
        args << (c.git_init ? "--git" : "--no-git")
        args << (c.include_example ? "--example" : "--no-example")
        args << (c.include_joobq ? "--joobq" : "--no-joobq")
        args << "--yes"
        args.map { |arg| Process.quote(arg) }.join(' ')
      end

      private def plan : Array(Array(UI::Seg))
        apply
        c = @command
        lines = [] of Array(UI::Seg)
        number = 0
        step = ->(text : String) { number += 1; lines << [UI::Seg["#{number}  ", UI::Token::Purple], UI::Seg[text]] }
        step.call("Write the project into ./#{c.project_name}")
        step.call(".env with fresh secrets (0600)") unless c.project_type == "cli"
        step.call("git init, first commit") if c.git_init
        step.call("shards install")
        step.call("Type-check src/#{c.main_file}")
        lines << [] of UI::Seg
        lines << [UI::Seg["Needs on this machine", UI::Token::Muted]]
        tools = ["crystal", "shards"]
        tools << "git" if c.git_init
        tools.each do |tool|
          found = Process.find_executable(tool)
          lines << (found ? [UI::Seg["✔ ", UI::Token::Green], UI::Seg[tool]] : [UI::Seg["▲ #{tool} not found on PATH", UI::Token::Amber]])
        end
        if hint = c.database_hint
          lines << [UI::Seg["▲ ", UI::Token::Amber], UI::Seg[hint, UI::Token::Muted]]
        end
        lines
      end
    end
  end
end
