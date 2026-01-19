# AZU Framework Patterns Reference

This document defines the **accurate** patterns that azu_cli must enforce when generating AZU framework code.

## Endpoint Pattern

AZU endpoints use `include Azu::Endpoint(RequestType, ResponseType)` - NOT inheritance.

### Basic Endpoint Structure

```crystal
struct HelloEndpoint
  include Azu::Endpoint(HelloRequest, HelloResponse)

  get "/hello/:name"

  def call : HelloResponse
    HelloResponse.new(
      message: "Hello, #{request.param("name")}!"
    )
  end
end
```

### RESTful Endpoint Examples

```crystal
# GET endpoint
struct UsersIndexEndpoint
  include Azu::Endpoint(EmptyRequest, UsersListResponse)

  get "/api/users"

  def call : UsersListResponse
    users = UserService.all(
      page: request.page,
      per_page: request.per_page
    )
    UsersListResponse.new(users: users)
  end
end

# GET with params
struct UsersShowEndpoint
  include Azu::Endpoint(EmptyRequest, UserResponse)

  get "/api/users/:id"

  def call : UserResponse
    user_id = path_params["id"].to_i64
    user = UserService.find(user_id)
    
    unless user
      raise Azu::Response::NotFoundError.new("User not found")
    end
    
    UserResponse.new(user)
  end
end

# POST endpoint
struct UsersCreateEndpoint
  include Azu::Endpoint(UserRequest, UserResponse)

  post "/api/users"

  def call : UserResponse
    user = UserService.create_user(request)
    UserResponse.new(user)
  rescue ex : Azu::Response::ValidationError
    raise ex
  end
end

# PUT endpoint
struct UsersUpdateEndpoint
  include Azu::Endpoint(UserRequest, UserResponse)

  put "/api/users/:id"

  def call : UserResponse
    user_id = path_params["id"].to_i64
    user = UserService.update(user_id, request)
    UserResponse.new(user)
  end
end

# DELETE endpoint
struct UsersDestroyEndpoint
  include Azu::Endpoint(EmptyRequest, EmptyResponse)

  delete "/api/users/:id"

  def call : EmptyResponse
    user_id = path_params["id"].to_i64
    UserService.delete(user_id)
    EmptyResponse.new
  end
end
```

## Request Pattern

Requests use `include Azu::Request` with JSON::Serializable.

```crystal
struct UserRequest
  include Azu::Request
  include JSON::Serializable

  getter name : String
  getter email : String
  getter age : Int32?
  getter profile_image : Azu::Params::Multipart::File?

  def initialize(@name = "", @email = "", @age = nil, @profile_image = nil)
  end

  # Built-in validation rules
  validate :name, presence: true, length: {min: 2, max: 50}
  validate :email, presence: true, format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
  validate :age, numericality: {greater_than: 0, less_than: 150}, if: ->{ age }

  # Custom validators
  use EmailValidator
  use UniqueRecordValidator
end

struct SearchRequest
  include Azu::Request
  include JSON::Serializable

  getter query : String
  getter page : Int32
  getter per_page : Int32
  getter sort : String
  getter filters : Hash(String, String)

  def initialize(@query = "", @page = 1, @per_page = 20, @sort = "created_at", @filters = {} of String => String)
  end

  validate :query, presence: true, length: {min: 1}
  validate :page, numericality: {greater_than: 0}
  validate :per_page, numericality: {greater_than: 0, less_than_or_equal_to: 100}
  validate :sort, inclusion: {in: %w(name email created_at updated_at)}
end
```

## Response Pattern

Responses use `include Azu::Response` with JSON::Serializable.

```crystal
struct UserResponse
  include Azu::Response
  include JSON::Serializable

  getter id : Int64
  getter name : String
  getter email : String
  getter created_at : String

  def initialize(user : User)
    @id = user.id.not_nil!
    @name = user.name
    @email = user.email
    @created_at = user.created_at.not_nil!.to_s("%Y-%m-%d %H:%M:%S")
  end

  def render
    to_json
  end
end

struct UsersListResponse
  include Azu::Response
  include JSON::Serializable

  getter users : Array(UserResponse)
  getter pagination : PaginationMeta?

  def initialize(@users : Array(UserResponse), @pagination : PaginationMeta? = nil)
  end

  def render
    to_json
  end
end

# HTML Response with Templates
struct UserPageResponse
  include Azu::Response
  include Azu::Templates::Renderable

  getter user : User

  def initialize(@user : User)
  end

  def render
    view "users/show.html", {
      "user" => {
        "id" => user.id,
        "name" => user.name,
        "email" => user.email
      },
      "title" => "#{user.name}'s Profile"
    }
  end
end
```

## Custom Validator Pattern

Validators inherit from `Azu::Validator`.

```crystal
class EmailValidator < Azu::Validator
  getter :record, :field, :message

  EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def initialize(@record : User)
    @field = :email
    @message = "Email must be valid!"
  end

  def valid? : Array(Schema::Error)
    errors = [] of Schema::Error

    email = @record.email
    return errors if email.empty?

    unless EMAIL_REGEX.match(email)
      errors << Schema::Error.new(@field, @message)
    end

    errors
  end
end

class UniqueRecordValidator < Azu::Validator
  getter :record, :field, :message

  def initialize(@record : User)
    @field = :email
    @message = "Email must be unique!"
  end

  def valid? : Array(Schema::Error)
    errors = [] of Schema::Error

    if User.where(email: @record.email).where { id != @record.id }.exists?
      errors << Schema::Error.new(@field, @message)
    end

    errors
  end
end
```

## Channel (WebSocket) Pattern

Channels inherit from `Azu::Channel` with `ws` macro.

```crystal
class ChatChannel < Azu::Channel
  SUBSCRIBERS = [] of HTTP::WebSocket

  ws "/chat"

  def on_connect
    SUBSCRIBERS << socket.not_nil!
    broadcast_to_all("user_joined", {
      "message" => "A user joined the chat",
      "user_count" => SUBSCRIBERS.size
    })
  end

  def on_message(message : String)
    begin
      data = JSON.parse(message)
      event_type = data["type"]?.try(&.as_s) || "message"

      case event_type
      when "chat_message"
        handle_chat_message(data)
      when "typing_start"
        handle_typing(data, true)
      when "typing_stop"
        handle_typing(data, false)
      else
        send_error("Unknown message type: #{event_type}")
      end
    rescue JSON::ParseError
      send_error("Invalid JSON format")
    end
  end

  def on_close(code, message)
    SUBSCRIBERS.delete(socket)
    broadcast_to_all("user_left", {
      "message" => "A user left the chat",
      "user_count" => SUBSCRIBERS.size
    })
  end

  private def broadcast_to_all(event : String, data)
    message = {"event" => event, "data" => data}.to_json
    SUBSCRIBERS.each do |subscriber|
      begin
        subscriber.send(message)
      rescue
        SUBSCRIBERS.delete(subscriber)
      end
    end
  end

  private def send_error(error_message : String)
    socket.not_nil!.send({"event" => "error", "data" => {"message" => error_message}}.to_json)
  end
end
```

## Component (Live Components) Pattern

Components use `include Azu::Component`.

```crystal
class CounterComponent
  include Azu::Component

  property count : Int32 = 0

  def content
    div(class: "counter") do
      h2 { text "Count: #{@count}" }
      button(onclick: "increment") { text "+" }
      button(onclick: "decrement") { text "-" }
    end
  end

  def on_event(name, data)
    case name
    when "increment"
      @count += 1
      refresh  # Automatically updates the client
    when "decrement"
      @count -= 1
      refresh
    end
  end
end

class ChatComponent
  include Azu::Component

  property messages : Array(Hash(String, String)) = [] of Hash(String, String)
  property current_user : String = "Anonymous"

  def initialize(@current_user : String)
  end

  def content
    div(class: "chat-container") do
      div(class: "messages") do
        @messages.each do |message|
          div(class: "message") do
            span(class: "user") { text "#{message["user"]}:" }
            span(class: "text") { text message["text"] }
          end
        end
      end

      form(onsubmit: "send_message") do
        input(type: "text", name: "message", placeholder: "Type a message...")
        button(type: "submit") { text "Send" }
      end
    end
  end

  def on_event(name, data)
    case name
    when "send_message"
      if message_text = data["message"]?.try(&.as_s)
        unless message_text.empty?
          @messages << {"user" => @current_user, "text" => message_text}
          refresh
          broadcast("new_message", {"user" => @current_user, "text" => message_text})
        end
      end
    when "receive_message"
      if user = data["user"]?.try(&.as_s)
        if text = data["text"]?.try(&.as_s)
          @messages << {"user" => user, "text" => text}
          refresh
        end
      end
    end
  end
end
```

## Application Configuration Pattern

```crystal
module MyApp
  include Azu

  configure do
    port = ENV.fetch("PORT", "4000").to_i
    host = ENV.fetch("HOST", "0.0.0.0")

    # Template configuration
    templates.path = ["src/templates", "src/views"]
    template_hot_reload = ENV.fetch("CRYSTAL_ENV", "development") == "development"

    # File upload configuration
    upload.max_file_size = 50.megabytes
    upload.temp_dir = "tmp/uploads"

    # Cache configuration
    cache_config.enabled = true
    cache_config.store = "memory"
    cache_config.max_size = 1000
    cache_config.default_ttl = 300
  end
end
```

## Server Startup Pattern

```crystal
# server.cr
require "./src/my_app"

MyApp.start [
  Azu::Handler::RequestId.new,
  Azu::Handler::Rescuer.new,
  Azu::Handler::Logger.new,
]

puts "🚀 Server starting on http://#{MyApp::CONFIG.host}:#{MyApp::CONFIG.port}"
```

## Middleware Pattern

```crystal
class AuthenticationMiddleware
  include HTTP::Handler

  def call(context)
    if public_path?(context.request.path)
      call_next(context)
      return
    end

    token = extract_token(context.request)

    unless token && valid_token?(token)
      context.response.status = HTTP::Status::UNAUTHORIZED
      context.response.content_type = "application/json"
      context.response.print({"error" => "Authentication required"}.to_json)
      return
    end

    if user = get_user_from_token(token)
      context.set("current_user", user)
    end

    call_next(context)
  end

  private def public_path?(path : String) : Bool
    %w[/ /login /register /health].any? { |p| path.starts_with?(p) }
  end

  private def extract_token(request : HTTP::Request) : String?
    if auth_header = request.headers["Authorization"]?
      return auth_header[7..-1] if auth_header.starts_with?("Bearer ")
    end
    request.query_params["token"]?
  end
end
```

## Error Handling Pattern

```crystal
# Built-in error types
raise Azu::Response::ValidationError.new("email", "is invalid")
raise Azu::Response::NotFoundError.new("User not found")
raise Azu::Response::AuthenticationError.new("Login required")
raise Azu::Response::AuthorizationError.new("Admin access required")
raise Azu::Response::RateLimitError.new(retry_after: 60)
raise Azu::Response::InternalServerError.new("Something went wrong")
```

## Naming Conventions

| Component | Convention | Example |
|-----------|------------|---------|
| Endpoint | PascalCase + Endpoint | `UsersIndexEndpoint`, `PostsCreateEndpoint` |
| Request | PascalCase + Request | `UserRequest`, `SearchRequest` |
| Response | PascalCase + Response | `UserResponse`, `UsersListResponse` |
| Channel | PascalCase + Channel | `ChatChannel`, `NotificationChannel` |
| Component | PascalCase + Component | `CounterComponent`, `ChatComponent` |
| Validator | PascalCase + Validator | `EmailValidator`, `PasswordValidator` |
| Middleware | PascalCase + Middleware | `AuthenticationMiddleware` |

## File Organization

```
src/
├── my_app.cr              # Main app with Azu configuration
├── endpoints/
│   └── api/
│       └── users/
│           ├── index.cr   # UsersIndexEndpoint
│           ├── show.cr    # UsersShowEndpoint
│           ├── create.cr  # UsersCreateEndpoint
│           └── update.cr  # UsersUpdateEndpoint
├── requests/
│   └── user_request.cr
├── responses/
│   └── user_response.cr
├── validators/
│   └── email_validator.cr
├── channels/
│   └── chat_channel.cr
├── components/
│   └── counter_component.cr
├── middleware/
│   └── authentication_middleware.cr
└── templates/
    ├── layouts/
    │   └── base.html
    └── users/
        └── show.html
```
