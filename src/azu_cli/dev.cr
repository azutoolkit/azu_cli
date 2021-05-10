module AzuCLI
  class Dev
    include Builder

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

    def run
      announce "Building..."
      `shards build`
      success "Build complete!"
    end
  end
end
