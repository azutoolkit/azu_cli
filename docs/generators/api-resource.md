# API Resource Generator

Generate complete REST API resources with a single command.

## Overview

The `api_resource` generator creates a complete REST API resource including models, endpoints, request validators, and JSON responses. It's designed specifically for API-only projects.

## Usage

```bash
azu generate api_resource <name> [attributes] [options]
```

### Arguments

- `<name>` - Resource name (singular, e.g., `Post`, `User`, `Article`)
- `[attributes]` - Space-separated list of `field:type` pairs

### Options

- `--force` - Overwrite existing files
- `--skip COMPONENTS` - Skip specific components (comma-separated)
- `--help` - Show help message

## Examples

### Basic Resource

```bash
azu generate api_resource Post title:string content:text published:bool
```

Generates:
- `src/models/post.cr` - CQL model with attributes
- `src/migrations/TIMESTAMP_create_posts.cr` - Database migration
- `src/endpoints/posts/*_endpoint.cr` - REST endpoints (index, show, create, update, destroy)
- `src/requests/posts/*_request.cr` - Request validation classes
- `src/pages/posts/*_page.cr` - JSON response classes

### Complex Resource

```bash
azu generate api_resource Article \
  title:string \
  slug:string \
  content:text \
  excerpt:string \
  published_at:time \
  author_id:int64 \
  view_count:int32 \
  featured:bool
```

### Skip Specific Components

```bash
# Skip migration (if table already exists)
azu generate api_resource Comment body:text user_id:int64 post_id:int64 --skip migration

# Skip model (if using existing model)
azu generate api_resource User name:string email:string --skip model,migration
```

## Generated Structure

### Models

Generated in `src/models/<name>.cr`:

```crystal
require "cql"

struct Post < CQL::Record(Int64)
  include CQL::Timestamps
  
  property title : String
  property content : String
  property published : Bool
  
  timestamps
end
```

### Migrations

Generated in `src/migrations/TIMESTAMP_create_<plural>.cr`:

```crystal
class CreatePosts < CQL::Migration
  def up
    schema.create :posts do
      primary :id, Int64
      text :title
      text :content
      boolean :published, default: false
      timestamps
    end
  end
  
  def down
    schema.drop :posts
  end
end
```

### Endpoints

Generated in `src/endpoints/<plural>/<name>_<action>_endpoint.cr`:

**Index** (GET /posts):
```crystal
struct Posts::PostsIndexEndpoint
  include Azu::Endpoint(Posts::PostsIndexRequest, Posts::PostsIndexPage)
  
  get "/posts"
  
  def call : Posts::PostsIndexPage
    posts = Post.all
    Posts::PostsIndexPage.new(posts: posts)
  end
end
```

**Show** (GET /posts/:id):
```crystal
struct Posts::PostsShowEndpoint
  include Azu::Endpoint(Posts::PostsShowRequest, Posts::PostsShowPage)
  
  get "/posts/:id"
  
  def call : Posts::PostsShowPage
    post = Post.find(request.id)
    Posts::PostsShowPage.new(post: post)
  end
end
```

**Create** (POST /posts):
```crystal
struct Posts::PostsCreateEndpoint
  include Azu::Endpoint(Posts::PostsCreateRequest, Posts::PostsCreatePage)
  
  post "/posts"
  
  def call : Posts::PostsCreatePage
    post = Post.create(
      title: request.title,
      content: request.content,
      published: request.published || false
    )
    Posts::PostsCreatePage.new(post: post)
  end
end
```

**Update** (PATCH /posts/:id):
```crystal
struct Posts::PostsUpdateEndpoint
  include Azu::Endpoint(Posts::PostsUpdateRequest, Posts::PostsUpdatePage)
  
  patch "/posts/:id"
  
  def call : Posts::PostsUpdatePage
    post = Post.find(request.id)
    post.update(
      title: request.title,
      content: request.content,
      published: request.published
    )
    Posts::PostsUpdatePage.new(post: post)
  end
end
```

**Destroy** (DELETE /posts/:id):
```crystal
struct Posts::PostsDestroyEndpoint
  include Azu::Endpoint(Posts::PostsDestroyRequest, Posts::PostsDestroyPage)
  
  delete "/posts/:id"
  
  def call : Posts::PostsDestroyPage
    post = Post.find(request.id)
    post.destroy
    Posts::PostsDestroyPage.new(success: true)
  end
end
```

### Request Classes

Generated in `src/requests/<plural>/<name>_<action>_request.cr`:

```crystal
struct Posts::PostsCreateRequest < Azu::Request
  property title : String
  property content : String
  property published : Bool?
end
```

### Response Classes

Generated in `src/pages/<plural>/<name>_<action>_page.cr`:

```crystal
require "json"

struct Posts::PostsIndexPage < Azu::Page
  include JSON::Serializable
  
  property posts : Array(Post)
  
  def render : String
    to_json
  end
end
```

## Supported Attribute Types

| Type | Description | Database Type |
|------|-------------|---------------|
| `string` | String values | VARCHAR/TEXT |
| `text` | Long text | TEXT |
| `int32` | 32-bit integer | INTEGER |
| `int64` | 64-bit integer | BIGINT |
| `float32` | 32-bit float | REAL |
| `float64` | 64-bit float | DOUBLE PRECISION |
| `bool` | Boolean | BOOLEAN |
| `time` | Timestamp | TIMESTAMP |

## Best Practices

### Naming Conventions

- Use singular names: `Post`, `User`, `Article`
- Names should be PascalCase
- Database tables will be pluralized automatically

### Attribute Design

- Keep attributes simple and focused
- Use foreign keys for relationships (`author_id:int64`)
- Add timestamps automatically (built-in)
- Use appropriate types for data

### API Structure

- Follow REST conventions
- Use plural resource names in URLs (`/posts`)
- Implement proper HTTP status codes
- Version your API (`/api/v1/posts`)

### Security

- Always validate input in request classes
- Implement authentication in endpoints
- Use authorization for sensitive operations
- Sanitize user input

## API-Only vs Web Projects

The `api_resource` generator is optimized for API-only projects:

**API Resource:**
- Generates JSON responses
- Skips Jinja templates
- Skips page views
- Focuses on REST endpoints

**Scaffold (Web):**
- Generates HTML pages
- Includes Jinja templates
- Includes forms
- Web and API endpoints

## Integration

### With OpenAPI

Generate OpenAPI spec from API resources:

```bash
# Generate API resource
azu generate api_resource Post title:string content:text

# Export to OpenAPI spec
azu openapi:export --output docs/api.yaml
```

### With Authentication

Add authentication to API resources:

```bash
# Generate auth system
azu generate auth --strategy jwt

# Generate API resource with auth
azu generate api_resource Post title:string content:text

# Add authentication middleware to endpoints manually
```

### With Pagination

Implement pagination in index endpoints:

```crystal
struct Posts::PostsIndexEndpoint
  include Azu::Endpoint(Posts::PostsIndexRequest, Posts::PostsIndexPage)
  
  get "/posts"
  
  def call : Posts::PostsIndexPage
    page = request.page || 1
    per_page = request.per_page || 25
    
    posts = Post.all.limit(per_page).offset((page - 1) * per_page)
    total = Post.count
    
    Posts::PostsIndexPage.new(
      posts: posts,
      page: page,
      per_page: per_page,
      total: total
    )
  end
end
```

## Comparison with Scaffold

| Feature | api_resource | scaffold |
|---------|--------------|----------|
| Models | ✓ | ✓ |
| Migrations | ✓ | ✓ |
| REST Endpoints | ✓ | ✓ |
| Request Classes | ✓ | ✓ |
| JSON Responses | ✓ | ✓ |
| HTML Pages | ✗ | ✓ |
| Jinja Templates | ✗ | ✓ |
| Forms | ✗ | ✓ |
| Use Case | APIs | Web Apps |

## See Also

- [Scaffold Generator](./scaffold.md) - Full-stack CRUD generation
- [Model Generator](./model.md) - Generate models only
- [Endpoint Generator](./endpoint.md) - Generate endpoints only
- [OpenAPI Commands](../commands/openapi.md) - OpenAPI integration
- [REST API Example](../examples/rest-api.md) - Complete example

