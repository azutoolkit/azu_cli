# Jobs Commands

Background job processing commands for managing JoobQ workers and queues.

## Overview

The Azu CLI provides comprehensive commands for managing background jobs using the JoobQ framework. These commands handle worker processes, monitor queue status, retry failed jobs, and provide a web interface for job management.

## Prerequisites

Before using job commands, ensure:

1. **JoobQ is installed** in your project:
   ```bash
   azu generate joobq
   ```

2. **Redis is running**:
   ```bash
   redis-server
   ```

3. **Redis URL is configured**:
   ```bash
   export REDIS_URL="redis://localhost:6379"
   ```

## Commands

### `azu jobs:worker`

Start background job worker processes to execute queued jobs.

#### Synopsis

```bash
azu jobs:worker [options]
```

#### Description

Starts one or more worker processes that poll the job queue and execute background jobs. Workers run continuously until stopped with `Ctrl+C`.

#### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--workers <n>` | `-w` | Number of worker processes | 1 |
| `--queues <list>` | `-q` | Comma-separated queue names | `default` |
| `--daemon` | `-d` | Run as daemon process | `false` |
| `--verbose` | `-v` | Verbose output | `false` |

#### Examples

```bash
# Start single worker
azu jobs:worker

# Start multiple workers
azu jobs:worker --workers 4

# Process specific queues
azu jobs:worker --queues critical,default,low

# Start workers with all options
azu jobs:worker --workers 4 --queues critical,default --verbose

# Run as daemon
azu jobs:worker --daemon
```

#### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_URL` | Redis connection URL | `redis://localhost:6379` |
| `JOOBQ_REDIS_URL` | JoobQ-specific Redis URL | Falls back to `REDIS_URL` |
| `JOOBQ_QUEUE` | Default queue name | `default` |
| `JOOBQ_WORKERS` | Number of workers | `1` |

#### Worker Requirements

The workers expect a `src/worker.cr` file in your project:

```crystal
require "./app"
require "joobq"

# Configure JoobQ
JoobQ.configure do |config|
  config.redis_url = ENV["REDIS_URL"]
  config.queues = ENV["JOOBQ_QUEUES"]?.try(&.split(",")) || ["default"]
end

# Start processing jobs
JoobQ.start
```

---

### `azu jobs:status`

Display current status and statistics for all job queues.

#### Synopsis

```bash
azu jobs:status
```

#### Description

Connects to Redis and displays real-time statistics for all JoobQ queues, including pending, processing, and failed job counts.

#### Output Format

```
Job Queue Status
================================================================================
Redis: redis://localhost:6379
Queue: default

Queue                |    Pending |   Processing |     Failed
================================================================================
critical             |          5 |            2 |          0
default              |         23 |            4 |          1
low                  |         12 |            1 |          0
mailers              |          8 |            0 |          0
================================================================================
Total                |         48 |            7 |          1
```

#### Examples

```bash
# Show status for all queues
azu jobs:status

# Show status with custom Redis URL
REDIS_URL="redis://localhost:6380" azu jobs:status
```

#### Queue States

- **Pending**: Jobs waiting to be processed
- **Processing**: Jobs currently being executed by workers
- **Failed**: Jobs that encountered errors during execution

---

### `azu jobs:clear`

Clear jobs from queues.

#### Synopsis

```bash
azu jobs:clear [options]
```

#### Description

Remove jobs from specified queues. Use with caution as this operation is irreversible.

#### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--queue <name>` | `-q` | Specific queue to clear (default: `default`) |
| `--all` | | Clear all queues |
| `--failed` | | Clear only failed jobs |
| `--force` | `-f` | Skip confirmation prompt |

#### Examples

```bash
# Clear default queue (with confirmation)
azu jobs:clear

# Clear specific queue
azu jobs:clear --queue mailers

# Clear failed jobs only
azu jobs:clear --failed

# Clear all queues without confirmation
azu jobs:clear --all --force

# Clear failed jobs in specific queue
azu jobs:clear --queue default --failed
```

#### Confirmation Prompt

Unless `--force` is specified, you'll be prompted to confirm:

```
⚠️  This will permanently delete jobs from the queue.
Are you sure? (y/N):
```

---

### `azu jobs:retry`

Retry failed jobs.

#### Synopsis

```bash
azu jobs:retry [options]
```

#### Description

Re-queue failed jobs for another execution attempt. Useful for recovering from temporary failures like network issues or external service downtime.

#### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--queue <name>` | `-q` | Specific queue (default: `default`) |
| `--all` | | Retry all failed jobs |
| `--limit <n>` | `-l` | Maximum number of jobs to retry |

#### Examples

```bash
# Retry all failed jobs in default queue
azu jobs:retry

# Retry all failed jobs across all queues
azu jobs:retry --all

# Retry limited number of failed jobs
azu jobs:retry --limit 10

# Retry failed jobs in specific queue
azu jobs:retry --queue critical --all
```

#### Retry Behavior

- Jobs are moved from failed queue to pending queue
- Original job parameters and metadata are preserved
- Retry count is incremented
- Jobs exceeding max retries are not re-queued

---

### `azu jobs:ui`

Launch the JoobQUI web interface for visual job management.

#### Synopsis

```bash
azu jobs:ui [options]
```

#### Description

Starts a web server providing a graphical interface to monitor and manage background jobs. The UI displays real-time statistics, job details, and allows manual job management.

#### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--port <port>` | `-p` | UI server port | `4000` |
| `--host <host>` | `-h` | UI server host | `localhost` |
| `--verbose` | `-v` | Verbose output | `false` |

#### Examples

```bash
# Start UI on default port
azu jobs:ui

# Start on custom port
azu jobs:ui --port 5000

# Make accessible from network
azu jobs:ui --host 0.0.0.0 --port 8080

# Start with verbose logging
azu jobs:ui --verbose
```

#### Web Interface Features

The JoobQUI provides:

- **Dashboard**: Overview of all queues and statistics
- **Job List**: Browse pending, processing, and failed jobs
- **Job Details**: View job parameters, status, and error messages
- **Retry Controls**: Manually retry individual failed jobs
- **Queue Management**: Pause, resume, or clear queues
- **Real-time Updates**: Live statistics and job status

#### Accessing the UI

Once started, open your browser to:

```
http://localhost:4000
```

Or with custom host/port:

```
http://your-host:your-port
```

---

## Common Workflows

### Development Setup

```bash
# Terminal 1: Start application server
azu serve

# Terminal 2: Start job workers
azu jobs:worker --verbose

# Terminal 3: Monitor job status
watch -n 1 azu jobs:status
```

### Production Deployment

```bash
# Start multiple workers for high throughput
azu jobs:worker --workers 8 --queues critical,default,low

# Or use process manager like systemd
# /etc/systemd/system/myapp-workers.service
```

### Queue Monitoring

```bash
# Check queue status
azu jobs:status

# Launch web UI for detailed monitoring
azu jobs:ui --port 5000
```

### Handling Failed Jobs

```bash
# Check for failed jobs
azu jobs:status

# Review failures in web UI
azu jobs:ui

# Retry all failed jobs
azu jobs:retry --all

# Or retry limited batch
azu jobs:retry --limit 10
```

### Queue Maintenance

```bash
# Clear old failed jobs
azu jobs:clear --failed --force

# Clear test queue
azu jobs:clear --queue test

# Clear all queues (caution!)
azu jobs:clear --all --force
```

## Best Practices

### 1. Use Multiple Queues

Prioritize jobs by using separate queues:

```bash
# High priority workers
azu jobs:worker --queues critical --workers 4

# General purpose workers
azu jobs:worker --queues default --workers 8

# Low priority workers
azu jobs:worker --queues low --workers 2
```

### 2. Monitor Queue Health

Regularly check queue status:

```bash
# Add to cron or monitoring system
*/5 * * * * azu jobs:status | mail -s "Job Status" admin@example.com
```

### 3. Set Up Alerting

Monitor for stuck or growing queues:

```bash
# Script to check queue depth
#!/bin/bash
pending=$(azu jobs:status | grep default | awk '{print $2}')
if [ "$pending" -gt 1000 ]; then
  echo "WARNING: Queue depth is $pending"
fi
```

### 4. Handle Failed Jobs Promptly

Review and retry or clear failed jobs regularly:

```bash
# Daily cleanup of old failures
0 2 * * * azu jobs:clear --failed
```

### 5. Scale Workers Based on Load

Adjust worker count based on queue depth:

```bash
# Light load
azu jobs:worker --workers 2

# Heavy load
azu jobs:worker --workers 16
```

## Process Management

### Using Systemd (Linux)

Create `/etc/systemd/system/myapp-workers.service`:

```ini
[Unit]
Description=MyApp Background Workers
After=network.target redis.service

[Service]
Type=simple
User=myapp
WorkingDirectory=/var/www/myapp
Environment=REDIS_URL=redis://localhost:6379
Environment=JOOBQ_WORKERS=4
ExecStart=/usr/local/bin/azu jobs:worker --workers 4
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable myapp-workers
sudo systemctl start myapp-workers
sudo systemctl status myapp-workers
```

### Using Docker

```dockerfile
# Worker container
FROM crystallang/crystal:latest

WORKDIR /app
COPY . .
RUN shards install
RUN shards build

CMD ["azu", "jobs:worker", "--workers", "4"]
```

Docker Compose:

```yaml
version: '3'
services:
  worker:
    build: .
    command: azu jobs:worker --workers 4 --queues critical,default
    environment:
      REDIS_URL: redis://redis:6379
    depends_on:
      - redis
```

### Using Foreman

Create `Procfile`:

```
web: azu serve
worker: azu jobs:worker --workers 4
```

Start all services:

```bash
foreman start
```

## Troubleshooting

### Workers Not Processing Jobs

Check worker is running:

```bash
ps aux | grep "jobs:worker"
```

Verify Redis connection:

```bash
redis-cli ping
# Should return: PONG
```

Check queue status:

```bash
azu jobs:status
```

### Redis Connection Errors

Verify Redis URL:

```bash
echo $REDIS_URL
# Should be: redis://localhost:6379
```

Test connection:

```bash
redis-cli -u $REDIS_URL ping
```

### Jobs Stuck in Processing

Failed workers may leave jobs in processing state. Clear and retry:

```bash
# Restart workers
pkill -f jobs:worker
azu jobs:worker --workers 4 &

# Clear stuck jobs (if needed)
azu jobs:clear --force
```

### High Memory Usage

Reduce worker count:

```bash
azu jobs:worker --workers 2
```

Or implement job batching in your application.

## Environment Variables

All job commands respect these variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_URL` | Primary Redis connection URL | `redis://localhost:6379` |
| `JOOBQ_REDIS_URL` | JoobQ-specific Redis URL | Falls back to `REDIS_URL` |
| `JOOBQ_QUEUE` | Default queue name | `default` |
| `JOOBQ_WORKERS` | Default number of workers | `1` |

## Related Commands

- [`azu generate joobq`](../generators/joobq.md) - Set up JoobQ infrastructure
- [`azu generate job`](../generators/joobq.md#job-generator) - Create new job classes
- [`azu serve`](serve.md) - Development server

## See Also

- [JoobQ Documentation](https://github.com/azutoolkit/joobq)
- [Background Jobs Guide](../guides/background-jobs.md)
- [Production Deployment](../deployment/production.md)

