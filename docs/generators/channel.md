# Channel Generator

Generate WebSocket channels for real-time, bidirectional communication between clients and your Azu application.

## Synopsis

```bash
azu generate channel <name> [actions...] [options]
```

## Description

The channel generator creates WebSocket channel classes that enable real-time features like live updates, chat systems, notifications, and collaborative editing. Channels provide a clean abstraction for WebSocket connections with support for subscriptions, broadcasts, and custom action handlers.

## Features

- 🔌 **WebSocket Communication**: Full-duplex real-time connections
- 📡 **Broadcast Support**: Send messages to all connected clients
- 🎯 **Action Handlers**: Custom methods for different message types
- 🔐 **Authentication Ready**: Integrate with your auth system
- 📝 **Automatic Logging**: Built-in connection and message logging
- 🔄 **Auto-Reconnect**: Client-side reconnection handling
- 💬 **Room/Stream Support**: Group clients into channels or rooms

## Usage

### Basic Channel

Generate a basic channel with default actions:

```bash
azu generate channel Chat
```

This creates a `ChatChannel` with three default actions:

- `subscribed` - Called when client connects
- `unsubscribed` - Called when client disconnects
- `receive` - Called when client sends data

### Channel with Custom Actions

Generate a channel with specific custom actions:

```bash
azu generate channel Notification subscribed unsubscribed broadcast dismiss
```

### Real-World Examples

#### Chat Channel

```bash
azu generate channel Chat subscribed receive message typing
```

#### Presence Channel

```bash
azu generate channel Presence subscribed unsubscribed appear away
```

#### Notifications Channel

```bash
azu generate channel Notification subscribed receive mark_read dismiss
```

#### Collaborative Editing

```bash
azu generate channel Document subscribed receive edit cursor_move save
```

## Arguments

| Argument       | Type    | Description                | Required |
| -------------- | ------- | -------------------------- | -------- |
| `<name>`       | string  | Channel name (PascalCase)  | Yes      |
| `[actions...]` | strings | Custom action method names | No       |

## Options

| Option    | Description                | Default |
| --------- | -------------------------- | ------- |
| `--force` | Overwrite existing channel | false   |

## Generated Files

### Directory Structure

```
src/
└── channels/
    └── chat_channel.cr          # WebSocket channel class
```

### Channel File

The generator creates a channel class with the following structure:

```crystal
require "json"

# Chat WebSocket channel for real-time messaging
class ChatChannel
  include Azu::Channel

  # Called when a client subscribes to this channel
  def subscribed
    # Setup subscription, join rooms, authenticate user
    # stream_from "chat_#{user_id}"
    Log.info { "Client subscribed to ChatChannel" }
  end

  # Called when a client unsubscribes from this channel
  def unsubscribed
    # Cleanup, leave rooms, update presence
    Log.info { "Client unsubscribed from ChatChannel" }
  end

  # Called when a client sends data to this channel
  def receive(data : JSON::Any)
    # Process incoming messages
    Log.info { "Received data: #{data}" }

    # Broadcast to all connected clients
    # broadcast(data)
  end

  # Custom actions
  def message(data : JSON::Any)
    # Handle message action
    Log.info { "message: #{data}" }
  end

  def typing(data : JSON::Any)
    # Handle typing action
    Log.info { "typing: #{data}" }
  end
end
```

## Default Actions

### subscribed

Called when a client connects to the channel:

```crystal
def subscribed
  # Authenticate user
  unless current_user
    reject_subscription("Authentication required")
    return
  end

  # Join user-specific stream
  stream_from "user_#{current_user.id}"

  # Join room/topic
  stream_from "chat_room_#{params[:room_id]}"

  # Update presence
  Presence.add(current_user.id, channel_name)

  # Notify others
  broadcast({
    type: "user_joined",
    user: current_user.to_json
  })

  Log.info { "User #{current_user.id} subscribed to #{channel_name}" }
end
```

### unsubscribed

Called when a client disconnects:

```crystal
def unsubscribed
  # Clean up presence
  if user = current_user
    Presence.remove(user.id, channel_name)

    # Notify others
    broadcast({
      type: "user_left",
      user_id: user.id
    })
  end

  Log.info { "Client unsubscribed from #{channel_name}" }
end
```

### receive

Called when receiving raw data from client:

```crystal
def receive(data : JSON::Any)
  # Parse message
  action = data["action"]?.try(&.as_s)
  payload = data["payload"]?

  # Route to specific action handler
  case action
  when "message"
    handle_message(payload)
  when "typing"
    handle_typing(payload)
  else
    Log.warn { "Unknown action: #{action}" }
  end
end
```

## Custom Actions

Define custom action methods to handle specific message types:

```crystal
def message(data : JSON::Any)
  content = data["content"].as_s
  room_id = data["room_id"].as_s

  # Save message to database
  message = ChatMessage.create!(
    user_id: current_user.id,
    room_id: room_id,
    content: content
  )

  # Broadcast to room
  broadcast_to("chat_room_#{room_id}", {
    type: "new_message",
    message: message.to_json
  })
end

def typing(data : JSON::Any)
  room_id = data["room_id"].as_s
  is_typing = data["typing"].as_bool

  # Broadcast typing indicator
  broadcast_to("chat_room_#{room_id}", {
    type: "typing",
    user_id: current_user.id,
    typing: is_typing
  }, exclude_current: true)
end
```

## Client-Side JavaScript

The generator also provides reference JavaScript code for connecting to your channels:

```javascript
// Chat Channel Client
class ChatChannel {
  constructor(url = "ws://localhost:3000/cable") {
    this.url = url;
    this.ws = null;
    this.callbacks = {};
  }

  connect() {
    this.ws = new WebSocket(this.url);

    this.ws.onopen = () => {
      console.log("Connected to ChatChannel");
      this.subscribe();
    };

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.handleMessage(data);
    };

    this.ws.onclose = () => {
      console.log("Disconnected from ChatChannel");
      setTimeout(() => this.connect(), 1000); // Reconnect
    };

    this.ws.onerror = (error) => {
      console.error("WebSocket error:", error);
    };
  }

  subscribe() {
    this.send({ command: "subscribe", identifier: "chat" });
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

// Usage
const channel = new ChatChannel("ws://localhost:3000/cable");

// Set up event handlers
channel.on("new_message", (data) => {
  console.log("New message:", data.message);
  displayMessage(data.message);
});

channel.on("typing", (data) => {
  console.log("User typing:", data.user_id);
  showTypingIndicator(data.user_id);
});

channel.on("user_joined", (data) => {
  console.log("User joined:", data.user);
  updateUserList(data.user);
});

// Connect to channel
channel.connect();

// Send message
function sendMessage(content) {
  channel.send({
    action: "message",
    payload: {
      content: content,
      room_id: currentRoomId,
    },
  });
}

// Send typing indicator
function sendTyping(isTyping) {
  channel.send({
    action: "typing",
    payload: {
      room_id: currentRoomId,
      typing: isTyping,
    },
  });
}
```

## Common Use Cases

### 1. Chat Application

```crystal
class ChatChannel
  include Azu::Channel

  def subscribed
    room_id = params[:room_id]
    stream_from "chat_room_#{room_id}"

    # Load and send recent messages
    messages = ChatMessage.recent(room_id, limit: 50)
    transmit({type: "history", messages: messages})
  end

  def message(data : JSON::Any)
    content = data["content"].as_s
    room_id = data["room_id"].as_s

    message = ChatMessage.create!(
      user_id: current_user.id,
      room_id: room_id,
      content: content
    )

    broadcast_to("chat_room_#{room_id}", {
      type: "new_message",
      message: message.to_json
    })
  end

  def typing(data : JSON::Any)
    room_id = data["room_id"].as_s

    broadcast_to("chat_room_#{room_id}", {
      type: "typing",
      user_id: current_user.id,
      user_name: current_user.name
    }, exclude_current: true)
  end
end
```

### 2. Live Notifications

```crystal
class NotificationChannel
  include Azu::Channel

  def subscribed
    # Subscribe to user-specific notifications
    stream_from "notifications_#{current_user.id}"

    # Send unread count
    unread = Notification.unread_count(current_user.id)
    transmit({type: "unread_count", count: unread})
  end

  def mark_read(data : JSON::Any)
    notification_id = data["id"].as_i64

    notification = Notification.find(notification_id)
    notification.mark_as_read!

    transmit({type: "marked_read", id: notification_id})
  end

  def mark_all_read(data : JSON::Any)
    Notification.mark_all_read(current_user.id)
    transmit({type: "all_marked_read"})
  end
end
```

### 3. Presence Tracking

```crystal
class PresenceChannel
  include Azu::Channel

  def subscribed
    stream_from "presence"

    # Add user to presence
    Presence.add(current_user)

    # Broadcast user joined
    broadcast({
      type: "user_joined",
      user: current_user.to_presence_json
    })

    # Send current online users
    transmit({
      type: "online_users",
      users: Presence.online_users
    })
  end

  def unsubscribed
    Presence.remove(current_user)

    broadcast({
      type: "user_left",
      user_id: current_user.id
    })
  end

  def appear(data : JSON::Any)
    status = data["status"]?.try(&.as_s) || "online"

    Presence.update_status(current_user, status)

    broadcast({
      type: "status_changed",
      user_id: current_user.id,
      status: status
    })
  end
end
```

### 4. Collaborative Editing

```crystal
class DocumentChannel
  include Azu::Channel

  def subscribed
    document_id = params[:document_id]
    stream_from "document_#{document_id}"

    # Track active editors
    DocumentPresence.add_editor(document_id, current_user)

    # Send document state
    document = Document.find(document_id)
    transmit({
      type: "document_state",
      content: document.content,
      version: document.version
    })
  end

  def edit(data : JSON::Any)
    document_id = data["document_id"].as_i64
    changes = data["changes"]
    cursor_position = data["cursor"]?

    # Apply changes (using OT or CRDT)
    document = Document.find(document_id)
    document.apply_changes(changes, current_user)

    # Broadcast to other editors
    broadcast_to("document_#{document_id}", {
      type: "edit",
      user_id: current_user.id,
      changes: changes,
      version: document.version
    }, exclude_current: true)
  end

  def cursor_move(data : JSON::Any)
    document_id = data["document_id"].as_i64
    position = data["position"]

    # Broadcast cursor position
    broadcast_to("document_#{document_id}", {
      type: "cursor",
      user_id: current_user.id,
      position: position
    }, exclude_current: true)
  end
end
```

## Channel Methods

### Broadcasting

```crystal
# Broadcast to all clients on channel
broadcast({type: "update", data: "value"})

# Broadcast to specific stream
broadcast_to("room_123", {type: "message"})

# Exclude current client
broadcast({type: "update"}, exclude_current: true)

# Transmit to only current client
transmit({type: "private_message"})
```

### Stream Management

```crystal
# Subscribe to stream
stream_from("chat_room_#{room_id}")

# Subscribe to multiple streams
stream_from("user_#{user_id}")
stream_from("notifications_#{user_id}")

# Stop streaming
stop_stream_from("chat_room_#{room_id}")

# Stop all streams
stop_all_streams
```

### Authentication

```crystal
def subscribed
  unless authenticated?
    reject_subscription("Authentication required")
    return
  end

  # Continue with subscription
end

private def authenticated?
  current_user.present?
end

private def current_user
  # Get user from token or session
  @current_user ||= authenticate_from_token
end
```

## Server Setup

### Mount Channels in Server

```crystal
# src/server.cr
require "./channels/**"

Azu::Server.configure do
  # Enable WebSocket support
  websocket "/cable" do |socket, context|
    Azu::ActionCable.handle_connection(socket, context)
  end
end
```

### Configure Action Cable

```crystal
# src/config/cable.cr
Azu::ActionCable.configure do |config|
  config.allowed_request_origins = [
    "http://localhost:3000",
    "https://yourapp.com"
  ]

  config.connection_timeout = 30.seconds
  config.ping_interval = 3.seconds
  config.log_level = :info
end
```

## Client Integration Examples

### React/TypeScript

```typescript
// channels/ChatChannel.ts
import { ActionCable } from "@rails/actioncable";

class ChatChannel {
  cable: ActionCable.Cable;
  subscription: ActionCable.Channel | null = null;

  constructor(url: string = "ws://localhost:3000/cable") {
    this.cable = ActionCable.createConsumer(url);
  }

  subscribe(roomId: string, callbacks: ChatCallbacks) {
    this.subscription = this.cable.subscriptions.create(
      { channel: "ChatChannel", room_id: roomId },
      {
        connected() {
          console.log("Connected to ChatChannel");
        },

        disconnected() {
          console.log("Disconnected from ChatChannel");
        },

        received(data: any) {
          switch (data.type) {
            case "new_message":
              callbacks.onMessage?.(data.message);
              break;
            case "typing":
              callbacks.onTyping?.(data.user_id);
              break;
          }
        },
      }
    );
  }

  sendMessage(content: string, roomId: string) {
    this.subscription?.perform("message", {
      content,
      room_id: roomId,
    });
  }

  disconnect() {
    this.subscription?.unsubscribe();
    this.cable.disconnect();
  }
}

interface ChatCallbacks {
  onMessage?: (message: any) => void;
  onTyping?: (userId: number) => void;
}

export default ChatChannel;
```

### Vue.js

```javascript
// composables/useChannel.js
import { ref, onUnmounted } from "vue";

export function useChannel(channelName, callbacks) {
  const ws = ref(null);
  const connected = ref(false);

  function connect() {
    ws.value = new WebSocket(`ws://localhost:3000/cable`);

    ws.value.onopen = () => {
      connected.value = true;
      subscribe();
    };

    ws.value.onmessage = (event) => {
      const data = JSON.parse(event.data);
      handleMessage(data);
    };

    ws.value.onclose = () => {
      connected.value = false;
      // Reconnect after 1 second
      setTimeout(connect, 1000);
    };
  }

  function subscribe() {
    send({ command: "subscribe", identifier: channelName });
  }

  function send(data) {
    if (ws.value?.readyState === WebSocket.OPEN) {
      ws.value.send(JSON.stringify(data));
    }
  }

  function handleMessage(data) {
    const callback = callbacks[data.type];
    if (callback) {
      callback(data);
    }
  }

  onUnmounted(() => {
    ws.value?.close();
  });

  connect();

  return {
    connected,
    send,
  };
}
```

## Testing

Example channel tests:

```crystal
require "../spec_helper"

describe ChatChannel do
  it "subscribes user to channel" do
    user = create_user
    channel = ChatChannel.new(user: user, params: {room_id: "1"})

    channel.subscribed

    channel.streams.should include("chat_room_1")
  end

  it "broadcasts messages to room" do
    user = create_user
    channel = ChatChannel.new(user: user)

    broadcasted_data = nil
    allow_broadcast do |data|
      broadcasted_data = data
    end

    channel.message(JSON.parse({
      "content" => "Hello!",
      "room_id" => "1"
    }.to_json))

    broadcasted_data.should_not be_nil
    broadcasted_data["type"].should eq("new_message")
  end

  it "handles typing indicator" do
    user = create_user
    channel = ChatChannel.new(user: user)

    channel.typing(JSON.parse({
      "room_id" => "1"
    }.to_json))

    # Assert broadcast was called
  end
end
```

## Best Practices

### 1. Authentication

Always authenticate users in `subscribed`:

```crystal
def subscribed
  reject_subscription unless current_user
  # Continue...
end
```

### 2. Rate Limiting

Implement rate limiting for actions:

```crystal
RATE_LIMIT = 10.messages.per(1.second)

def message(data : JSON::Any)
  if rate_limited?(current_user)
    transmit({type: "error", message: "Rate limit exceeded"})
    return
  end

  # Process message
end
```

### 3. Error Handling

Handle errors gracefully:

```crystal
def message(data : JSON::Any)
  content = data["content"].as_s
  # ...
rescue ex : Exception
  Log.error { "Error in message action: #{ex.message}" }
  transmit({type: "error", message: "Failed to process message"})
end
```

### 4. Clean Up Resources

Always clean up in `unsubscribed`:

```crystal
def unsubscribed
  # Remove from presence
  # Cancel pending jobs
  # Update database status
  # Notify other users
end
```

### 5. Use Specific Streams

Avoid broadcasting to all clients:

```crystal
# Bad: Broadcasts to everyone
broadcast({type: "update"})

# Good: Broadcasts to specific room
broadcast_to("room_#{room_id}", {type: "update"})
```

## Troubleshooting

### Connection Issues

**Problem**: WebSocket connection fails

**Solutions**:

- Check server WebSocket endpoint is configured
- Verify CORS settings
- Check firewall/proxy settings
- Ensure correct WebSocket URL (ws:// or wss://)

### Messages Not Received

**Problem**: Broadcast messages not reaching clients

**Solutions**:

- Verify client is subscribed to correct stream
- Check stream name matches broadcast target
- Ensure WebSocket connection is open
- Check server logs for errors

### Memory Leaks

**Problem**: Server memory grows over time

**Solutions**:

- Properly clean up in `unsubscribed`
- Don't store large objects in instance variables
- Use weak references where appropriate
- Monitor connection count

## Related Documentation

- [WebSocket RFC](https://tools.ietf.org/html/rfc6455)
- [Action Cable Guide](https://guides.rubyonrails.org/action_cable_overview.html)
- [Real-Time Best Practices](../guides/real-time.md)

## See Also

- [`azu generate component`](component.md) - Generate live components
- [`azu serve`](../commands/serve.md) - Development server
- [Presence System](../guides/presence.md)
