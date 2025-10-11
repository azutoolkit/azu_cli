# Azu CLI - Command Line Interface

**Feature-Complete, Production-Ready CLI for the Azu Toolkit**

AZU is a toolkit for artisans with expressive, elegant syntax that
offers great performance to build rich, interactive type safe, applications
quickly, with less code and cohesive parts that adapts to your preferred style.

## Features

- 🚀 **Rails-Like Workflows** - Complete database management, generators, and development tools
- 🔥 **Hot Reloading** - Development server with automatic recompilation on file changes
- 📦 **25+ Commands** - Comprehensive CLI for all development tasks
- 🎨 **12+ Generators** - Scaffold models, endpoints, services, jobs, and more
- 🗄️ **CQL ORM Integration** - Full support for CQL database operations
- ⚡ **JoobQ Integration** - Background job management and monitoring
- 🔐 **Session Management** - Redis, Memory, and Database backends
- 🧪 **Testing Infrastructure** - Test runner with watch mode
- 📧 **Mailer Support** - Email generation with async jobs
- 💬 **WebSocket Channels** - Real-time communication scaffolding
- 🔒 **Authentication** - Complete auth system generation (JWT/Session)

## Target Frameworks

The Azu CLI is specifically designed to work with two main frameworks from the Azu Toolkit ecosystem:

### CQL ORM Framework

**CQL** (Crystal Query Language) is a comprehensive Object-Relational Mapping (ORM) library designed to simplify and enhance the management and execution of SQL queries in Crystal.

**Key Features:**

- Type-safe ORM using Crystal's static type system
- Macro-powered DSL for defining models and relationships
- Active Record-style API with flexibility for Repository and Data Mapper patterns
- Support for major relational databases through Crystal DB drivers (PostgreSQL, MySQL, SQLite)
- Built for performance, leveraging compile-time optimizations
- Comprehensive query builder with type safety
- Migration system for database schema management

**Repository:** https://github.com/azutoolkit/cql

### Azu Web Framework

**Azu** is a high-performance, type-safe web framework for Crystal that emphasizes developer productivity, compile-time safety, and real-time capabilities.

**Key Features:**

- **Type-Safe Architecture:** Compile-time type checking for requests, responses, and parameters
- **Real-Time Capabilities:** WebSocket channels with automatic connection management
- **Performance-Optimized:** High-performance routing with LRU cache and path optimization
- **Developer Experience:** Comprehensive error handling and flexible middleware system
- **Modern Web Patterns:** Live components, Spark system for reactive UI updates
- **Content Negotiation:** Supporting JSON, HTML, XML, and plain text
- **Template Engine:** Hot reloading in development with production caching

**Repository:** https://github.com/azutoolkit/azu

## Jennifer ORM Support (Legacy)

Jennifer is an ORM (Object Relation Mapping) built for Crystal language that is supported for legacy projects.

## Documentation

- **Azu Toolkit** - <https://azutopia.gitbook.io/azu/>
- **CQL ORM Framework** - <https://github.com/azutoolkit/cql>
- **Azu Web Framework** - <https://github.com/azutoolkit/azu>
- **Jennifer ORM (Legacy)** - <https://imdrasil.github.io/jennifer.cr/docs/>

## Installation

### From Source

```bash
# Clone repository
git clone https://github.com/azutoolkit/azu_cli
cd azu_cli

# Install dependencies
shards install

# Build CLI
shards build

# Install globally (may require sudo)
sudo make install
```

### Using Makefile

```bash
make install
```

The `azu` command will be available system-wide.

## Quick Start

```bash
# Create a new project (interactive mode asks about JoobQ and other options)
azu new my-app

# Or create with specific options
azu new my-app --type web --database postgresql --joobq

# Navigate to project
cd my-app

# Setup database
azu db:create
azu db:migrate

# Generate a model
azu generate model User name:string email:string

# Generate a complete CRUD scaffold
azu generate scaffold Post title:string content:text

# Start development server with hot reloading
azu serve

# Run tests in watch mode (in another terminal)
azu test --watch
```

## Available Commands

### Project Management

- `azu new <name>` - Create a new Azu project
- `azu init` - Initialize Azu in existing project
- `azu generate <type> <name>` - Generate code from templates

### Database Commands (Rails-Like)

- `azu db:create` - Create the database
- `azu db:drop` - Drop the database
- `azu db:migrate` - Run pending migrations
- `azu db:rollback` - Rollback migrations
- `azu db:seed` - Seed the database with data
- `azu db:reset` - Reset database (drop, create, migrate)
- `azu db:status` - Show migration status
- `azu db:setup` - Setup database (create and migrate)

### Development Commands

- `azu serve` - Start development server with hot reload
- `azu test [--watch]` - Run application tests

### Job Queue Commands (JoobQ)

- `azu jobs:worker` - Start background job workers
- `azu jobs:status` - Show queue status and statistics
- `azu jobs:clear` - Clear job queues
- `azu jobs:retry` - Retry failed jobs
- `azu jobs:ui` - Start JoobQUI web interface

### Session Commands

- `azu session:setup` - Setup session management (Redis/Memory/Database)
- `azu session:clear` - Clear all sessions

### Code Generators

- `model` - CQL database models
- `service` - Business logic services
- `joobq` - JoobQ background job infrastructure setup
- `job` - Background jobs (JoobQ)
- `mailer` - Email functionality
- `channel` - WebSocket channels
- `auth` - Authentication system (JWT/Session)
- `scaffold` - Complete CRUD with all components
- `endpoint` - HTTP request handlers
- `contract` - Request validation
- `page` - Response pages
- `migration` - Database migrations
- `middleware` - HTTP middleware
- `component` - Reusable components
- `validator` - Custom validators

## Examples

### Create a Blog

```bash
# Create project
azu new blog
cd blog

# Setup database
azu db:create

# Generate models
azu generate model User name:string email:string
azu generate model Post title:string content:text author_id:int64

# Generate CRUD
azu generate scaffold Post title:string content:text published:bool

# Setup authentication
azu generate auth --strategy jwt

# Migrate and seed
azu db:migrate
azu db:seed

# Start development
azu serve
```

### Create an API

```bash
# Create API project
azu new api-service --type api
cd api-service

# Generate API scaffold
azu generate scaffold Product name:string price:float64 --api-only

# Setup background jobs
azu generate job ProcessOrder order_id:int64
azu session:setup --backend redis

# Start services
azu db:create && azu db:migrate
azu serve &
azu jobs:worker --workers 4 &
```

## Documentation

For complete documentation, see:

- **CLI Reference:** [CLI_REFERENCE.md](CLI_REFERENCE.md)
- **Test Report:** [TEST_VALIDATION_REPORT.md](TEST_VALIDATION_REPORT.md)
- **Implementation:** [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)
- **Azu Framework:** https://azutopia.gitbook.io/azu/
- **CQL ORM:** https://github.com/azutoolkit/cql
- **JoobQ:** https://github.com/azutoolkit/joobq
- **Session:** https://github.com/azutoolkit/session

## Contributing

1. Fork it (<https://github.com/azutoolkit/azu_cli/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Elias J. Perez](https://github.com/eliasjpr) - creator and maintainer

```

```
