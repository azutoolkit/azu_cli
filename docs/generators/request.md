# Contract Generator

The Contract Generator creates validation contracts that define the structure and validation rules for incoming data in your Azu application.

## Usage

```bash
azu generate contract CONTRACT_NAME [OPTIONS]
```

## Description

Contracts in Azu applications provide a way to validate and structure incoming data from HTTP requests, API calls, or form submissions. They ensure data integrity and provide clear error messages when validation fails.

## Options

- `CONTRACT_NAME` - Name of the contract to generate (required)
- `-d, --description DESCRIPTION` - Description of the contract
- `-f, --fields FIELDS` - Comma-separated list of fields with types and validations
- `-t, --template TEMPLATE` - Template to use (default: basic)
- `-f, --force` - Overwrite existing files
- `-h, --help` - Show help message

## Examples

### Generate a basic contract

```bash
azu generate contract UserContract
```

This creates:

- `src/contracts/user_contract.cr` - The contract class
- `spec/contracts/user_contract_spec.cr` - Test file

### Generate a contract with fields

```bash
azu generate contract UserContract --fields "name:string:required,email:string:required:email,age:integer:min:18"
```

### Generate a contract with description

```bash
azu generate contract PostContract --description "Validates blog post creation and updates"
```

## Generated Files

### Contract Class (`src/contracts/CONTRACT_NAME.cr`)

```crystal
# <%= @description || @name.underscore.humanize %> contract for data validation
class <%= @name %>Contract < Azu::Contract
  # Define your contract fields here
  # Example:
  # field :name, String, required: true
  # field :email, String, required: true, format: /^[^@]+@[^@]+\.[^@]+$/
  # field :age, Int32, min: 18, max: 120

  # Custom validation methods
  # def validate_custom_rule
  #   # Add custom validation logic
  # end
end
```

### Test File (`spec/contracts/CONTRACT_NAME_spec.cr`)

```crystal
require "../spec_helper"

describe <%= @name %>Contract do
  describe "#valid?" do
    it "validates required fields" do
      contract = <%= @name %>Contract.new

      # Add your test cases here
      # contract.valid?.should be_true
    end
  end
end
```

## Contract Patterns

### Basic Contract Pattern

```crystal
class UserContract < Azu::Contract
  field :name, String, required: true, min_length: 2, max_length: 50
  field :email, String, required: true, format: /^[^@]+@[^@]+\.[^@]+$/
  field :age, Int32, min: 18, max: 120
  field :bio, String?, max_length: 500
end
```

### Contract with Custom Validations

```crystal
class RegistrationContract < Azu::Contract
  field :email, String, required: true, format: /^[^@]+@[^@]+\.[^@]+$/
  field :password, String, required: true, min_length: 8
  field :password_confirmation, String, required: true

  def validate_password_confirmation
    return unless password && password_confirmation

    unless password == password_confirmation
      errors.add(:password_confirmation, "must match password")
    end
  end

  def validate_unique_email
    return unless email

    if User.find_by(email: email)
      errors.add(:email, "is already taken")
    end
  end
end
```

### Nested Contract Pattern

```crystal
class AddressContract < Azu::Contract
  field :street, String, required: true
  field :city, String, required: true
  field :postal_code, String, required: true
end

class UserContract < Azu::Contract
  field :name, String, required: true
  field :email, String, required: true
  field :address, AddressContract
end
```

### Array Contract Pattern

```crystal
class TagContract < Azu::Contract
  field :name, String, required: true, max_length: 20
end

class PostContract < Azu::Contract
  field :title, String, required: true, max_length: 200
  field :content, String, required: true
  field :tags, Array(TagContract), max_size: 10
end
```

## Field Types and Validations

### Supported Field Types

```crystal
class ExampleContract < Azu::Contract
  # Basic types
  field :string_field, String
  field :integer_field, Int32
  field :float_field, Float64
  field :boolean_field, Bool
  field :time_field, Time

  # Optional types (can be nil)
  field :optional_string, String?
  field :optional_integer, Int32?

  # Array types
  field :string_array, Array(String)
  field :integer_array, Array(Int32)

  # Nested contracts
  field :nested_contract, NestedContract
  field :nested_contract_array, Array(NestedContract)
end
```

### Common Validations

```crystal
class ValidationContract < Azu::Contract
  # Required fields
  field :required_field, String, required: true

  # String validations
  field :name, String,
    required: true,
    min_length: 2,
    max_length: 50,
    format: /^[a-zA-Z\s]+$/

  # Numeric validations
  field :age, Int32,
    required: true,
    min: 0,
    max: 150

  field :price, Float64,
    required: true,
    min: 0.0,
    max: 10000.0

  # Array validations
  field :tags, Array(String),
    max_size: 10,
    min_size: 1

  # Custom validation
  field :custom_field, String, required: true
end
```

## Using Contracts

### In Controllers

```crystal
class UsersController < ApplicationController
  def create
    contract = UserContract.new(params.to_h)

    if contract.valid?
      user = User.create(contract.valid_data)
      render json: user, status: :created
    else
      render json: {errors: contract.errors}, status: :unprocessable_entity
    end
  end

  def update
    contract = UserContract.new(params.to_h)

    if contract.valid?
      user = User.find(params["id"])
      user.update(contract.valid_data)
      render json: user
    else
      render json: {errors: contract.errors}, status: :unprocessable_entity
    end
  end
end
```

### In Services

```crystal
class UserService
  def create_user(data : Hash) : User
    contract = UserContract.new(data)

    unless contract.valid?
      raise InvalidUserDataError.new(contract.errors)
    end

    User.create(contract.valid_data)
  end
end
```

### Accessing Validated Data

```crystal
contract = UserContract.new(params.to_h)

if contract.valid?
  # Access individual fields
  name = contract.name
  email = contract.email

  # Access all valid data as hash
  user_data = contract.valid_data

  # Access specific field with type safety
  age = contract.age.try(&.to_i) || 0
end
```

## Error Handling

### Accessing Validation Errors

```crystal
contract = UserContract.new(params.to_h)

unless contract.valid?
  # Get all errors
  all_errors = contract.errors

  # Get errors for specific field
  name_errors = contract.errors_for(:name)

  # Check if field has errors
  if contract.has_errors_for?(:email)
    # Handle email errors
  end

  # Get first error for field
  first_name_error = contract.first_error_for(:name)
end
```

### Custom Error Messages

```crystal
class CustomContract < Azu::Contract
  field :email, String,
    required: true,
    format: /^[^@]+@[^@]+\.[^@]+$/,
    messages: {
      required: "Email address is required",
      format: "Please provide a valid email address"
    }
end
```

## Best Practices

### 1. Keep Contracts Focused

Each contract should validate a specific use case:

```crystal
# Good: Separate contracts for different operations
class CreateUserContract < Azu::Contract
  field :name, String, required: true
  field :email, String, required: true
  field :password, String, required: true
end

class UpdateUserContract < Azu::Contract
  field :name, String, required: true
  field :email, String, required: true
  # No password field for updates
end
```

### 2. Use Descriptive Field Names

```crystal
# Good
field :email_address, String, required: true
field :phone_number, String, required: true

# Avoid
field :email, String, required: true
field :phone, String, required: true
```

### 3. Implement Custom Validations

```crystal
class UserContract < Azu::Contract
  field :username, String, required: true

  def validate_username_format
    return unless username

    unless username.match(/^[a-zA-Z0-9_]+$/)
      errors.add(:username, "can only contain letters, numbers, and underscores")
    end
  end

  def validate_username_availability
    return unless username

    if User.find_by(username: username)
      errors.add(:username, "is already taken")
    end
  end
end
```

### 4. Reuse Common Validations

```crystal
module CommonValidations
  def self.email_field(name = :email)
    field name, String,
      required: true,
      format: /^[^@]+@[^@]+\.[^@]+$/,
      messages: {
        required: "Email is required",
        format: "Invalid email format"
      }
  end
end

class UserContract < Azu::Contract
  include CommonValidations

  CommonValidations.email_field
  field :name, String, required: true
end
```

## Testing Contracts

### Unit Testing

```crystal
describe UserContract do
  describe "#valid?" do
    it "is valid with correct data" do
      data = {
        "name" => "John Doe",
        "email" => "john@example.com",
        "age" => "25"
      }

      contract = UserContract.new(data)
      contract.valid?.should be_true
    end

    it "is invalid with missing required fields" do
      data = {"name" => "John Doe"}

      contract = UserContract.new(data)
      contract.valid?.should be_false
      contract.errors_for(:email).should contain("is required")
    end

    it "validates email format" do
      data = {
        "name" => "John Doe",
        "email" => "invalid-email",
        "age" => "25"
      }

      contract = UserContract.new(data)
      contract.valid?.should be_false
      contract.errors_for(:email).should contain("invalid format")
    end
  end

  describe "#valid_data" do
    it "returns cleaned data" do
      data = {
        "name" => "  John Doe  ",
        "email" => "john@example.com",
        "age" => "25"
      }

      contract = UserContract.new(data)
      contract.valid_data["name"].should eq("John Doe")
    end
  end
end
```

### Integration Testing

```crystal
describe "Contract integration" do
  it "works with controller" do
    post "/users", {
      "name" => "John Doe",
      "email" => "john@example.com"
    }

    response.status_code.should eq(201)
  end

  it "returns validation errors" do
    post "/users", {
      "name" => "",
      "email" => "invalid-email"
    }

    response.status_code.should eq(422)
    response.body.should contain("validation errors")
  end
end
```

## Related Commands

- `azu generate endpoint` - Generate API endpoints
- `azu generate model` - Generate data models
- `azu generate service` - Generate business logic services
- `azu generate middleware` - Generate middleware components

## Templates

The contract generator supports different templates:

- `basic` - Simple contract with basic structure
- `user` - User registration/update contract template
- `api` - API request/response contract template
- `form` - Form submission contract template

To use a specific template:

```bash
azu generate contract ApiRequestContract --template api
```
