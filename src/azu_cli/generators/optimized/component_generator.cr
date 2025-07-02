require "../core/abstract_generator"

module AzuCLI::Generator
  # Optimized Component Generator following SOLID principles
  # Uses configuration-driven approach with Template Method pattern
  class ComponentGenerator < Core::AbstractGenerator
    property attributes : Hash(String, String)
    property events : Array(String)
    property with_websocket : Bool
    property component_type : String

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @attributes = options.attributes
      @events = extract_events(options)
      @with_websocket = has_websocket_flag?(options)
      @component_type = options.custom_options["type"]? || "interactive"
      super(name, project_name, options.force, options.skip_tests)
    end

    # Concrete implementation of abstract method
    def generator_type : String
      "component"
    end

    # Concrete implementation of abstract method
    def generate_files : Nil
      generate_component_file
    end

    # Override to add component-specific directory creation
    def create_directories : Nil
      super

      # Create component-specific directories from configuration
      component_dir = config.get("directories.source") || "src/components"
      file_strategy.create_directory(component_dir)

      unless skip_tests
        spec_dir = config.get("directories.spec") || "spec/components"
        file_strategy.create_directory(spec_dir)
      end
    end

    # Override to generate component tests
    def generate_tests : Nil
      return if skip_tests

      test_template = config.get("templates.spec") || "component/component_spec.cr.ecr"
      test_path = "spec/components/#{snake_case_name}_component_spec.cr"

      test_variables = generate_test_variables

      create_file_from_template(
        test_template,
        test_path,
        test_variables,
        "component test"
      )
    end

    # Generate the main component file
    private def generate_component_file : Nil
      template = config.get("templates.main") || "component/component.cr.ecr"
      output_path = "src/components/#{snake_case_name}_component.cr"

      component_variables = generate_component_variables

      create_file_from_template(
        template,
        output_path,
        component_variables,
        "component"
      )
    end

    # Generate template variables specific to components
    private def generate_component_variables : Hash(String, String)
      default_template_variables.merge({
        "attributes_list"   => generate_attributes_list,
        "events_list"       => generate_events_list,
        "websocket_methods" => generate_websocket_methods,
        "content_method"    => generate_content_method,
        "component_id"      => "#{snake_case_name}-\#{object_id}",
        "component_type"    => @component_type,
      })
    end

    # Generate test-specific template variables
    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "test_events"           => generate_test_events,
        "test_attributes"       => generate_test_attributes,
        "test_constructor_args" => generate_test_constructor_args,
        "component_type"        => @component_type,
      })
    end

    # Extract events from options
    private def extract_events(options : Core::GeneratorOptions) : Array(String)
      events = [] of String
      options.additional_args.each do |arg|
        if arg.starts_with?("event:")
          events << arg.split(":", 2)[1]
        end
      end
      events.empty? ? ["click"] : events
    end

    # Check for WebSocket flag
    private def has_websocket_flag?(options : Core::GeneratorOptions) : Bool
      options.custom_options.has_key?("websocket") ||
      options.custom_options.has_key?("ws") ||
      options.additional_args.includes?("--websocket") ||
      options.additional_args.includes?("realtime")
    end

    # Generate attributes list for constructor
    private def generate_attributes_list : String
      return "" if attributes.empty?

      constructor_params = attributes.map do |attr_name, attr_type|
        crystal_type_name = crystal_type(attr_type)
        "@#{attr_name} : #{crystal_type_name}"
      end.join(", ")

      "    def initialize(#{constructor_params})\n    end"
    end

    # Generate events list with handlers
    private def generate_events_list : String
      return generate_default_events if events.empty?

      lines = [] of String
      events.each do |event_name|
        lines << generate_event_handler(event_name)
      end

      lines.join("\n\n")
    end

    # Generate default events
    private def generate_default_events : String
      <<-CRYSTAL
      def on_event("click", data)
        # Handle click events
        # Example: update counter, toggle state, etc.
        Log.info { "#{self.class.name}: Click event received" }
      end
      CRYSTAL
    end

    # Generate event handler for specific event
    private def generate_event_handler(event_name : String) : String
      <<-CRYSTAL
      def on_event("#{event_name}", data)
        # Handle #{event_name} event
        # data contains event payload from client
        Log.info { "#{self.class.name}: #{event_name.capitalize} event received" }

        # Example DOM updates:
        # update_element "status", "#{event_name.capitalize} clicked!"
        # broadcast_update({type: "#{event_name}", component: "#{snake_case_name}"})
      end
      CRYSTAL
    end

    # Generate WebSocket methods if enabled
    private def generate_websocket_methods : String
      return "" unless with_websocket

      <<-CRYSTAL

      # WebSocket lifecycle methods
      def on_mount
        Log.info { "#{self.class.name} mounted" }
        # Initialize component state, load data, etc.
      end

      def on_unmount
        Log.info { "#{self.class.name} unmounted" }
        # Cleanup resources, unsubscribe from events, etc.
      end

      def on_connect
        Log.info { "#{self.class.name} WebSocket connected" }
        # Handle WebSocket connection
      end

      def on_disconnect
        Log.info { "#{self.class.name} WebSocket disconnected" }
        # Handle WebSocket disconnection
      end
      CRYSTAL
    end

    # Generate content method based on component type
    private def generate_content_method : String
      case @component_type
      when "static"
        generate_static_content
      when "realtime"
        generate_realtime_content
      else
        generate_interactive_content
      end
    end

    # Generate static content
    private def generate_static_content : String
      <<-CRYSTAL
      div class: "#{kebab_case_name}-component", id: "#{snake_case_name}-\#{object_id}" do
        h3 "#{class_name} Component"
        div class: "component-content" do
          p "This is a static #{class_name} component."
        end
      end
      CRYSTAL
    end

    # Generate interactive content
    private def generate_interactive_content : String
      <<-CRYSTAL
      div class: "#{kebab_case_name}-component", id: "#{snake_case_name}-\#{object_id}" do
        h3 "#{class_name} Component"
        div class: "component-content" do
          p "This is an interactive #{class_name} component."
          button onclick: "click()", class: "btn btn-primary" do
            text "Click Me"
          end
        end
      end
      CRYSTAL
    end

    # Generate real-time content
    private def generate_realtime_content : String
      <<-CRYSTAL
      div class: "#{kebab_case_name}-component", id: "#{snake_case_name}-\#{object_id}" do
        h3 "#{class_name} Component (Real-time)"
        div class: "component-content" do
          p "This is a real-time #{class_name} component."
          div id: "live-data" do
            span "Waiting for updates..."
          end
          button onclick: "click()", class: "btn btn-primary" do
            text "Send Update"
          end
        end
      end
      CRYSTAL
    end

    # Generate test events
    private def generate_test_events : String
      test_events = events.empty? ? ["click"] : events

      lines = [] of String
      test_events.each do |event_name|
        lines << <<-CRYSTAL
        it "handles #{event_name} event" do
          component = #{module_name}::#{class_name}Component.new#{generate_test_constructor_args}
          component.should respond_to(:on_event)
          component.on_event("#{event_name}", {} of String => JSON::Any)
        end
        CRYSTAL
      end

      lines.join("\n\n")
    end

    # Generate test attributes
    private def generate_test_attributes : String
      return "" if attributes.empty?

      test_values = attributes.map do |attr_name, attr_type|
        value = case crystal_type(attr_type).gsub("?", "")
                when "String"
                  "\"test_#{attr_name}\""
                when "Int32"
                  "42"
                when "Int64"
                  "42_i64"
                when "Float64"
                  "3.14"
                when "Bool"
                  "true"
                when "Time"
                  "Time.utc"
                else
                  "\"test_#{attr_name}\""
                end
        "#{attr_name}: #{value}"
      end.join(", ")

      <<-CRYSTAL

      describe "initialization with attributes" do
        it "accepts and stores attributes" do
          component = #{module_name}::#{class_name}Component.new(#{test_values})
          # Add attribute-specific assertions
        end
      end
      CRYSTAL
    end

    # Generate test constructor args
    private def generate_test_constructor_args : String
      return "" if attributes.empty?

      test_values = attributes.map do |attr_name, attr_type|
        case crystal_type(attr_type).gsub("?", "")
        when "String"
          "\"test_#{attr_name}\""
        when "Int32"
          "42"
        when "Int64"
          "42_i64"
        when "Float64"
          "3.14"
        when "Bool"
          "true"
        when "Time"
          "Time.utc"
        else
          "\"test_#{attr_name}\""
        end
      end.join(", ")

      "(#{test_values})"
    end

    # Override success message to include component-specific information
    def success_message : String
      base_message = super
      features = [] of String
      features << "#{events.size} event(s)" unless events.empty?
      features << "#{attributes.size} attribute(s)" unless attributes.empty?
      features << "WebSocket support" if with_websocket
      
      feature_text = features.empty? ? "" : " with #{features.join(", ")}"
      "#{base_message}#{feature_text}"
    end

    # Override to show component-specific next steps
    def post_generation_tasks : Nil
      super
      show_component_usage_info
    end

    # Show component usage information
    private def show_component_usage_info
      puts
      puts "📦 Component Usage:".colorize(:yellow).bold
      puts "  1. Include in your endpoints or pages:"
      puts "     component = #{class_name}Component.new#{generate_example_constructor_args}"
      puts "     component.render"
      puts
      puts "  2. Component type: #{@component_type.capitalize}"
      
      case @component_type
      when "static"
        puts "     - Static content with no interactions"
      when "interactive"
        puts "     - Interactive content with event handling"
      when "realtime"
        puts "     - Real-time updates via WebSocket"
      end
      
      if with_websocket
        puts
        puts "  3. WebSocket configuration:"
        puts "     Add WebSocket routes to your application"
      end
      
      puts
      puts "📚 Learn more: https://azutopia.gitbook.io/azu/real-time/components".colorize(:cyan)
    end

    # Generate example constructor args
    private def generate_example_constructor_args : String
      return "" if attributes.empty?

      example_values = attributes.map do |attr_name, attr_type|
        case crystal_type(attr_type).gsub("?", "")
        when "String"
          "\"example_#{attr_name}\""
        when "Int32"
          "10"
        when "Int64"
          "100_i64"
        when "Float64"
          "99.9"
        when "Bool"
          "true"
        when "Time"
          "Time.utc"
        else
          "\"example_#{attr_name}\""
        end
      end.join(", ")

      "(#{example_values})"
    end
  end
end