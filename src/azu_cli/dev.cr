module AzuCLI
  class Dev
    include Builder
    SHARD_FILE = "./shard.yml"

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

    option build : Bool, "--build-only", "-b", "Builds project", false

    getter server : Process? = nil

    def run
      if build
        announce "Building..."
        `shard build`
        success "Build complete!"
      else
        run_dev server
      end
    end

    def run_dev(server)
      name, target = params

      if server.is_a? Process
        unless server.terminated?
          announce "🤖 Starting #{name}... \n\n"
          server.signal(:kill)
          server.wait
        end
      end

      announce "🤖 Starting erver #{name}... \n\n"
      @server = create_process target
    rescue ex
      error "Error starting server."
      error ex.message.to_s
      error ex.cause.to_s
      exit 1
    end

    def params
      error "No ./shards.yml in path" unless File.exists?(SHARD_FILE)

      file_contents = File.read(SHARD_FILE)
      shard = YAML.parse file_contents

      name = shard["name"]
      target = shard["targets"][name]["main"]

      {name, target}
    end

    def create_process(target)
      Process.new(
        command: "crystal #{target}",
        shell: true,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit)
    end
  end
end
