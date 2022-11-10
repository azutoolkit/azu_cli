module AzuCLI
  class Dev
    include Command
    DESCRIPTION = <<-DESC
    #{bold "Azu - Dev"} - Runs and recompiles project
    
      Runs your application locally, watches for files changes and runs your 
      app in the background 

      #{underline "Note"}
      
      Must have targets define in your `shard.yml`

      Eg.
        targets:
          azu: 
            main: ./src/azu_cli.cr
    DESC

    option prod : Bool, "--production", "-p", "Production release", true
    option run_args : String, "--args arg1 arg2", "-a arg1 arg2", "A list of arguments", ""

    def run
      puts "Starting server #{project_name}..."

      ProcessRunner.new(
        project_name,
        "shards",
        run_command,
        ["build", "#{project_name}"],
        [""],
        files, install_shards: false).run
    rescue ex
      error "Error starting server."
      error ex.message.to_s
      error ex.cause.to_s
      exit 1
    end

    def files
      ["./src/**/*.cr", "./lib/**/*.cr"]
    end

    def run_command
      "./bin/#{project_name}"
    end
  end
end
