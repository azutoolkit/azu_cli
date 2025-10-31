require "teeplate"

module AzuCLI
  module Generate
    # WebSocket channel generator
    class Channel < Teeplate::FileTree
      directory "#{__DIR__}/../templates/channel"
      OUTPUT_DIR = "."

      property name : String
      property actions : Array(String)
      property snake_case_name : String
      property camel_case_name : String

      def initialize(@name : String, @actions : Array(String) = [] of String)
        @snake_case_name = @name.underscore
        @camel_case_name = @name.camelcase
        @actions = ["subscribed", "unsubscribed", "receive"] if @actions.empty?
      end

      # Generate action method definitions
      def action_methods : String
        @actions.map do |action|
          case action
          when "subscribed"
            <<-METHOD
                def subscribed
                  # Called when a client subscribes to this channel
                  # stream_from "#{@snake_case_name}_\#{user_id}"
                  Log.info { "Client subscribed to #{@camel_case_name}Channel" }
                end
            METHOD
          when "unsubscribed"
            <<-METHOD
                def unsubscribed
                  # Called when a client unsubscribes from this channel
                  Log.info { "Client unsubscribed from #{@camel_case_name}Channel" }
                end
            METHOD
          when "receive"
            <<-METHOD
                def receive(data : JSON::Any)
                  # Called when a client sends data to this channel
                  Log.info { "Received data: \#{data}" }

                  # Broadcast to all connected clients
                  # broadcast(data)
                end
            METHOD
          else
            <<-METHOD
                def #{action}(data : JSON::Any)
                  # Handle #{action} action
                  Log.info { "#{action}: \#{data}" }
                end
            METHOD
          end
        end.join("\n\n")
      end

      # Generate client-side JavaScript
      def client_javascript : String
        <<-JS
          // #{@camel_case_name} Channel Client
          class #{@camel_case_name}Channel {
            constructor(url = 'ws://localhost:3000/cable') {
              this.url = url;
              this.ws = null;
              this.callbacks = {};
            }

            connect() {
              this.ws = new WebSocket(this.url);

              this.ws.onopen = () => {
                console.log('Connected to #{@camel_case_name}Channel');
                this.subscribe();
              };

              this.ws.onmessage = (event) => {
                const data = JSON.parse(event.data);
                this.handleMessage(data);
              };

              this.ws.onclose = () => {
                console.log('Disconnected from #{@camel_case_name}Channel');
                setTimeout(() => this.connect(), 1000); // Reconnect
              };

              this.ws.onerror = (error) => {
                console.error('WebSocket error:', error);
              };
            }

            subscribe() {
              this.send({ command: 'subscribe', identifier: '#{@snake_case_name}' });
            }

            send(data) {
              if (this.ws && this.ws.readyState === WebSocket.OPEN) {
                this.ws.send(JSON.stringify(data));
              }
            }

            on(event, callback) {
              this.callbacks[event] = callback;
            }

            handleMessage(data) {
              const callback = this.callbacks[data.type];
              if (callback) {
                callback(data);
              }
            }

            disconnect() {
              if (this.ws) {
                this.ws.close();
              }
            }
          }

          // Usage:
          // const channel = new #{@camel_case_name}Channel();
          // channel.on('message', (data) => console.log(data));
          // channel.connect();
        JS
      end
    end
  end
end
