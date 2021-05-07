module AzuCLI
  module Base
    include Topia::Plugin
    include Opts
    include Helpers

    USAGE = <<-EOF

    {{description}}
    
    Usage: azu {{program}} {{args}}

    Options:
    {{options}}

    {{version}}
    EOF

    macro included
      PROGRAM = self.name.split("::").last
      VERSION = Shard.git_description.split(/\s+/, 2).last
      
      option help    : Bool  , "--help"   , "Show this help", false
      option version : Bool  , "--version", "Print the version and exit", false

      def run(input, params)
        die "Invalid number of arguments" if params.empty? && !ARGS.empty?
        run(params)
        run
        true
      rescue e
        error "#{PROGRAM} command failed! - #{e.message}"
        exit 1
      end

      def show_usage
        USAGE.gsub(/\{{version}}/, show_version)
          .gsub(/\{{program}}/, PROGRAM)
          .gsub(/\{{description}}/, DESCRIPTION)
          .gsub(/\{{args}}/, ARGS)
          .gsub(/\{{options}}/, new_option_parser.to_s)
      end

      def on(event : String)
      end
    end
  end
end
