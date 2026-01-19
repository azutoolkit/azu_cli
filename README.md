# Azu CLI

Production-ready CLI for the Azu Toolkit.

A Rails-like command-line interface for Crystal that provides database management, code generation, hot reloading, and comprehensive development tools.

## Features

- **Rails-Like Workflows** - Complete database management, generators, and development tools
- **Hot Reloading** - Development server with automatic recompilation
- **25+ Commands** - Comprehensive CLI for all development tasks
- **12+ Generators** - Scaffold models, endpoints, services, jobs, and more
- **CQL ORM Integration** - Full support for CQL database operations
- **JoobQ Integration** - Background job management and monitoring
- **Authentication** - Complete auth system generation (JWT/Session)

## Installation

```bash
git clone https://github.com/azutoolkit/azu_cli
cd azu_cli
shards install
shards build
sudo make install
```

## Quick Start

```bash
# Create a new project
azu new my_app --database postgres

# Navigate and setup
cd my_app
azu db:create
azu db:migrate

# Generate a resource
azu generate scaffold Post title:string content:text published:bool

# Run migration and start server
azu db:migrate
azu serve
```

Visit `http://localhost:4000/posts` to see your application.

## Core Commands

| Category   | Commands                                           |
| ---------- | -------------------------------------------------- |
| Project    | `new`, `init`, `generate`                          |
| Database   | `db:create`, `db:migrate`, `db:rollback`, `db:seed`|
| Development| `serve`, `test`                                    |
| Jobs       | `jobs:worker`, `jobs:status`, `jobs:ui`            |
| Session    | `session:setup`, `session:clear`                   |

## Generators

```bash
azu generate model User name:string email:string
azu generate endpoint api/v1/users --api
azu generate scaffold Product name:string price:float64
azu generate auth --strategy jwt
azu generate job SendEmail user_id:int64
```

## Documentation

- [Full Documentation](docs/)
- [CLI Reference](CLI_REFERENCE.md)
- [Azu Framework](https://github.com/azutoolkit/azu)
- [CQL ORM](https://github.com/azutoolkit/cql)
- [JoobQ](https://github.com/azutoolkit/joobq)

## Contributing

1. Fork it (<https://github.com/azutoolkit/azu_cli/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Elias J. Perez](https://github.com/eliasjpr) - creator and maintainer
