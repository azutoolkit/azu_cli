# Session Commands

Session management commands for setting up and managing user sessions in your Azu application.

## Overview

The Azu CLI provides commands to set up and manage session storage backends. Sessions are essential for maintaining user state across HTTP requests, implementing authentication, and storing temporary user data.

## Supported Backends

Azu supports three session storage backends:

| Backend      | Description                                     | Use Case                               |
| ------------ | ----------------------------------------------- | -------------------------------------- |
| **Redis**    | Fast, in-memory key-value store                 | Production, high-traffic applications  |
| **Database** | Persistent storage in your application database | Audit requirements, queryable sessions |
| **Memory**   | In-process memory storage                       | Development, testing only              |

## Commands

### `azu session:setup`

Configure and install session management for your application.

#### Synopsis

```bash
azu session:setup [options]
```

#### Description

Sets up session management by generating configuration files, initializers, and (optionally) database migrations. The command integrates with your existing application and adds the necessary dependencies.

#### Options

| Option             | Short | Description                                       | Default |
| ------------------ | ----- | ------------------------------------------------- | ------- |
| `--backend <type>` | `-b`  | Session backend: `redis`, `memory`, or `database` | `redis` |
| `--force`          | `-f`  | Overwrite existing configuration files            | `false` |

#### Examples

```bash
# Setup with Redis backend (recommended)
azu session:setup

# Setup with explicit backend
azu session:setup --backend redis

# Setup with database backend
azu session:setup --backend database

# Setup with memory backend (development only)
azu session:setup --backend memory

# Force overwrite existing configuration
azu session:setup --backend redis --force
```

#### Generated Files

The setup command generates the following files:

##### All Backends

```
src/initializers/session.cr    # Session configuration
```

##### Database Backend Only

```
src/db/migrations/TIMESTAMP_create_sessions.cr    # Sessions table migration
```

#### Setup Steps

After running the command, complete these steps:

1. **Install dependencies**:

   ```bash
   shards install
   ```

2. **Run migrations** (database backend only):

   ```bash
   azu db:migrate
   ```

3. **Set environment variables**:

   ```bash
   # Required for all backends
   export SESSION_SECRET="your-secret-key-here"

   # For Redis backend
   export REDIS_URL="redis://localhost:6379"

   # For Database backend
   export DATABASE_URL="postgresql://user:password@localhost/myapp"
   ```

4. **Require the initializer** in your application:
   ```crystal
   # src/app.cr
   require "./initializers/session"
   ```

#### Backend-Specific Configuration

##### Redis Backend

**Pros:**

- Fast performance
- Automatic expiration
- Scales horizontally
- No database overhead

**Cons:**

- Requires Redis server
- Data is not persistent across Redis restarts (unless configured)

**Configuration:**

```crystal
# src/initializers/session.cr
Session.configure do |config|
  config.store = RedisStore.new(
    url: ENV["REDIS_URL"],
    prefix: "myapp:session:",
    ttl: 1.hour
  )
  config.secret = ENV["SESSION_SECRET"]
end
```

##### Database Backend

**Pros:**

- Persistent storage
- Queryable sessions
- No additional infrastructure
- Good for audit trails

**Cons:**

- Slower than Redis
- Increases database load
- Requires migrations

**Configuration:**

```crystal
# src/initializers/session.cr
Session.configure do |config|
  config.store = DatabaseStore.new(
    table: "sessions",
    ttl: 1.hour
  )
  config.secret = ENV["SESSION_SECRET"]
end
```

##### Memory Backend

**Pros:**

- No external dependencies
- Fast for development
- Simple setup

**Cons:**

- Not production-safe
- Sessions lost on restart
- Not scalable
- Single process only

**Configuration:**

```crystal
# src/initializers/session.cr
Session.configure do |config|
  config.store = MemoryStore.new(ttl: 1.hour)
  config.secret = ENV["SESSION_SECRET"]
end
```

---

### `azu session:clear`

Clear all sessions from the configured backend.

#### Synopsis

```bash
azu session:clear [options]
```

#### Description

Removes all active sessions from storage, effectively logging out all users. Use this command for maintenance, security incidents, or when changing session structure.

#### Options

| Option             | Short | Description               |
| ------------------ | ----- | ------------------------- |
| `--force`          | `-f`  | Skip confirmation prompt  |
| `--backend <type>` | `-b`  | Override detected backend |

#### Examples

```bash
# Clear sessions (with confirmation)
azu session:clear

# Clear without confirmation
azu session:clear --force

# Clear with explicit backend
azu session:clear --backend redis
```

#### Confirmation Prompt

Unless `--force` is specified, you'll be prompted:

```
Are you sure you want to clear all sessions? This will log out all users. [y/N]:
```

#### Backend Detection

The command automatically detects the session backend by:

1. Checking `src/initializers/session.cr` for store type
2. Reading `SESSION_BACKEND` environment variable
3. Defaulting to Redis

#### Clearing Behavior by Backend

##### Redis

Removes all keys matching the session prefix:

```bash
# Pattern: myapp:session:*
azu session:clear
```

Output:

```
Clearing sessions...
Backend: redis
Redis URL: redis://localhost:6379
Clearing Redis sessions with pattern: myapp:session:*
Cleared 142 session(s)
✓ Sessions cleared successfully
```

##### Database

Executes a `DELETE` query on the sessions table:

```bash
azu session:clear --backend database
```

Output:

```
Clearing sessions...
Backend: database
Clearing database sessions...
Cleared 89 session(s)
✓ Sessions cleared successfully
```

##### Memory

Cannot be cleared remotely:

```bash
azu session:clear --backend memory
```

Output:

```
Clearing sessions...
Backend: memory
⚠️  Memory sessions cannot be cleared remotely
Restart the application to clear memory sessions
```

---

## Common Workflows

### Initial Setup

```bash
# 1. Choose and setup backend
azu session:setup --backend redis

# 2. Install dependencies
shards install

# 3. Configure environment
cat >> .env << EOF
SESSION_SECRET=$(openssl rand -hex 32)
REDIS_URL=redis://localhost:6379
EOF

# 4. Update application to require session
echo 'require "./initializers/session"' >> src/app.cr

# 5. Start application
azu serve
```

### Switching Backends

```bash
# 1. Setup new backend
azu session:setup --backend database --force

# 2. Clear old sessions
azu session:clear --backend redis --force

# 3. Run migrations (if database backend)
azu db:migrate

# 4. Restart application
pkill -f "azu serve"
azu serve
```

### Security Incident Response

```bash
# Immediately invalidate all sessions
azu session:clear --force

# Rotate session secret
export SESSION_SECRET=$(openssl rand -hex 32)

# Restart application
systemctl restart myapp
```

### Maintenance

```bash
# Before deployment
azu session:clear --force

# After changing session structure
azu session:clear --force
azu serve
```

## Best Practices

### 1. Use Strong Session Secrets

Generate cryptographically secure secrets:

```bash
# Generate random secret
openssl rand -hex 32

# Or use uuidgen
uuidgen
```

Never commit secrets to version control:

```bash
# .gitignore
.env
config/secrets.yml
```

### 2. Choose the Right Backend

**For Production:**

- **High traffic**: Redis
- **Compliance/audit**: Database
- **Hybrid**: Redis with database backup

**For Development:**

- Memory backend for simplicity

### 3. Set Appropriate TTL

Balance security and user experience:

```crystal
# Short-lived for sensitive apps (banking)
config.ttl = 15.minutes

# Standard web apps
config.ttl = 1.day

# Remember me functionality
config.ttl = 30.days
```

### 4. Monitor Session Storage

```bash
# Check Redis memory usage
redis-cli info memory

# Check session count
redis-cli keys "myapp:session:*" | wc -l

# Database session count
psql -c "SELECT COUNT(*) FROM sessions;"
```

### 5. Implement Session Cleanup

For database backend, clean expired sessions:

```crystal
# src/tasks/cleanup_sessions.cr
task :cleanup_sessions do
  DB.exec("DELETE FROM sessions WHERE expires_at < NOW()")
end
```

Schedule with cron:

```bash
# crontab -e
0 2 * * * cd /var/www/myapp && crystal run src/tasks/cleanup_sessions.cr
```

## Configuration Examples

### Redis with Custom Options

```crystal
Session.configure do |config|
  config.store = RedisStore.new(
    url: ENV["REDIS_URL"],
    prefix: "myapp:session:",
    ttl: 2.hours,
    pool_size: 10,
    pool_timeout: 5.seconds
  )
  config.secret = ENV["SESSION_SECRET"]
  config.cookie_name = "myapp_session"
  config.secure = true  # HTTPS only
  config.http_only = true
  config.same_site = :strict
end
```

### Database with Cleanup

```crystal
Session.configure do |config|
  config.store = DatabaseStore.new(
    table: "sessions",
    ttl: 1.day
  )
  config.secret = ENV["SESSION_SECRET"]

  # Auto-cleanup expired sessions
  config.cleanup_interval = 1.hour
end
```

### Environment-Specific Configuration

```crystal
case ENV["AZU_ENV"]?
when "production"
  Session.configure do |config|
    config.store = RedisStore.new(
      url: ENV["REDIS_URL"],
      prefix: "#{ENV["APP_NAME"]}:session:",
      ttl: 1.day
    )
    config.secret = ENV["SESSION_SECRET"]
    config.secure = true
    config.same_site = :strict
  end
when "development", "test"
  Session.configure do |config|
    config.store = MemoryStore.new(ttl: 1.hour)
    config.secret = "development-secret"
  end
end
```

## Troubleshooting

### Sessions Not Persisting

**Check configuration:**

```crystal
# Verify initializer is loaded
pp Session.configuration
```

**Verify backend connectivity:**

```bash
# Redis
redis-cli ping

# Database
psql $DATABASE_URL -c "SELECT 1;"
```

**Check cookie settings:**

```crystal
# Ensure cookies are set correctly
config.secure = false  # For development (HTTP)
config.http_only = true
```

### Sessions Expiring Too Quickly

**Adjust TTL:**

```crystal
config.ttl = 24.hours  # Instead of default
```

**Check Redis eviction policy:**

```bash
redis-cli config get maxmemory-policy
# Should be: allkeys-lru or volatile-lru
```

### Redis Connection Errors

**Verify URL format:**

```bash
# Correct format
redis://localhost:6379

# With auth
redis://:password@localhost:6379

# With database number
redis://localhost:6379/1
```

**Test connection:**

```bash
redis-cli -u $REDIS_URL ping
```

### Database Migration Issues

**Ensure migration ran:**

```bash
azu db:status
```

**Verify table exists:**

```bash
psql $DATABASE_URL -c "\dt sessions"
```

**Re-run migration:**

```bash
azu db:rollback --steps 1
azu db:migrate
```

## Security Considerations

### 1. Session Hijacking Prevention

```crystal
Session.configure do |config|
  config.rotate_on_login = true
  config.regenerate_id = true
  config.secure = true  # HTTPS only
  config.same_site = :strict
end
```

### 2. Session Fixation Protection

Regenerate session ID after authentication:

```crystal
def login(user)
  session.regenerate_id
  session[:user_id] = user.id
end
```

### 3. Secure Cookie Flags

```crystal
config.secure = true      # HTTPS only
config.http_only = true   # No JavaScript access
config.same_site = :strict  # CSRF protection
```

### 4. Session Secret Rotation

```bash
# Generate new secret
NEW_SECRET=$(openssl rand -hex 32)

# Update environment
export SESSION_SECRET=$NEW_SECRET

# Clear old sessions
azu session:clear --force

# Restart application
systemctl restart myapp
```

## Environment Variables

| Variable          | Description                            | Required               |
| ----------------- | -------------------------------------- | ---------------------- |
| `SESSION_SECRET`  | Encryption key for session data        | Yes                    |
| `SESSION_BACKEND` | Backend type (redis, database, memory) | No                     |
| `REDIS_URL`       | Redis connection URL                   | Yes (Redis backend)    |
| `DATABASE_URL`    | Database connection URL                | Yes (Database backend) |

## Related Commands

- [`azu generate auth`](../generators/README.md#authentication) - Generate authentication system
- [`azu db:migrate`](database.md#azu-dbmigrate) - Run database migrations
- [`azu serve`](serve.md) - Development server

## See Also

- [Session Management Guide](../guides/sessions.md)
- [Security Best Practices](../guides/security.md)
- [Authentication Guide](../guides/authentication.md)
- [Redis Configuration](https://redis.io/documentation)
