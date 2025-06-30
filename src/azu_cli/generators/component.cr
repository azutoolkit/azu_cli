require "./base"

module AzuCLI
  module Generator
    class Component < Base
      getter attributes : Hash(String, String)
      getter events : Array(String)
      getter with_websocket : Bool

      def initialize(@name : String, @project_name : String, @attributes = Hash(String, String).new, @events = Array(String).new, @with_websocket = false, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_component
        generate_tests unless skip_tests

        puts "  📦 Generated #{class_name}Component".colorize(:green)
        show_component_usage_info
      end

      private def create_directories
        ensure_directory("src/components")
        ensure_directory("spec/components") unless skip_tests
      end

      private def generate_component
        template_variables = {
          "attributes_list"   => generate_attributes_list,
          "events_list"       => generate_events_list,
          "websocket_methods" => generate_websocket_methods,
          "content_method"    => generate_content_method,
          "component_id"      => "#{snake_case_name}-\#{object_id}",
        }

        copy_template(
          "generators/component/component.cr.ecr",
          "src/components/#{snake_case_name}_component.cr",
          template_variables
        )
      end

      private def generate_tests
        template_variables = {
          "test_events"           => generate_test_events,
          "test_attributes"       => generate_test_attributes,
          "test_constructor_args" => generate_test_constructor_args,
        }

        copy_template(
          "generators/component/component_spec.cr.ecr",
          "spec/components/#{snake_case_name}_component_spec.cr",
          template_variables
        )
      end

      private def generate_attributes_list : String
        return "" if attributes.empty?

        constructor_params = attributes.map do |attr_name, attr_type|
          crystal_type = crystal_type(attr_type)
          "@#{attr_name} : #{crystal_type}"
        end.join(", ")

        "    def initialize(#{constructor_params})\n    end"
      end

      private def generate_events_list : String
        return generate_default_events if events.empty?

        lines = [] of String
        events.each do |event_name|
          lines << generate_event_handler(event_name)
        end

        lines.join("\n\n")
      end

      private def generate_default_events : String
        <<-CRYSTAL
        def on_event("click", data)
          # Handle click events
          # Example: update counter, toggle state, etc.
          Log.info { "#{self.class.name}: Click event received" }
        end
        CRYSTAL
      end

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

      private def generate_content_method : String
        if attributes.empty?
          generate_simple_content
        else
          generate_content_with_attributes
        end
      end

      private def generate_simple_content : String
        <<-CRYSTAL
        div class: "#{kebab_case_name}-component", id: "#{snake_case_name}-\#{object_id}" do
          h3 "#{class_name} Component"

          div class: "component-content" do
            p "This is your #{class_name} component."

            button onclick: "click()", class: "btn btn-primary" do
              text "Click Me"
            end
          end
        end
        CRYSTAL
      end

      private def generate_content_with_attributes : String
        attribute_displays = attributes.map do |attr_name, attr_type|
          case crystal_type(attr_type)
          when "Bool"
            "          span \"#{attr_name.capitalize}: \#{@#{attr_name} ? 'Yes' : 'No'}\""
          else
            "          span \"#{attr_name.capitalize}: \#{@#{attr_name}}\""
          end
        end.join("\n")

        <<-CRYSTAL
        div class: "#{kebab_case_name}-component", id: "#{snake_case_name}-\#{object_id}" do
          h3 "#{class_name} Component"

          div class: "component-info" do
        #{attribute_displays}
          end

          div class: "component-actions" do
            button onclick: "click()", class: "btn btn-primary" do
              text "Action"
            end
          end
        end
        CRYSTAL
      end

      private def generate_test_events : String
        test_events = events.empty? ? ["click"] : events

        lines = [] of String
        test_events.each do |event_name|
          lines << <<-CRYSTAL
          it "handles #{event_name} event" do
            component = #{module_name}::#{class_name}Component.new#{generate_test_constructor_args}

            # Mock DOM update
            component.should respond_to(:on_event)

            # Test event handling
            component.on_event("#{event_name}", {} of String => JSON::Any)

            # Add assertions here
            # Example: component.instance_variable_get(:@state).should eq(expected_state)
          end
          CRYSTAL
        end

        lines.join("\n\n")
      end

      private def generate_test_attributes : String
        return "" if attributes.empty?

        test_values = attributes.map do |attr_name, attr_type|
          case crystal_type(attr_type)
          when "String"
            "#{attr_name}: \"test_#{attr_name}\""
          when "Int32"
            "#{attr_name}: 42"
          when "Int64"
            "#{attr_name}: 42_i64"
          when "Float64"
            "#{attr_name}: 3.14"
          when "Bool"
            "#{attr_name}: true"
          when "Time"
            "#{attr_name}: Time.utc"
          else
            "#{attr_name}: \"test_#{attr_name}\""
          end
        end.join(", ")

        <<-CRYSTAL

        describe "initialization with attributes" do
          it "accepts and stores attributes" do
            component = #{module_name}::#{class_name}Component.new(#{test_values})

            #{attributes.map { |attr_name, _| "component.#{attr_name}.should eq(#{attr_name == "string" ? "\"test_#{attr_name}\"" : "test_value"})" }.join("\n            ")}
          end
        end
        CRYSTAL
      end

      private def generate_test_constructor_args : String
        return "" if attributes.empty?

        test_values = attributes.map do |attr_name, attr_type|
          case crystal_type(attr_type)
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

      private def show_component_usage_info
        puts
        puts "📋 Component Usage:".colorize(:yellow).bold
        puts "  1. Include your component in endpoints or pages:"
        puts "     component = #{class_name}Component.new#{generate_example_constructor_args}"
        puts "     component.render"
        puts
        puts "  2. For real-time features, enable WebSocket support:"
        puts "     Add WebSocket routes to your application configuration"
        puts
        puts "  3. Handle events in your component:"
        puts "     def on_event(\"your_event\", data)"
        puts "       # Process event and update DOM"
        puts "     end"
        puts
        if with_websocket
          puts "  4. WebSocket lifecycle methods are ready to use:"
          puts "     - on_mount: Component initialization"
          puts "     - on_unmount: Cleanup"
          puts "     - on_connect/on_disconnect: WebSocket events"
          puts
        end
        puts "💡 Learn more: https://azutopia.gitbook.io/azu/real-time/components".colorize(:blue)
      end

      private def generate_example_constructor_args : String
        return "" if attributes.empty?

        example_values = attributes.map do |attr_name, attr_type|
          case crystal_type(attr_type)
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
end
