module AzuCLI
  class Dev
    include Helpers
    include Base
    DESCRIPTION = <<-DESC
    Azu - Dev
    
    Runs your application locally, watches for files changes and recompiles in
    the background using `shards build` command. 

    Note:
      - Must have targets define in your `shard.yml`

    Eg.
      targets:
        azu: 
          main: ./src/azu_cli.cr

    DESC

    option rim : Bool, "-r", "Show this help", false

    def run
      announce "Building..."
      `shards build`
      announce "Build complete!"
      true
    rescue
      error("Build failed!")
    end
  end
end
