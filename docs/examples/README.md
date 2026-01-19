# Examples

Practical examples demonstrating Azu CLI patterns.

## Quick Examples

### Create a Blog

```bash
azu new blog --database postgres
cd blog

# Generate resources
azu generate scaffold Post title:string content:text published:bool
azu generate scaffold Comment content:text post_id:references user_id:references
azu generate auth --strategy session

# Setup and run
azu db:create && azu db:migrate
azu serve
```

### Create an API

```bash
azu new api_service --api --database postgres
cd api_service

# Generate API resources
azu generate scaffold Product name:string price:float64 --api-only
azu generate scaffold Order product_id:references quantity:int32 --api-only
azu generate auth --strategy jwt

# Setup and run
azu db:create && azu db:migrate
azu serve
```

### Background Jobs

```bash
azu new worker_app --joobq
cd worker_app

# Generate job
azu generate job SendEmail user_id:int64 template:string

# Start workers
azu jobs:worker --workers 4
```

## Code Patterns

### Model

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :posts

  getter id : Int64?
  getter title : String
  getter content : String
  getter published : Bool
  getter user_id : Int64
  getter created_at : Time?
  getter updated_at : Time?

  belongs_to :user, User, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :post_id

  validate :title, presence: true, size: 1..100
  validate :content, presence: true

  scope :published, -> { where(published: true) }

  def initialize(@title : String, @content : String, @user_id : Int64, @published : Bool = false)
  end
end
```

### Endpoint

```crystal
module App::Posts
  struct IndexEndpoint
    include Azu::Endpoint(Posts::IndexRequest, Posts::IndexPage)

    get "/posts"

    def call : Posts::IndexPage
      posts = Post.published.order(created_at: :desc).all
      Posts::IndexPage.new(posts: posts)
    end
  end
end
```

### Request

```crystal
struct Posts::CreateRequest
  include Azu::Request
  include JSON::Serializable

  getter title : String
  getter content : String
  getter published : Bool

  def initialize(@title = "", @content = "", @published = false)
  end

  validate :title, presence: true, size: 1..100
  validate :content, presence: true
end
```

### Service

```crystal
module App::Posts
  class CreateService
    def call(request : CreateRequest, user_id : Int64) : Result(Post)
      post = Post.new(
        title: request.title,
        content: request.content,
        user_id: user_id,
        published: request.published
      )

      if post.save
        Result(Post).success(post)
      else
        Result(Post).failure(post.errors)
      end
    end
  end
end
```

### Migration

```crystal
class CreatePosts < CQL::Migration(20240115103045)
  def up
    schema.table :posts do
      primary :id, Int64
      text :title
      text :content
      boolean :published, default: "0"
      bigint :user_id
      timestamps
    end
    schema.posts.create!
  end

  def down
    schema.posts.drop!
  end
end
```

## Related Documentation

- [Getting Started](../getting-started/quick-start.md)
- [Generators](../generators/README.md)
- [Commands](../commands/README.md)
