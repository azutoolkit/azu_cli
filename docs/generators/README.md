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

| Generator                            | Purpose                     | Files Created                          | Use Case                         |
| ------------------------------------ | --------------------------- | -------------------------------------- | -------------------------------- |
| **[endpoint](endpoint.md)**          | HTTP request handlers       | Endpoints, contracts, pages, templates | Web controllers, API endpoints   |
| **[model](model.md)**                | Database models             | Model classes with validations         | Data persistence layer           |
| **[service](service.md)**            | Business logic              | Service classes                        | Domain logic, complex operations |
| **[middleware](middleware.md)**      | HTTP middleware             | Middleware classes                     | Cross-cutting concerns           |
| **[contract](contract.md)**          | Request/response validation | Contract structs                       | Input validation, API contracts  |
| **[page](page.md)**                  | HTML page components        | Page classes, templates                | View layer, HTML rendering       |
| **[component](component.md)**        | Live interactive components | Component classes                      | Real-time UI, dynamic interfaces |
| **[validator](custom-validator.md)** | Custom validation logic     | Validator classes                      | Reusable validation rules        |
| **[migration](migration.md)**        | Database migrations         | Migration files                        | Database schema changes          |
| **[scaffold](scaffold.md)**          | Complete CRUD resource      | All of the above                       | Rapid prototyping                |

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
- [Development Workflows](../workflows/README.md) - Use generators in real projects
