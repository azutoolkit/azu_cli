require "../core/abstract_generator"

module AzuCLI::Generator
  class ChannelGenerator < Core::AbstractGenerator
    property events : Array(String)
    property with_auth : Bool
    property channel_type : String

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @events = extract_events(options)
      @with_auth = has_auth_flag?(options)
      @channel_type = options.custom_options["type"]? || "basic"
      super(name, project_name, options.force, options.skip_tests)
    end

    def generator_type : String
      "channel"
    end

    def generate_files : Nil
      generate_channel_file
    end

    def create_directories : Nil
      super
      file_strategy.create_directory("src/channels")
      file_strategy.create_directory("spec/channels") unless skip_tests
    end

    def generate_tests : Nil
      return if skip_tests
      test_variables = generate_test_variables
      create_file_from_template(
        "channel/channel_spec.cr.ecr",
        "spec/channels/#{snake_case_name}_spec.cr",
        test_variables,
        "channel test"
      )
    end

    private def generate_channel_file : Nil
      channel_variables = generate_channel_variables
      create_file_from_template(
        "channel/channel.cr.ecr",
        "src/channels/#{snake_case_name}.cr",
        channel_variables,
        "channel"
      )
    end

    private def generate_channel_variables : Hash(String, String)
      default_template_variables.merge({
        "event_handlers" => generate_event_handlers,
        "auth_methods" => generate_auth_methods,
        "channel_type" => @channel_type,
        "lifecycle_methods" => generate_lifecycle_methods,
      })
    end

    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "test_events" => generate_test_events,
        "channel_type" => @channel_type,
      })
    end

    private def extract_events(options : Core::GeneratorOptions) : Array(String)
      events = [] of String
      options.additional_args.each do |arg|
        if arg.starts_with?("event:")
          events << arg.split(":", 2)[1]
        end
      end
      events.empty? ? config.get_array("default_events") : events
    end

    private def has_auth_flag?(options : Core::GeneratorOptions) : Bool
      options.custom_options.has_key?("auth") ||
      options.additional_args.includes?("--auth")
    end

    private def generate_event_handlers : String
      lines = [] of String
      events.each do |event|
        lines << <<-CRYSTAL
        def on_#{event}(data)
          Log.info { "#{self.class.name}: #{event} event received" }
          # Handle #{event} event
          # data contains the event payload
        end
        CRYSTAL
      end
      lines.join("\n\n")
    end

    private def generate_auth_methods : String
      return "" unless with_auth

      <<-CRYSTAL

      def authorized?(token : String?) : Bool
        # TODO: Implement authorization logic
        return false unless token
        # Verify token and check permissions
        true
      end

      def current_user(token : String?)
        # TODO: Get user from token
        nil
      end
      CRYSTAL
    end

    private def generate_lifecycle_methods : String
      lifecycle_methods = config.get_array("lifecycle_methods")
      
      lines = [] of String
      lifecycle_methods.each do |method|
        lines << <<-CRYSTAL
        def #{method}
          Log.info { "#{self.class.name}: #{method}" }
          # Implement #{method} logic
        end
        CRYSTAL
      end
      lines.join("\n\n")
    end

    private def generate_test_events : String
      lines = [] of String
      events.each do |event|
        lines << <<-CRYSTAL
        it "handles #{event} event" do
          channel.on_#{event}({} of String => JSON::Any)
        end
        CRYSTAL
      end
      lines.join("\n\n")
    end

    def success_message : String
      base_message = super
      "#{base_message} with #{events.size} event(s)"
    end

    def post_generation_tasks : Nil
      super
      puts
      puts "📡 Channel Usage:".colorize(:yellow).bold
      puts "  1. Configure WebSocket routes in your application"
      puts "  2. Handle events: #{events.join(", ")}"
      puts "  3. Add authentication if needed" if with_auth
    end
  end
end