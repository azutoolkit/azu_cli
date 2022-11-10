module AzuCLI
  module Command
    include Topia::Plugin
    include Opts

    abstract def run

    PROGRAM = self.name.split("::").last
    VERSION = Shard.git_description.split(/\s+/, 2).last
    USAGE   = <<-EOF

    {description}
    
    #{bold :Usage}
    
      #{light_blue :azu} {{program}} {{args}}

    #{bold :Options}
    
    {options}

    {version}
    EOF

    getter project_name : String { shard.as_h["name"].as_s }

    macro included
      macro finished
        option help : Bool, "--help", "Show this help", false
        option version : Bool, "--version", "Print the version and exit", false
      end

      def run(input, args)
        die "Invalid number of arguments" if args.empty? && !ARGS.empty?
        run(args)
        run
        true
      rescue e
        error "#{PROGRAM} command failed! - #{e.message}"
        exit 1
      end

      def show_usage
        USAGE.gsub(/{version}/, show_version)
          .gsub(/{program}/, PROGRAM.downcase)
          .gsub(/{description}/, DESCRIPTION)
          .gsub(/{args}/, ARGS)
          .gsub(/{options}/, new_option_parser.to_s)
      end

      def on(event : String)
      end

      def not_exists?(path)
        if File.exists? path
          error "File `#{path.underscore}` already exists"
          exit 1
        else
          yield
        end
      end

      def shard(path = "./shard.yml")
        contents = File.read(path)
        YAML.parse contents
      end
    end
  end
end
