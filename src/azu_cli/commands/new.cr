require "./base"
require "option_parser"
require "readline"
require "../ui"

module AzuCLI
  module Commands
    # New command for creating new Azu projects
    class New < Base
      # Configuration properties
      property project_name : String = ""
      property module_name : String = ""
      property author : String = ""
      property email : String = ""
      property license : String = "MIT"
      property project_type : String = "web"
      # SQLite needs no server: `azu new blog && cd blog && azu db:setup && azu serve` works on a fresh machine
      property database : String = "sqlite"
      property test_framework : String = "spec"
      property ci_setup : String = "GitHub Actions"
      property docker_support : Bool = false
      property git_init : Bool = true
      property include_example : Bool = true
      property include_joobq : Bool = true
      property non_interactive : Bool = false
      # rich, plain or json; nil decides from the terminal (`AZU_UI` is the same as an environment variable).
      property ui_mode : String? = nil
      @ui : UI::Reporter?
      @wizard_ran = false

      def initialize
        super("new", "Create a new Azu project")
      end

      # Override parse_args to also trigger custom parsing
      def parse_args(args : Array(String))
        super(args)
        parse_arguments
      end

      def execute : Result
        parse_arguments
        if (mode = @ui_mode) && !UI::Reporter::MODES.includes?(mode)
          return usage_error("--ui must be one of: #{UI::Reporter::MODES.join(", ")}")
        end

        # Set project name from argument if not set by flag
        if @project_name.empty?
          if name = get_arg(0)
            @project_name = name
          else
            return error("Project name is required. Usage: azu new <project-name> [options]")
          end
        end

        # Validate project name
        unless valid_project_name?(@project_name)
          error_msg = "Invalid project name '#{@project_name}'.\n"
          error_msg += "  Project names must:\n"
          error_msg += "  • Start with a letter (not a number)\n"
          error_msg += "  • Contain only letters, numbers, underscores, and hyphens\n"
          error_msg += "  • Not be a Crystal reserved word (e.g., class, module, def)\n"
          error_msg += "  • Be convertible to a valid Crystal module name\n"
          error_msg += "\n  Example: my_app, blog, web_service"
          return error(error_msg)
        end

        # Check if directory already exists
        if Dir.exists?(@project_name)
          return error("Directory '#{@project_name}' already exists. Choose a different name.")
        end

        # Show welcome message (the wizard has its own title bar; JSON output carries events only)
        Logger.announce("Creating new Azu project: #{@project_name}") if plain_output? && !wizard?

        # Gather configuration (interactive or from flags)
        unless gather_configuration
          return Result.error("Cancelled: nothing was written")
        end

        if message = delivery_error
          return usage_error(message)
        end

        # Show configuration summary
        show_configuration_summary

        ui.group("Compilation Progress") do
          generate_project
          post_generation_tasks
        end

        # Show success message
        show_success_message

        success("Project '#{@project_name}' created successfully")
      end

      private def parse_arguments
        OptionParser.parse(get_args) do |parser|
          parser.banner = "Usage: azu new <project-name> [options]"

          parser.on("--name NAME", "Project name") { |name| @project_name = name }
          parser.on("--module MODULE", "Module name (PascalCase)") { |mod| @module_name = mod }
          parser.on("--author AUTHOR", "Author name") { |author| @author = author }
          parser.on("--email EMAIL", "Author email") { |email| @email = email }
          parser.on("--license LICENSE", "License (MIT, Apache-2.0, GPL-3.0, etc.)") { |license| @license = license }
          parser.on("--type TYPE", "Project type (web, api, cli)") { |type| @project_type = type }
          parser.on("--api", "Create API project (shorthand for --type api)") { @project_type = "api" }
          parser.on("--db DATABASE", "Database adapter (postgresql, mysql, sqlite)") { |db| @database = db }
          parser.on("--test TEST", "Test framework (spec, minitest)") { |test| @test_framework = test }
          parser.on("--ci CI", "CI setup (\"GitHub Actions\" or \"None\")") { |ci| @ci_setup = ci }
          parser.on("--no-ci", "Skip the CI workflow") { @ci_setup = "None" }
          parser.on("--docker", "Include Docker support") { @docker_support = true }
          parser.on("--no-docker", "Skip Docker support") { @docker_support = false }
          parser.on("--git", "Initialize Git repository") { @git_init = true }
          parser.on("--no-git", "Skip Git initialization") { @git_init = false }
          parser.on("--example", "Include example code") { @include_example = true }
          parser.on("--no-example", "Skip example code") { @include_example = false }
          parser.on("--joobq", "Include JoobQ for background jobs") { @include_joobq = true }
          parser.on("--no-joobq", "Skip JoobQ integration") { @include_joobq = false }
          parser.on("--yes", "Non-interactive mode (use defaults)") { @non_interactive = true }
          parser.on("--ui MODE", "Output: rich, plain or json (default: rich on a terminal)") { |mode| @ui_mode = mode }
          parser.on("--help", "Show help") {
            puts parser
            exit(0)
          }
        end
      end

      # False when the wizard was cancelled.
      private def gather_configuration : Bool
        if @non_interactive
          # Use defaults or provided flags
          set_defaults
        elsif wizard?
          return false unless run_wizard
        else
          # Interactive prompts
          interactive_configuration
        end

        # Set module name if not provided
        if @module_name.empty?
          @module_name = self.class.module_name_for(@project_name)
        end
        true
      end

      def self.module_name_for(project_name : String) : String
        project_name.split(/[-_]/).map(&.capitalize).join
      end

      def self.git_config(key : String) : String?
        new.get_git_config(key)
      end

      # The progress reporter: a live card on a terminal, lines on a pipe, NDJSON with --ui json.
      def ui : UI::Reporter
        @ui ||= UI::Reporter.build(@ui_mode, stdout)
      end

      def ui=(reporter : UI::Reporter)
        @ui = reporter
      end

      private def plain_output? : Bool
        ui.is_a?(UI::Plain)
      end

      # The wizard runs when the prompts would: rich output and a keyboard on the other end.
      private def wizard? : Bool
        !@non_interactive && ui.rich? && STDIN.tty? && ui.as(UI::Rich).terminal.interactive?
      end

      private def run_wizard : Bool
        wizard = NewWizard.new(self)
        terminal = ui.as(UI::Rich).terminal
        UI::Program.new(wizard.screen, terminal, UI::InlineRenderer.new(terminal.output, terminal.theme.color?)).run
        return false unless wizard.screen.outcome.confirmed?

        wizard.apply
        @wizard_ran = true
        true
      end

      private def set_defaults
        @author = get_git_config("user.name") || "Your Name" if @author.empty?
        @email = get_git_config("user.email") || "your.email@example.com" if @email.empty?
      end

      private def interactive_configuration
        puts
        Logger.info("Please provide the following information:")
        puts

        # Project name (already set)
        Logger.step(1, 9, "Project name: #{@project_name}")

        # Module name
        if @module_name.empty?
          default_module = @project_name.split(/[-_]/).map(&.capitalize).join
          @module_name = prompt_with_default("Module name (PascalCase)", default_module)
        end
        Logger.step(2, 9, "Module name: #{@module_name}")

        # Author
        if @author.empty?
          default_author = get_git_config("user.name") || ""
          @author = prompt_with_default("Author name", default_author)
        end
        Logger.step(3, 9, "Author: #{@author}")

        # Email
        if @email.empty?
          default_email = get_git_config("user.email") || ""
          @email = prompt_with_default("Author email", default_email)
        end
        Logger.step(4, 9, "Email: #{@email}")

        # License
        @license = prompt_choice("License", ["MIT", "Apache-2.0", "GPL-3.0", "BSD-3-Clause", "ISC"], @license)
        Logger.step(5, 9, "License: #{@license}")

        # Project type
        @project_type = prompt_choice("Project type", PROJECT_TYPES, @project_type)
        Logger.step(6, 9, "Project type: #{@project_type}")

        # Database (a cli project has none)
        unless @project_type == "cli"
          @database = prompt_choice("Database adapter", ["postgresql", "mysql", "sqlite"], @database)
          Logger.step(7, 9, "Database: #{@database}")
        end

        # Test framework
        @test_framework = prompt_choice("Test framework", ["spec", "minitest"], @test_framework)

        # CI setup
        @ci_setup = prompt_choice("CI setup", AzuCLI::Generate::Project::CI_SETUPS, @ci_setup)

        # Boolean options
        @docker_support = prompt_boolean("Include Docker support?", @docker_support)
        @git_init = prompt_boolean("Initialize Git repository?", @git_init)
        @include_example = prompt_boolean("Include example #{get_example_description}?", @include_example)

        # Ask about background jobs (only for web/api projects)
        unless @project_type == "cli"
          @include_joobq = prompt_boolean("Include JoobQ for background job processing?", @include_joobq)
        end

        Logger.step(8, 9, "Additional options configured")
        Logger.step(9, 9, "Configuration complete")
      end

      private def prompt_with_default(question : String, default : String) : String
        prompt_text = default.empty? ? "#{question}: " : "#{question} [#{default}]: "
        Logger.prompt(prompt_text)

        response = Readline.readline("", false)
        return default if response.nil? || response.strip.empty?
        response.strip
      end

      private def prompt_choice(question : String, choices : Array(String), default : String) : String
        puts
        Logger.prompt("#{question}:")
        choices.each_with_index do |choice, _|
          marker = choice == default ? "●" : "○"
          puts "  #{marker} #{choice}"
        end

        print "Select (#{choices.join("/")}) [#{default}]: "
        response = Readline.readline("", false)

        return default if response.nil? || response.strip.empty?

        selected = response.strip.downcase
        choice = choices.find(&.downcase.starts_with?(selected))
        choice || default
      end

      private def prompt_boolean(question : String, default : Bool) : Bool
        default_text = default ? "Y/n" : "y/N"
        Logger.prompt("#{question} (#{default_text}): ")

        response = Readline.readline("", false)
        return default if response.nil? || response.strip.empty?

        response = response.strip.downcase
        case response
        when "y", "yes", "true", "1"
          true
        when "n", "no", "false", "0"
          false
        else
          default
        end
      end

      private def get_example_description : String
        case @project_type
        when "web"
          "endpoint"
        when "api"
          "API endpoint"
        when "cli"
          "command"
        else
          "code"
        end
      end

      def get_git_config(key : String) : String?
        # Validate key to prevent shell injection - only allow safe git config keys
        unless key.matches?(/^[a-z][a-z0-9.\-]*$/i)
          Logger.debug("Invalid git config key format: #{key}")
          return nil
        end

        # Use Process.run for safer execution
        process = Process.new("git", ["config", "--global", key], output: Process::Redirect::Pipe, error: Process::Redirect::Close)
        output = process.output.gets_to_end.strip
        process.wait
        output.empty? ? nil : output
      rescue ex : Exception
        Logger.debug("Failed to get git config #{key}: #{ex.message}")
        nil
      end

      # Crystal reserved words that cannot be used as project names
      CRYSTAL_RESERVED_WORDS = %w[
        abstract alias annotation as asm begin break case class def do else elsif end ensure enum
        extend false for fun if include instance_sizeof is_a? lib macro module next nil of out
        pointerof private protected require rescue responds_to? return select self sizeof struct
        super then true type typeof union uninitialized unless until verbatim when while with yield
      ]

      private def valid_project_name?(name : String) : Bool
        return false if name.empty?

        # Project name must start with a letter
        return false unless name[0].ascii_letter?

        # Must not start or end with hyphen or underscore
        return false if name.starts_with?("-") || name.ends_with?("-")
        return false if name.starts_with?("_") || name.ends_with?("_")

        # Must contain only valid characters
        return false unless name.matches?(/^[a-zA-Z][a-zA-Z0-9_-]*$/)

        # Cannot be a Crystal reserved word
        return false if CRYSTAL_RESERVED_WORDS.includes?(name.downcase)

        # Module name (derived from project name) must also be valid
        module_name = name.split(/[-_]/).map(&.capitalize).join
        return false unless module_name.matches?(/^[A-Z][a-zA-Z0-9]*$/)
        return false if CRYSTAL_RESERVED_WORDS.includes?(module_name.downcase)

        true
      end

      private def show_configuration_summary
        return if @wizard_ran # its review screen is the summary, and it stays on screen

        rows = [
          {"Project", "#{@project_name} · module #{@module_name}"},
          {"Author", "#{@author} <#{@email}>"},
          {"License", @license},
          {"Type", @project_type},
          {"Tests", @test_framework},
          {"CI", @ci_setup},
          {"Docker", @docker_support ? "yes" : "no"},
          {"Git", @git_init ? "init + first commit" : "no"},
          {"Example", @include_example ? "yes" : "no"},
        ]
        unless @project_type == "cli" # a cli project has no database and no jobs
          rows.insert(4, {"Database", @database})
          rows << {"Jobs", @include_joobq ? "JoobQ" : "none"}
        end
        ui.panel("Project", rows.map { |(label, value)| [UI::Seg[label.ljust(10), UI::Token::Muted], UI::Seg[value]] })
      end

      PROJECT_TYPES = ["web", "api", "cli"]
      # The adapters Generate::Project knows, with the aliases it accepts
      DATABASES = ["sqlite", "sqlite3", "postgresql", "postgres", "pg", "mysql"]

      private def delivery_error : String?
        unless PROJECT_TYPES.includes?(@project_type)
          return "Unknown project type '#{@project_type}'. Choose one of: #{PROJECT_TYPES.join(", ")}."
        end
        unless @project_type == "cli" || DATABASES.includes?(@database)
          return "Unknown database adapter '#{@database}'. Choose one of: sqlite, postgresql, mysql."
        end
        unless AzuCLI::Generate::Project::CI_SETUPS.includes?(@ci_setup)
          return "Unknown CI setup '#{@ci_setup}'. Choose one of: #{AzuCLI::Generate::Project::CI_SETUPS.join(", ")}."
        end
        "--docker is for web and api projects; a cli project has no server to run in a container." if @docker_support && @project_type == "cli"
      end

      private def generate_project
        ui.task("Files") do |task|
          # Create the generator
          generator = AzuCLI::Generate::Project.new(
            project: @project_name,
            module_name: @module_name,
            author: @author,
            email: @email,
            license: @license,
            project_type: @project_type,
            database: @database,
            test_framework: @test_framework,
            ci_setup: @ci_setup,
            docker_support: @docker_support,
            git_init: @git_init,
            include_example: @include_example,
            include_joobq: @include_joobq,
            env: "development"
          )

          # Generate the project in the target directory
          # The directory is closed to others while the files are written, so the .env (secrets) is never briefly
          # readable; it is opened up afterwards like any project directory.
          Dir.mkdir_p(@project_name, 0o700)
          generator.render(@project_name, force: false, interactive: false, list: false, color: true)
          File.chmod(@project_name, 0o755)

          # Remove JoobQ files if not included
          unless @include_joobq
            remove_joobq_files
          end
          task.finish(detail: "#{count_files(@project_name)} written into ./#{@project_name}")
        end

        env_file = File.join(@project_name, ".env")
        if File.exists?(env_file)
          ui.task("Secrets") do |task|
            File.chmod(env_file, 0o600) # it holds the generated secrets
            names = File.read_lines(env_file).compact_map { |line| line.split('=', 2).first.strip if line.includes?("_SECRET=") }
            task.finish(detail: ".env (0600)#{names.empty? ? "" : " · #{names.join(", ")}"}")
          end
        end
      end

      private def count_files(directory : String) : Int32
        Dir.glob(File.join(directory, "**", "*"), match: File::MatchOptions::DotFiles).count { |path| File.file?(path) }
      end

      private def remove_joobq_files
        Dir.cd(@project_name) do
          # Remove JoobQ-related files
          File.delete("config/jobs.yml") if File.exists?("config/jobs.yml")
          File.delete("src/initializers/joobq.cr") if File.exists?("src/initializers/joobq.cr")
          File.delete("src/worker.cr") if File.exists?("src/worker.cr")

          # Remove jobs directory if it exists and is empty
          if Dir.exists?("src/jobs")
            begin
              Dir.children("src/jobs").each do |file|
                File.delete(File.join("src/jobs", file))
              end
              Dir.delete("src/jobs")
            rescue
              # Directory not empty or other error - skip
            end
          end
        rescue ex
          # Silently ignore errors - files may not exist
        end
      end

      private def post_generation_tasks
        Dir.cd(@project_name) do
          ui.task("Git", "init + first commit") do |task|
            next task.skip("--no-git") unless @git_init
            next task.fail("git not found on PATH") unless Process.find_executable("git")

            ok = run_quiet("git", ["init"]) && run_quiet("git", ["add", "."]) &&
                 run_quiet("git", ["commit", "-m", "Initial commit"])
            ok ? task.finish(detail: "init + 1 commit") : task.fail("git commit failed (is user.name set?)")
          end

          shards_ok = ui.task("Shards", "install") { |task| install_shards(task) }
          ui.warn("Failed to install dependencies. Run 'shards install' manually.") unless shards_ok

          ui.task("Type-check", "crystal build --no-codegen") do |task|
            next task.skip("needs the shards") unless shards_ok

            output = IO::Memory.new
            status = Process.run("crystal", ["build", "src/#{main_file}", "--no-codegen"], output: output, error: output)
            if status.success?
              task.finish(detail: "src/#{main_file}")
            else
              task.fail("src/#{main_file} does not compile")
              ui.warn("Project may have compilation issues. Check with 'crystal build'.")
              output.to_s.lines.last(8).each { |line| ui.note("  #{line}") }
            end
          rescue IO::Error
            task.fail("crystal not found on PATH")
          end
        end
      end

      # `shards install`, counting the shards as they install; true when it succeeds.
      private def install_shards(task : UI::Task) : Bool
        reader, writer = IO.pipe
        process = Process.new("shards", ["install"], output: writer, error: writer)
        writer.close
        installed = 0
        tail = [] of String
        reader.each_line do |line|
          tail = (tail << line).last(8)
          if line.includes?("Installing")
            installed += 1
            task.progress(installed)
          end
          task.note = line.sub(/\AI: /, "").strip if line.starts_with?("I: ") || line.includes?("Fetching")
        end
        status = process.wait
        if status.success?
          task.finish(detail: "#{installed} installed")
        else
          task.fail("shards install failed")
          tail.each { |line| ui.note("  #{line}") }
        end
        status.success?
      rescue IO::Error
        task.fail("shards not found on PATH")
        false
      end

      private def run_quiet(command : String, args : Array(String)) : Bool
        Process.run(command, args, output: Process::Redirect::Close, error: Process::Redirect::Close).success?
      rescue IO::Error
        false
      end

      def main_file : String
        case @project_type
        when "web"
          "server.cr"
        when "api"
          "api.cr"
        when "cli"
          "#{@project_name}.cr"
        else
          "server.cr"
        end
      end

      # What to run after `azu new`, in order. `azu db:setup` creates the database and runs the migrations, so it
      # works on a fresh project; the app listens on azu's default port, the PORT of the generated .env.
      def next_steps : Array(String)
        return ["cd #{@project_name}", "shards build", "./bin/#{@project_name.downcase.gsub(/[^a-z0-9_]/, "_")} --help"] if @project_type == "cli"

        url = "http://localhost:#{AzuCLI::Config::Ports::DEV_SERVER}"
        steps = ["cd #{@project_name}", "azu db:setup", "azu serve"]
        steps << (@project_type == "api" ? "Test: curl #{url}/health" : "Visit: #{url}")
        steps << "Start background workers: azu jobs:worker" if @include_joobq
        steps
      end

      # A database with a server has to be running before `azu db:setup`; SQLite is a file the command creates
      def database_hint : String?
        return if @project_type == "cli" || @database.starts_with?("sqlite")
        "azu db:setup needs a running #{@database} server: DATABASE_URL is in .env.development"
      end

      private def show_success_message
        lines = [] of Array(UI::Seg)
        next_steps.each do |step|
          if step.includes?(": ")
            label, value = step.split(": ", 2)
            lines << [UI::Seg["  #{label}: ", UI::Token::Muted], UI::Seg[value, UI::Token::Blue]]
          else
            lines << [UI::Seg["  $ ", UI::Token::Muted], UI::Seg[step]]
          end
        end
        database_hint.try { |hint| lines << [UI::Seg["  ▲ #{hint}", UI::Token::Amber]] }

        if @include_joobq && (@project_type == "web" || @project_type == "api")
          lines << [] of UI::Seg
          lines << [UI::Seg["JoobQ  ", UI::Token::Purple], UI::Seg["config/jobs.yml · src/initializers/joobq.cr · src/worker.cr", UI::Token::Muted]]
          lines << [UI::Seg["       azu generate job <name> [params]", UI::Token::Muted]]
        end
        unless @project_type == "cli"
          lines << [] of UI::Seg
          lines << [UI::Seg["▸ ", UI::Token::Purple], UI::Seg["Try  ", UI::Token::Muted], UI::Seg["azu g scaffold post title:string body:text", UI::Token::Text],
                    UI::Seg["  then watch azu dev rebuild", UI::Token::Muted]]
        end
        lines << [UI::Seg["Docs https://azutoolkit.org · Support https://github.com/azutoolkit/azu", UI::Token::Muted]]
        ui.panel("#{@project_name} is ready", lines, badge: "✔", tone: UI::Token::Green)
      end

      def show_help
        puts "Usage: azu new <project-name> [options]"
        puts
        puts "Create a new Azu project with the specified name."
        puts
        puts "Options:"
        puts "  --name NAME               Project name"
        puts "  --module MODULE           Module name (PascalCase)"
        puts "  --author AUTHOR           Author name"
        puts "  --email EMAIL             Author email"
        puts "  --license LICENSE         License (MIT, Apache-2.0, GPL-3.0, etc.)"
        puts "  --type TYPE               Project type (web, api, cli) [default: web]"
        puts "  --api                     Create API project (shorthand for --type api)"
        puts "  --db DATABASE             Database adapter (postgresql, mysql, sqlite) [default: sqlite]"
        puts "  --test TEST               Test framework (spec, minitest) [default: spec]"
        puts "  --ci CI                   CI setup (\"GitHub Actions\" or \"None\") [default: GitHub Actions]"
        puts "  --no-ci                   Skip the CI workflow"
        puts "  --docker                  Generate a Dockerfile and .dockerignore (web and api projects)"
        puts "  --no-docker               Skip Docker support"
        puts "  --git                     Initialize Git repository [default]"
        puts "  --no-git                  Skip Git initialization"
        puts "  --example                 Include example code [default]"
        puts "  --no-example              Skip example code"
        puts "  --joobq                   Include JoobQ for background jobs [default]"
        puts "  --no-joobq                Skip JoobQ integration"
        puts "  --yes                     Non-interactive mode (use defaults)"
        puts "  --ui MODE                 Output: rich (live cards, the default on a terminal), plain or json"
        puts "  --help                    Show this help message"
        puts
        puts "Interactive Examples:"
        puts "  azu new my_app            # The wizard (prompts when the terminal cannot run it)"
        puts "  azu new my_blog --type web"
        puts
        puts "Non-interactive Examples:"
        puts "  azu new my_api --type api --db postgresql --yes"
        puts "  azu new my_tool --type cli --no-docker --no-git --yes"
        puts "  azu new my_service --author \"John Doe\" --email john@example.com --license MIT --yes"
      end
    end
  end
end
