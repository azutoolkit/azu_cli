# Service Generator

The Service Generator creates service classes that encapsulate business logic and provide a clean interface for your application's core functionality.

## Usage

```bash
azu generate service SERVICE_NAME [OPTIONS]
```

## Description

Services in Azu applications handle complex business logic, external API integrations, and data processing operations. They provide a clean separation between your application's business rules and the presentation layer.

## Options

- `SERVICE_NAME` - Name of the service to generate (required)
- `-d, --description DESCRIPTION` - Description of the service
- `-m, --methods METHODS` - Comma-separated list of methods to generate
- `-t, --template TEMPLATE` - Template to use (default: basic)
- `-f, --force` - Overwrite existing files
- `-h, --help` - Show help message

## Examples

### Generate a basic service

```bash
azu generate service UserService
```

This creates:

- `src/services/user_service.cr` - The service class
- `spec/services/user_service_spec.cr` - Test file

### Generate a service with specific methods

```bash
azu generate service EmailService --methods send_welcome,reset_password,notify_admin
```

### Generate a service with description

```bash
azu generate service PaymentProcessor --description "Handles payment processing and transactions"
```

## Generated Files

### Service Class (`src/services/SERVICE_NAME.cr`)

```crystal
# Handles business logic for <%= @description || @name.underscore.humanize %>
class <%= @name %>Service
  # Initialize the service
  def initialize
  end

  # Add your service methods here
  # Example:
  # def process_data(data : String) : Bool
  #   # Implementation
  # end
end
```

### Test File (`spec/services/SERVICE_NAME_spec.cr`)

```crystal
require "../spec_helper"

describe <%= @name %>Service do
  describe "#initialize" do
    it "creates a new service instance" do
      service = <%= @name %>Service.new
      service.should be_a(<%= @name %>Service)
    end
  end

  # Add your test cases here
end
```

## Service Patterns

### Basic Service Pattern

```crystal
class UserService
  def initialize(@user_repository : UserRepository)
  end

  def create_user(user_data : Hash) : User
    # Validate user data
    # Create user
    # Return user
  end

  def update_user(id : Int64, user_data : Hash) : User?
    # Find user
    # Update user
    # Return updated user
  end

  def delete_user(id : Int64) : Bool
    # Delete user
    # Return success status
  end
end
```

### Service with Error Handling

```crystal
class PaymentService
  class PaymentError < Exception; end

  def process_payment(payment_data : Hash) : Payment
    begin
      # Process payment logic
      Payment.new(payment_data)
    rescue ex : Exception
      raise PaymentError.new("Payment processing failed: #{ex.message}")
    end
  end
end
```

### Service with Dependencies

```crystal
class OrderService
  def initialize(
    @order_repository : OrderRepository,
    @payment_service : PaymentService,
    @email_service : EmailService
  )
  end

  def create_order(order_data : Hash) : Order
    # Create order
    # Process payment
    # Send confirmation email
  end
end
```

## Best Practices

### 1. Single Responsibility

Each service should have a single, well-defined responsibility:

```crystal
# Good: Focused on user operations
class UserService
  def create_user(data : Hash) : User; end
  def update_user(id : Int64, data : Hash) : User?; end
  def delete_user(id : Int64) : Bool; end
end

# Good: Focused on authentication
class AuthService
  def authenticate(email : String, password : String) : User?; end
  def reset_password(email : String) : Bool; end
end
```

### 2. Dependency Injection

Use dependency injection to make services testable:

```crystal
class OrderService
  def initialize(@repository : OrderRepository)
  end
end

# In your application setup
order_service = OrderService.new(OrderRepository.new)
```

### 3. Error Handling

Implement proper error handling and custom exceptions:

```crystal
class UserService
  class UserNotFoundError < Exception; end
  class InvalidUserDataError < Exception; end

  def find_user(id : Int64) : User
    user = @repository.find(id)
    raise UserNotFoundError.new("User with id #{id} not found") unless user
    user
  end
end
```

### 4. Method Naming

Use clear, descriptive method names:

```crystal
# Good
def process_payment(payment_data : Hash) : Payment
def send_welcome_email(user : User) : Bool
def validate_user_data(data : Hash) : Bool

# Avoid
def do_something(data : Hash)
def process(data : Hash)
```

## Integration with Controllers

Use services in your controllers:

```crystal
class UsersController < ApplicationController
  def initialize(@user_service : UserService)
  end

  def create
    user = @user_service.create_user(params.to_h)
    render json: user, status: :created
  rescue UserService::InvalidUserDataError => ex
    render json: {error: ex.message}, status: :bad_request
  end
end
```

## Testing Services

### Unit Testing

```crystal
describe UserService do
  describe "#create_user" do
    it "creates a new user with valid data" do
      service = UserService.new
      user_data = {"name" => "John Doe", "email" => "john@example.com"}

      user = service.create_user(user_data)

      user.name.should eq("John Doe")
      user.email.should eq("john@example.com")
    end

    it "raises error with invalid data" do
      service = UserService.new
      user_data = {"name" => ""}

      expect_raises(UserService::InvalidUserDataError) do
        service.create_user(user_data)
      end
    end
  end
end
```

### Mocking Dependencies

```crystal
describe OrderService do
  describe "#create_order" do
    it "processes payment and sends email" do
      mock_payment_service = MockPaymentService.new
      mock_email_service = MockEmailService.new
      service = OrderService.new(mock_payment_service, mock_email_service)

      service.create_order({"amount" => 100})

      mock_payment_service.should have_received(:process_payment)
      mock_email_service.should have_received(:send_confirmation)
    end
  end
end
```

## Common Service Types

### 1. CRUD Services

Handle basic Create, Read, Update, Delete operations:

```crystal
class PostService
  def create_post(data : Hash) : Post; end
  def find_post(id : Int64) : Post?; end
  def update_post(id : Int64, data : Hash) : Post?; end
  def delete_post(id : Int64) : Bool; end
  def list_posts(page : Int32 = 1) : Array(Post); end
end
```

### 2. External API Services

Handle communication with external APIs:

```crystal
class WeatherService
  def get_weather(city : String) : WeatherData
    response = HTTP::Client.get("https://api.weather.com/#{city}")
    WeatherData.from_json(response.body)
  end
end
```

### 3. Processing Services

Handle complex data processing:

```crystal
class ReportService
  def generate_monthly_report(month : Time) : Report
    # Complex report generation logic
  end

  def export_to_pdf(report : Report) : Bytes
    # PDF generation logic
  end
end
```

## Related Commands

- `azu generate model` - Generate data models
- `azu generate endpoint` - Generate API endpoints
- `azu generate contract` - Generate validation contracts
- `azu generate middleware` - Generate middleware components

## Templates

The service generator supports different templates:

- `basic` - Simple service with basic structure
- `crud` - Service with full CRUD operations
- `api` - Service designed for external API integration
- `processing` - Service for data processing operations

To use a specific template:

```bash
azu generate service DataProcessor --template processing
```
