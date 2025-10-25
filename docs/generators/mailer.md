# Mailer Generator

Generate email functionality using the Carbon email library with support for HTML/text templates and async delivery via background jobs.

## Synopsis

```bash
azu generate mailer <name> [methods...] [options]
```

## Description

The mailer generator creates email functionality for your Azu application using the Carbon email library. It generates mailer classes with methods for sending emails, template files for email content, and optional background job integration for async email delivery.

## Features

- 📧 **HTML & Text Emails**: Dual-format support for all email clients
- 🎨 **Template System**: Jinja/ECR templates for email content
- 🚀 **Async Delivery**: Background job integration via JoobQ
- 🔧 **Multiple Adapters**: SMTP, SendGrid, development, and custom adapters
- 📎 **Attachments**: File attachment support
- 🔐 **Secure**: Built-in security best practices
- 🧪 **Testable**: Easy to test email functionality

## Usage

### Basic Usage

Generate a mailer with default welcome email:

```bash
azu generate mailer User
```

This creates:

- `src/mailers/user_mailer.cr` - Mailer class
- `src/mailers/templates/user/welcome.text.ecr` - Plain text template
- `src/mailers/templates/user/welcome.html.ecr` - HTML template

### Custom Email Methods

Generate mailer with specific email methods:

```bash
azu generate mailer User welcome password_reset email_confirmation
```

### Common Mailer Types

#### User Notifications

```bash
azu generate mailer User welcome password_reset email_confirmation
```

#### Order/Transaction Emails

```bash
azu generate mailer Order confirmation shipped delivered
```

#### Newsletter/Marketing

```bash
azu generate mailer Newsletter weekly_digest promotional announcement
```

#### System Notifications

```bash
azu generate mailer System error_alert backup_complete security_notice
```

## Arguments

| Argument       | Type    | Description              | Required                   |
| -------------- | ------- | ------------------------ | -------------------------- |
| `<name>`       | string  | Mailer name (PascalCase) | Yes                        |
| `[methods...]` | strings | Email method names       | No (defaults to `welcome`) |

## Options

| Option       | Description              | Default |
| ------------ | ------------------------ | ------- |
| `--async`    | Enable async delivery    | `true`  |
| `--no-async` | Disable async delivery   |         |
| `--force`    | Overwrite existing files | `false` |

## Generated Files

### Directory Structure

```
src/
├── mailers/
│   ├── user_mailer.cr                      # Mailer class
│   ├── templates/
│   │   └── user/
│   │       ├── welcome.text.ecr            # Plain text template
│   │       ├── welcome.html.ecr            # HTML template
│   │       ├── password_reset.text.ecr
│   │       └── password_reset.html.ecr
│   └── base_mailer.cr                      # Base mailer (if not exists)
└── jobs/
    └── user_mailer_job.cr                  # Async delivery job (if --async)
```

### Mailer Class

```crystal
require "carbon"
require "../base_mailer"

# User mailer for user-related emails
class UserMailer < BaseMailer
  # Send welcome email
  def welcome(to email : Carbon::Address, **params)
    welcome_email(to: email, **params)
  end

  private def welcome_email(to email : Carbon::Address, **params)
    Carbon::Email.new(
      to: email,
      from: Carbon::Address.new(from_email, from_name),
      subject: "Welcome",
      text_body: render_text("user/welcome", params),
      html_body: render_html("user/welcome", params)
    )
  end

  # Send password reset email
  def password_reset(to email : Carbon::Address, **params)
    password_reset_email(to: email, **params)
  end

  private def password_reset_email(to email : Carbon::Address, **params)
    Carbon::Email.new(
      to: email,
      from: Carbon::Address.new(from_email, from_name),
      subject: "Password Reset",
      text_body: render_text("user/password_reset", params),
      html_body: render_html("user/password_reset", params)
    )
  end

  # Deliver welcome email asynchronously
  def welcome_later(to email : Carbon::Address, **params)
    UserMailerJob.perform_later(
      action: "welcome",
      to: email.to_s,
      params: params.to_h
    )
  end

  # Deliver password reset email asynchronously
  def password_reset_later(to email : Carbon::Address, **params)
    UserMailerJob.perform_later(
      action: "password_reset",
      to: email.to_s,
      params: params.to_h
    )
  end
end
```

### Base Mailer

```crystal
require "carbon"

# Base mailer with common configuration and helpers
abstract class BaseMailer
  # Default from email
  def from_email : String
    ENV["FROM_EMAIL"]? || "noreply@example.com"
  end

  # Default from name
  def from_name : String
    ENV["FROM_NAME"]? || "My App"
  end

  # Render plain text template
  def render_text(template : String, params : NamedTuple) : String
    path = "src/mailers/templates/#{template}.text.ecr"
    ECR.render(path)
  end

  # Render HTML template
  def render_html(template : String, params : NamedTuple) : String
    path = "src/mailers/templates/#{template}.html.ecr"
    ECR.render(path)
  end

  # Helper: Format currency
  def format_currency(amount : Float64) : String
    "$%.2f" % amount
  end

  # Helper: Format date
  def format_date(date : Time) : String
    date.to_s("%B %d, %Y")
  end
end
```

### Email Templates

#### HTML Template (`welcome.html.ecr`)

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Welcome to <%= params[:app_name] %></title>
    <style>
      body {
        font-family: Arial, sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 600px;
        margin: 0 auto;
        padding: 20px;
      }
      .header {
        background-color: #007bff;
        color: white;
        padding: 20px;
        text-align: center;
      }
      .content {
        padding: 30px 20px;
      }
      .button {
        display: inline-block;
        padding: 12px 30px;
        background-color: #007bff;
        color: white;
        text-decoration: none;
        border-radius: 5px;
        margin: 20px 0;
      }
      .footer {
        text-align: center;
        color: #666;
        font-size: 12px;
        padding: 20px;
        border-top: 1px solid #ddd;
      }
    </style>
  </head>
  <body>
    <div class="header">
      <h1>Welcome to <%= params[:app_name] %>!</h1>
    </div>

    <div class="content">
      <p>Hi <%= params[:user_name] %>,</p>

      <p>Thank you for signing up! We're excited to have you on board.</p>

      <p>
        To get started, please confirm your email address by clicking the button
        below:
      </p>

      <p style="text-align: center;">
        <a href="<%= params[:confirmation_url] %>" class="button">
          Confirm Email Address
        </a>
      </p>

      <p>
        If the button doesn't work, you can also copy and paste this link into
        your browser:
      </p>
      <p><%= params[:confirmation_url] %></p>

      <p>If you didn't create an account, you can safely ignore this email.</p>

      <p>
        Best regards,<br />
        The <%= params[:app_name] %> Team
      </p>
    </div>

    <div class="footer">
      <p>This email was sent to <%= params[:user_email] %></p>
      <p><%= params[:app_name] %> | <%= params[:company_address] %></p>
    </div>
  </body>
</html>
```

#### Text Template (`welcome.text.ecr`)

```text
Welcome to <%= params[:app_name] %>!

Hi <%= params[:user_name] %>,

Thank you for signing up! We're excited to have you on board.

To get started, please confirm your email address by visiting:
<%= params[:confirmation_url] %>

If you didn't create an account, you can safely ignore this email.

Best regards,
The <%= params[:app_name] %> Team

---
This email was sent to <%= params[:user_email] %>
<%= params[:app_name] %> | <%= params[:company_address] %>
```

### Async Job (with --async)

```crystal
require "joobq"
require "../mailers/user_mailer"

# Background job for async email delivery
struct UserMailerJob
  include JoobQ::Job

  queue "mailers"

  property action : String
  property to : String
  property params : Hash(String, String)

  def perform
    email_address = Carbon::Address.new(to)
    mailer = UserMailer.new

    case action
    when "welcome"
      email = mailer.welcome(email_address, **named_tuple_from_hash(params))
      email.deliver
    when "password_reset"
      email = mailer.password_reset(email_address, **named_tuple_from_hash(params))
      email.deliver
    else
      raise "Unknown mailer action: #{action}"
    end

    Log.info { "Delivered #{action} email to #{to}" }
  end

  private def named_tuple_from_hash(hash : Hash(String, String))
    hash.transform_keys(&.to_sym)
  end
end
```

## Email Adapter Configuration

### Development Adapter

Prints emails to console (no external services required):

```crystal
# src/config/carbon.cr
Carbon::DevAdapter.configure do |settings|
  settings.print_emails = true
end
```

### SMTP Adapter

For production use with any SMTP server:

```crystal
Carbon::SmtpAdapter.configure do |settings|
  settings.host = ENV["SMTP_HOST"]
  settings.port = ENV["SMTP_PORT"].to_i
  settings.username = ENV["SMTP_USERNAME"]
  settings.password = ENV["SMTP_PASSWORD"]
  settings.use_tls = true
end
```

### SendGrid Adapter

For SendGrid email service:

```crystal
Carbon::SendGridAdapter.configure do |settings|
  settings.api_key = ENV["SENDGRID_API_KEY"]
end
```

### Custom Adapter

Create your own adapter:

```crystal
class MyCustomAdapter < Carbon::Adapter
  def deliver(email : Carbon::Email)
    # Your delivery logic
  end
end

Carbon.adapter = MyCustomAdapter.new
```

## Usage Examples

### Send Welcome Email

```crystal
# Synchronous delivery
mailer = UserMailer.new
email = mailer.welcome(
  to: Carbon::Address.new("user@example.com", "John Doe"),
  user_name: "John",
  app_name: "My App",
  confirmation_url: "https://app.com/confirm/abc123",
  user_email: "user@example.com",
  company_address: "123 Main St, City, State 12345"
)
email.deliver

# Asynchronous delivery (via background job)
mailer.welcome_later(
  to: Carbon::Address.new("user@example.com", "John Doe"),
  user_name: "John",
  app_name: "My App",
  confirmation_url: "https://app.com/confirm/abc123",
  user_email: "user@example.com",
  company_address: "123 Main St, City, State 12345"
)
```

### Send Password Reset

```crystal
user = User.find_by_email("user@example.com")
token = generate_password_reset_token(user)

OrderMailer.new.password_reset_later(
  to: Carbon::Address.new(user.email, user.name),
  user_name: user.name,
  reset_url: "https://app.com/reset/#{token}",
  expiry_time: "24 hours"
)
```

### Send Order Confirmation

```crystal
order = Order.find(order_id)

OrderMailer.new.confirmation_later(
  to: Carbon::Address.new(order.customer_email, order.customer_name),
  order_id: order.id.to_s,
  order_total: format_currency(order.total),
  order_items: order.items.map(&.to_json),
  tracking_url: "https://app.com/orders/#{order.id}"
)
```

### Send with Attachments

```crystal
mailer = InvoiceMailer.new
email = mailer.invoice(
  to: Carbon::Address.new("customer@example.com"),
  invoice_number: "INV-001"
)

# Add PDF attachment
pdf_data = generate_invoice_pdf(invoice)
email.attach(
  file_name: "invoice-001.pdf",
  data: pdf_data,
  mime_type: "application/pdf"
)

email.deliver
```

## Advanced Features

### Multiple Recipients

```crystal
email = UserMailer.new.newsletter(
  to: [
    Carbon::Address.new("user1@example.com"),
    Carbon::Address.new("user2@example.com"),
    Carbon::Address.new("user3@example.com")
  ],
  subject: "Monthly Newsletter",
  content: newsletter_content
)
```

### CC and BCC

```crystal
email.cc = [Carbon::Address.new("manager@example.com")]
email.bcc = [Carbon::Address.new("archive@example.com")]
```

### Custom Headers

```crystal
email.headers["X-Custom-Header"] = "custom-value"
email.headers["X-Priority"] = "high"
```

### Reply-To

```crystal
email.reply_to = Carbon::Address.new("support@example.com", "Support Team")
```

### Email Priorities

```crystal
# High priority
email.headers["X-Priority"] = "1"
email.headers["Importance"] = "high"

# Low priority
email.headers["X-Priority"] = "5"
email.headers["Importance"] = "low"
```

## Template Helpers

### Common Helpers

Add to `BaseMailer`:

```crystal
abstract class BaseMailer
  # Format money
  def format_money(amount : Float64, currency : String = "USD") : String
    case currency
    when "USD"
      "$%.2f" % amount
    when "EUR"
      "€%.2f" % amount
    else
      "#{currency} %.2f" % amount
    end
  end

  # Format date
  def format_date(date : Time, format : String = "%B %d, %Y") : String
    date.to_s(format)
  end

  # Pluralize
  def pluralize(count : Int32, singular : String, plural : String? = nil) : String
    plural ||= "#{singular}s"
    count == 1 ? "#{count} #{singular}" : "#{count} #{plural}"
  end

  # Truncate
  def truncate(text : String, length : Int32 = 100, suffix : String = "...") : String
    text.size <= length ? text : "#{text[0...length]}#{suffix}"
  end

  # Link button
  def link_button(text : String, url : String, color : String = "#007bff") : String
    <<-HTML
    <a href="#{url}" style="display: inline-block; padding: 12px 30px; background-color: #{color}; color: white; text-decoration: none; border-radius: 5px;">
      #{text}
    </a>
    HTML
  end
end
```

## Testing

### Unit Tests

```crystal
require "../spec_helper"

describe UserMailer do
  describe "#welcome" do
    it "creates welcome email" do
      mailer = UserMailer.new
      email = mailer.welcome(
        to: Carbon::Address.new("test@example.com", "Test User"),
        user_name: "Test",
        app_name: "Test App",
        confirmation_url: "https://test.com/confirm/abc",
        user_email: "test@example.com",
        company_address: "Test Address"
      )

      email.to.first.address.should eq("test@example.com")
      email.subject.should eq("Welcome")
      email.html_body.should contain("Test User")
      email.html_body.should contain("https://test.com/confirm/abc")
    end
  end

  describe "#password_reset" do
    it "creates password reset email" do
      mailer = UserMailer.new
      email = mailer.password_reset(
        to: Carbon::Address.new("test@example.com"),
        user_name: "Test",
        reset_url: "https://test.com/reset/token"
      )

      email.subject.should eq("Password Reset")
      email.html_body.should contain("reset/token")
    end
  end
end
```

### Integration Tests

```crystal
describe "Email delivery" do
  it "delivers welcome email asynchronously" do
    user = create_user(email: "test@example.com")

    UserMailer.new.welcome_later(
      to: Carbon::Address.new(user.email, user.name),
      user_name: user.name,
      # ...
    )

    # Check job was enqueued
    UserMailerJob.queue.size.should eq(1)

    # Process job
    UserMailerJob.process_queue

    # Check email was delivered (using test adapter)
    Carbon::DevAdapter.emails.size.should eq(1)
    email = Carbon::DevAdapter.emails.first
    email.to.first.address.should eq(user.email)
  end
end
```

## Best Practices

### 1. Use Plain Text + HTML

Always provide both formats:

```crystal
Carbon::Email.new(
  # ...
  text_body: render_text("template"),
  html_body: render_html("template")
)
```

### 2. Personalize Emails

Use recipient's name:

```html
<p>Hi <%= params[:user_name] %>,</p>
```

### 3. Clear Call-to-Action

Make primary action obvious:

```html
<p style="text-align: center;">
  <a href="<%= params[:action_url] %>" class="button"> Take Action Now </a>
</p>
```

### 4. Responsive Design

Use mobile-friendly HTML:

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<style>
  @media only screen and (max-width: 600px) {
    .content {
      padding: 10px;
    }
  }
</style>
```

### 5. Unsubscribe Links

Always include for marketing emails:

```html
<p>
  <a href="<%= params[:unsubscribe_url] %>">Unsubscribe</a>
</p>
```

### 6. Test in Multiple Clients

Test emails in:

- Gmail
- Outlook
- Apple Mail
- Mobile devices

### 7. Monitor Delivery

Track:

- Delivery rate
- Open rate
- Click rate
- Bounce rate

## Environment Configuration

Add to `.env`:

```bash
# From Email
FROM_EMAIL=noreply@yourapp.com
FROM_NAME=Your App Name

# SMTP Configuration
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your-username
SMTP_PASSWORD=your-password

# SendGrid (alternative)
SENDGRID_API_KEY=your-sendgrid-api-key

# Company Info
COMPANY_NAME=Your Company
COMPANY_ADDRESS=123 Main St, City, State 12345
SUPPORT_EMAIL=support@yourapp.com
```

## Dependencies

Add to `shard.yml`:

```yaml
dependencies:
  carbon:
    github: luckyframework/carbon
    version: ~> 0.4.0

  # For async delivery
  joobq:
    github: azutoolkit/joobq
```

## Troubleshooting

### Emails Not Sending

**Check adapter configuration**:

```crystal
pp Carbon.adapter
```

**Check environment variables**:

```bash
echo $SMTP_HOST
echo $SMTP_USERNAME
```

**Enable debug logging**:

```crystal
Carbon.configure do |settings|
  settings.debug = true
end
```

### Templates Not Found

Verify template paths:

```bash
ls -la src/mailers/templates/user/
```

### Async Delivery Not Working

Ensure JoobQ workers are running:

```bash
azu jobs:worker
```

Check job queue:

```bash
azu jobs:status
```

## Related Documentation

- [Carbon Email Documentation](https://github.com/luckyframework/carbon)
- [JoobQ Background Jobs](../commands/jobs.md)
- [Email Best Practices](../guides/email-best-practices.md)

## See Also

- [`azu generate job`](joobq.md) - Generate background jobs
- [`azu jobs:worker`](../commands/jobs.md) - Run job workers
- [Email Templates Guide](../guides/email-templates.md)
