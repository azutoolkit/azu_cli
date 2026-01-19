# JOOBQ Framework Patterns Reference

This document defines the patterns that azu_cli must enforce when generating JOOBQ background job code.

## Job Class Pattern

### Basic Job

```crystal
# src/jobs/send_welcome_email_job.cr
class SendWelcomeEmailJob
  include Joobq::Job
  
  # Job configuration
  queue "emails"
  retry_on Timeout::Error, attempts: 3, delay: 30.seconds
  discard_on User::NotFoundError
  
  # Job arguments - must be JSON serializable
  getter user_id : Int64
  
  def initialize(@user_id)
  end
  
  def perform
    user = UserRepository.find!(@user_id)
    
    Mailer.welcome(user).deliver
    
    log.info { "Welcome email sent to #{user.email}" }
  rescue ex : Mailer::DeliveryError
    log.error { "Failed to send email: #{ex.message}" }
    raise ex  # Will trigger retry
  end
end
```

### Job with Multiple Arguments

```crystal
class ProcessOrderJob
  include Joobq::Job
  
  queue "orders"
  retry_on NetworkError, attempts: 5, delay: :exponential
  
  getter order_id : Int64
  getter notify_customer : Bool
  getter priority : String
  
  def initialize(@order_id, @notify_customer = true, @priority = "normal")
  end
  
  def perform
    order = OrderRepository.find!(@order_id)
    
    OrderProcessor.new(order).process!
    
    if @notify_customer
      SendOrderConfirmationJob.perform_async(order.id)
    end
    
    log.info { "Order #{order.id} processed with priority #{@priority}" }
  end
end
```

### Job with Complex Arguments

```crystal
class ImportDataJob
  include Joobq::Job
  
  queue "imports"
  timeout 30.minutes
  
  # Use a struct for complex arguments
  struct ImportConfig
    include JSON::Serializable
    
    getter file_path : String
    getter format : String
    getter options : Hash(String, String)
    
    def initialize(@file_path, @format = "csv", @options = {} of String => String)
    end
  end
  
  getter config : ImportConfig
  
  def initialize(@config)
  end
  
  def perform
    importer = DataImporter.new(@config.file_path, @config.format)
    result = importer.import(@config.options)
    
    log.info { "Imported #{result.count} records" }
  end
end
```

## Queue Configuration Pattern

### Queue Definition

```crystal
# config/joobq.cr
Joobq.configure do |config|
  # Redis connection
  config.redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  
  # Define queues with priorities
  config.queues do |q|
    q.add "critical", workers: 5, priority: 1
    q.add "default", workers: 10, priority: 2
    q.add "emails", workers: 3, priority: 3
    q.add "reports", workers: 2, priority: 4
    q.add "imports", workers: 1, priority: 5
  end
  
  # Global settings
  config.default_queue = "default"
  config.max_retries = 3
  config.retry_delay = 30.seconds
  
  # Dead letter queue
  config.dead_letter_queue = "dead"
  config.dead_letter_ttl = 7.days
  
  # Logging
  config.log_level = :info
end
```

### Queue Priority Table

| Queue | Workers | Priority | Use Case |
|-------|---------|----------|----------|
| critical | 5 | 1 (highest) | Payment processing, urgent notifications |
| default | 10 | 2 | General background tasks |
| emails | 3 | 3 | Email delivery |
| reports | 2 | 4 | Report generation |
| imports | 1 | 5 (lowest) | Bulk data imports |

## Retry Pattern

### Retry Configuration

```crystal
class FlakeyServiceJob
  include Joobq::Job
  
  # Retry specific exceptions
  retry_on Timeout::Error, attempts: 3, delay: 30.seconds
  retry_on RateLimitError, attempts: 5, delay: 1.minute
  
  # Exponential backoff
  retry_on NetworkError, attempts: 5, delay: :exponential
  # Results in: 1s, 2s, 4s, 8s, 16s delays
  
  # Custom backoff
  retry_on CustomError, attempts: 3, delay: ->(attempt : Int32) {
    (attempt * 10).seconds
  }
  
  # Discard (don't retry) specific exceptions
  discard_on InvalidDataError
  discard_on RecordNotFound
  
  def perform
    # Job logic
  end
end
```

### Manual Retry Control

```crystal
class SmartRetryJob
  include Joobq::Job
  
  getter attempt : Int32 = 0
  
  def perform
    @attempt += 1
    
    begin
      risky_operation
    rescue ex : TransientError
      if @attempt < 3
        retry_in((@attempt * 30).seconds)
      else
        log.error { "Giving up after #{@attempt} attempts" }
        raise ex
      end
    end
  end
end
```

## Scheduled Jobs Pattern

### Cron-style Scheduling

```crystal
# config/schedule.cr
Joobq.schedule do |s|
  # Every minute
  s.every(1.minute) { CleanupTempFilesJob.perform_async }
  
  # Every hour at minute 0
  s.cron("0 * * * *") { HourlyReportJob.perform_async }
  
  # Daily at midnight
  s.daily(at: "00:00") { DailyDigestJob.perform_async }
  
  # Weekly on Monday at 9am
  s.weekly(on: :monday, at: "09:00") { WeeklyReportJob.perform_async }
  
  # Monthly on the 1st at midnight
  s.monthly(day: 1, at: "00:00") { MonthlyBillingJob.perform_async }
  
  # Custom cron expression
  s.cron("0 9 * * 1-5") { WeekdayReminderJob.perform_async }  # Weekdays at 9am
end
```

### Scheduled Job Class

```crystal
class DailyCleanupJob
  include Joobq::Job
  include Joobq::Scheduled
  
  queue "maintenance"
  schedule "0 0 * * *"  # Daily at midnight
  
  def perform
    # Cleanup old records
    Session.where("expires_at < ?", Time.utc).delete_all
    TempFile.where("created_at < ?", 7.days.ago).delete_all
    
    log.info { "Daily cleanup completed" }
  end
end
```

## Worker Pattern

### Custom Worker

```crystal
class PriorityWorker < Joobq::Worker
  def initialize
    super(
      queues: ["critical", "default"],
      concurrency: 5,
      shutdown_timeout: 30.seconds
    )
  end
  
  def before_perform(job : Joobq::Job)
    log.info { "Starting job: #{job.class.name}" }
    Metrics.increment("jobs.started", tags: {job: job.class.name})
  end
  
  def after_perform(job : Joobq::Job)
    log.info { "Completed job: #{job.class.name}" }
    Metrics.increment("jobs.completed", tags: {job: job.class.name})
  end
  
  def on_error(job : Joobq::Job, error : Exception)
    log.error { "Job failed: #{job.class.name} - #{error.message}" }
    Metrics.increment("jobs.failed", tags: {job: job.class.name})
    ErrorTracker.capture(error, context: {job_id: job.id})
  end
end
```

## Job Invocation Pattern

### Asynchronous Execution

```crystal
# Basic async execution
SendWelcomeEmailJob.perform_async(user.id)

# With delay
SendReminderJob.perform_in(1.hour, user.id)

# At specific time
SendBirthdayEmailJob.perform_at(user.birthday.at_beginning_of_day, user.id)

# Bulk enqueue
user_ids.each do |id|
  SendNewsletterJob.perform_async(id)
end

# Batch processing
Joobq.batch do |batch|
  batch.description = "Process monthly invoices"
  batch.on_complete = BatchCompleteJob
  batch.on_success = NotifyAdminJob
  
  invoices.each do |invoice|
    batch.add ProcessInvoiceJob.new(invoice.id)
  end
end
```

### Job Options

```crystal
# Specify queue at runtime
SendEmailJob.set(queue: "high_priority").perform_async(user.id)

# Override retry settings
RiskyJob.set(retry: 5).perform_async(data)

# Set deadline
TimelyJob.set(deadline: 1.hour.from_now).perform_async(task_id)

# Unique jobs (prevent duplicates)
UniqueJob.set(unique: true, unique_for: 5.minutes).perform_async(key)
```

## Middleware Pattern

### Job Middleware

```crystal
# config/joobq.cr
Joobq.configure do |config|
  config.middleware do |m|
    m.add Joobq::Middleware::Logging
    m.add Joobq::Middleware::Timing
    m.add CustomMetricsMiddleware
    m.add TransactionMiddleware
  end
end

# Custom middleware
class TransactionMiddleware < Joobq::Middleware
  def call(job : Joobq::Job, &block)
    if job.responds_to?(:use_transaction?) && job.use_transaction?
      CQL.transaction { yield }
    else
      yield
    end
  end
end
```

## Error Handling Pattern

### Comprehensive Error Handling

```crystal
class RobustJob
  include Joobq::Job
  
  queue "default"
  retry_on StandardError, attempts: 3
  
  def perform
    with_error_handling do
      process_data
    end
  end
  
  private def with_error_handling(&)
    yield
  rescue ex : NetworkError
    log.warn { "Network error, will retry: #{ex.message}" }
    raise ex
  rescue ex : ValidationError
    log.error { "Validation failed: #{ex.message}" }
    # Don't retry, just log and notify
    ErrorTracker.capture(ex)
  rescue ex : Exception
    log.error { "Unexpected error: #{ex.message}" }
    ErrorTracker.capture(ex, severity: :critical)
    raise ex
  end
end
```

## Naming Conventions

| Component | Convention | Example |
|-----------|------------|---------|
| Job Class | Action + Job | `SendEmailJob`, `ProcessOrderJob` |
| Queue Name | lowercase, descriptive | `emails`, `reports`, `imports` |
| Scheduled Job | Frequency + Action + Job | `DailyCleanupJob`, `HourlyReportJob` |
| Worker | Purpose + Worker | `PriorityWorker`, `ImportWorker` |
| Middleware | Purpose + Middleware | `LoggingMiddleware`, `MetricsMiddleware` |

## File Organization

```
src/
├── jobs/
│   ├── emails/
│   │   ├── send_welcome_email_job.cr
│   │   ├── send_password_reset_job.cr
│   │   └── send_newsletter_job.cr
│   ├── orders/
│   │   ├── process_order_job.cr
│   │   └── refund_order_job.cr
│   ├── reports/
│   │   ├── daily_report_job.cr
│   │   └── monthly_report_job.cr
│   └── maintenance/
│       ├── cleanup_job.cr
│       └── sync_job.cr
├── workers/
│   └── priority_worker.cr
config/
├── joobq.cr
└── schedule.cr
```

## Testing Pattern

### Job Specs

```crystal
# spec/jobs/send_welcome_email_job_spec.cr
require "spec"
require "joobq/testing"

describe SendWelcomeEmailJob do
  include Joobq::Testing
  
  before_each do
    Joobq::Testing.clear_all
  end
  
  it "sends welcome email to user" do
    user = UserFactory.create
    
    SendWelcomeEmailJob.perform_sync(user.id)
    
    Mailer::TestAdapter.deliveries.size.should eq(1)
    Mailer::TestAdapter.last.to.should eq(user.email)
  end
  
  it "enqueues job in emails queue" do
    user = UserFactory.create
    
    SendWelcomeEmailJob.perform_async(user.id)
    
    Joobq::Testing.size("emails").should eq(1)
    Joobq::Testing.jobs("emails").first.args.should eq([user.id])
  end
  
  it "retries on delivery failure" do
    user = UserFactory.create
    Mailer.simulate_failure!
    
    expect_raises(Mailer::DeliveryError) do
      SendWelcomeEmailJob.perform_sync(user.id)
    end
  end
end
```
