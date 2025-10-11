# REST API Example

A complete example of building a REST API with Azu CLI using OpenAPI integration.

## Overview

This example demonstrates building a blog API with posts, comments, and users using the Azu CLI API features.

## Project Setup

### Create API Project

```bash
# Create new API project
azu new blog_api --api --db postgresql

# Navigate to project
cd blog_api
```

This creates an API-only project with:
- OpenAPI configuration
- Health check endpoint
- CORS middleware
- JSON error handling
- Swagger UI

### Configure Database

Edit `config/azu.yml`:

```yaml
database:
  adapter: postgresql
  host: localhost
  port: 5432
  database: blog_api_development
  username: postgres
  password: ""
```

Create database:

```bash
azu db:create
```

## Generate Resources

### User Resource

```bash
azu generate api_resource User \
  name:string \
  email:string \
  password_hash:string \
  bio:text \
  avatar_url:string
```

### Post Resource

```bash
azu generate api_resource Post \
  title:string \
  slug:string \
  content:text \
  excerpt:string \
  published:bool \
  published_at:time \
  author_id:int64 \
  view_count:int32
```

### Comment Resource

```bash
azu generate api_resource Comment \
  body:text \
  author_id:int64 \
  post_id:int64 \
  approved:bool
```

## Run Migrations

```bash
azu db:migrate
```

## Project Structure

```
blog_api/
├── config/
│   ├── azu.yml
│   ├── api.yml
│   ├── openapi.yml
│   └── database.yml
├── src/
│   ├── api.cr
│   ├── blog_api.cr
│   ├── endpoints/
│   │   ├── health/
│   │   │   └── health_endpoint.cr
│   │   ├── users/
│   │   │   ├── users_index_endpoint.cr
│   │   │   ├── users_show_endpoint.cr
│   │   │   ├── users_create_endpoint.cr
│   │   │   ├── users_update_endpoint.cr
│   │   │   └── users_destroy_endpoint.cr
│   │   ├── posts/
│   │   │   └── [same structure]
│   │   └── comments/
│   │       └── [same structure]
│   ├── models/
│   │   ├── user.cr
│   │   ├── post.cr
│   │   └── comment.cr
│   ├── requests/
│   │   ├── users/
│   │   ├── posts/
│   │   └── comments/
│   ├── pages/
│   │   ├── users/
│   │   ├── posts/
│   │   └── comments/
│   └── schemas/
│       └── app_schema.cr
├── public/
│   └── api/
│       └── swagger-ui.html
└── shard.yml
```

## Implement Business Logic

### User Model with Relations

Edit `src/models/user.cr`:

```crystal
require "cql"

struct User < CQL::Record(Int64)
  include CQL::Timestamps
  
  property name : String
  property email : String
  property password_hash : String
  property bio : String?
  property avatar_url : String?
  
  timestamps
  
  # Relations
  has_many :posts, Post, foreign_key: :author_id
  has_many :comments, Comment, foreign_key: :author_id
  
  # Validations
  validates :email, presence: true, format: /\A[^@\s]+@[^@\s]+\z/
  validates :name, presence: true, length: {minimum: 2, maximum: 100}
  
  # Methods
  def posts_count : Int64
    Post.where(author_id: id).count
  end
end
```

### Post Model with Relations

Edit `src/models/post.cr`:

```crystal
require "cql"

struct Post < CQL::Record(Int64)
  include CQL::Timestamps
  
  property title : String
  property slug : String
  property content : String
  property excerpt : String?
  property published : Bool
  property published_at : Time?
  property author_id : Int64
  property view_count : Int32
  
  timestamps
  
  # Relations
  belongs_to :author, User, foreign_key: :author_id
  has_many :comments, Comment, foreign_key: :post_id
  
  # Scopes
  scope :published, -> { where(published: true) }
  scope :recent, -> { order_by(published_at: :desc) }
  
  # Before callbacks
  before_save :generate_slug
  before_save :set_published_at
  
  private def generate_slug
    self.slug = title.downcase.gsub(/[^a-z0-9]+/, "-") if slug.empty?
  end
  
  private def set_published_at
    self.published_at = Time.utc if published && published_at.nil?
  end
end
```

### Comment Model

Edit `src/models/comment.cr`:

```crystal
require "cql"

struct Comment < CQL::Record(Int64)
  include CQL::Timestamps
  
  property body : String
  property author_id : Int64
  property post_id : Int64
  property approved : Bool
  
  timestamps
  
  # Relations
  belongs_to :author, User, foreign_key: :author_id
  belongs_to :post, Post, foreign_key: :post_id
  
  # Scopes
  scope :approved, -> { where(approved: true) }
end
```

### Enhanced Posts Index Endpoint

Edit `src/endpoints/posts/posts_index_endpoint.cr`:

```crystal
struct Posts::PostsIndexEndpoint
  include Azu::Endpoint(Posts::PostsIndexRequest, Posts::PostsIndexPage)
  
  get "/posts"
  
  def call : Posts::PostsIndexPage
    # Pagination
    page = request.page || 1
    per_page = [request.per_page || 25, 100].min
    
    # Build query
    query = Post.query
    
    # Filter by published status
    query = query.where(published: true) if request.published_only
    
    # Filter by author
    query = query.where(author_id: request.author_id) if request.author_id
    
    # Search
    if search = request.search
      query = query.where("title LIKE ? OR content LIKE ?", "%#{search}%", "%#{search}%")
    end
    
    # Order
    query = query.order_by(created_at: :desc)
    
    # Execute with pagination
    posts = query.limit(per_page).offset((page - 1) * per_page).to_a
    total = query.count
    
    Posts::PostsIndexPage.new(
      posts: posts,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: (total / per_page).ceil.to_i
    )
  end
end
```

### Enhanced Request with Validation

Edit `src/requests/posts/posts_index_request.cr`:

```crystal
struct Posts::PostsIndexRequest < Azu::Request
  property page : Int32?
  property per_page : Int32?
  property published_only : Bool?
  property author_id : Int64?
  property search : String?
  
  # Validation
  validates :page, numericality: {greater_than: 0}, allow_nil: true
  validates :per_page, numericality: {greater_than: 0, less_than_or_equal_to: 100}, allow_nil: true
end
```

### Enhanced Response with Metadata

Edit `src/pages/posts/posts_index_page.cr`:

```crystal
require "json"

struct Posts::PostsIndexPage < Azu::Page
  include JSON::Serializable
  
  property data : Array(PostSummary)
  property meta : Metadata
  
  def initialize(posts : Array(Post), page : Int32, per_page : Int32, total : Int64, total_pages : Int32)
    @data = posts.map { |p| PostSummary.from_post(p) }
    @meta = Metadata.new(page, per_page, total, total_pages)
  end
  
  def render : String
    to_json
  end
  
  struct PostSummary
    include JSON::Serializable
    
    property id : Int64
    property title : String
    property slug : String
    property excerpt : String?
    property published : Bool
    property published_at : Time?
    property author : AuthorInfo
    property view_count : Int32
    property created_at : Time
    
    def self.from_post(post : Post) : PostSummary
      author = User.find(post.author_id)
      new(
        id: post.id,
        title: post.title,
        slug: post.slug,
        excerpt: post.excerpt,
        published: post.published,
        published_at: post.published_at,
        author: AuthorInfo.new(author.id, author.name, author.avatar_url),
        view_count: post.view_count,
        created_at: post.created_at
      )
    end
  end
  
  struct AuthorInfo
    include JSON::Serializable
    
    property id : Int64
    property name : String
    property avatar_url : String?
    
    def initialize(@id, @name, @avatar_url)
    end
  end
  
  struct Metadata
    include JSON::Serializable
    
    property page : Int32
    property per_page : Int32
    property total : Int64
    property total_pages : Int32
    
    def initialize(@page, @per_page, @total, @total_pages)
    end
  end
end
```

## Add Authentication

```bash
azu generate auth --strategy jwt
```

Add authentication to endpoints:

```crystal
struct Posts::PostsCreateEndpoint
  include Azu::Endpoint(Posts::PostsCreateRequest, Posts::PostsCreatePage)
  
  post "/posts"
  authenticate! # Requires authentication
  
  def call : Posts::PostsCreatePage
    # Get current user from JWT token
    author_id = current_user.id
    
    post = Post.create(
      title: request.title,
      content: request.content,
      slug: request.slug || "",
      excerpt: request.excerpt,
      published: request.published || false,
      author_id: author_id,
      view_count: 0
    )
    
    Posts::PostsCreatePage.new(post: post)
  end
end
```

## Export OpenAPI Specification

```bash
azu openapi:export --output docs/api.yaml
```

Generated `docs/api.yaml`:

```yaml
openapi: 3.1.0
info:
  title: BlogApi API
  description: API documentation for blog_api
  version: 1.0.0
servers:
  - url: http://localhost:3000
    description: Development server
paths:
  /health:
    get:
      summary: GET Health
      operationId: getHealth
      tags:
        - Health
      responses:
        '200':
          description: Successful response
  /posts:
    get:
      summary: GET Posts
      operationId: getPosts
      tags:
        - Posts
      parameters:
        - name: page
          in: query
          schema:
            type: integer
        - name: per_page
          in: query
          schema:
            type: integer
      responses:
        '200':
          description: Successful response
components:
  schemas:
    Post:
      type: object
      properties:
        id:
          type: integer
          format: int64
        title:
          type: string
        # ... other properties
```

## Run the API

```bash
# Start the API server
azu serve

# Or run directly
crystal run src/api.cr
```

Visit http://localhost:3000/api/docs/ui for Swagger UI.

## Testing the API

### Health Check

```bash
curl http://localhost:3000/health
```

Response:
```json
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2025-01-10T12:00:00Z"
}
```

### List Posts

```bash
curl http://localhost:3000/posts?page=1&per_page=10
```

### Create Post (with auth)

```bash
curl -X POST http://localhost:3000/posts \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My First Post",
    "content": "This is the content...",
    "published": true
  }'
```

### Get Single Post

```bash
curl http://localhost:3000/posts/1
```

## See Also

- [OpenAPI Commands](../commands/openapi.md)
- [API Resource Generator](../generators/api-resource.md)
- [New Command](../commands/new.md)
- [Authentication Guide](../integration/authentication.md)

