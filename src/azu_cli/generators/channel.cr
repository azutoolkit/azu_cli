require "./base"

module AzuCLI
  module Generator
    class Channel < Base
      getter events : Array(String)
      getter with_auth : Bool

      def initialize(@name : String, @project_name : String, @events = Array(String).new, @with_auth = false, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_channel
        generate_tests unless skip_tests

        puts "  📡 Generated #{class_name}Channel".colorize(:green)
        show_channel_usage_info
      end

      private def create_directories
        ensure_directory("src/channels")
        ensure_directory("spec/channels") unless skip_tests
      end

      private def generate_channel
        template_variables = {
          "events_list"       => generate_events_list,
          "auth_methods"      => generate_auth_methods,
          "lifecycle_methods" => generate_lifecycle_methods,
        }

        copy_template(
          "generators/channel/channel.cr.ecr",
          "src/channels/#{snake_case_name}_channel.cr",
          template_variables
        )
      end

      private def generate_tests
        template_variables = {
          "test_events"       => generate_test_events,
          "test_auth"         => generate_test_auth,
          "test_lifecycle"    => generate_test_lifecycle,
        }

        copy_template(
          "generators/channel/channel_spec.cr.ecr",
          "spec/channels/#{snake_case_name}_channel_spec.cr",
          template_variables
        )
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
        def on_message(message : String)
          data = JSON.parse(message)

          case data["type"]?.try(&.as_s)
          when "#{snake_case_name}_action"
            handle_#{snake_case_name}_action(data)
          else
            Log.warn { "Unknown message type: \#{data["type"]?}" }
          end
        rescue JSON::ParseException
          Log.error { "Invalid JSON message: \#{message}" }
        end

        private def handle_#{snake_case_name}_action(data : JSON::Any)
          Log.info { "#{class_name}Channel: #{snake_case_name}_action received" }

          # Process the action and broadcast updates
          response = {
            type: "#{snake_case_name}_response",
            data: data["payload"]?,
            timestamp: Time.utc.to_rfc3339
          }

          broadcast(response.to_json)
        end
        CRYSTAL
      end

      private def generate_event_handler(event_name : String) : String
        <<-CRYSTAL
        private def handle_#{event_name}(data : JSON::Any)
          Log.info { "#{class_name}Channel: #{event_name} event received" }

          # TODO: Implement #{event_name} event logic
          # Example: update database, notify other users, etc.

          response = {
            type: "#{event_name}_response",
            data: data["payload"]?,
            timestamp: Time.utc.to_rfc3339
          }

          broadcast(response.to_json)
        end
        CRYSTAL
      end

      private def generate_auth_methods : String
        return "" unless with_auth

        <<-CRYSTAL

        # Authentication and authorization
        private def authenticate_user(token : String?) : User?
          return nil unless token

          # TODO: Implement token validation
          # Example: JWT.decode(token) or User.find_by_token(token)
          # User.find_by_auth_token(token)
        rescue
          nil
        end

        private def authorized?(user : User?, action : String) : Bool
          return false unless user

          # TODO: Implement authorization logic
          # Example: user.can?(action, self.class.name)
          true
        end
        CRYSTAL
      end

      private def generate_lifecycle_methods : String
        <<-CRYSTAL

        # WebSocket lifecycle methods
        def on_connect
          Log.info { "#{class_name}Channel: User connected" }

          # Optional: Authenticate user on connection
          #{with_auth ? "
          token = request.headers[\"Authorization\"]?.try(&.split(\" \")[1]?)
          @current_user = authenticate_user(token)

          unless @current_user
            send({error: \"Authentication required\"}.to_json)
            close
            return
          end" : ""}

          # Send welcome message or initial state
          send({
            type: "connected",
            message: "Welcome to #{class_name}!",
            timestamp: Time.utc.to_rfc3339
          }.to_json)
        end

        def on_disconnect
          Log.info { "#{class_name}Channel: User disconnected" }

          # Cleanup: remove from active connections, notify other users, etc.
          # Example: broadcast user left message to other connected clients
        end
        CRYSTAL
      end

      private def generate_test_events : String
        test_events = events.empty? ? ["#{snake_case_name}_action"] : events

        lines = [] of String
        test_events.each do |event_name|
          lines << generate_test_event(event_name)
        end

        lines.join("\n\n")
      end

      private def generate_test_event(event_name : String) : String
        <<-CRYSTAL
        describe "#handle_#{event_name}" do
          it "handles #{event_name} event correctly" do
            message = {
              type: "#{event_name}",
              payload: {data: "test"}
            }.to_json

            channel.on_message(message)

            # Add assertions for expected behavior
            # channel.should have_broadcasted({type: "#{event_name}_response"})
          end
        end
        CRYSTAL
      end

      private def generate_test_auth : String
        return "" unless with_auth

        <<-CRYSTAL

        describe "authentication" do
          it "authenticates valid users" do
            # Test valid authentication
            # user = channel.authenticate_user("valid_token")
            # user.should_not be_nil
          end

          it "rejects invalid tokens" do
            # Test invalid authentication
            # user = channel.authenticate_user("invalid_token")
            # user.should be_nil
          end
        end
        CRYSTAL
      end

      private def generate_test_lifecycle : String
        <<-CRYSTAL

        describe "lifecycle methods" do
          describe "#on_connect" do
            it "sends welcome message" do
              channel.on_connect

              # Add assertions for connection behavior
              # channel.should have_sent({type: "connected"})
            end
          end

          describe "#on_disconnect" do
            it "handles disconnection properly" do
              channel.on_disconnect

              # Add assertions for disconnection cleanup
            end
          end
        end
        CRYSTAL
      end

      private def show_channel_usage_info
        puts
        puts "📡 Channel Usage:".colorize(:yellow).bold
        puts "  1. Register your channel in your server configuration:"
        puts "     MyApp.start ["
        puts "       # ... other handlers"
        puts "       Azu::Handler::WebSocket.new(\"/#{snake_case_name}\", #{class_name}Channel)"
        puts "     ]"
        puts
        puts "  2. Connect from client JavaScript:"
        puts "     const socket = new WebSocket('ws://localhost:4000/#{snake_case_name}');"
        puts "     socket.send(JSON.stringify({type: '#{snake_case_name}_action', payload: {data: 'hello'}}));"
        puts
        puts "  3. Handle messages in your channel:"
        events.each do |event|
          puts "     - #{event} event handler ready"
        end
        puts
        puts "💡 WebSocket Features:".colorize(:blue).bold
        puts "  - Real-time bidirectional communication"
        puts "  - Automatic JSON message parsing"
        puts "  - Broadcasting to multiple clients"
        puts "  - Connection lifecycle management"
        if with_auth
          puts "  - User authentication and authorization"
        end
        puts
        puts "📚 Learn more: https://azutopia.gitbook.io/azu/real-time/channels".colorize(:cyan)
      end
    end
  end
end
