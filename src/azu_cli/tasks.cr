module AzuCLI
  class Tasks
    include Helpers
    include Base
    PATH        = "./tasks/taskfile.cr"
    DESCRIPTION = <<-DESC
    Azu - Topia Taskfile Generator
    
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
        `crystal #{PATH} -- -r #{task}`
      else
        if Dir[target].any?
          announce "File `#{PATH.underscore}` already exists"
        else
          create_tasks_file PATH
        end
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


        Topia.run
        CONTENT
      end
    end
  end
end
