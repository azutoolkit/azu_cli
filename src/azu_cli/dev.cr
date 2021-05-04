module AzuCLI
  class Dev
    include Topia::Plugin
    include Helpers

    getter spinner : Topia::Spinner = Topia::Spinner.new("Waiting...")

    def run(input, params)
      spinner.start("Building...")
      `shards build`
      spinner.success("Build complete!")
      true
    rescue
      spinner.error("Build failed!")
    end

    def on(event : String)
    end
  end
end