# Scaffold Generator

The scaffold generator creates a complete set of files for a resource with full CRUD operations.

## Usage

```bash
azu generate scaffold <name> [field:type...] [options]
```

## Options

| Option       | Description              | Default |
| ------------ | ------------------------ | ------- |
| `--api-only` | Generate API components  | false   |
| `--web-only` | Generate web components  | false   |
| `--force`    | Overwrite existing files | false   |

## Examples

```bash
# Basic scaffold
azu generate scaffold User name:string email:string

# Blog post with relationships
azu generate scaffold Post title:string content:text user_id:references published:bool

# API-only scaffold
azu generate scaffold Product name:string price:float64 --api-only
```

## Naming

One scheme runs through every layer. For `Post` in a project named `blog` (module `Blog`):

| Layer      | Constant                           | File                                    |
| ---------- | ---------------------------------- | --------------------------------------- |
| Model      | `Post`                             | `src/models/post.cr`                    |
| Migration  | `CreatePosts`                      | `src/db/migrations/<timestamp>_create_posts.cr` |
| Request    | `Blog::Posts::CreateRequest`       | `src/requests/posts/create_request.cr`  |
| Endpoint   | `Blog::Posts::CreateEndpoint`      | `src/endpoints/posts/create_endpoint.cr` |
| Service    | `Blog::Posts::CreateService`       | `src/services/posts/create_service.cr`  |
| Page       | `Blog::Posts::IndexPage`           | `src/pages/posts/index_page.cr`         |
| Template   |                                    | `public/templates/blog/posts/index_page.jinja` |

The model is a top-level class (`Post.create!`, `Post.find?`); everything that belongs to the web layer lives
in the plural namespace `Blog::Posts`, so the two never collide. The template path is the one
`Azu::Templates::Renderable#page_path` derives from the page's class name (`Blog::Posts::IndexPage` is
`blog/posts/index_page.jinja`).

## Generated Files

```text
src/
├── models/post.cr
├── db/
│   ├── schema.cr                    # gets the `posts` table
│   └── migrations/20240115103045_create_posts.cr
├── requests/posts/                  # index, show, new, create, edit, update, destroy
├── endpoints/posts/                 # the same seven actions
├── services/posts/                  # create, update, destroy
└── pages/posts/                     # index, show, new, edit
public/templates/blog/posts/         # index, show, new, edit and the shared _form partial
```

An API project (`--api-only`, or `azu new --type api`) has no forms: it gets `src/responses/posts/` (index,
show) instead of pages and templates, and endpoints without `new` and `edit`.

Run `azu db:setup` to create the database and the table, then `azu serve`. The pages are at `/posts`.

## Generated Code

### Model

Columns and associations only; validation lives in the request contracts.

```crystal
# src/models/post.cr
class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :posts

  getter title : String
  getter body : String
  getter published : Bool
  getter created_at : Time?
  getter updated_at : Time?

  def initialize(@title : String, @body : String, @published : Bool)
  end
end
```

### Migration

The same `table` block is added to `src/db/schema.cr`, where the models look their columns up.

```crystal
# src/db/migrations/20240115103045_create_posts.cr
class CreatePosts < CQL::Migration(20240115103045)
  def up
    schema.table :posts do
      primary :id, Int64, auto_increment: true
      text :title
      text :body
      boolean :published, default: false
      timestamps
    end
    schema.posts.create!
  end

  def down
    schema.posts.drop!
  end
end
```

### Request

An invalid request never reaches the endpoint: Azu answers it with a 422.

```crystal
# src/requests/posts/create_request.cr
module Blog
  struct Posts::CreateRequest
    include Azu::Request

    getter title : String
    getter body : String
    getter published : Bool = false

    validate title, presence: true
    validate body, presence: true
  end
end
```

### Endpoint

Writes answer with a `303 See Other`, so a browser reload does not repeat the form.

```crystal
# src/endpoints/posts/create_endpoint.cr
module Blog
  struct Posts::CreateEndpoint
    include Azu::Endpoint(Posts::CreateRequest, Azu::Response::Empty)

    post "/posts"

    def call : Azu::Response::Empty
      post = Posts::CreateService.new.call(create_request)
      redirect to: "/posts/#{post.id}", status: 303
    end
  end
end
```

### Service

```crystal
# src/services/posts/create_service.cr
module Blog
  class Posts::CreateService
    def call(request : Posts::CreateRequest) : Post
      post = Post.new(title: request.title, body: request.body, published: request.published)
      post.save!
      post
    end
  end
end
```

### Forms

The `_form` partial carries the CSRF field (`csrf_tag`, the project enables `Azu::Handler::CSRF`) and
the edit page adds `_method=patch`, which the router turns into a `PATCH`. Delete is a form on the show page
with `_method=delete`. Values are escaped with `| e`: `.jinja` templates are not auto-escaped.

## Attributes

`name:type[?][:modifier...]`, for example `title:string`, `age:int32?`, `email:string:unique`,
`owner_id:int64:ref:users`.

- `?` makes the column and the request field optional; without it a column is NOT NULL and a string must be present.
- `unique` and `index` become column options, `required` is the default and accepted for clarity,
  `ref:<table>` (or the `references` type) adds a foreign key.
- Names are lowercase identifiers and not Crystal keywords (`end`, `class`, `select`, ...) or methods of the model (`errors`, `table`, ...).
- Resource names must differ in singular and plural (`Series`, `News`, `Fish` are rejected) and must not hide a constant
  the generated code uses (`Status`, `Request`, `Context`, ...). A typed name is taken for a plural only when it is the plural of its own singular: `Posts` and `People` give `Post` and `Person`, while `Campus`, `Analysis`, `Address` and `Business` stay as typed (tables `campuses`, `analyses`, ...). The checks run for every generator that takes a resource name, not only the scaffold.
- Not supported yet by the scaffold forms: `json` and `uuid` fields (they generate, but their forms are untested).

An update is a `PATCH`: its request fields are all optional and only the ones sent change the record
(a given string must not be blank). The edit form sends a hidden `false` before each checkbox so an unchecked box is saved.

## Field Types

| Type         | Crystal Type | Description           |
| ------------ | ------------ | --------------------- |
| `string`     | `String`     | Text field (must be present) |
| `text`       | `String`     | Long text field       |
| `int32`      | `Int32`      | 32-bit integer        |
| `int64`      | `Int64`      | 64-bit integer        |
| `float64`    | `Float64`    | Decimal number        |
| `bool`       | `Bool`       | Boolean value         |
| `time`       | `Time`       | Timestamp             |
| `uuid`       | `UUID`       | UUID field            |
| `references` | `Int64`      | Foreign key reference |

## Common Patterns

### Blog Post

```bash
azu generate scaffold Post title:string content:text user_id:references published:bool
```

### E-commerce Product

```bash
azu generate scaffold Product name:string description:text price:float64 stock:int32
```

### User Management

```bash
azu generate scaffold User name:string email:string role:string active:bool
```

---

**Next Steps:**

- [Model Generator](model.md) - Create database models
- [Endpoint Generator](endpoint.md) - Create HTTP endpoints
- [Migration Generator](migration.md) - Create database migrations
