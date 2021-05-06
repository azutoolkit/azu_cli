module AzuCLI
  class Tasks
    include Helpers
    include Base
    PATH        = "./tasks"
    DESCRIPTION = <<-DESC
    Azu - Topia Tasks
    
    Creates a tasks taskfile is placed in /tasks/taskfile.cr
    
    Leverage tasks to automate mundane, repetitive tasks and compose them into 
    efficient automated build pipelines and workflows.

    Docs: https://github.com/azutoolkit/topia

    Creating Tasks

      Example Task:
      
        task("customtask")
          .command("mkdir -p ./hello_world")
          .pipe(ExampePipe.new) 
      
      Example Pipe:
      
        class ExampePipe
          include AzuCLI::Base
        
          def run
            announce "Building..."
            # ... do somethong ...
            announce "Build complete!"
            true
          rescue
            error("Build failed!")
          end
        end
    DESC

    option task : String, "--t task", "Runs a specific task", ""

    def run
      if task.size > 0
        `crystal ./tasks/taskfile.cr -- -r #{task}`
      else
        path = "#{PATH}/taskfile.cr".downcase
        exists? path

        announce "Generating taskfile..."
        create_tasks_file path
        announce "Task file created!"
      end
      true
    rescue e
      error("Failed: #{e.message}")
      false
    end

    def create_tasks_file(path)
      File.open(path, "w") do |file|
        file.puts <<-CONTENT
        require "topia"
        module Tasks
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
          # Wrire your tasks here
          #
          # Example:
          #
          # task("customtask")
          #   .command("mkdir -p ./hello_world")
          #   .pipe(ExampePipe.new) 

          def self.run
            if ARGV.size > 0
              task, command = ARGV.first, ARGV[1..-1]
              Topia.run(task, command)
            else
              Topia.run("azu", ["--help"])
            end
          end
        end

        Tasks.run
        CONTENT
      end
    end
  end
end
