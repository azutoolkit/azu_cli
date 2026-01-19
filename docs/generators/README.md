# Generators Overview

Azu CLI's generator system is one of its most powerful features, allowing you to rapidly scaffold components, models, services, and complete applications. This guide provides an overview of how generators work, the philosophy behind them, and how to use them effectively.

## What Are Generators?

Generators are automated code creation tools that follow Azu's conventions and best practices. They create files, directories, and boilerplate code based on templates, saving you time and ensuring consistency across your application.

## Generator Philosophy

### Convention Over Configuration

Generators follow established patterns and naming conventions, so you don't have to make decisions about file organization, naming, or structure.

### DRY (Don't Repeat Yourself)

Instead of writing boilerplate code repeatedly, generators create it for you with proper patterns and best practices built-in.

### Test-Driven Development

All generators create corresponding test files, encouraging you to write tests alongside your application code.

### Modular Architecture

Each generator creates focused, single-responsibility components that work together as part of a larger system.

## Available Generators

| Generator                               | Purpose                     | Files Created                          | Use Case                         |
| --------------------------------------- | --------------------------- | -------------------------------------- | -------------------------------- |
| **[endpoint](endpoint.md)**             | HTTP request handlers       | Endpoints, contracts, pages, templates | Web controllers, API endpoints   |
| **[model](model.md)**                   | Database models             | Model classes with validations         | Data persistence layer           |
| **[service](service.md)**               | Business logic              | Service classes                        | Domain logic, complex operations |
| **[middleware](middleware.md)**         | HTTP middleware             | Middleware classes                     | Cross-cutting concerns           |
| **[contract](contract.md)**             | Request/response validation | Contract structs                       | Input validation, API contracts  |
| **[page](page.md)**                     | HTML page components        | Page classes, templates                | View layer, HTML rendering       |
| **[component](component.md)**           | Live interactive components | Component classes                      | Real-time UI, dynamic interfaces |
| **[validator](custom-validator.md)**    | Custom validation logic     | Validator classes                      | Reusable validation rules        |
| **[migration](migration.md)**           | Database migrations         | Migration files                        | Database schema changes          |
| **[data_migration](data-migration.md)** | Data transformations        | Data migration scripts                 | Data imports, transformations    |
| **[auth](auth.md)**                     | Authentication system       | Auth models, endpoints, middleware     | User authentication, RBAC        |
| **[channel](channel.md)**               | WebSocket channels          | Channel classes, client code           | Real-time communication          |
| **[mailer](mailer.md)**                 | Email functionality         | Mailer classes, templates, jobs        | Transactional emails             |
| **[scaffold](scaffold.md)**             | Complete CRUD resource      | All of the above                       | Rapid prototyping                |

## Generator Types

### 1. Structural Generators

Create the main building blocks of your application:

- **Model**: Data layer with database persistence
- **Endpoint**: HTTP request handling and routing
- **Service**: Business logic encapsulation
- **Middleware**: Request/response processing

### 2. Interface Generators

Create user-facing components:

- **Page**: HTML rendering and templates
- **Component**: Interactive, real-time UI elements
- **Contract**: API input/output contracts

### 3. Utility Generators

Create supporting functionality:

- **Validator**: Custom validation logic
- **Migration**: Database schema management

### 4. Composite Generators

Create multiple related files:

- **Scaffold**: Complete CRUD resource with all components

## Generator Workflow

### 1. Planning Phase

Before running a generator, consider:

- **Component name** (should be descriptive and follow conventions)
- **Attributes** (for models, contracts, components)
- **Relationships** (how it connects to other components)
- **Custom options** (API-only, skip tests, etc.)

### 2. Generation Phase

```bash
# Basic syntax
azu generate <type> <name> [attributes] [options]

# Examples
azu generate model User name:string email:string
azu generate endpoint posts
azu generate service UserRegistration
```

### 3. Customization Phase

After generation:

- **Review generated files** for accuracy
- **Customize business logic** in services and endpoints
- **Add validations** to models and contracts
- **Write tests** for your specific use cases
- **Update routes** if needed

### 4. Integration Phase

- **Connect components** together
- **Update imports** and dependencies
- **Run migrations** for database changes
- **Test the complete feature**

## Common Generator Patterns

### 1. Resource-Based Generation

For typical CRUD resources:

```bash
# Generate everything for a blog post
azu generate scaffold Post title:string content:text published:boolean

# Or step by step
azu generate model Post title:string content:text published:boolean
azu generate migration create_posts_table title:string content:text published:boolean
azu generate endpoint posts
```

### 2. Service-Oriented Generation

For complex business logic:

```bash
# Generate the service
azu generate service UserRegistration

# Generate supporting models if needed
azu generate model User name:string email:string
azu generate validator EmailValidator type:email
```

### 3. API-First Generation

For API-only applications:

```bash
# Generate API endpoints without pages
azu generate endpoint api/v1/users --api

# Generate models for data
azu generate model User name:string email:string
azu generate service UserRegistration
```

### 4. Component-Based Generation

For interactive features:

```bash
# Generate real-time components
azu generate component Counter count:integer --websocket
azu generate component ChatMessage text:string user:string --events send,delete
```

## Generator Options

### Global Options

Available for all generators:

| Option         | Description               | Default |
| -------------- | ------------------------- | ------- |
| `--force`      | Overwrite existing files  | false   |
| `--skip-tests` | Don't generate test files | false   |
| `--help`       | Show generator help       |         |

### Specific Options

Different generators have specialized options:

**Endpoint Generator:**

- `--api` - Generate API-only (no pages/templates)
- `--actions <list>` - Specify which CRUD actions

**Model Generator:**

- `--validations` - Add common validations
- `--timestamps` - Add created_at/updated_at
- `--uuid` - Use UUID primary key

**Component Generator:**

- `--websocket` - Enable real-time features
- `--events <list>` - Custom event handlers

## Naming Conventions

### Component Names

- **PascalCase** for class names: `User`, `BlogPost`, `UserRegistration`
- **snake_case** for file names: `user.cr`, `blog_post.cr`, `user_registration.cr`
- **Pluralized** for collections: `users` (endpoints), `posts` (tables)

### File Organization

```
src/
├── models/user.cr              # User
├── endpoints/users/            # Users::*Endpoint
│   ├── index_endpoint.cr
│   └── show_endpoint.cr
├── services/user_registration_service.cr  # UserRegistrationService
├── contracts/users/            # Users::*Contract
│   └── create_contract.cr
└── pages/users/                # Users::*Page
    └── index_page.cr
```

### Namespace Conventions

- **Endpoints**: `Users::IndexEndpoint`
- **Contracts**: `Users::CreateContract`
- **Pages**: `Users::IndexPage`
- **Models**: `User` (no namespace)
- **Services**: `UserRegistrationService`
- **Components**: `CounterComponent`

## Template System

### How Templates Work

Generators use ECR (Embedded Crystal) templates:

```crystal
# Template: model.cr.ecr
class <%= class_name %> < CQL::Model
  db_table "<%= table_name %>"

<% attributes.each do |name, type| -%>
  field <%= name %> : <%= crystal_type(type) %>
<% end -%>

<% if validations? -%>
<% attributes.each do |name, type| -%>
  validate :<%= name %>, presence: true
<% end -%>
<% end -%>
end
```

### Template Variables

Common variables available in templates:

| Variable       | Description           | Example                |
| -------------- | --------------------- | ---------------------- |
| `class_name`   | PascalCase class name | `User`                 |
| `file_name`    | snake_case file name  | `user`                 |
| `table_name`   | Database table name   | `users`                |
| `namespace`    | Module namespace      | `Users`                |
| `attributes`   | Hash of attributes    | `{"name" => "string"}` |
| `project_name` | Current project name  | `my_blog`              |

### Custom Templates

You can override default templates:

1. **Create template directory**:

   ```bash
   mkdir -p ~/.azu/templates/generators/model/
   ```

2. **Create custom template**:

   ```crystal
   # ~/.azu/templates/generators/model/model.cr.ecr
   # Your custom model template
   ```

3. **Use custom template**:
   ```bash
   azu generate model User --template custom
   ```

## Generated File Structure

### Complete Example

When you run `azu generate scaffold Post title:string content:text`, you get:

```
src/
├── models/
│   └── post.cr                 # Post model with validations
├── endpoints/posts/
│   ├── index_endpoint.cr       # GET /posts
│   ├── show_endpoint.cr        # GET /posts/:id
│   ├── new_endpoint.cr         # GET /posts/new
│   ├── create_endpoint.cr      # POST /posts
│   ├── edit_endpoint.cr        # GET /posts/:id/edit
│   ├── update_endpoint.cr      # PUT /posts/:id
│   └── destroy_endpoint.cr     # DELETE /posts/:id
├── contracts/posts/
│   ├── index_contract.cr       # Query parameters
│   ├── show_contract.cr        # Show parameters
│   ├── create_contract.cr      # Creation validation
│   └── update_contract.cr      # Update validation
└── pages/posts/
    ├── index_page.cr           # Posts listing
    ├── show_page.cr            # Post details
    ├── new_page.cr             # New post form
    └── edit_page.cr            # Edit post form

public/templates/posts/
├── index_page.jinja            # HTML templates
├── show_page.jinja
├── new_page.jinja
└── edit_page.jinja

spec/
├── models/post_spec.cr         # Model tests
└── endpoints/posts_spec.cr     # Endpoint tests

db/migrations/
└── 20231214_120000_create_posts_table.cr  # Migration
```

## Best Practices

### 1. Planning Before Generation

- **Design your models** first to understand relationships
- **Plan your API structure** before generating endpoints
- **Consider reusable components** for common functionality

### 2. Consistent Naming

- **Use descriptive names** that clearly indicate purpose
- **Follow Crystal conventions** for naming
- **Be consistent** across your application

### 3. Incremental Generation

- **Start with models** to establish your data layer
- **Add services** for business logic
- **Generate endpoints** for HTTP interface
- **Use scaffold** only for rapid prototyping

### 4. Customization After Generation

- **Review all generated code** before committing
- **Add custom validation rules** to models
- **Implement business logic** in services
- **Customize templates** to match your UI needs

### 5. Testing Strategy

- **Don't skip test generation** unless absolutely necessary
- **Customize generated tests** for your specific requirements
- **Add integration tests** for complete workflows
- **Test both success and failure scenarios**

## Advanced Usage

### 1. Batch Generation

```bash
# Generate related components in sequence
azu generate model User name:string email:string
azu generate service UserRegistration
azu generate endpoint users
azu generate migration create_users_table name:string email:string
```

### 2. Template Customization

```bash
# Override specific generator templates
mkdir -p ~/.azu/templates/generators/model/
cp default_template.cr.ecr ~/.azu/templates/generators/model/model.cr.ecr
# Edit the template
```

### 3. Generator Configuration

```yaml
# .azu/config.yml
generators:
  model:
    include_timestamps: true
    default_validations: true
  endpoint:
    default_format: json
    include_authentication: true
```

## Troubleshooting

### Common Issues

**File Already Exists**

```bash
# Use --force to overwrite
azu generate model User --force
```

**Invalid Attribute Format**

```bash
# Correct: name:type
azu generate model User name:string email:string

# Incorrect: name=string, name string
```

**Missing Dependencies**

```bash
# Ensure you're in an Azu project directory
# Check that required shards are installed
shards install
```

**Generator Not Found**

```bash
# Check available generators
azu generate --help

# Use full generator names, not abbreviations
```

### Getting Help

```bash
# General generator help
azu generate --help

# Specific generator help
azu generate model --help
azu generate endpoint --help
```

---

The generator system is designed to accelerate your development while maintaining code quality and consistency. Master these tools to become highly productive with Azu applications.

**Next Steps:**

- [Endpoint Generator](endpoint.md) - Generate HTTP request handlers
- [Model Generator](model.md) - Create database models
- [Development Workflows](../examples/README.md) - Use generators in real projects

# README Generator

The README Generator creates comprehensive, well-structured README.md files following modern documentation best practices for Crystal projects.

## Overview

The README generator produces professional README.md files that include:

- **Project metadata**: title, description, badges, license information
- **Installation instructions**: both shards and manual installation
- **Usage examples**: tailored to project type (library, CLI, web, service)
- **Development setup**: prerequisites, setup steps, testing, building
- **Contribution guidelines**: standards, workflow, issue reporting
- **Comprehensive sections**: API docs, changelog, roadmap, support

## Usage

### Basic Usage

Generate a basic README.md file:

```bash
azu generate readme my_project
```

This creates a README.md file in the current directory with:

- Project title: "My Project" (formatted)
- Default description: "A Crystal project"
- Standard sections for a library project
- MIT license and basic author info
- Default features and badges

### Advanced Usage

Generate with custom configuration:

```bash
azu generate readme my_awesome_cli \
  --description "A powerful CLI tool for developers" \
  --github-user "johndoe" \
  --project-type "cli" \
  --license "Apache-2.0" \
  --database "postgresql" \
  --crystal-version ">= 1.15.0" \
  --output-dir "."
```

### Project Type Specific Generation

Generate README tailored to specific project types:

```bash
# For CLI tools
azu generate readme my_tool --project-type cli

# For web applications
azu generate readme my_webapp --project-type web

# For libraries (default)
azu generate readme my_lib --project-type library

# For services/APIs
azu generate readme my_api --project-type service
```

### Programmatic Usage

```crystal
require "azu_cli/generators/readme_generator"

# Basic usage
generator = AzuCLI::Generators::ReadmeGenerator.new("my_project")
generator.generate!

# Advanced configuration
generator = AzuCLI::Generators::ReadmeGenerator.new(
  "my_awesome_project",
  output_dir: "/path/to/project",
  description: "An amazing Crystal project that does awesome things",
  github_user: "developer",
  license: "MIT",
  crystal_version: ">= 1.16.0",
  authors: ["Developer <dev@example.com>"],
  features: [
    "🚀 Lightning fast performance",
    "📦 Easy installation and setup",
    "🔧 Comprehensive test coverage",
    "💎 Built with Crystal",
    "🛡️ Type-safe and reliable"
  ],
  project_type: "web",
  database: "postgresql",
  has_badges: true,
  has_api_docs: true,
  has_roadmap: true,
  roadmap_items: [
    "Add GraphQL support",
    "Implement real-time features",
    "Performance optimizations"
  ],
  has_acknowledgments: true,
  acknowledgments: [
    "Crystal programming language community",
    "Contributors and maintainers"
  ]
)

output_path = generator.generate!
```

## Generated Output

### Example README.md

Generated for a web application with PostgreSQL:

````markdown
# My Awesome Project

An amazing Crystal project that does awesome things

## Badges

[![Crystal CI](https://github.com/developer/my-awesome-project/actions/workflows/ci.yml/badge.svg)](https://github.com/developer/my-awesome-project/actions/workflows/ci.yml)
[![GitHub release](https://img.shields.io/github/release/developer/my-awesome-project.svg)](https://github.com/developer/my-awesome-project/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/developer/my-awesome-project/blob/master/LICENSE)

## Features

- 🚀 Lightning fast performance
- 📦 Easy installation and setup
- 🔧 Comprehensive test coverage
- 💎 Built with Crystal
- 🛡️ Type-safe and reliable

## Installation

### Using Shards

Add this to your application's `shard.yml`:

```yaml
dependencies:
  my_awesome_project:
    github: developer/my-awesome-project
```
````

### Web Application

1. Start the server:

   ```bash
   crystal run src/my_awesome_project.cr
   ```

2. Open your browser and visit:
   ```
   http://localhost:3000
   ```

### Configuration

Create a `.env` file in the project root:

```bash
# Database configuration
DATABASE_URL=postgres://user:password@localhost:5432/database_name

# Server configuration
PORT=3000
HOST=localhost

# Environment
ENVIRONMENT=development
```

## Development

### Prerequisites

- Crystal >= 1.16.0
- PostgreSQL database

### Setup

1. Fork it (<https://github.com/developer/my-awesome-project/fork>)
2. Clone your fork...
3. Install dependencies...
4. Set up the database...

## Contributing

1. Fork it
2. Create your feature branch
3. Make your changes and add tests
4. Ensure all tests pass
5. Format your code
6. Run the linter
7. Commit your changes
8. Push to the branch
9. Create a new Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

````

## Configuration Options

### Project Metadata

| Option          | Type          | Default                          | Description                                  |
| --------------- | ------------- | -------------------------------- | -------------------------------------------- |
| `project_name`  | String        | Required                         | Project name (formatted automatically)      |
| `description`   | String        | `"A Crystal project"`            | Project description                          |
| `github_user`   | String        | `"your-github-user"`             | GitHub username/organization                 |
| `license`       | String        | `"MIT"`                          | License identifier                           |
| `authors`       | Array(String) | `["Your Name <your@email.com>"]` | Author information                           |

### Project Configuration

| Option             | Type   | Default        | Description                                                           |
| ------------------ | ------ | -------------- | --------------------------------------------------------------------- |
| `project_type`     | String | `"library"`    | Project type (`library`, `cli`, `web`, `service`)                    |
| `crystal_version`  | String | `">= 1.16.0"`  | Minimum Crystal version requirement                                   |
| `database`         | String | `"none"`       | Database type (`postgresql`, `mysql`, `sqlite`, `none`)              |

### Features and Content

| Option            | Type          | Default         | Description                      |
| ----------------- | ------------- | --------------- | -------------------------------- |
| `features`        | Array(String) | Default set     | List of project features         |
| `has_badges`      | Bool          | `true`          | Include GitHub badges            |
| `has_api_docs`    | Bool          | `true`          | Include API documentation section |
| `has_roadmap`     | Bool          | `false`         | Include roadmap section          |
| `roadmap_items`   | Array(String) | `[]`            | Roadmap items list               |

## Project Types

The generator tailors content based on project type:

### Library Projects (`library`)
- Installation via shards
- Basic and advanced usage examples
- API documentation links
- Library-specific development setup

### CLI Tools (`cli`)
- Command-line usage examples
- Available commands section
- Installation instructions
- CLI-specific help and options

### Web Applications (`web`)
- Server setup and configuration
- Database setup instructions
- Environment configuration
- Development server commands

### Services/APIs (`service`)
- API endpoint documentation
- Service configuration
- Deployment considerations
- Monitoring and health checks

## Naming Conventions

The generator automatically formats project names:

### Project Name Formatting

- Input: `my_awesome_project` → Title: "My Awesome Project"
- Input: `MyAwesomeProject` → Title: "My Awesome Project"
- Input: `my-awesome-project` → Title: "My Awesome Project"
- Input: `myproject` → Title: "Myproject"

### File and URL Generation

```yaml
Project: "my_awesome_project"
├── README title: "My Awesome Project"
├── GitHub repo: "my-awesome-project" (kebab-case)
├── Shard name: "my_awesome_project" (snake_case)
└── Class name: "MyAwesomeProject" (PascalCase)
````

## Database Integration

When database support is specified, the README includes:

### PostgreSQL

- Database setup instructions
- Connection configuration
- Migration commands
- Prerequisites section mentions PostgreSQL

### MySQL

- MySQL-specific setup
- Connection string examples
- Database creation steps

### SQLite

- File-based database info
- Simplified setup process
- Local development focus

### None

- Omits database-related sections
- Focuses on application logic
- Simplified prerequisites

## Advanced Features

### Badges and Shields

Automatically includes relevant badges:

- **CI/CD Status**: GitHub Actions workflow status
- **Release Version**: Latest GitHub release version
- **License**: License type with appropriate color
- **Custom badges**: Can be extended for specific needs

### Author Attribution

Generates GitHub links for authors:

- Extracts names from email format: `"John Doe <john@example.com>"`
- Creates GitHub profile links: `https://github.com/john-doe`
- Assigns roles: first author is "creator and maintainer", others are "contributors"

### Roadmap Integration

When enabled, includes:

- Checkbox-style roadmap items
- Future feature planning
- Development priorities
- Community engagement

### Support Information

Customizable support section:

- Default: generic contribution encouragement
- Custom: specific support channels, contact info
- Community resources and links

## Validation

The generator validates:

- **Project names**: Must be valid Crystal identifiers
- **GitHub usernames**: Must follow GitHub username format
- **Required fields**: Description, license, crystal version cannot be empty
- **Author format**: Authors array cannot be empty
- **Features**: Feature descriptions cannot be empty

## Integration with Azu CLI

The README generator integrates with the main `azu generate` command:

```bash
# List available generators
azu generate --help

# Generate README
azu generate readme my_project

# Generate with specific options
azu generate readme my_project \
  --description "My project description" \
  --project-type web \
  --github-user myusername
```

## Best Practices

### Content Guidelines

- Write clear, concise descriptions
- Include comprehensive installation instructions
- Provide working code examples
- Document all configuration options
- Keep README updated with project changes

### Project Type Selection

- **Library**: Choose for reusable packages and modules
- **CLI**: Choose for command-line tools and utilities
- **Web**: Choose for web applications and websites
- **Service**: Choose for APIs and microservices

### GitHub Integration

- Use your actual GitHub username
- Ensure repository names match project names
- Set up CI/CD workflows referenced in badges
- Create LICENSE file to match specified license

### Feature Description

- Use emoji for visual appeal and scanning
- Focus on user benefits, not technical details
- Keep descriptions short and impactful
- Highlight unique selling points

### Database Documentation

- Document all required environment variables
- Provide working connection examples
- Include database schema information
- Document migration and seeding processes

## Troubleshooting

### Common Issues

**Invalid GitHub username error:**

```
Error: Invalid GitHub username format: -invalid-
```

_Solution_: Use valid GitHub username format (alphanumeric, hyphens allowed, cannot start/end with hyphen)

**Empty description error:**

```
Error: Description cannot be empty
```

_Solution_: Provide a meaningful project description

**Unsupported project type:**

```
Error: Unsupported project type: invalid
```

_Solution_: Use one of the supported types: `library`, `cli`, `web`, `service`

### Debugging

Check generated content:

```bash
cat README.md
```

Validate Markdown syntax:

```bash
# Use a Markdown linter
markdownlint README.md
```

Preview rendered output:

```bash
# Use a Markdown viewer or GitHub preview
```

## Examples

### Minimal Library

```crystal
generator = AzuCLI::Generators::ReadmeGenerator.new(
  "crypto_utils",
  description: "Cryptographic utilities for Crystal",
  github_user: "cryptodev"
)
generator.generate!
```

### Full-Featured Web App

```crystal
generator = AzuCLI::Generators::ReadmeGenerator.new(
  "social_platform",
  description: "A modern social media platform built with Crystal",
  github_user: "socialdev",
  project_type: "web",
  database: "postgresql",
  features: [
    "🔐 Secure authentication and authorization",
    "📱 Real-time messaging and notifications",
    "🎨 Modern, responsive UI design",
    "⚡ High-performance backend",
    "🛡️ Privacy-focused architecture"
  ],
  has_roadmap: true,
  roadmap_items: [
    "Mobile application development",
    "Advanced analytics dashboard",
    "Integration with external services",
    "Performance monitoring and optimization"
  ]
)
generator.generate!
```

### CLI Tool

```crystal
generator = AzuCLI::Generators::ReadmeGenerator.new(
  "file_organizer",
  description: "Intelligent file organization tool",
  github_user: "devtools",
  project_type: "cli",
  features: [
    "🗂️ Smart file categorization",
    "⚡ Lightning-fast processing",
    "🎯 Customizable organization rules",
    "📊 Detailed operation reports"
  ]
)
generator.generate!
```

## Related Documentation

- [Crystal Language Documentation](https://crystal-lang.org/reference/)
- [Azu Framework Documentation](https://github.com/azutoolkit/azu)
- [Generator Architecture](../architecture/generator-system.md)
- [CLI Commands Reference](../commands/generate.md)
- [Markdown Guide](https://guides.github.com/features/mastering-markdown/)
