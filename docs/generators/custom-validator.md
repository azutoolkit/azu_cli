# Custom Validator Generator

The Custom Validator Generator creates reusable validation components that can be used across multiple contracts and models in your Azu application.

## Usage

```bash
azu generate custom_validator VALIDATOR_NAME [OPTIONS]
```

## Description

Custom validators in Azu applications provide a way to create reusable validation logic that can be shared across different contracts and models. They encapsulate complex validation rules and can be easily tested and maintained.

## Options

- `VALIDATOR_NAME` - Name of the validator to generate (required)
- `-d, --description DESCRIPTION` - Description of the validator
- `-t, --template TEMPLATE` - Template to use (default: basic)
- `-f, --force` - Overwrite existing files
- `-h, --help` - Show help message

## Examples

### Generate a basic custom validator

```bash
azu generate custom_validator EmailValidator
```

This creates:

- `src/validators/email_validator.cr` - The validator class
- `spec/validators/email_validator_spec.cr` - Test file

### Generate a validator with description

```bash
azu generate custom_validator PhoneValidator --description "Validates phone numbers in various formats"
```

### Generate specific validator types

```bash
azu generate custom_validator PasswordValidator --template password
azu generate custom_validator UrlValidator --template url
```

## Generated Files

### Validator Class (`src/validators/VALIDATOR_NAME.cr`)

```crystal
# <%= @description || @name.underscore.humanize %> custom validator
class <%= @name %>Validator < Azu::Validator
  def initialize
  end

  def validate(value : String, context : Azu::ValidationContext) : Bool
    # Add your validation logic here
    # Example:
    # return false if value.nil?
    # return value.match(/^[^@]+@[^@]+\.[^@]+$/) != nil

    true
  end

  def error_message : String
    "<%= @name.underscore.humanize %> is invalid"
  end
end
```

### Test File (`spec/validators/VALIDATOR_NAME_spec.cr`)

```crystal
require "../spec_helper"

describe <%= @name %>Validator do
  describe "#validate" do
    it "validates correctly" do
      validator = <%= @name %>Validator.new
      context = Azu::ValidationContext.new

      # Add your test cases here
      # validator.validate("test", context).should be_true
    end
  end
end
```

## Validator Patterns

### Basic Validator Pattern

```crystal
class EmailValidator < Azu::Validator
  def validate(value : String, context : Azu::ValidationContext) : Bool
    return false if value.nil? || value.empty?

    value.match(/^[^@]+@[^@]+\.[^@]+$/) != nil
  end

  def error_message : String
    "must be a valid email address"
  end
end
```

### Validator with Options

```crystal
class LengthValidator < Azu::Validator
  def initialize(@min_length : Int32? = nil, @max_length : Int32? = nil)
  end

  def validate(value : String, context : Azu::ValidationContext) : Bool
    return true if value.nil?

    length = value.size

    if @min_length && length < @min_length
      return false
    end

    if @max_length && length > @max_length
      return false
    end

    true
  end

  def error_message : String
    if @min_length && @max_length
      "must be between #{@min_length} and #{@max_length} characters"
    elsif @min_length
      "must be at least #{@min_length} characters"
    elsif @max_length
      "must be no more than #{@max_length} characters"
    else
      "length is invalid"
    end
  end
end
```

### Complex Validator Pattern

```crystal
class PasswordValidator < Azu::Validator
  def initialize(
    @min_length : Int32 = 8,
    @require_uppercase : Bool = true,
    @require_lowercase : Bool = true,
    @require_numbers : Bool = true,
    @require_special : Bool = false
  )
  end

  def validate(value : String, context : Azu::ValidationContext) : Bool
    return false if value.nil? || value.size < @min_length

    if @require_uppercase && !value.match(/[A-Z]/)
      return false
    end

    if @require_lowercase && !value.match(/[a-z]/)
      return false
    end

    if @require_numbers && !value.match(/\d/)
      return false
    end

    if @require_special && !value.match(/[!@#$%^&*(),.?":{}|<>]/)
      return false
    end

    true
  end

  def error_message : String
    requirements = [] of String

    requirements << "at least #{@min_length} characters"
    requirements << "uppercase letter" if @require_uppercase
    requirements << "lowercase letter" if @require_lowercase
    requirements << "number" if @require_numbers
    requirements << "special character" if @require_special

    "must contain #{requirements.join(", ")}"
  end
end
```

### Async Validator Pattern

```crystal
class UniqueEmailValidator < Azu::Validator
  def initialize(@model_class : Class)
  end

  def validate(value : String, context : Azu::ValidationContext) : Bool
    return true if value.nil? || value.empty?

    # Check if email already exists in database
    existing_user = @model_class.find_by(email: value)

    # If updating, exclude current record
    if context.record_id
      existing_user = nil if existing_user.try(&.id) == context.record_id
    end

    existing_user.nil?
  end

  def error_message : String
    "email is already taken"
  end
end
```

## Using Custom Validators

### In Contracts

```crystal
class UserContract < Azu::Contract
  field :email, String,
    required: true,
    validators: [EmailValidator.new]

  field :password, String,
    required: true,
    validators: [PasswordValidator.new(min_length: 8, require_special: true)]

  field :username, String,
    required: true,
    validators: [
      LengthValidator.new(min_length: 3, max_length: 20),
      UniqueUsernameValidator.new(User)
    ]
end
```

### In Models

```crystal
class User < CQL::Model
  table :users

  column :email, String
  column :password, String
  column :username, String

  validates :email, presence: true, validator: EmailValidator.new
  validates :password, presence: true, validator: PasswordValidator.new
  validates :username, presence: true, validator: UniqueUsernameValidator.new(User)
end
```

### Creating Validator Instances

```crystal
# Basic usage
email_validator = EmailValidator.new

# With options
password_validator = PasswordValidator.new(
  min_length: 10,
  require_uppercase: true,
  require_lowercase: true,
  require_numbers: true,
  require_special: true
)

# With model reference
unique_email_validator = UniqueEmailValidator.new(User)
```

## Best Practices

### 1. Keep Validators Focused

Each validator should validate one specific thing:

```crystal
# Good: Focused on email format
class EmailValidator < Azu::Validator
  def validate(value : String, context : Azu::ValidationContext) : Bool
    return false if value.nil? || value.empty?
    value.match(/^[^@]+@[^@]+\.[^@]+$/) != nil
  end
end

# Good: Focused on uniqueness
class UniqueEmailValidator < Azu::Validator
  def initialize(@model_class : Class)
  end

  def validate(value : String, context : Azu::ValidationContext) : Bool
    # Check uniqueness logic
  end
end
```

### 2. Provide Clear Error Messages

```crystal
class PhoneValidator < Azu::Validator
  def validate(value : String, context : Azu::ValidationContext) : Bool
    return false if value.nil? || value.empty?
    value.match(/^\+?[\d\s\-\(\)]+$/) != nil
  end

  def error_message : String
    "must be a valid phone number (e.g., +1-555-123-4567)"
  end
end
```

### 3. Handle Edge Cases

```crystal
class UrlValidator < Azu::Validator
  def validate(value : String, context : Azu::ValidationContext) : Bool
    return true if value.nil? || value.empty? # Allow optional URLs

    begin
      URI.parse(value)
      true
    rescue URI::Error
      false
    end
  end

  def error_message : String
    "must be a valid URL"
  end
end
```

### 4. Use Type Safety

```crystal
class AgeValidator < Azu::Validator
  def initialize(@min_age : Int32 = 0, @max_age : Int32 = 150)
  end

  def validate(value : String, context : Azu::ValidationContext) : Bool
    return false if value.nil? || value.empty?

    age = value.to_i?
    return false unless age

    age >= @min_age && age <= @max_age
  end

  def error_message : String
    "must be between #{@min_age} and #{@max_age} years old"
  end
end
```

## Testing Validators

### Unit Testing

```crystal
describe EmailValidator do
  describe "#validate" do
    it "validates correct email addresses" do
      validator = EmailValidator.new
      context = Azu::ValidationContext.new

      validator.validate("user@example.com", context).should be_true
      validator.validate("test.email+tag@domain.co.uk", context).should be_true
    end

    it "rejects invalid email addresses" do
      validator = EmailValidator.new
      context = Azu::ValidationContext.new

      validator.validate("invalid-email", context).should be_false
      validator.validate("user@", context).should be_false
      validator.validate("@domain.com", context).should be_false
      validator.validate("", context).should be_false
      validator.validate(nil, context).should be_false
    end
  end

  describe "#error_message" do
    it "returns appropriate error message" do
      validator = EmailValidator.new
      validator.error_message.should eq("must be a valid email address")
    end
  end
end
```

### Integration Testing

```crystal
describe "Validator integration" do
  it "works with contracts" do
    contract = UserContract.new({
      "email" => "invalid-email",
      "password" => "weak"
    })

    contract.valid?.should be_false
    contract.errors_for(:email).should contain("must be a valid email address")
    contract.errors_for(:password).should contain("must contain")
  end
end
```

## Common Validator Types

### 1. Format Validators

Validate data format:

```crystal
class PhoneValidator < Azu::Validator
  def validate(value : String, context : Azu::ValidationContext) : Bool
    return false if value.nil? || value.empty?
    value.match(/^\+?[\d\s\-\(\)]+$/) != nil
  end
end

class PostalCodeValidator < Azu::Validator
  def validate(value : String, context : Azu::ValidationContext) : Bool
    return false if value.nil? || value.empty?
    value.match(/^\d{5}(-\d{4})?$/) != nil
  end
end
```

### 2. Range Validators

Validate numeric ranges:

```crystal
class RangeValidator < Azu::Validator
  def initialize(@min : Float64? = nil, @max : Float64? = nil)
  end

  def validate(value : String, context : Azu::ValidationContext) : Bool
    return true if value.nil? || value.empty?

    number = value.to_f?
    return false unless number

    if @min && number < @min
      return false
    end

    if @max && number > @max
      return false
    end

    true
  end
end
```

### 3. Uniqueness Validators

Validate database uniqueness:

```crystal
class UniqueValidator < Azu::Validator
  def initialize(@model_class : Class, @column : String)
  end

  def validate(value : String, context : Azu::ValidationContext) : Bool
    return true if value.nil? || value.empty?

    query = @model_class.where({@column => value})

    if context.record_id
      query = query.where.not({id: context.record_id})
    end

    query.first.nil?
  end
end
```

### 4. Conditional Validators

Validate based on conditions:

```crystal
class ConditionalValidator < Azu::Validator
  def initialize(@condition : Proc(Azu::ValidationContext, Bool), @validator : Azu::Validator)
  end

  def validate(value : String, context : Azu::ValidationContext) : Bool
    return true unless @condition.call(context)
    @validator.validate(value, context)
  end

  def error_message : String
    @validator.error_message
  end
end
```

## Related Commands

- `azu generate contract` - Generate validation contracts
- `azu generate model` - Generate data models
- `azu generate service` - Generate business logic services
- `azu generate endpoint` - Generate API endpoints

## Templates

The custom validator generator supports different templates:

- `basic` - Simple validator with basic structure
- `format` - Format validation template
- `range` - Range validation template
- `uniqueness` - Uniqueness validation template
- `conditional` - Conditional validation template

To use a specific template:

```bash
azu generate custom_validator PhoneValidator --template format
```
