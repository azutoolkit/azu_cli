# Azu CLI

Command-line tool for the Azu Toolkit: it creates Azu projects, generates code (models, endpoints, scaffolds,
channels, session authentication, jobs and more), manages the CQL database and runs a development server.

## Features

- **Project generator** - `azu new` creates a web, API or CLI project; `--docker` adds a multi-stage Dockerfile, `--ci` a GitHub Actions workflow
- **Generators** - models, endpoints, scaffolds (CRUD), migrations, services, requests, pages, channels, session authentication, jobs and more
- **Database commands** - create, migrate, rollback, seed, reset, status (CQL migrations)
- **Development server** - `azu serve` rebuilds and restarts when sources change
- **JoobQ and sessions** - `jobs:*` and `session:*` commands
- **OpenAPI** - export a spec from the code, or generate code from a spec

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
# Create a new project (SQLite needs no database server)
azu new my_app --db sqlite
cd my_app
shards install

# Generate a CRUD resource, create and migrate the database
azu generate scaffold Post title:string content:text published:bool
azu db:setup

# Start the development server
azu serve
```

Visit `http://localhost:4000/posts` to see your application.

## Commands

Run `azu help` for the list (`azu --help` and `azu --version` are not options: use `azu help` and `azu version`).

| Category    | Commands                                                                                       |
| ----------- | ---------------------------------------------------------------------------------------------- |
| Project     | `new`, `init`, `generate` (`g`)                                                                |
| Database    | `db:create`, `db:drop`, `db:setup`, `db:reset`, `db:migrate`, `db:rollback`, `db:status`, `db:seed`, `db:schema:load`, `db:data:migrate`, `db:migrations:verify`, `db:validate` |
| Development | `serve` (`server`, `s`), `test` (`t`)                                                          |
| Jobs        | `jobs:worker`, `jobs:status`, `jobs:clear`, `jobs:retry`, `jobs:ui`                            |
| Session     | `session:setup`, `session:clear`                                                               |
| OpenAPI     | `openapi:export`, `openapi:generate`                                                           |
| Config      | `config:show`, `config:validate`, `config:env`                                                 |
| Other       | `completion`, `version`, `help`                                                                |

## Generators

```bash
azu generate model User name:string email:string
azu generate scaffold Product name:string price:float64
azu generate channel Chat
azu generate auth
azu generate job SendEmail user_id:int64
```

## Delivery

```bash
azu new my_app --db sqlite --docker   # Dockerfile + .dockerignore (production image, non-root, /health check)
azu new my_app --no-ci                # skip the GitHub Actions workflow
```

`scripts/e2e_generated_app.sh` (CI) and `scripts/e2e_docker.sh` (needs a docker daemon) build and boot generated projects.

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
