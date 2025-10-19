# Enhanced Authentication System

This authentication system provides comprehensive security features including JWT tokens, RBAC, CSRF protection, OAuth2 integration, and more.

## Features

### 🔐 Authentication Strategies

- **JWT Tokens**: Secure token-based authentication with refresh tokens
- **Session-based**: Traditional session authentication
- **OAuth2**: Integration with Authly for OAuth2/OIDC support
- **Authly Integration**: Full OAuth2 provider implementation

### 🛡️ Security Features

- **CSRF Protection**: Cross-site request forgery prevention
- **Security Headers**: Comprehensive security headers middleware
- **Rate Limiting**: Protection against brute force attacks
- **Password Security**: Strong password requirements and bcrypt hashing
- **Account Lockout**: Automatic account locking after failed attempts
- **Two-Factor Authentication**: Ready for 2FA implementation

### 👥 Role-Based Access Control (RBAC)

- **Roles**: Hierarchical role system (super_admin, admin, moderator, user)
- **Permissions**: Granular permission system
- **Resource-based**: Permissions tied to specific resources and actions
- **Flexible**: Easy to extend with custom roles and permissions

### 🔑 OAuth2 Integration

- **Multiple Providers**: Google, GitHub, and custom providers
- **Authly Integration**: Full OAuth2 authorization server
- **PKCE Support**: Enhanced security for public clients
- **Token Management**: Secure token storage and validation

## Quick Start

### 1. Generate Authentication System

```bash
# Generate with default Authly strategy
azu generate auth

# Generate with JWT strategy
azu generate auth --strategy=jwt

# Generate with session strategy
azu generate auth --strategy=session

# Generate with custom options
azu generate auth --strategy=authly --rbac=true --csrf=true --oauth-providers=google,github
```

### 2. Configure Environment

Copy the environment example and configure your values:

```bash
cp env.example .env
```

Edit `.env` with your configuration:

```bash
# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-here
JWT_REFRESH_SECRET=your-refresh-secret-key
JWT_ISSUER=your-app-api
JWT_AUDIENCE=your-app-client

# Admin User
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=Admin123!

# OAuth Providers (if using Authly)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
```

### 3. Run Migrations

```bash
# Create authentication tables
azu db:migrate

# Seed RBAC data (if RBAC is enabled)
crystal run db/seed_rbac.cr
```

### 4. Configure Middleware

Add security middleware to your application:

```crystal
# In your main application file
require "./src/middleware/csrf_protection"
require "./src/middleware/security_headers"

# Add middleware to your Azu application
use <%=project.camelcase%>::Middleware::SecurityHeaders
use <%=project.camelcase%>::Middleware::CSRFProtection
```

## API Endpoints

### Authentication Endpoints

| Method | Endpoint                | Description               |
| ------ | ----------------------- | ------------------------- |
| POST   | `/auth/register`        | Register a new user       |
| POST   | `/auth/login`           | Login with email/password |
| POST   | `/auth/refresh`         | Refresh access token      |
| POST   | `/auth/logout`          | Logout user               |
| GET    | `/auth/me`              | Get current user info     |
| POST   | `/auth/change-password` | Change user password      |

### OAuth Endpoints (if using Authly)

| Method | Endpoint                         | Description      |
| ------ | -------------------------------- | ---------------- |
| GET    | `/auth/oauth/:provider`          | Start OAuth flow |
| GET    | `/auth/oauth/:provider/callback` | OAuth callback   |

### RBAC Endpoints (if RBAC enabled)

| Method | Endpoint            | Description          |
| ------ | ------------------- | -------------------- |
| GET    | `/auth/permissions` | Get user permissions |

## Usage Examples

### Registration

```javascript
const response = await fetch("/auth/register", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    email: "user@example.com",
    password: "SecurePass123!",
    password_confirmation: "SecurePass123!",
    name: "John Doe",
  }),
});

const data = await response.json();
// Returns: { user: {...}, access_token: "...", refresh_token: "..." }
```

### Login

```javascript
const response = await fetch("/auth/login", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    email: "user@example.com",
    password: "SecurePass123!",
  }),
});

const data = await response.json();
// Returns: { user: {...}, access_token: "...", refresh_token: "..." }
```

### Using Access Token

```javascript
const response = await fetch("/auth/me", {
  headers: {
    Authorization: `Bearer ${access_token}`,
  },
});

const userData = await response.json();
```

### Token Refresh

```javascript
const response = await fetch("/auth/refresh", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    refresh_token: refresh_token,
  }),
});

const data = await response.json();
// Returns: { access_token: "...", refresh_token: "..." }
```

## Security Features

### CSRF Protection

The system includes comprehensive CSRF protection:

```crystal
# Get CSRF token for forms
csrf_token = CSRFProtection.get_or_create_token(context)

# Include in forms
<form>
  <input type="hidden" name="_csrf_token" value="<%= csrf_token %>">
  <!-- form fields -->
</form>
```

### Security Headers

The SecurityHeaders middleware adds:

- Content Security Policy (CSP)
- HTTP Strict Transport Security (HSTS)
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection
- Referrer Policy
- Permissions Policy

### Rate Limiting

Built-in rate limiting prevents brute force attacks:

- Maximum 5 failed login attempts
- 30-minute lockout period
- Automatic unlock after cooldown

## RBAC System

### Default Roles

1. **super_admin**: Full system access
2. **admin**: Most system access
3. **moderator**: Content management access
4. **user**: Basic user access

### Default Permissions

- `users:*` - User management
- `roles:*` - Role management
- `permissions:*` - Permission management
- `admin:*` - Admin operations
- `content:*` - Content management
- `profile:*` - Profile management

### Checking Permissions

```crystal
# In your endpoints
def some_protected_action
  halt 403, {error: "Access denied"}.to_json unless current_user.has_permission?("users:read")

  # Your protected logic here
end

# Check resource-specific permissions
def edit_user(user_id)
  halt 403, {error: "Access denied"}.to_json unless current_user.has_permission_for_resource?("users", "update")

  # Your logic here
end
```

## OAuth2 with Authly

### Configuration

```crystal
# In your application startup
require "./src/config/authly"
<%=project.camelcase%>::Config::AuthlyConfig.configure
```

### OAuth Flow

1. User clicks "Login with Google"
2. Redirect to `/auth/oauth/google`
3. User authorizes on Google
4. Google redirects to `/auth/oauth/google/callback`
5. System creates/updates user account
6. Return access token to client

## Customization

### Adding Custom Permissions

```crystal
# Create new permission
permission = Permission.create!(
  name: "custom:action",
  description: "Custom action permission",
  resource: "custom",
  action: "action"
)

# Assign to role
role = Role.find_by(name: "admin")
role.add_permission!("custom:action")
```

### Custom OAuth Providers

```crystal
# In authly configuration
config.oauth_providers = {
  "custom" => CustomOAuthProvider.new
}
```

## Troubleshooting

### Common Issues

1. **JWT Secret Not Set**

   ```
   Error: JWT_SECRET environment variable not set
   ```

   Solution: Set JWT_SECRET in your .env file

2. **Database Connection Issues**

   ```
   Error: Database connection failed
   ```

   Solution: Check DATABASE_URL in your .env file

3. **CSRF Token Mismatch**
   ```
   Error: Invalid CSRF token
   ```
   Solution: Ensure CSRF tokens are properly included in forms

### Debug Mode

Enable debug logging:

```crystal
# In your application
AzuCLI::Logger.level = :debug
```

## Best Practices

1. **Environment Variables**: Never commit secrets to version control
2. **Token Expiration**: Use short-lived access tokens (15 minutes)
3. **Refresh Tokens**: Store securely and rotate regularly
4. **Password Policy**: Enforce strong password requirements
5. **Rate Limiting**: Implement rate limiting on all auth endpoints
6. **HTTPS**: Always use HTTPS in production
7. **Security Headers**: Enable all security headers
8. **Regular Updates**: Keep dependencies updated

## Dependencies

The authentication system uses these Crystal shards:

- `crypto/bcrypt` - Password hashing
- `jwt` - JWT token handling
- `uuid` - Unique identifier generation
- `authly` - OAuth2/OIDC implementation (if using Authly)
- `secure_random` - Secure random number generation
- `openssl` - Cryptographic operations

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review the generated code and configuration
3. Check environment variables and database connectivity
4. Enable debug logging for detailed error information

## License

This authentication system is part of the Azu CLI project and follows the same license terms.
