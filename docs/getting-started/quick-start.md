# Quick Start

This guide will walk you through creating your first Azu application in just a few minutes. By the end of this tutorial, you'll have a running web application with a database, complete with CRUD operations.

## Prerequisites

- [Azu CLI installed](installation.md)
- Database server running (PostgreSQL, MySQL, or SQLite)
- Basic familiarity with Crystal syntax

## Step 1: Create a New Project

Let's create a blog application:

```bash
azu new my_blog --database postgres
```

This command will:

- Create a new directory called `my_blog`
- Generate the complete project structure
- Configure PostgreSQL as the database
- Set up all necessary dependencies
- Initialize a Git repository

**Output:**

```
🚀 Creating new Azu project: my_blog
📦 Using database: postgres
📁 Generating project structure...
   create  my_blog/
   create  my_blog/src/
   create  my_blog/src/my_blog.cr
   create  my_blog/src/server.cr
   create  my_blog/shard.yml
   create  my_blog/README.md
   ... (more files)
✅ Project created successfully!

📋 Next Steps:
  cd my_blog
  azu db create
  azu serve
```

## Step 2: Navigate to Your Project

```bash
cd my_blog
```

Let's examine the generated project structure:

```
my_blog/
├── src/
│   ├── my_blog.cr              # Main application file
│   ├── server.cr               # HTTP server configuration
│   ├── endpoints/              # API endpoints (controllers)
│   ├── models/                 # Database models
│   ├── contracts/              # Request/response contracts
│   ├── pages/                  # Page components (views)
│   ├── services/               # Business logic services
│   ├── middleware/             # HTTP middleware
│   └── initializers/           # Application initializers
├── spec/                       # Test files
├── public/                     # Static assets
├── db/                         # Database files
│   ├── migrations/             # Database migrations
│   └── seed.cr                 # Database seeds
├── shard.yml                   # Dependencies
└── README.md                   # Project documentation
```

## Step 3: Set Up the Database

Create your database:

```bash
azu db create
```

**Output:**

```
🗄️  Creating database: my_blog_development
✅ Database created successfully!
```

Run initial migrations:

```bash
azu db migrate
```

**Output:**

```
🔄 Running migrations...
✅ All migrations completed successfully!
```

## Step 4: Start the Development Server

Launch the development server with hot reloading:

```bash
azu serve
```

**Output:**

```
🚀 Starting Azu development server...
📦 Compiling application...
✅ Compilation successful!
🌐 Server running at: http://localhost:4000
🔥 Hot reloading enabled
👀 Watching for file changes...

Press Ctrl+C to stop the server
```

Open your browser and navigate to `http://localhost:4000`. You should see the Azu welcome page!

## Step 5: Generate Your First Resource

Let's create a complete blog post resource with CRUD operations:

```bash
azu generate scaffold Post title:string content:text published:boolean
```

**Output:**

```
🛠️  Generating scaffold: Post
   create  src/models/post.cr
   create  src/endpoints/posts/index_endpoint.cr
   create  src/endpoints/posts/show_endpoint.cr
   create  src/endpoints/posts/new_endpoint.cr
   create  src/endpoints/posts/create_endpoint.cr
   create  src/endpoints/posts/edit_endpoint.cr
   create  src/endpoints/posts/update_endpoint.cr
   create  src/endpoints/posts/destroy_endpoint.cr
   create  src/contracts/posts/index_contract.cr
   create  src/contracts/posts/show_contract.cr
   create  src/contracts/posts/create_contract.cr
   create  src/contracts/posts/update_contract.cr
   create  src/pages/posts/index_page.cr
   create  src/pages/posts/show_page.cr
   create  src/pages/posts/new_page.cr
   create  src/pages/posts/edit_page.cr
   create  public/templates/posts/index_page.jinja
   create  public/templates/posts/show_page.jinja
   create  public/templates/posts/new_page.jinja
   create  public/templates/posts/edit_page.jinja
   create  spec/models/post_spec.cr
   create  spec/endpoints/posts_spec.cr
✅ Scaffold Post generated successfully!
```

## Step 6: Create the Database Migration

Generate a migration for the posts table:

```bash
azu generate migration create_posts_table title:string content:text published:boolean
```

**Output:**

```
🛠️  Generating migration: create_posts_table
   create  db/migrations/20231214_120000_create_posts_table.cr
✅ Migration create_posts_table generated successfully!
```

Run the migration:

```bash
azu db migrate
```

**Output:**

```
🔄 Running migrations...
   migrate  20231214_120000_create_posts_table.cr
✅ All migrations completed successfully!
```

## Step 7: Explore Your Application

The development server should automatically reload your application. Visit these URLs:

- **Homepage**: `http://localhost:4000`
- **Posts Index**: `http://localhost:4000/posts`
- **New Post**: `http://localhost:4000/posts/new`

### Generated Files Explained

#### 1. Model (`src/models/post.cr`)

```crystal
require "cql"

class Post < CQL::Model
  db_table "posts"

  field title : String
  field content : String
  field published : Boolean = false

  validate :title, presence: true, length: {min: 1, max: 255}
  validate :content, presence: true
end
```

#### 2. Endpoint (`src/endpoints/posts/index_endpoint.cr`)

```crystal
class Posts::IndexEndpoint
  include Azu::Endpoint

  def call(request)
    posts = Post.all
    index_page = Posts::IndexPage.new(posts: posts)
    index_page.render
  end
end
```

#### 3. Contract (`src/contracts/posts/create_contract.cr`)

```crystal
struct Posts::CreateContract
  include Azu::Request

  validate title, presence: true, length: {min: 1, max: 255}
  validate content, presence: true
  validate published, inclusion: [true, false]
end
```

#### 4. Page (`src/pages/posts/index_page.cr`)

```crystal
class Posts::IndexPage
  include Azu::Page

  def initialize(@posts : Array(Post))
  end

  def render
    template("posts/index_page.jinja", {
      "posts" => @posts.map(&.to_h)
    })
  end
end
```

## Step 8: Test Your Application

Run the test suite:

```bash
crystal spec
```

**Output:**

```
🧪 Running tests...

Post
  ✓ should be valid with valid attributes
  ✓ should validate presence of title
  ✓ should validate presence of content

Posts::IndexEndpoint
  ✓ should return all posts
  ✓ should render index page

Finished in 0.045 seconds
5 examples, 0 failures
```

## Step 9: Add Sample Data

Seed your database with sample data:

```bash
# Edit db/seed.cr
cat > db/seed.cr << 'EOF'
require "../src/models/**"

# Create sample posts
Post.create!(
  title: "Welcome to My Blog",
  content: "This is my first blog post using Azu!",
  published: true
)

Post.create!(
  title: "Getting Started with Crystal",
  content: "Crystal is an amazing language for web development...",
  published: true
)

Post.create!(
  title: "Draft Post",
  content: "This is a draft post that's not published yet.",
  published: false
)

puts "✅ Sample data created successfully!"
EOF

# Run the seed
azu db:seed
```

**Output:**

```
🌱 Seeding database...
✅ Sample data created successfully!
```

## Step 10: Customize Your Application

### Add Custom Styling

Edit `public/assets/css/cover.css` to customize your application's appearance:

```css
/* Add custom styles */
.blog-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 2rem 0;
}

.post-card {
  border: 1px solid #e9ecef;
  border-radius: 0.5rem;
  padding: 1.5rem;
  margin-bottom: 1rem;
  transition: transform 0.2s;
}

.post-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}
```

### Add a Custom Endpoint

Generate a custom endpoint for published posts only:

```bash
azu generate endpoint published_posts
```

Edit the generated endpoint:

```crystal
# src/endpoints/published_posts/index_endpoint.cr
class PublishedPosts::IndexEndpoint
  include Azu::Endpoint

  def call(request)
    published_posts = Post.where(published: true)
    index_page = PublishedPosts::IndexPage.new(posts: published_posts)
    index_page.render
  end
end
```

## Next Steps

Congratulations! You've successfully created your first Azu application. Here's what you can explore next:

### 🎯 **Immediate Next Steps**

1. **[Add Authentication](../workflows/building-web-apps.md#authentication)** - Secure your blog
2. **[Add Real-time Features](../workflows/real-time-components.md)** - Live comments or reactions
3. **[Create an API](../workflows/building-apis.md)** - Build a REST API for your blog
4. **[Add Testing](../workflows/testing.md)** - Write comprehensive tests

### 📚 **Learn More**

- **[Command Reference](../commands/README.md)** - All available CLI commands
- **[Generators Guide](../generators/README.md)** - Detailed generator documentation
- **[Development Workflows](../workflows/README.md)** - Common development patterns
- **[Configuration](../configuration/README.md)** - Advanced configuration options

### 🛠️ **Advanced Features**

- **[Database Relationships](../workflows/database-workflow.md#relationships)** - Model associations
- **[Background Jobs](../workflows/building-apis.md#background-jobs)** - Async processing
- **[Deployment](../workflows/deployment.md)** - Deploy to production
- **[Performance Optimization](../architecture/README.md#performance)** - Scale your application

### 🌟 **Community Examples**

- **[Blog Tutorial](../examples/blog-tutorial.md)** - Extended blog with user authentication
- **[API Tutorial](../examples/api-tutorial.md)** - Build a complete REST API
- **[Chat Tutorial](../examples/chat-tutorial.md)** - Real-time chat application

## Troubleshooting

### Server Won't Start

```bash
# Check for compilation errors
crystal build src/main.cr

# Check database connection
azu db:create
```

### Port Already in Use

```bash
# Use a different port
azu serve --port 4000
```

### Database Connection Error

```bash
# Verify database is running
sudo systemctl status postgresql  # Linux
brew services list | grep postgres  # macOS

# Check database configuration
cat src/initializers/database.cr
```

### Hot Reloading Not Working

```bash
# Restart the server
# Make sure you're editing files in the src/ directory
```

---

**Congratulations!** 🎉 You've built your first Azu application. The development server will automatically reload when you make changes, so start experimenting and building something amazing!

**Need Help?** Check out the [troubleshooting guide](../troubleshooting/README.md) or [create an issue](https://github.com/azutoolkit/azu_cli/issues) on GitHub.
