module AzuCLI
  class Project
    include Builder

    ARGS        = "[name]"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Project Generator"}

      The `azu project` command generates a new Crystal application with Azu 
      installed and Clear ORM.
      
      Docs - https://azutopia.gitbook.io/azu/installation
    DESC

    @deps = {
      "targets" => {
        "azu" => {
          "main" => "./tasks/azu.cr",
        },
      },
      "dependencies" => {
        "azu" => {
          "github" => "azutoolkit/azu",
          "branch" => "master",
        },
        "clear" => {
          "github" => "anykeyh/clear",
          "branch" => "master",
        },
        "azu_cli" => {
          "github" => "azutoolkit/azu_cli",
          "branch" => "master",
        },
      },
    }

    option clear : Bool, "--clear", "Generates project with Clear Orm", true

    def run
      project = args.first.underscore

      announce "Scafolding Crystal App!"
      `crystal init app #{project}`

      announce "Adding required shards!"
      add_shard(project, clear)

      Dir.cd("./#{project}")

      announce "Defining project structure"
      `mkdir -p #{Migration::PATH}` if clear
      `mkdir -p ./src/requests`
      `mkdir -p ./src/responses`
      `mkdir -p ./src/models`
      `mkdir -p ./src/templates`
      `mkdir -p ./src/endpoints`

      announce "Adding Azu to main file!"
      main_cr_file(project, clear)

      # Create directories
      # plublic/templates
      announce "Adding tasks runner!"
      create_tasks_file(project, clear)

      announce "Installing shards and building CLI!"
      `shards build --ignore-crystal-version`

      announce "Formatting code"
      `crystal tool format`

      success "Project #{project.camelcase} created!"
      exit 1
    end

    def main_cr_file(project, clear)
      File.open("./src/#{project}.cr".downcase, "w") do |file|
        file.puts <<-CONTENT
        require "azu"
        #{%Q(require "clear") if clear}

        # Docs - https://azutopia.gitbook.io/azu/defining-your-app
        module #{project.camelcase}
          include Azu
          VERSION = "0.1.0"
          #{"# Clear Orm Docs - https://clear.gitbook.io/project/introduction/installation" if clear}
          #{%q(DATABASE_URL = ENV["DATABASE_URL"]) if clear}
          
          #{%Q(Clear::SQL.init(DATABASE_URL)) if clear}

          configure do |c|
            # Default HTML templates path
            c.templates.path = "public/templates"

            # Uncomment to enable Spark real time apps
            # Docs: https://azutopia.gitbook.io/azu/spark-1
            # c.router.ws "/live-view", Spark 

            # To Server static content
            c.router.get "/*", Handler::Static.new
          end
        end

        # Require files after initializing project module
        require "./requests/**"
        require "./responses/**"
        require "./models/**"
        require "./templates/**"
        require "./endpoints/**"

        # Start your server
        # Add Handlers to your App Server
        #{project.camelcase}.start [
          Azu::Handler::Rescuer.new,
          Azu::Handler::Logger.new,
        ]

        CONTENT
      end
    end

    def create_tasks_file(project, clear)
      `mkdir -p ./tasks`

      File.open("./tasks/azu.cr".downcase, "w") do |file|
        file.puts <<-CONTENT
        #{%Q(require "clear") if clear}
        #{%Q(require ".#{Migration::PATH}/**") if clear}
        #{%q(require "azu_cli")}

        # #{project.capitalize} Task Runner and Azu CLI
        #
        # This file allows you register custom tasks for your project
        # and run those tasks from Azu CLI.
        #
        # Plugins
        #
        # Create plugins build your custom workflows
        # 
        # Example Pipe:
        #
        # class ExampePipe
        #   include AzuCLI::Base
        #
        #   def run
        #     announce "Building..."
        #     # ... do somethong ...
        #     announce "Build complete!"
        #     true
        #   rescue
        #     error("Build failed!")
        #   end
        # end
        #
        #
        # Wrire your tasks here
        #
        # Example:
        #
        # task("customtask")
        #   .command("mkdir -p ./hello_world")
        #   .pipe(ExampePipe.new) 

        AzuCLI.run
        CONTENT
      end
    end

    def add_shard(project, clear : Bool)
      project_path = "./#{project}/shard.yml"
      shard = shard(project_path).as_h
      @deps["dependencies"].delete("clear") unless clear
      result = shard.merge(@deps).to_yaml
      File.write(project_path, result)
    end
  end
end
