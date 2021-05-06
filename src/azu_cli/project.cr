module AzuCLI
  class Project
    include Helpers
    include Base

    ARGS        = "[name]"
    DESCRIPTION = <<-DESC
    Azu - Project

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
      `mkdir -p #{Migration::PATH}` if clear

      announce "Adding tasks runner!"
      create_tasks_file(project, clear)

      announce "Installing shards and building CLI!"
      `shards build --ignore-crystal-version`

      true
    rescue e
      error("Initializing project failed! #{e.message}")
    end

    def create_tasks_file(project, clear)
      `mkdir -p ./tasks`

      File.open("./tasks/azu.cr".downcase, "w") do |file|
        file.puts <<-CONTENT
        #{%Q(require "clear") if clear}
        #{%Q(require ".#{Migration::PATH}/**") if clear}
        #{%q(require "azu_cli")}

        module Tasks
          include AzuCLI
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

        end

        Tasks.run
        CONTENT
      end
    end

    def add_shard(project, clear : Bool)
      project_path = "./#{project}/shard.yml"
      contents = File.read(project_path)
      yaml = YAML.parse contents
      shard = yaml.as_h

      @deps["dependencies"].delete("clear") unless clear
      result = shard.merge(@deps).to_yaml
      File.write(project_path, result)
    end
  end
end
