module AzuCLI
  class Project
    include Helpers
    include Base

    ARGS = "[name]"
    DESCRIPTION = <<-DESC
    Azu - Project

    The `azu project` command generates a new Crystal application with Azu 
    installed and Clear ORM.
    
    Docs - https://azutopia.gitbook.io/azu/installation
    DESC

    @deps = {
      "targets" => {
        "azu" => {
          "main" => "./tasks/azu.cr"
        }
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
      },
      "development_dependencies" => {
        "azu_cli" => {
          "path" => "azutoolkit/azu_cli",
        },
      },
    }

    option clear : Bool, "--clear", "Generates project with Clear Orm", false
    
    def run
      project = args.first.underscore
      `crystal init app #{project}`
      add_shard(project, clear)
      Dir.cd("./#{project}")
      `mkdir -p #{Migration::PATH}`
      `mkdir -p ./tasks`
      create_tasks_file(project, clear)
     `shards build --ignore-crystal-version`
      announce "Azu project initialized!"

      true
    rescue e
      error("Initializing project failed! #{e.message}")
    end

    def create_tasks_file(project,clear)
      File.open("./tasks/azu.cr".downcase, "w") do |file|
      file.puts <<-CONTENT
      #{if clear
      %q(require "azu_cli")
      %q(require "clear")
      %Q(require "#{Migration::PATH}")
      end}

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

    def add_shard(project, with_db : Bool)
      project_path = "./#{project}/shard.yml"
      contents = File.read(project_path)
      yaml = YAML.parse contents
      shard = yaml.as_h

      @deps["dependencies"].delete("clear") if with_db
      result = shard.merge(@deps).to_yaml

      File.write(project_path, result)
    end
  end
end
