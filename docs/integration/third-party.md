# Third-party Library Integration

The Azu CLI supports integration with various third-party libraries and tools in the Crystal ecosystem, enabling developers to leverage existing solutions and extend functionality.

## Overview

Third-party integration capabilities include:

- **Authentication Libraries**: Authly, Crystal Auth, and custom auth providers
- **Background Job Systems**: JoobQ, Sidekiq, and custom job queues
- **Template Engines**: Jinja, ECR, and custom template systems
- **Testing Frameworks**: Spec, Minitest, and custom test runners
- **Development Tools**: Linters, formatters, and code analyzers
- **Deployment Tools**: Docker, Kubernetes, and cloud platforms

## Authentication Libraries

### Authly Integration

```yaml
# azu.yml
authentication:
  provider: "authly"
  version: "latest"

  # Authly configuration
  authly:
    secret_key: "${AZU_AUTH_SECRET}"
    session_timeout: 24.hours
    remember_me: true
    password_reset: true
    email_verification: true
```

```crystal
# src/initializers/auth.cr
require "authly"

Authly.configure do |config|
  config.secret_key = ENV["AZU_AUTH_SECRET"]
  config.session_timeout = 24.hours
  config.remember_me = true
  config.password_reset = true
  config.email_verification = true
end
```

### Custom Authentication Provider

```crystal
# src/auth/custom_provider.cr
class CustomAuthProvider < Azu::Auth::Provider
  def authenticate(request)
    # Custom authentication logic
    token = request.headers["Authorization"]?
    return nil unless token

    # Validate token
    user = User.find_by(token: token)
    user if user&.active?
  end

  def login(user, request)
    # Custom login logic
    token = generate_token(user)
    user.update(token: token)
    token
  end

  def logout(user, request)
    # Custom logout logic
    user.update(token: nil)
  end
end
```

### OAuth Integration

```crystal
# OAuth configuration
class OAuthProvider < Azu::Auth::Provider
  def initialize(@provider : String, @client_id : String, @client_secret : String)
  end

  def authenticate(request)
    code = request.params["code"]?
    return nil unless code

    # Exchange code for token
    token = exchange_code_for_token(code)

    # Get user info
    user_info = get_user_info(token)

    # Find or create user
    User.find_or_create_by(oauth_id: user_info["id"]) do |user|
      user.email = user_info["email"]
      user.name = user_info["name"]
    end
  end
end
```

## Background Job Systems

### JoobQ Integration

```yaml
# azu.yml
background_jobs:
  provider: "joobq"
  version: "latest"

  # JoobQ configuration
  joobq:
    redis_url: "${AZU_REDIS_URL}"
    workers: 4
    retry_attempts: 3
    retry_delay: 5.minutes
```

```crystal
# src/initializers/jobs.cr
require "joobq"

JoobQ.configure do |config|
  config.redis_url = ENV["AZU_REDIS_URL"]
  config.workers = ENV["AZU_JOB_WORKERS"]?.try(&.to_i) || 4
  config.retry_attempts = 3
  config.retry_delay = 5.minutes
end
```

### Job Generation

```bash
# Generate job with JoobQ integration
azu generate job SendWelcomeEmail --provider=joobq

# Generate job with custom options
azu generate job ProcessPayment \
  --provider=joobq \
  --retry=3 \
  --timeout=30 \
  --queue=high_priority
```

### Generated Job

```crystal
# Generated job with JoobQ
class SendWelcomeEmailJob < JoobQ::Job
  # Job configuration
  retry_attempts 3
  retry_delay 5.minutes
  timeout 30.seconds
  queue "default"

  # Job parameters
  property user_id : UUID

  def initialize(@user_id)
  end

  def perform
    user = User.find(@user_id)
    return unless user

    EmailService.send_welcome_email(user)
  end

  def on_failure(error)
    # Handle job failure
    Azu.logger.error "Failed to send welcome email: #{error.message}"
  end
end
```

### Custom Job Provider

```crystal
# Custom job provider
class CustomJobProvider < Azu::Jobs::Provider
  def initialize(@queue_url : String)
  end

  def enqueue(job_class, *args)
    # Custom job enqueue logic
    job_data = {
      class: job_class.name,
      args: args,
      enqueued_at: Time.utc
    }

    # Send to custom queue
    send_to_queue(@queue_url, job_data)
  end

  def process_jobs
    # Custom job processing logic
    loop do
      job_data = receive_from_queue(@queue_url)
      break unless job_data

      job_class = job_data["class"].as(String)
      args = job_data["args"].as(Array)

      # Execute job
      job_class.constantize.new(*args).perform
    end
  end
end
```

## Template Engines

### Jinja Integration

```yaml
# azu.yml
template_engine:
  provider: "jinja"
  version: "latest"

  # Jinja configuration
  jinja:
    auto_reload: true
    cache_size: 100
    debug: false
```

```crystal
# src/initializers/templates.cr
require "jinja"

Jinja.configure do |config|
  config.template_paths = ["src/pages", "src/components"]
  config.auto_reload = Azu.env.development?
  config.cache_size = 100
  config.debug = Azu.env.development?
end
```

### Template Generation

```bash
# Generate page with Jinja
azu generate page users/index --engine=jinja

# Generate component with Jinja
azu generate component UserCard --engine=jinja
```

### Generated Template

```jinja
{# Generated Jinja template #}
{% extends "layout.jinja" %}

{% block title %}Users{% endblock %}

{% block content %}
<div class="container">
  <h1>Users</h1>

  <div class="row">
    {% for user in users %}
      <div class="col-md-4">
        {% include "components/user_card.jinja" %}
      </div>
    {% endfor %}
  </div>

  {% if users.has_previous %}
    <a href="?page={{ users.previous_page_number }}" class="btn btn-primary">Previous</a>
  {% endif %}

  {% if users.has_next %}
    <a href="?page={{ users.next_page_number }}" class="btn btn-primary">Next</a>
  {% endif %}
</div>
{% endblock %}
```

### ECR Integration

```yaml
# azu.yml
template_engine:
  provider: "ecr"

  # ECR configuration
  ecr:
    auto_reload: true
    cache_templates: false
```

```crystal
# ECR template generation
class UsersPage < Azu::Page
  def initialize(@users : Array(User))
  end

  def render
    ECR.render("src/pages/users/index.ecr")
  end
end
```

## Testing Frameworks

### Spec Integration

```yaml
# azu.yml
testing:
  framework: "spec"
  version: "latest"

  # Spec configuration
  spec:
    parallel: true
    coverage: true
    coverage_threshold: 80
    random_seed: true
```

```crystal
# spec/spec_helper.cr
require "spec"
require "azu/test"

# Configure test environment
Azu.configure do |config|
  config.env = :test
  config.database_url = "postgresql://localhost/myapp_test"
end
```

### Test Generation

```bash
# Generate test with Spec
azu generate test UserEndpoint --framework=spec

# Generate test with custom options
azu generate test UserService \
  --framework=spec \
  --coverage=true \
  --parallel=true
```

### Generated Test

```crystal
# Generated Spec test
require "spec"
require "../spec_helper"

describe UserEndpoint do
  before_each do
    Database.clean
  end

  describe "GET /users" do
    it "returns list of users" do
      user = User.create!(email: "test@example.com", name: "Test User")

      get "/users"

      response.status_code.should eq(200)
      response.body.should contain(user.name)
    end
  end

  describe "POST /users" do
    it "creates new user" do
      user_data = {
        email: "new@example.com",
        name: "New User"
      }

      post "/users", json: user_data

      response.status_code.should eq(201)
      User.find_by(email: "new@example.com").should_not be_nil
    end

    it "validates required fields" do
      post "/users", json: {}

      response.status_code.should eq(422)
      response.body.should contain("email")
    end
  end
end
```

### Minitest Integration

```crystal
# Minitest configuration
require "minitest/autorun"
require "azu/test"

class UserEndpointTest < Minitest::Test
  def setup
    Database.clean
  end

  def test_creates_user
    user_data = {email: "test@example.com", name: "Test User"}

    post "/users", json: user_data

    assert_equal 201, response.status_code
    assert User.find_by(email: "test@example.com")
  end
end
```

## Development Tools

### Linter Integration

```yaml
# azu.yml
development:
  linting:
    provider: "ameba"
    version: "latest"

    # Ameba configuration
    ameba:
      config_file: ".ameba.yml"
      parallel: true
      fail_fast: false
```

```bash
# Run linter
azu lint

# Run linter with specific rules
azu lint --rules=Style,Performance

# Fix auto-fixable issues
azu lint --fix
```

### Formatter Integration

```yaml
# azu.yml
development:
  formatting:
    provider: "crystal"
    version: "latest"

    # Crystal formatter configuration
    crystal:
      check: true
      format: true
```

```bash
# Format code
azu format

# Check formatting without changes
azu format --check

# Format specific files
azu format src/endpoints/*.cr
```

### Code Analyzer Integration

```yaml
# azu.yml
development:
  analysis:
    provider: "crystal"

    # Analysis configuration
    crystal:
      hierarchy: true
      dependencies: true
      complexity: true
```

```bash
# Analyze code
azu analyze

# Show type hierarchy
azu analyze --hierarchy

# Show dependencies
azu analyze --dependencies

# Check complexity
azu analyze --complexity
```

## Deployment Tools

### Docker Integration

```yaml
# azu.yml
deployment:
  docker:
    enabled: true
    multi_stage: true
    optimization: true

    # Docker configuration
    dockerfile:
      base_image: "crystallang/crystal:latest"
      build_args:
        - "CRYSTAL_VERSION=1.16.0"
      ports:
        - "8080:8080"
```

```dockerfile
# Generated Dockerfile
FROM crystallang/crystal:1.16.0 AS builder

WORKDIR /app
COPY shard.yml shard.lock ./
RUN shards install

COPY . .
RUN crystal build --release src/main.cr

FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    libssl1.1 \
    libevent-2.1-7 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/main ./

EXPOSE 8080
CMD ["./main"]
```

### Kubernetes Integration

```yaml
# azu.yml
deployment:
  kubernetes:
    enabled: true

    # Kubernetes configuration
    kubernetes:
      namespace: "myapp"
      replicas: 3
      resources:
        requests:
          memory: "256Mi"
          cpu: "250m"
        limits:
          memory: "512Mi"
          cpu: "500m"
```

```yaml
# Generated Kubernetes manifests
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:latest
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
```

### Cloud Platform Integration

#### AWS Integration

```yaml
# azu.yml
deployment:
  aws:
    enabled: true

    # AWS configuration
    aws:
      region: "us-west-2"
      ecr_repository: "myapp"
      ecs_cluster: "myapp-cluster"
      load_balancer: "myapp-alb"
```

```bash
# Deploy to AWS
azu deploy --platform=aws

# Build and push Docker image
azu deploy --platform=aws --build

# Update ECS service
azu deploy --platform=aws --update
```

#### Google Cloud Integration

```yaml
# azu.yml
deployment:
  gcp:
    enabled: true

    # GCP configuration
    gcp:
      project: "myapp-project"
      region: "us-central1"
      cloud_run_service: "myapp"
```

```bash
# Deploy to Google Cloud
azu deploy --platform=gcp

# Deploy to Cloud Run
azu deploy --platform=gcp --service=cloud-run
```

## Custom Integrations

### Plugin System

```crystal
# Custom integration plugin
class CustomIntegrationPlugin < Azu::Plugin
  def initialize
    @name = "custom_integration"
    @version = "1.0.0"
    @description = "Custom third-party integration"
  end

  def install
    # Installation logic
    add_dependency "custom_library", "~> 1.0"
    generate_files
  end

  def configure(config)
    # Configuration logic
    config.set("custom_integration.enabled", true)
    config.set("custom_integration.api_key", ENV["CUSTOM_API_KEY"])
  end

  private def generate_files
    # Generate integration files
    generate_file "src/integrations/custom_integration.cr"
    generate_file "spec/integrations/custom_integration_spec.cr"
  end
end
```

### Integration Commands

```bash
# Install integration
azu integration install custom_integration

# Configure integration
azu integration configure custom_integration

# Test integration
azu integration test custom_integration

# Remove integration
azu integration remove custom_integration
```

## Configuration Management

### Integration Configuration

```yaml
# azu.yml
integrations:
  # Authentication
  authly:
    enabled: true
    version: "latest"
    config:
      secret_key: "${AZU_AUTH_SECRET}"

  # Background jobs
  joobq:
    enabled: true
    version: "latest"
    config:
      redis_url: "${AZU_REDIS_URL}"

  # Template engine
  jinja:
    enabled: true
    version: "latest"
    config:
      auto_reload: true

  # Testing
  spec:
    enabled: true
    version: "latest"
    config:
      parallel: true
      coverage: true

  # Development tools
  ameba:
    enabled: true
    version: "latest"
    config:
      config_file: ".ameba.yml"

  # Deployment
  docker:
    enabled: true
    config:
      multi_stage: true
      optimization: true
```

### Environment-Specific Configuration

```yaml
# azu.yml
integrations:
  authly:
    development:
      debug: true
      session_timeout: 1.hour
    production:
      debug: false
      session_timeout: 24.hours

  joobq:
    development:
      workers: 1
      retry_attempts: 1
    production:
      workers: 4
      retry_attempts: 3
```

## Troubleshooting

### Common Issues

**Version Conflicts**: Ensure compatible versions between CLI and third-party libraries.

**Configuration Errors**: Verify integration configuration and environment variables.

**Performance Issues**: Monitor integration performance and optimize as needed.

**Dependency Conflicts**: Resolve dependency conflicts between different integrations.

### Debug Commands

```bash
# Check integration status
azu integration status

# Validate integration configuration
azu integration validate

# Test integration connectivity
azu integration test

# Show integration information
azu integration info
```

### Debugging Integrations

```crystal
# Enable integration debugging
Azu.configure do |config|
  config.integrations.debug = true
  config.integrations.log_level = :debug
end

# Custom integration debugging
class CustomIntegration
  def self.debug(message)
    Azu.logger.debug "[CustomIntegration] #{message}"
  end
end
```

## Best Practices

### Integration Management

1. **Version Compatibility**: Keep CLI and integration versions in sync
2. **Configuration**: Use environment-specific configurations
3. **Testing**: Test integrations thoroughly in development
4. **Documentation**: Document custom integration patterns

### Performance

1. **Monitoring**: Monitor integration performance
2. **Caching**: Implement appropriate caching strategies
3. **Connection Pooling**: Use connection pooling for external services
4. **Error Handling**: Implement proper error handling and retry logic

### Security

1. **Secrets Management**: Use secure secrets management
2. **API Keys**: Store API keys securely using environment variables
3. **Authentication**: Implement proper authentication for external services
4. **Validation**: Validate all data from external integrations

## Support and Resources

### Documentation

- [Authly Documentation](https://github.com/azutoolkit/authly)
- [JoobQ Documentation](https://github.com/azutoolkit/joobq)
- [Jinja Documentation](https://github.com/mamantoha/jinja)
- [Spec Documentation](https://crystal-lang.org/reference/1.16/guides/testing.html)

### Community

- **GitHub**: Report issues and contribute
- **Discord**: Join the Azu community
- **Examples**: Sample integration patterns
- **Tutorials**: Step-by-step integration guides

### Getting Help

- **Documentation**: Comprehensive integration guides
- **Community Support**: Ask questions in Discord
- **Issue Tracking**: Report bugs on GitHub
- **Contributing**: Contribute to integration development
