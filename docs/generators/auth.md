# Authentication Generator

Generate a complete, production-ready authentication system with support for JWT, sessions, OAuth, and advanced security features including RBAC (Role-Based Access Control).

## Synopsis

```bash
azu generate auth [options]
```

## Description

The auth generator creates a comprehensive authentication system for your Azu application, including user models, authentication endpoints, security middleware, and database migrations. It supports multiple authentication strategies and can be configured with advanced features like role-based access control, CSRF protection, and OAuth integration.

## Features

### Core Authentication

- ✅ **User Registration**: Secure user signup with email verification
- ✅ **Login/Logout**: Session or token-based authentication
- ✅ **Password Management**: Secure password hashing with BCrypt (cost: 14)
- ✅ **Password Reset**: Email-based password recovery
- ✅ **Email Confirmation**: Account verification workflow
- ✅ **Account Locking**: Automatic lockout after failed attempts

### Security Features

- 🔐 **BCrypt Password Hashing**: Industry-standard with high cost factor
- 🎫 **JWT Support**: Secure token generation with refresh tokens
- 🛡️ **CSRF Protection**: Cross-site request forgery prevention
- 🔒 **Security Headers**: Comprehensive HTTP security headers
- 🚫 **Rate Limiting**: Protection against brute force attacks
- 🔑 **Two-Factor Authentication**: Optional 2FA support (infrastructure ready)

### Advanced Features

- 👥 **RBAC**: Complete role-based access control system
- 🌐 **OAuth Integration**: Google and GitHub authentication
- ⏰ **Token Expiration**: Configurable access and refresh tokens
- 📊 **Audit Trail**: Track login attempts and security events
- 🎯 **Permission System**: Granular permission management

## Usage

### Basic Usage

Generate authentication with default settings (Authly strategy with RBAC):

```bash
azu generate auth
```

This creates a complete authentication system with:

- User model with security features
- Authentication endpoints (register, login, logout)
- JWT token management
- RBAC tables and structure
- Security middleware

### Strategy-Specific Generation

#### Authly (Recommended)

Full-featured OAuth2 server with JWT and RBAC:

```bash
azu generate auth --strategy authly
```

Features:

- OAuth2 server capabilities
- JWT access and refresh tokens
- RBAC and permissions
- OAuth provider integration
- Comprehensive security

#### JWT Only

Simple JWT-based authentication:

```bash
azu generate auth --strategy jwt
```

Features:

- JWT access tokens
- Refresh token support
- User model with basic auth
- Login/register endpoints

#### Session-Based

Traditional session authentication using the [Session shard](https://github.com/azutoolkit/session):

```bash
azu generate auth --strategy session
azu generate auth --strategy session --user-model Account
```

Features:

- **Server-side encrypted sessions**: Secure cookie-based authentication
- **Strongly-typed session data**: Type-safe session payload with Crystal structs
- **Multiple storage backends**: Memory (default), Redis, or Database
- **Auto-expiration**: Configurable timeout (default: 1 hour for CSRF, 24 hours without)
- **Session lifecycle callbacks**: on_started, on_deleted events
- **Automatic integration**: Generates session config, middleware, and helper methods
- **Dependency management**: Automatically adds session shard to shard.yml

What gets generated:
- Session configuration file (`src/config/session.cr`)
- Session HTTP handler middleware (`src/middleware/session_handler.cr`)
- Strongly-typed session struct (`Sessions::AccountSession` or `Sessions::UserSession`)
- Session helper method (`YourApp.session`)
- Updated endpoints to use session storage
- Environment variable template for SESSION_SECRET

#### OAuth

External OAuth provider authentication:

```bash
azu generate auth --strategy oauth
```

Features:

- Google OAuth
- GitHub OAuth
- Extensible provider support

### Advanced Options

```bash
# Full-featured auth with all options
azu generate auth \
  --strategy authly \
  --user-model CustomUser \
  --enable-rbac \
  --enable-csrf \
  --oauth-providers google,github,facebook

# Simple JWT auth without RBAC
azu generate auth \
  --strategy jwt \
  --no-rbac \
  --no-csrf

# Custom user model
azu generate auth \
  --user-model Account \
  --strategy session
```

## Options

| Option                     | Type            | Default         | Description                                                  |
| -------------------------- | --------------- | --------------- | ------------------------------------------------------------ |
| `--strategy <type>`        | string          | `authly`        | Authentication strategy: `authly`, `jwt`, `session`, `oauth` |
| `--user-model <name>`      | string          | `User`          | Custom name for the user model class (e.g., `Account`)      |
| `--enable-rbac`            | flag            | `true`          | Enable role-based access control                             |
| `--no-rbac`                | flag            |                 | Disable RBAC features                                        |
| `--enable-csrf`            | flag            | `true`          | Enable CSRF protection                                       |
| `--no-csrf`                | flag            |                 | Disable CSRF protection                                      |
| `--oauth-providers <list>` | comma-separated | `google,github` | OAuth providers to enable                                    |
| `--force`                  | flag            | `false`         | Overwrite existing files                                     |

### Custom User Model

The `--user-model` option allows you to use a custom name for your user model instead of the default `User`. This is useful when:

- You need to avoid naming conflicts
- Your domain uses different terminology (Account, Member, etc.)
- You're integrating with existing systems

Example:
```bash
azu generate auth --user-model Account --strategy session
```

This generates:
- Model class: `Account` (not `User`)
- Table: `accounts` (not `users`)
- RBAC tables: `account_roles` (not `user_roles`)
- All migrations and endpoints use the custom model name

## Generated Files

### Directory Structure

The generator creates different files based on your chosen strategy:

```
project/
├── src/
│   ├── models/
│   │   └── user.cr                      # User model with auth (or custom name)
│   ├── endpoints/
│   │   └── auth/
│   │       ├── register_endpoint.cr     # POST /auth/register
│   │       ├── login_endpoint.cr        # POST /auth/login
│   │       ├── logout_endpoint.cr       # POST /auth/logout
│   │       ├── refresh_endpoint.cr      # POST /auth/refresh (jwt/authly only)
│   │       ├── me_endpoint.cr           # GET  /auth/me
│   │       ├── change_password_endpoint.cr # POST /auth/change-password
│   │       ├── permissions_endpoint.cr  # GET  /auth/permissions (rbac only)
│   │       ├── oauth_provider_endpoint.cr   # GET /auth/oauth/:provider (authly only)
│   │       └── oauth_callback_endpoint.cr   # GET /auth/oauth/:provider/callback (authly only)
│   ├── response/
│   │   └── auth/
│   │       ├── register_json.cr         # Register JSON response
│   │       ├── login_json.cr            # Login JSON response
│   │       ├── refresh_json.cr          # Refresh JSON response (jwt/authly only)
│   │       ├── logout_json.cr           # Logout JSON response
│   │       ├── me_json.cr               # Me JSON response
│   │       ├── change_password_json.cr  # Change Password JSON response
│   │       └── permissions_json.cr      # Permissions JSON response (rbac only)
│   ├── requests/
│   │   └── auth/
│   │       ├── register_request.cr      # Registration validation
│   │       ├── login_request.cr         # Login validation
│   │       ├── refresh_token_request.cr # Token refresh (jwt/authly only)
│   │       ├── logout_request.cr        # Logout request
│   │       ├── me_request.cr            # Me request
│   │       └── change_password_request.cr # Password change validation
│   ├── middleware/
│   │   ├── csrf_protection.cr           # CSRF middleware (if enabled)
│   │   ├── security_headers.cr          # Security headers
│   │   └── session_handler.cr           # Session HTTP handler (session only)
│   └── config/
│       ├── authly.cr                    # Authly configuration (authly only)
│       └── session.cr                   # Session configuration (session only)
├── src/db/
│   ├── migrations/
│   │   ├── <timestamp>_create_users.cr                 # Users table (or custom name)
│   │   ├── <timestamp>_create_roles.cr                 # RBAC (if enabled)
│   │   ├── <timestamp>_create_user_roles.cr            # RBAC (if enabled)
│   │   ├── <timestamp>_create_permissions.cr           # RBAC (if enabled)
│   │   ├── <timestamp>_create_role_permissions.cr      # RBAC (if enabled)
│   │   └── <timestamp>_create_oauth_applications.cr    # Authly (authly only)
│   └── seed_rbac.cr                     # RBAC seed data (if enabled)
├── env.example                          # Environment variables template
└── README.md                            # Auth system documentation
```

**Note**: Migrations are generated in `src/db/migrations/` with unique incremental timestamps to avoid conflicts.

### File Descriptions

#### User Model (`src/models/user.cr`)

Complete user model with CQL ORM (name depends on `--user-model` option):

```crystal
# Example with default User model
class User 
  include CQL::Model(Int64)
  db_context AppDB, :users

  property id : Int64
  property email : String
  property password_hash : String
  property name : String?
  property role : String
  property confirmed_at : Time?
  property locked_at : Time?
  property failed_login_attempts : Int32
  property last_login_at : Time?
  property password_changed_at : Time?
  property two_factor_enabled : Bool
  property two_factor_secret : String?
  property recovery_codes : String?
  property created_at : Time
  property updated_at : Time

  # Authentication methods
  def self.authenticate(email : String, password : String) : User?
  def verify_password(password : String) : Bool
  def locked? : Bool
  def confirmed? : Bool
  def has_role?(role_name : String) : Bool
  def has_permission?(permission : String) : Bool
  def record_failed_login!
  def reset_failed_login_attempts!
end

# Example with custom Account model (--user-model Account)
class Account
  include CQL::Model(Int64)
  db_context BlogDB, :accounts

  # Same properties and methods as above...
end
```

**Note**: The model name and table name automatically adjust based on the `--user-model` option.

#### Authentication Endpoints (`src/endpoints/auth/*_endpoint.cr`)

RESTful authentication API (per action files):

- `POST /auth/register` - User registration (`register_endpoint.cr`)
- `POST /auth/login` - User login (`login_endpoint.cr`)
- `POST /auth/logout` - User logout (`logout_endpoint.cr`)
- `POST /auth/refresh` - Refresh access token (`refresh_endpoint.cr`, jwt/authly)
- `POST /auth/change-password` - Change authenticated user password (`change_password_endpoint.cr`)
- `GET /auth/me` - Current user (`me_endpoint.cr`)
- `GET /auth/permissions` - RBAC permissions (`permissions_endpoint.cr`)
- `GET /auth/oauth/:provider` and `GET /auth/oauth/:provider/callback` (authly)

#### CSRF Protection Middleware (`src/middleware/csrf_protection.cr`)

Protects against cross-site request forgery:

```crystal
class CSRFProtection
  include Azu::Middleware

  def call(context : HTTP::Server::Context)
    return call_next(context) if safe_method?(context.request.method)

    token = get_token(context)
    stored_token = context.session["csrf_token"]

    if token.nil? || token != stored_token
      context.response.status = HTTP::Status::FORBIDDEN
      return context.response.print("CSRF token validation failed")
    end

    call_next(context)
  end
end
```

#### Security Headers Middleware (`src/middleware/security_headers.cr`)

Comprehensive HTTP security headers:

```crystal
class SecurityHeaders
  include Azu::Middleware

  def call(context : HTTP::Server::Context)
    context.response.headers["X-Frame-Options"] = "DENY"
    context.response.headers["X-Content-Type-Options"] = "nosniff"
    context.response.headers["X-XSS-Protection"] = "1; mode=block"
    context.response.headers["Strict-Transport-Security"] = "max-age=31536000"
    context.response.headers["Content-Security-Policy"] = csp_policy

    call_next(context)
  end
end
```

## Database Schema

### Users Table

Core user authentication table:

| Column                  | Type    | Description                  |
| ----------------------- | ------- | ---------------------------- |
| `id`                    | Int64   | Primary key                  |
| `email`                 | String  | Unique email address         |
| `password_hash`         | String  | BCrypt password hash         |
| `name`                  | String  | User's full name             |
| `role`                  | String  | User role (default: "user")  |
| `confirmed_at`          | Time?   | Email confirmation timestamp |
| `locked_at`             | Time?   | Account lock timestamp       |
| `failed_login_attempts` | Int32   | Failed login counter         |
| `last_login_at`         | Time?   | Last successful login        |
| `password_changed_at`   | Time?   | Password change timestamp    |
| `two_factor_enabled`    | Bool    | 2FA enabled flag             |
| `two_factor_secret`     | String? | 2FA secret key               |
| `recovery_codes`        | String? | Backup recovery codes        |
| `created_at`            | Time    | Creation timestamp           |
| `updated_at`            | Time    | Last update timestamp        |

### RBAC Tables (when `--enable-rbac`)

#### Roles Table

| Column        | Type   | Description            |
| ------------- | ------ | ---------------------- |
| `id`          | Int64  | Primary key            |
| `name`        | String | Role name (unique)     |
| `description` | String | Role description       |
| `permissions` | String | JSON permissions array |
| `created_at`  | Time   | Creation timestamp     |
| `updated_at`  | Time   | Last update timestamp  |

#### Permissions Table

| Column        | Type   | Description              |
| ------------- | ------ | ------------------------ |
| `id`          | Int64  | Primary key              |
| `name`        | String | Permission name (unique) |
| `description` | String | Permission description   |
| `resource`    | String | Resource type            |
| `action`      | String | Action type              |
| `created_at`  | Time   | Creation timestamp       |

#### User_Roles Junction Table

| Column        | Type   | Description          |
| ------------- | ------ | -------------------- |
| `id`          | Int64  | Primary key          |
| `user_id`     | Int64  | Foreign key to users |
| `role_id`     | Int64  | Foreign key to roles |
| `assigned_at` | Time   | Assignment timestamp |
| `assigned_by` | Int64? | Assigning user ID    |

#### Role_Permissions Junction Table

| Column          | Type  | Description                |
| --------------- | ----- | -------------------------- |
| `id`            | Int64 | Primary key                |
| `role_id`       | Int64 | Foreign key to roles       |
| `permission_id` | Int64 | Foreign key to permissions |
| `created_at`    | Time  | Creation timestamp         |

### OAuth Tables (when `--strategy authly`)

#### OAuth_Applications Table

| Column          | Type   | Description           |
| --------------- | ------ | --------------------- |
| `id`            | Int64  | Primary key           |
| `name`          | String | Application name      |
| `client_id`     | String | Unique client ID      |
| `client_secret` | String | Client secret         |
| `redirect_uri`  | String | OAuth redirect URI    |
| `scopes`        | String | Allowed scopes        |
| `confidential`  | Bool   | Confidential flag     |
| `created_at`    | Time   | Creation timestamp    |
| `updated_at`    | Time   | Last update timestamp |

#### OAuth_Access_Tokens Table

| Column              | Type    | Description                 |
| ------------------- | ------- | --------------------------- |
| `id`                | Int64   | Primary key                 |
| `application_id`    | Int64   | Foreign key to applications |
| `resource_owner_id` | Int64   | User ID                     |
| `token`             | String  | Access token (unique)       |
| `refresh_token`     | String? | Refresh token (unique)      |
| `expires_in`        | Int32   | Token lifetime (seconds)    |
| `scopes`            | String  | Granted scopes              |
| `created_at`        | Time    | Creation timestamp          |
| `revoked_at`        | Time?   | Revocation timestamp        |

## Configuration

### Environment Variables

Add to `.env`:

```bash
# JWT Configuration
JWT_SECRET=your-secret-key-here
JWT_REFRESH_SECRET=your-refresh-secret-here
JWT_ISSUER=your-app-name-api
JWT_AUDIENCE=your-app-name-client

# OAuth Configuration (if using Authly)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret

# Email Configuration (for confirmations)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your-username
SMTP_PASSWORD=your-password
FROM_EMAIL=noreply@yourapp.com

# Security
CSRF_SECRET=your-csrf-secret
SESSION_SECRET=your-session-secret

# Account Security
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_DURATION=30m
PASSWORD_MIN_LENGTH=8
REQUIRE_EMAIL_CONFIRMATION=true
```

### Authly Configuration (`src/config/authly.cr`)

```crystal
Authly.configure do |config|
  # Token lifetimes
  config.access_token_lifetime = 15.minutes
  config.refresh_token_lifetime = 7.days

  # OAuth providers
  config.oauth_providers = {
    "google" => {
      "client_id" => ENV["GOOGLE_CLIENT_ID"],
      "client_secret" => ENV["GOOGLE_CLIENT_SECRET"],
      "redirect_uri" => "#{ENV["APP_URL"]}/auth/google/callback"
    },
    "github" => {
      "client_id" => ENV["GITHUB_CLIENT_ID"],
      "client_secret" => ENV["GITHUB_CLIENT_SECRET"],
      "redirect_uri" => "#{ENV["APP_URL"]}/auth/github/callback"
    }
  }

  # Security settings
  config.bcrypt_cost = 14
  config.max_login_attempts = 5
  config.lockout_duration = 30.minutes
  config.require_email_confirmation = true
end
```

## Usage Examples

### User Registration

```crystal
# Register new user
POST /auth/register
{
  "email": "user@example.com",
  "password": "SecurePassword123!",
  "name": "John Doe"
}

# Response
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "role": "user",
    "created_at": "2024-01-01T00:00:00Z"
  },
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc...",
  "expires_in": 900
}
```

### User Login

```crystal
POST /auth/login
{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}

# Response
{
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc...",
  "expires_in": 900,
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "role": "user"
  }
}
```

### Token Refresh

```crystal
POST /auth/refresh
{
  "refresh_token": "eyJhbGc..."
}

# Response
{
  "access_token": "eyJhbGc...",
  "expires_in": 900
}
```

### Password Reset

```crystal
# Request reset
POST /auth/forgot-password
{
  "email": "user@example.com"
}

# Reset with token
POST /auth/reset-password
{
  "token": "reset-token-from-email",
  "password": "NewSecurePassword123!"
}
```

### Using Authentication in Endpoints

```crystal
class ProtectedEndpoint
  include Azu::Endpoint(EmptyContract, JsonResponse)

  def call
    # Check if user is authenticated
    unless current_user
      return unauthorized("Authentication required")
    end

    # Check role
    unless current_user.has_role?("admin")
      return forbidden("Admin access required")
    end

    # Check specific permission
    unless current_user.can?("posts:delete")
      return forbidden("Insufficient permissions")
    end

    # Proceed with protected logic
    ok({ message: "Access granted" })
  end

  private def current_user
    @current_user ||= authenticate_from_token(request)
  end
end
```

## RBAC Usage

### Seeding Roles and Permissions

```crystal
# db/seed_rbac.cr
require "../src/models/**"

# Create permissions
read_posts = Permission.create!(
  name: "posts:read",
  description: "Read posts",
  resource: "posts",
  action: "read"
)

create_posts = Permission.create!(
  name: "posts:create",
  description: "Create posts",
  resource: "posts",
  action: "create"
)

delete_posts = Permission.create!(
  name: "posts:delete",
  description: "Delete posts",
  resource: "posts",
  action: "delete"
)

# Create roles
user_role = Role.create!(
  name: "user",
  description: "Regular user",
  permissions: [read_posts.id]
)

editor_role = Role.create!(
  name: "editor",
  description: "Content editor",
  permissions: [read_posts.id, create_posts.id]
)

admin_role = Role.create!(
  name: "admin",
  description: "Administrator",
  permissions: [read_posts.id, create_posts.id, delete_posts.id]
)

# Assign role to user
user = User.find!(1)
user.add_role(admin_role)
```

### Checking Permissions

```crystal
# Check if user has specific role
if user.has_role?("admin")
  # Allow admin actions
end

# Check if user has specific permission
if user.can?("posts:delete")
  # Allow post deletion
end

# Get all user permissions
permissions = user.permissions # => ["posts:read", "posts:create", "posts:delete"]

# Get all user roles
roles = user.roles # => [Role<admin>]
```

## Security Best Practices

### 1. Strong Secrets

Generate cryptographically secure secrets:

```bash
# JWT secrets
openssl rand -hex 64

# Session secrets
openssl rand -base64 32
```

### 2. Password Requirements

Enforce strong passwords in validation:

```crystal
class RegisterRequest
  include Azu::Contract

  field email : String
  field password : String

  validates :password, length: {minimum: 8, maximum: 72}
  validates :password, format: {
    with: /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/,
    message: "must include uppercase, lowercase, number, and special character"
  }
end
```

### 3. Rate Limiting

Implement rate limiting on auth endpoints:

```crystal
class RateLimitMiddleware
  def call(context : HTTP::Server::Context)
    if auth_endpoint?(context.request.path)
      check_rate_limit(context)
    end
    call_next(context)
  end
end
```

### 4. Secure Token Storage

Client-side token storage recommendations:

- **Web**: Use httpOnly, secure cookies for refresh tokens
- **SPA**: Store access tokens in memory, refresh tokens in httpOnly cookies
- **Mobile**: Use secure keychain/keystore

### 5. Token Rotation

Rotate refresh tokens on use:

```crystal
def refresh_token(old_token : String)
  # Verify old token
  payload = verify_refresh_token(old_token)
  return nil unless payload

  # Revoke old token
  revoke_token(old_token)

  # Generate new tokens
  user_id = payload["sub"].as_i64
  {
    access_token: generate_token(user_id),
    refresh_token: generate_refresh_token(user_id)
  }
end
```

## Dependencies

Add to `shard.yml`:

```yaml
dependencies:
  # Core auth
  crypto:
    github: crystal-lang/crypto
  jwt:
    github: crystal-community/jwt
  bcrypt:
    github: crystal-community/bcrypt

  # Authly (if using authly strategy)
  authly:
    github: azutoolkit/authly

  # Email (for confirmations)
  carbon:
    github: luckyframework/carbon
```

## Migration and Setup

After generation:

```bash
# 1. Install dependencies
shards install

# 2. Run migrations
azu db:migrate

# 3. Seed RBAC data (if enabled)
crystal run db/seed_rbac.cr

# 4. Set environment variables
cp .env.example .env
# Edit .env with your values

# 5. Start application
azu serve
```

## Testing

Example authentication tests:

```crystal
require "../spec_helper"

describe "Authentication" do
  describe "POST /auth/register" do
    it "registers new user" do
      response = post("/auth/register", {
        email: "test@example.com",
        password: "SecurePassword123!",
        name: "Test User"
      })

      response.status.should eq(201)
      json = JSON.parse(response.body)
      json["user"]["email"].should eq("test@example.com")
      json["access_token"].should_not be_nil
    end

    it "rejects weak password" do
      response = post("/auth/register", {
        email: "test@example.com",
        password: "weak"
      })

      response.status.should eq(422)
    end
  end

  describe "POST /auth/login" do
    it "authenticates valid credentials" do
      user = create_user(email: "test@example.com", password: "SecurePass123!")

      response = post("/auth/login", {
        email: "test@example.com",
        password: "SecurePass123!"
      })

      response.status.should eq(200)
      json = JSON.parse(response.body)
      json["access_token"].should_not be_nil
    end

    it "locks account after failed attempts" do
      user = create_user(email: "test@example.com", password: "correct")

      # Make 5 failed attempts
      5.times do
        post("/auth/login", {email: "test@example.com", password: "wrong"})
      end

      # Account should be locked
      response = post("/auth/login", {
        email: "test@example.com",
        password: "correct"
      })

      response.status.should eq(423) # Locked
    end
  end
end
```

## Troubleshooting

### JWT Token Issues

**Problem**: "JWT_SECRET environment variable not set"

**Solution**:

```bash
export JWT_SECRET=$(openssl rand -hex 64)
export JWT_REFRESH_SECRET=$(openssl rand -hex 64)
```

### BCrypt Cost Too High

**Problem**: Login is slow

**Solution**: Adjust BCrypt cost (default: 14):

```crystal
# In user model
Crypto::Bcrypt::Password.create(password, cost: 12)
```

### CSRF Token Mismatch

**Problem**: "CSRF token validation failed"

**Solution**:

- Ensure CSRF token is included in requests
- Check token matches session value
- Verify middleware order

### Account Lockout

**Problem**: Can't login after failed attempts

**Solution**:

```crystal
# Manually unlock user
user = User.find_by_email("locked@example.com")
user.update(locked_at: nil, failed_login_attempts: 0)
```

## Related Documentation

- [Session Management](../commands/session.md)
- [Security Best Practices](../guides/security.md)
- [Authly Documentation](https://github.com/azutoolkit/authly)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)

## See Also

- [`azu session:setup`](../commands/session.md) - Configure session storage
- [`azu generate model`](model.md) - Generate models
- [`azu db:migrate`](../commands/database.md) - Run migrations
