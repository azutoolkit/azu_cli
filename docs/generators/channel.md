# Channel Generator

Generates an [`Azu::Channel`](https://github.com/azutoolkit/azu): a WebSocket endpoint that relays every message
a client sends to all clients of the channel (the sender included).

```bash
azu generate channel Chat
```

creates `src/channels/chat_channel.cr`:

```crystal
module Blog
  class ChatChannel < Azu::Channel
    TOPIC = "chat"

    ws "/chat"

    def on_connect
      subscribe(TOPIC)
    end

    def on_message(message : String)
      broadcast(TOPIC, message)
    end
    # on_binary, on_ping, on_pong and on_close do nothing yet
  end
end
```

Clients connect to `ws://localhost:4000/chat`. Change what the channel does in `on_connect` (authenticate with
`params` or `headers`, choose a topic per room) and `on_message`. Generated projects load `src/channels/**`.

The name must be an identifier; a channel takes no actions.
