# Creating a New Project

This guide walks you through creating a new Azu project from scratch, including setup, configuration, and initial development.

## Prerequisites

Before creating a new project, ensure you have:

- [Crystal](https://crystal-lang.org/install/) installed (version 1.16.0 or later)
- [Azu CLI](getting-started/installation.md) installed
- A database system (PostgreSQL, MySQL, or SQLite) if you plan to use databases

## Quick Start

### 1. Create a New Project

```bash
azu new my-awesome-app
```

This creates a new project with the basic structure and dependencies.

### 2. Navigate to Your Project

```bash
cd my-awesome-app
```

### 3. Install Dependencies

```bash
shards install
```

### 4. Set Up the Database (Optional)

```bash
azu db:create
azu db:migrate
```

### 5. Start the Development Server

```bash
azu serve
```

Your application is now running at `http://localhost:3000`!

## Project Templates

Azu CLI provides several project templates to get you started quickly:

### Web Application Template

```bash
azu new my-web-app --template web
```

Creates a full-stack web application with:

- HTML templates with Jinja2
- CSS and JavaScript assets
- User authentication (optional)
- Database integration
- Real-time features (optional)

### API-Only Template

```bash
azu new my-api --template api
```

Creates a RESTful API with:

- JSON endpoints
- Authentication middleware
- Database models
- API documentation structure
- Testing framework

### CLI Application Template

```bash
azu new my-cli --template cli
```

Creates a command-line application with:

- Command structure
- Configuration management
- Logging system
- Testing framework

## Project Configuration

### Database Configuration

Choose your database when creating the project:

```bash
# PostgreSQL (recommended for production)
azu new my-app --database postgresql

# MySQL
azu new my-app --database mysql

# SQLite (good for development)
azu new my-app --database sqlite
```

### Authentication Setup

Include authentication in your project:

```bash
azu new my-app --auth
```

This adds:

- User model and migration
- Authentication endpoints
- Login/logout functionality
- Session management

### Real-time Features

Add real-time capabilities:

```bash
azu new my-app --real-time
```

This includes:

- WebSocket support
- Real-time channels
- Live updates
- Broadcasting system

## Project Structure

After creating a project, you'll have this structure:

```
my-awesome-app/
├── src/
│   ├── my_awesome_app.cr          # Main application file
│   ├── server.cr                  # Server configuration
│   ├── models/                    # Database models
│   ├── endpoints/                 # API endpoints
│   ├── pages/                     # Web pages
│   ├── contracts/                 # Validation contracts
│   ├── services/                  # Business logic
│   ├── middleware/                # HTTP middleware
│   ├── components/                # Reusable UI components
│   ├── db/                        # Database files
│   │   ├── migrations/            # Database migrations
│   │   ├── schema.cr              # Database schema
│   │   └── seed.cr                # Seed data
│   └── initializers/              # Application initialization
├── public/                        # Static assets
│   ├── assets/
│   │   ├── css/
│   │   └── js/
│   └── templates/                 # HTML templates
├── spec/                          # Test files
├── config/                        # Configuration files
├── shard.yml                      # Dependencies
├── shard.lock                     # Locked dependency versions
└── README.md                      # Project documentation
```

## Initial Setup

### 1. Configure Environment Variables

Create a `.env` file for your environment variables:

```bash
# Database
DATABASE_URL=postgresql://localhost/my_awesome_app_development

# Application
APP_ENV=development
APP_SECRET=your-secret-key-here

# Server
HOST=0.0.0.0
PORT=3000
```

### 2. Update Configuration

Edit `config/application.yml` to match your setup:

```yaml
database:
  url: <%= ENV["DATABASE_URL"] %>
  pool_size: 10

server:
  host: <%= ENV["HOST"] || "0.0.0.0" %>
  port: <%= ENV["PORT"] || 3000 %>

app:
  secret: <%= ENV["APP_SECRET"] %>
  environment: <%= ENV["APP_ENV"] || "development" %>
```

### 3. Set Up Git Repository

```bash
git init
git add .
git commit -m "Initial commit"
```

## Development Workflow

### 1. Start Development Server

```bash
azu serve
```

This starts the development server with:

- Hot reloading (automatically restarts on file changes)
- Error reporting
- Development logging

### 2. Generate Components

Use generators to create new components:

```bash
# Generate a model
azu generate model User name:string email:string

# Generate an endpoint
azu generate endpoint Users::Index

# Generate a page
azu generate page Users

# Generate a complete resource
azu generate scaffold Post title:string content:text
```

### 3. Run Tests

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/models/user_spec.cr

# Run tests with coverage
crystal spec --coverage
```

### 4. Database Operations

```bash
# Create database
azu db:create

# Run migrations
azu db:migrate

# Rollback migrations
azu db:rollback

# Seed database
azu db:seed

# Reset database (drop, create, migrate, seed)
azu db:reset
```

## Common Next Steps

### 1. Add Authentication

If you didn't include authentication during project creation:

```bash
# Generate user model
azu generate model User email:string password_digest:string

# Generate authentication endpoints
azu generate endpoint Auth::Login
azu generate endpoint Auth::Register
azu generate endpoint Auth::Logout

# Generate authentication pages
azu generate page Auth::Login
azu generate page Auth::Register
```

### 2. Set Up Testing

```bash
# Install testing dependencies
shards add ameba --group=development

# Run code analysis
crystal tool format
ameba
```

### 3. Add API Documentation

```bash
# Generate API documentation structure
azu generate docs

# Add OpenAPI specification
# Edit src/docs/openapi.yml
```

### 4. Configure Logging

```bash
# Set up structured logging
# Edit src/initializers/logger.cr
```

## Deployment Preparation

### 1. Production Configuration

Create production configuration:

```bash
# Create production environment file
cp .env .env.production

# Update production settings
# Edit .env.production
```

### 2. Build for Production

```bash
# Build optimized binary
crystal build --release src/my_awesome_app.cr

# Or use the build command
azu build
```

### 3. Environment Setup

Ensure your production environment has:

- Crystal runtime
- Database system
- Required system libraries
- Environment variables configured

## Troubleshooting

### Common Issues

#### Database Connection Errors

```bash
# Check database status
azu db:status

# Verify connection string
echo $DATABASE_URL

# Test connection
azu db:test
```

#### Port Already in Use

```bash
# Use different port
azu serve --port 3001

# Or kill existing process
lsof -ti:3000 | xargs kill -9
```

#### Missing Dependencies

```bash
# Reinstall dependencies
shards install

# Update dependencies
shards update
```

#### Compilation Errors

```bash
# Check Crystal version
crystal --version

# Format code
crystal tool format

# Check for syntax errors
crystal tool hierarchy
```

## Best Practices

### 1. Project Organization

- Keep related files together
- Use consistent naming conventions
- Separate concerns (models, views, controllers)
- Follow the established directory structure

### 2. Configuration Management

- Use environment variables for sensitive data
- Keep configuration files in version control
- Use different configurations for different environments
- Document configuration options

### 3. Development Workflow

- Write tests for new features
- Use generators for consistency
- Follow Crystal coding standards
- Use meaningful commit messages

### 4. Database Management

- Write migrations for all schema changes
- Test migrations before deploying
- Use meaningful migration names
- Keep migrations focused and reversible

## Next Steps

After setting up your project:

1. **Read the Documentation**: Explore the [command reference](commands/README.md) and [generators guide](generators/README.md)
2. **Build Your First Feature**: Use generators to create your first model and endpoints
3. **Set Up Testing**: Write tests for your application logic
4. **Configure Deployment**: Prepare your application for production deployment
5. **Join the Community**: Connect with other Azu developers for support and collaboration

## Related Documentation

- [Project Structure](getting-started/project-structure.md) - Detailed explanation of project organization
- [Database Workflow](database-workflow.md) - Working with databases
- [Building APIs](building-apis.md) - Creating RESTful APIs
- [Building Web Applications](building-web-apps.md) - Creating web applications
- [Testing Your Application](testing.md) - Testing strategies and best practices
