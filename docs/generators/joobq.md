# JoobQ Integration Generator

The JoobQ generator sets up complete background job processing infrastructure using the modern [JoobQ](https://github.com/azutoolkit/joobq) library for Crystal.

## Overview

JoobQ is a fast, efficient asynchronous reliable job queue and job scheduler library. It enables you to:

- Process background jobs asynchronously
- Schedule jobs to run at specific times
- Retry failed jobs automatically
- Monitor job performance and errors
- Scale job processing horizontally

## Basic Usage

### Setup JoobQ in an Existing Project

```bash
azu generate joobq
```

This command creates:

- `config/joobq.development.yml` - Development configuration
- `src/initializers/joobq.cr` - JoobQ initializer
- `src/jobs/example_job.cr` - Example job (optional)

### Generate a Background Job

```bash
# Simple job without parameters
azu generate job SendEmail

# Job with parameters
azu generate job ProcessPayment user_id:int32 amount:float64

# Job with custom queue and retry settings
azu generate job ImportData file_path:string --queue=imports --retries=5
```

## Command Options

### JoobQ Setup Options

- `--project NAME` - Project name (defaults to current directory name)
- `--redis URL` - Redis connection URL (defaults to `redis://localhost:6379`)
- `--no-example` - Skip creating example job

### Job Generator Options

- `--queue QUEUE_NAME` - Queue name (default: `default`)
- `--retries COUNT` - Number of retries on failure (default: `3`)
- `--expires DURATION` - Job expiration time (default: `1.days`)

## Generated Structure

### Configuration File

```yaml
# config/joobq.development.yml
joobq:
  settings:
    default_queue: "default"
    retries: 5
    timeout: "30 seconds"
    timezone: "UTC"
    worker_batch_size: 50

  queues:
    default:
      job_class: "ExampleJob"
      workers: 3

    mailers:
      job_class: "MailerJob"
      workers: 2

  middlewares:
    - type: "throttle"
    - type: "retry"
    - type: "timeout"

  error_monitoring:
    alert_thresholds:
      error: 10
      warn: 50
      info: 100
    time_window: "5 minutes"
    max_recent_errors: 200

  features:
    rest_api: true
    stats: true

  redis:
    host: "localhost"
    port: 6379
    password: ""
    pool_size: 200
    pool_timeout: 2.0

  pipeline:
    batch_size: 500
    timeout: 2.0
    max_commands: 2000
```

### Initializer File

```crystal
# src/initializers/joobq.cr
require "joobq"

# Require all job classes
require "../jobs/**"

# Register job types
JoobQ::QueueFactory.register_job_type(ExampleJob)
JoobQ::QueueFactory.register_job_type(EmailJob)

# Initialize from YAML config
environment = ENV["AZU_ENV"]? || "development"
JoobQ.initialize_config_with(:file, "config/joobq.#{environment}.yml")

# Disable REST API for worker processes
if ARGV.includes?("--worker")
  JoobQ.config.rest_api_enabled = false
end
```

### Job Structure

```crystal
# src/jobs/send_email_job.cr
struct SendEmailJob
  include JoobQ::Job

  # Queue configuration
  @queue   = "mailers"
  @retries = 3
  @expires = 1.hour.total_seconds.to_i

  # Job parameters
  property to : String
  property subject : String
  property body : String

  def initialize(@to : String, @subject : String, @body : String)
  end

  # Perform the job
  def perform
    # Send email logic here
    Log.info { "Sending email to #{@to}" }

    # Your email sending code...

    Log.info { "Email sent successfully" }
  rescue ex : Exception
    Log.error(exception: ex) { "Failed to send email" }
    raise ex  # Re-raise for retry mechanism
  end
end
```

## Working with Jobs

### Enqueue Jobs

```crystal
# Enqueue immediately
SendEmailJob.enqueue(
  to: "user@example.com",
  subject: "Welcome!",
  body: "Thanks for signing up"
)

# Schedule for later
SendEmailJob.schedule(
  in: 5.minutes,
  to: "user@example.com",
  subject: "Welcome!",
  body: "Thanks for signing up"
)

# Schedule at specific time
SendEmailJob.schedule(
  at: Time.utc(2025, 10, 12, 10, 0, 0),
  to: "user@example.com",
  subject: "Reminder",
  body: "Don't forget!"
)

# Enqueue with custom options
SendEmailJob.enqueue(
  to: "user@example.com",
  subject: "Important",
  body: "This is important",
  queue: "critical",
  retries: 5
)
```

### Start Workers

```bash
# Start worker from CLI
azu jobs:worker

# Start with options
azu jobs:worker --workers=5 --queues=default,mailers --verbose

# Start worker directly
crystal run src/worker.cr -- --worker

# In production with environment
AZU_ENV=production crystal run src/worker.cr -- --worker
```

### Job Queue Commands

```bash
# Start worker processes
azu jobs:worker --workers=5

# Check job status
azu jobs:status

# Clear all jobs from queue
azu jobs:clear

# Retry failed jobs
azu jobs:retry

# Start JoobQ web UI (if available)
azu jobs:ui
```

## Configuration

### Environment-Specific Configs

Create separate configuration files for each environment:

- `config/joobq.development.yml` - Development settings
- `config/joobq.test.yml` - Test settings
- `config/joobq.production.yml` - Production settings

The initializer automatically loads the correct config based on `AZU_ENV` or `CRYSTAL_ENV`.

### Queue Configuration

Define multiple queues with different priorities:

```yaml
queues:
  critical:
    job_class: "CriticalJob"
    workers: 5 # More workers for high priority

  default:
    job_class: "DefaultJob"
    workers: 3

  low_priority:
    job_class: "LowPriorityJob"
    workers: 1
```

### Middleware

JoobQ supports several middleware types:

- **throttle** - Rate limiting for job processing
- **retry** - Automatic retry with exponential backoff
- **timeout** - Job timeout enforcement

### Error Monitoring

Configure error monitoring thresholds:

```yaml
error_monitoring:
  alert_thresholds:
    error: 10 # Alert after 10 errors
    warn: 50 # Warning after 50 warnings
    info: 100 # Info after 100 info messages
  time_window: "5 minutes"
  max_recent_errors: 200
```

## REST API

JoobQ provides a REST API for job management (disabled in production by default):

### Endpoints

```bash
# Get job registry
curl http://localhost:8080/joobq/jobs/registry

# Enqueue a job
curl -X POST http://localhost:8080/joobq/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "queue": "email",
    "job_type": "EmailJob",
    "data": {
      "to": "user@example.com",
      "subject": "Hello"
    }
  }'

# Get error statistics
curl http://localhost:8080/joobq/errors/stats

# Health check
curl http://localhost:8080/joobq/health/check

# Reprocess busy jobs
curl -X POST http://localhost:8080/joobq/queues/default/reprocess
```

## Performance

JoobQ is designed for high performance:

- Processes up to **35,000 jobs/second** in benchmarks
- Efficient Redis pipelining
- Concurrent job processing
- Minimal memory overhead

### Optimization Tips

1. **Adjust Worker Count**: Match workers to your workload
2. **Use Batch Processing**: Process multiple items per job when possible
3. **Optimize Redis Pool**: Increase pool size for high throughput
4. **Queue Priorities**: Use separate queues for different priorities
5. **Monitor Performance**: Enable stats and monitor job processing times

## Integration with Azu Framework

### In Endpoints

```crystal
class Users::CreateEndpoint < Azu::Endpoint(Users::CreateRequest, Users::CreateResponse)
  def call : Users::CreateResponse
    user = User.create!(request.to_h)

    # Enqueue welcome email
    WelcomeEmailJob.enqueue(user_id: user.id)

    Users::CreateResponse.new(user: user)
  end
end
```

### In Models

```crystal
class User < CQL::Model(Int64)
  getter id : Int64?
  getter email : String
  getter name : String

  def after_create
    # Schedule job after user is created
    SendWelcomeEmailJob.schedule(
      in: 5.minutes,
      user_id: self.id.not_nil!
    )
  end
end
```

### With Mailers

```crystal
class UserMailer
  def welcome_email(user_id : Int64)
    user = User.find(user_id)

    email = Carbon::Email.new(
      to: user.email,
      subject: "Welcome!",
      text_body: "Thanks for signing up!"
    )

    email.deliver
  end
end

# Job to send emails asynchronously
struct WelcomeEmailJob
  include JoobQ::Job

  @queue = "mailers"
  @retries = 3

  property user_id : Int64

  def initialize(@user_id : Int64)
  end

  def perform
    UserMailer.new.welcome_email(@user_id)
  end
end
```

## Best Practices

### Job Design

1. **Keep Jobs Simple**: One job should do one thing
2. **Use Idempotent Operations**: Jobs may run multiple times
3. **Limit Parameters**: Use simple types (Int32, String, Bool)
4. **Handle Errors Gracefully**: Log errors but let JoobQ retry
5. **Set Appropriate Timeouts**: Don't let jobs run forever

### Error Handling

```crystal
struct RobustJob
  include JoobQ::Job

  def perform
    # Your job logic
    process_data
  rescue ex : SpecificError
    # Handle specific errors
    Log.warn { "Specific error: #{ex.message}" }
    # Don't re-raise if you want to consider this "successful"
  rescue ex : Exception
    # Log and re-raise for retry
    Log.error(exception: ex) { "Job failed" }
    raise ex
  end
end
```

### Monitoring

1. Enable stats collection in config
2. Monitor error rates
3. Track job processing times
4. Watch queue depths
5. Set up alerts for failures

## Troubleshooting

### Jobs Not Processing

- Check Redis connection: `redis-cli ping`
- Verify workers are running: `ps aux | grep worker`
- Check job is registered in initializer
- Review logs for errors

### Performance Issues

- Increase worker count
- Optimize job logic
- Increase Redis pool size
- Use batch processing
- Profile slow jobs

### Connection Issues

- Verify Redis URL is correct
- Check Redis is running
- Ensure network connectivity
- Review firewall rules

## Examples

See complete examples:

- [Basic Job Processing](../examples/joobq/basic.cr)
- [Scheduled Jobs](../examples/joobq/scheduled.cr)
- [Email Processing](../examples/joobq/emails.cr)
- [Data Import](../examples/joobq/import.cr)

## Related Documentation

- [Job Generator](job.md)
- [Mailer Generator](mailer.md)
- [Configuration](../configuration/project-config.md)
- [JoobQ GitHub](https://github.com/azutoolkit/joobq)
