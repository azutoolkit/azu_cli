# OpenAPI Commands

Azu CLI provides comprehensive OpenAPI 3.1 support for both generating code from OpenAPI specifications and exporting OpenAPI specifications from your Crystal code.

## Overview

The OpenAPI commands enable bidirectional integration between OpenAPI specifications and Azu applications:

- **Generate code** from OpenAPI specifications
- **Export specifications** from existing Azu code
- **Support OpenAPI 3.1** standard
- **Type-safe integration** with Crystal

## Available Commands

| Command | Description |
|---------|-------------|
| `azu openapi:generate` | Generate Crystal code from OpenAPI specification |
| `azu openapi:export` | Export OpenAPI specification from Crystal code |

## azu openapi:generate

Generates Crystal code from an OpenAPI 3.1 specification file, creating models, endpoints, requests, and responses.

### Basic Usage

```bash
# Generate all code from OpenAPI spec
azu openapi:generate openapi.yaml

# Generate only models
azu openapi:generate openapi.yaml --models-only

# Generate only endpoints
azu openapi:generate openapi.yaml --endpoints-only

# Force overwrite existing files
azu openapi:generate openapi.yaml --force
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--spec PATH` | Path to OpenAPI specification file | Required |
| `--force` | Overwrite existing files without prompting | false |
| `--models-only` | Generate only models from schemas | false |
| `--endpoints-only` | Generate only endpoints from paths | false |

### Examples

#### Generate Complete API

```bash
# Generate all components from OpenAPI spec
azu openapi:generate api-spec.yaml

# Output:
# Parsing OpenAPI specification: api-spec.yaml
# Generated models: 5
# Generated endpoints: 12
# Generated requests: 8
# Generated responses: 12
# ✓ Code generation completed successfully
```

#### Generate Specific Components

```bash
# Generate only models
azu openapi:generate api-spec.yaml --models-only
# Generated models: 5
# ✓ Code generation completed successfully

# Generate only endpoints
azu openapi:generate api-spec.yaml --endpoints-only
# Generated endpoints: 12
# ✓ Code generation completed successfully
```

#### Force Overwrite

```bash
# Overwrite existing files
azu openapi:generate api-spec.yaml --force
# Overwriting existing files...
# ✓ Code generation completed successfully
```

### Generated Code Structure

The generator creates the following files based on your OpenAPI specification:

```
src/
├── models/                    # Generated from schemas
│   ├── user.cr
│   ├── post.cr
│   └── comment.cr
├── endpoints/                 # Generated from paths
│   ├── users/
│   │   ├── index_endpoint.cr
│   │   ├── show_endpoint.cr
│   │   ├── create_endpoint.cr
│   │   ├── update_endpoint.cr
│   │   └── destroy_endpoint.cr
│   └── posts/
│       ├── index_endpoint.cr
│       └── show_endpoint.cr
├── requests/                  # Generated from request bodies
│   ├── users/
│   │   ├── create_request.cr
│   │   └── update_request.cr
│   └── posts/
│       ├── create_request.cr
│       └── update_request.cr
└── pages/                     # Generated from responses
    ├── users/
    │   ├── index_page.cr
    │   ├── show_page.cr
    │   └── create_page.cr
    └── posts/
        ├── index_page.cr
        └── show_page.cr
```

### Generated Model Example

```crystal
# src/models/user.cr
require "cql"

class User < CQL::Model
  table :users

  column :id, Int64
  column :name, String
  column :email, String
  column :created_at, Time
  column :updated_at, Time

  validates :name, presence: true
  validates :email, presence: true, format: /^[^@]+@[^@]+\.[^@]+$/
end
```

### Generated Endpoint Example

```crystal
# src/endpoints/users/index_endpoint.cr
class Users::IndexEndpoint < Azu::Endpoint
  def call
    users = User.all
    render_page(Users::IndexPage, users: users)
  end
end
```

### Generated Request Example

```crystal
# src/requests/users/create_request.cr
class Users::CreateRequest < Azu::Request
  field :name, String, required: true
  field :email, String, required: true, format: /^[^@]+@[^@]+\.[^@]+$/
end
```

### Generated Response Example

```crystal
# src/pages/users/show_page.cr
class Users::ShowPage < Azu::Page
  def initialize(@user : User)
  end

  def render
    template("users/show_page.jinja", {
      "user" => @user.to_h
    })
  end
end
```

### Supported OpenAPI Features

#### Schemas (Component Models)

- **Basic types**: string, integer, number, boolean
- **Complex types**: object, array
- **Validation**: required fields, format patterns, length constraints
- **Nested objects**: automatically handled
- **Enums**: converted to Crystal enums

#### Paths (Endpoints)

- **HTTP methods**: GET, POST, PUT, PATCH, DELETE
- **Path parameters**: automatically extracted
- **Query parameters**: converted to request validation
- **Request bodies**: generated as request classes
- **Responses**: generated as page classes

#### Request/Response Bodies

- **JSON schemas**: converted to Crystal structs
- **Validation rules**: mapped to Azu validation
- **Nested objects**: properly handled
- **Arrays**: converted to Crystal arrays

### OpenAPI Specification Example

```yaml
# openapi.yaml
openapi: 3.1.0
info:
  title: Blog API
  version: 1.0.0
  description: A simple blog API

paths:
  /users:
    get:
      summary: List users
      responses:
        '200':
          description: List of users
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/User'
    post:
      summary: Create user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUserRequest'
      responses:
        '201':
          description: User created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'

components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
        email:
          type: string
          format: email
        created_at:
          type: string
          format: date-time
      required:
        - id
        - name
        - email
        - created_at

    CreateUserRequest:
      type: object
      properties:
        name:
          type: string
        email:
          type: string
          format: email
      required:
        - name
        - email
```

## azu openapi:export

Exports an OpenAPI 3.1 specification from your existing Azu application code.

### Basic Usage

```bash
# Export to default file (openapi.yaml)
azu openapi:export

# Export to specific file
azu openapi:export --output api-spec.yaml

# Export as JSON
azu openapi:export --output api-spec.json --format json

# Export with custom project name and version
azu openapi:export --project "My API" --version "2.0.0"
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--output PATH` | Output file path | openapi.yaml |
| `--format FORMAT` | Output format (yaml, json) | yaml |
| `--project NAME` | Project name | Auto-detected from shard.yml |
| `--version VERSION` | API version | 1.0.0 |

### Examples

#### Export to YAML

```bash
# Export to default YAML file
azu openapi:export
# Building OpenAPI specification from code...
# ✓ OpenAPI specification exported to: openapi.yaml
```

#### Export to JSON

```bash
# Export to JSON file
azu openapi:export --output api-spec.json --format json
# Building OpenAPI specification from code...
# ✓ OpenAPI specification exported to: api-spec.json
```

#### Custom Project Information

```bash
# Export with custom project details
azu openapi:export --project "Blog API" --version "2.0.0" --output docs/api.yaml
# Building OpenAPI specification from code...
# ✓ OpenAPI specification exported to: docs/api.yaml
```

### Code Analysis

The export command analyzes your Azu application and extracts:

#### Endpoints Analysis

- **HTTP methods** from endpoint classes
- **Path patterns** from route definitions
- **Request parameters** from method signatures
- **Response types** from return values

#### Models Analysis

- **Schema definitions** from CQL models
- **Field types** and constraints
- **Validation rules** and formats
- **Relationships** between models

#### Request/Response Analysis

- **Request classes** and their fields
- **Response classes** and their structure
- **Validation rules** and constraints
- **Content types** and formats

### Generated OpenAPI Specification

The exported specification includes:

```yaml
# Generated openapi.yaml
openapi: 3.1.0
info:
  title: My Application
  version: 1.0.0
  description: Generated from Azu application

servers:
  - url: http://localhost:4000
    description: Development server

paths:
  /users:
    get:
      summary: List users
      operationId: listUsers
      responses:
        '200':
          description: List of users
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/User'
    post:
      summary: Create user
      operationId: createUser
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUserRequest'
      responses:
        '201':
          description: User created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'

components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
        email:
          type: string
          format: email
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time
      required:
        - id
        - name
        - email
        - created_at
        - updated_at

    CreateUserRequest:
      type: object
      properties:
        name:
          type: string
        email:
          type: string
          format: email
      required:
        - name
        - email
```

## Workflow Integration

### API-First Development

1. **Design API** using OpenAPI specification
2. **Generate code** from specification
3. **Implement business logic** in generated files
4. **Export updated spec** as you develop

```bash
# Start with OpenAPI spec
azu openapi:generate api-design.yaml

# Develop your application
# ... implement business logic ...

# Export updated specification
azu openapi:export --output updated-api.yaml
```

### Code-First Development

1. **Develop application** with Azu endpoints and models
2. **Export specification** from existing code
3. **Share specification** with frontend/API consumers
4. **Generate client code** from specification

```bash
# Develop your application
# ... create endpoints and models ...

# Export OpenAPI specification
azu openapi:export

# Share with frontend team
# They can generate client code from openapi.yaml
```

### Continuous Integration

```bash
# In CI pipeline
# Generate code from spec
azu openapi:generate api-spec.yaml

# Run tests
crystal spec

# Export updated spec
azu openapi:export --output generated-api.yaml

# Compare with original spec
diff api-spec.yaml generated-api.yaml
```

## Best Practices

### 1. Specification Management

```bash
# Keep specifications in version control
git add openapi.yaml
git commit -m "Update API specification"

# Use meaningful file names
azu openapi:export --output "api-v1.2.0.yaml"
```

### 2. Code Generation

```bash
# Always review generated code
azu openapi:generate api-spec.yaml

# Customize generated files as needed
# ... edit generated files ...

# Regenerate when spec changes
azu openapi:generate api-spec.yaml --force
```

### 3. Validation

```bash
# Validate OpenAPI specification
# Use online validators or tools like swagger-codegen

# Test generated code
crystal spec
```

### 4. Documentation

```bash
# Export specification for documentation
azu openapi:export --output docs/api.yaml

# Generate API documentation
# Use tools like Swagger UI or Redoc
```

## Troubleshooting

### Common Issues

#### Invalid OpenAPI Specification

```bash
# Check specification syntax
cat openapi.yaml | head -20

# Validate with online tools
# https://editor.swagger.io/
```

#### Generation Failures

```bash
# Check for missing dependencies
crystal deps

# Verify file permissions
ls -la openapi.yaml

# Use verbose output for debugging
azu openapi:generate openapi.yaml --verbose
```

#### Export Issues

```bash
# Check if endpoints exist
ls -la src/endpoints/

# Verify model definitions
ls -la src/models/

# Check for compilation errors
crystal build src/main.cr
```

### File Permission Issues

```bash
# Fix file permissions
chmod 644 openapi.yaml
chmod 755 src/

# Check directory permissions
ls -la
```

### Memory Issues

```bash
# For large specifications
# Process in smaller chunks
azu openapi:generate openapi.yaml --models-only
azu openapi:generate openapi.yaml --endpoints-only
```

## Integration Examples

### Frontend Integration

```bash
# Export API specification
azu openapi:export --output frontend/api-spec.json --format json

# Frontend team can generate TypeScript client
# npx @openapitools/openapi-generator-cli generate -i api-spec.json -g typescript-axios -o src/api
```

### API Documentation

```bash
# Export for documentation
azu openapi:export --output docs/api.yaml

# Generate Swagger UI
# Use tools like swagger-ui-dist or redoc-cli
```

### Testing Integration

```bash
# Generate test data from spec
azu openapi:generate test-spec.yaml --models-only

# Use in test files
# require "./models/**"
# user = User.new(name: "Test", email: "test@example.com")
```

---

The OpenAPI commands provide powerful integration between OpenAPI specifications and Azu applications, enabling both API-first and code-first development workflows.

**Next Steps:**

- [Generate Command](generate.md) - Learn about code generation
- [Model Generator](../generators/model.md) - Create database models
- [Endpoint Generator](../generators/endpoint.md) - Create HTTP endpoints
- [API Development Workflows](../examples/README.md) - Learn API development patterns