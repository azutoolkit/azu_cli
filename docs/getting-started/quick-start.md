# Quick Start

Create your first Azu application in minutes.

## Prerequisites

- [Azu CLI installed](installation.md)
- Database server running (PostgreSQL, MySQL, or SQLite)

## Step 1: Create a New Project

```bash
azu new my_blog --database postgres
```

This creates a new project with:

- Complete project structure
- PostgreSQL configuration
- Git repository initialized

## Step 2: Navigate and Explore

```bash
cd my_blog
```

Project structure:

```text
my_blog/
├── src/
│   ├── my_blog.cr           # Main application
│   ├── server.cr            # Server configuration
│   ├── endpoints/           # HTTP handlers
│   ├── models/              # Database models
│   ├── requests/            # Request validation
│   ├── pages/               # Response pages
│   ├── services/            # Business logic
│   └── db/
│       ├── migrations/      # Database migrations
│       └── schema.cr        # Auto-generated schema
├── spec/                    # Tests
├── public/                  # Static assets
└── shard.yml               # Dependencies
```

## Step 3: Set Up the Database

```bash
azu db:create
azu db:migrate
```

## Step 4: Start the Server

```bash
azu serve
```

Open `http://localhost:4000` in your browser.

## Step 5: Generate a Resource

Create a complete blog post resource:

```bash
azu generate scaffold Post title:string content:text published:bool
```

This generates:

- Model (`src/models/post.cr`)
- Endpoints (`src/endpoints/posts/`)
- Requests (`src/requests/posts/`)
- Pages (`src/pages/posts/`)
- Services (`src/services/posts/`)
- Migration (`src/db/migrations/`)

## Step 6: Run the Migration

```bash
azu db:migrate
```

## Step 7: View Your Application

Visit `http://localhost:4000/posts` to see your CRUD interface.

## Generated Code Examples

### Model

```crystal
# src/models/post.cr
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :posts

  getter id : Int64?
  getter title : String
  getter content : String
  getter published : Bool
  getter created_at : Time?
  getter updated_at : Time?

  validate :title, presence: true, size: 2..100
  validate :content, presence: true

  def initialize(@title : String, @content : String, @published : Bool = false)
  end
end
```

### Endpoint

```crystal
# src/endpoints/posts/post_index_endpoint.cr
module App::Posts
  struct IndexEndpoint
    include Azu::Endpoint(Posts::IndexRequest, Posts::IndexPage)

    get "/posts"

    def call : Posts::IndexPage
      result = IndexService.new.call

      if result.success?
        posts = result.data.not_nil!
        Posts::IndexPage.new(posts: posts)
      else
        Posts::IndexPage.new(posts: [] of Post)
      end
    end
  end
end
```

### Request

```crystal
# src/requests/posts/create_request.cr
struct Posts::CreateRequest
  include Azu::Request
  include JSON::Serializable

  getter title : String
  getter content : String
  getter published : Bool

  def initialize(@title = "", @content = "", @published = false)
  end

  validate :title, presence: true, size: 2..100
  validate :content, presence: true
end
```

## Run Tests

```bash
azu test
# Or with watch mode
azu test --watch
```

## Next Steps

- [Command Reference](../commands/README.md) - All CLI commands
- [Generators Guide](../generators/README.md) - Code generation
- [Configuration](../configuration/README.md) - Project settings

## Troubleshooting

### Server Won't Start

```bash
# Check for compilation errors
crystal build src/server.cr

# Check database connection
azu db:status
```

### Port Already in Use

```bash
azu serve --port 4001
```

### Database Connection Error

```bash
# Verify database is running
sudo systemctl status postgresql

# Check DATABASE_URL
echo $DATABASE_URL
```
