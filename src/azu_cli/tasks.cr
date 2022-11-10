module AzuCLI
  class Tasks
    include Command

    PATH        = "./tasks/taskfile.cr"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Topia Taskfile"} - Generates a Taskfile
    
      Creates a tasks taskfile is placed in ./tasks/taskfile.cr
      
      Leverage tasks to automate mundane, repetitive tasks and compose them into 
      efficient automated pipelines and workflows using `pipes`.

      Docs: https://github.com/azutoolkit/topia

      #{underline :Example}
      
        Topia.task("customtask")
          .command("mkdir -p ./hello_world")
          .pipe(ExampePipe.new) 
    
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

    option task : String, "--task Task", "-t Task", "Runs a specific task", ""

    def run
      if task.size > 0
        `crystal #{PATH} -- -r #{task}`
      else
        not_exists? PATH do
          announce "Creating task file!"
          `mkdir -p ./tasks`
          create_tasks_file!
          success "Created taskfile #{PATH}!"
        end
      end
    end

    private def create_tasks_file!
      File.open(PATH, "w") do |file|
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
        # Wire your tasks here
        #
        # Example:
        #
        # Topia.task("customtask")
        #   .command("mkdir -p ./hello_world")
        #   .pipe(ExampePipe.new) 

        def run
          if ARGV.size > 0
            task, command = ARGV.first, ARGV[1..-1]
            Topia.run(task, command)
          else
            Topia.run("azu", ["--help"])
          end
        end

        run
        CONTENT
      end
    end
  end
end
