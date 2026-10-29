# Azu CLI

Command-line tool for the Azu Toolkit: it creates Azu projects, generates code (models, endpoints, scaffolds,
channels, session authentication, jobs and more), manages the CQL database and runs a development server.

<img width="1990" height="480" alt="azu-cli-gitbook-cover" src="https://github.com/user-attachments/assets/1d3e67f1-f3ad-4b76-8c03-191468f18104" />

## Features

- **Project generator** - `azu new` creates a web, API or CLI project; `--docker` adds a multi-stage Dockerfile, `--ci` a GitHub Actions workflow
- **Generators** - models, endpoints, scaffolds (CRUD), migrations, services, requests, pages, channels, session authentication, jobs and more
- **Database commands** - create, migrate, rollback, seed, reset, status (CQL migrations)
- **Development server** - `azu dev` rebuilds (not a release build) and restarts when sources change; `azu serve` is the older `--production` variant
- **Diagnostics** - `azu routes` lists the routes, `azu doctor` checks the environment, `azu console` opens Crystal's interpreter with the app loaded
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
# Create a new project (SQLite by default: no database server needed; `--db postgresql` or `--db mysql` for a server)
azu new my_app
cd my_app

# Generate a CRUD resource, create and migrate the database
azu generate scaffold Post title:string content:text published:bool
azu db:setup

# Start the development server
azu dev
```

Visit `http://localhost:4000/posts` to see your application.

## Commands

Run `azu help` for the list (`azu --help` and `azu --version` are not options: use `azu help` and `azu version`).

| Category    | Commands                                                                                       |
| ----------- | ---------------------------------------------------------------------------------------------- |
| Project     | `new`, `init`, `generate` (`g`)                                                                |
| Database    | `db:create`, `db:drop`, `db:setup`, `db:reset`, `db:migrate`, `db:rollback`, `db:status`, `db:seed`, `db:schema:load`, `db:data:migrate`, `db:migrations:verify`, `db:validate` |
| Development | `dev`, `serve` (`server`, `s`), `routes`, `console`, `doctor`, `test` (`t`)                    |
| Jobs        | `jobs:worker`, `jobs:status`, `jobs:clear`, `jobs:retry`, `jobs:ui`                            |
| Session     | `session:setup`, `session:clear`                                                               |
| OpenAPI     | `openapi:export`, `openapi:generate`                                                           |
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

Generated web apps use **daisyUI + Tailwind CSS**, with ready-to-run local styles, light/dark themes, responsive navigation, CRUD forms, empty states and account avatars. Scaffolds and web index endpoints automatically add their sections to the shared navigation. Customize Jinja templates directly; use `npm ci` and `npm run watch:css` when changing styles. See [Generated UI and Navigation](docs/generators/ui.md).

```bash
azu new my_app --docker               # Dockerfile + .dockerignore (production image, non-root, /health check)
azu new my_app --no-ci                # skip the GitHub Actions workflow
```

`scripts/e2e_generated_app.sh` (CI) and `scripts/e2e_docker.sh` (needs a docker daemon) build and boot generated projects.

For real browser acceptance, install Python Playwright (`python3 -m pip install playwright`), Chromium, Redis and Node.js 20+, then run `sh scripts/e2e_browser_app.sh` after building `bin/azu`. Set `CHROMIUM_PATH` if Chromium is not on `PATH`. It generates a disposable SQLite web app, rebuilds CSS before generating its pages, and clicks through navigation, product CRUD, mobile forms, registration, login and logout; checks chat broadcasts with browser WebSockets; and verifies incremental migration rollback/reapply, idempotence and session/data persistence across a server rebuild/restart. The retained temporary directory contains the app, screenshots, logs and a report. The private Playwright trace contains synthetic session/CSRF cookies; do not publish it. This is a local acceptance runner, separate from hosted CI and deployment validation.

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

### Terminal diagnostics and generator validation

`azu joobq` provides queue, workflow-step and dead-letter views with bounded master/detail panes and confirmed atomic replay. `azu dev` adds an Errors tab and expands SQL with live queries, pool metrics and latency buckets. See [JoobQ dashboard](docs/command-reference/azu-joobq.md) and [dev telemetry requirements](docs/command-reference/azu-dev.md); expanded app telemetry requires the companion Azu producer changes, and PostgreSQL History Store support awaits a supported API.

Run `scripts/check_generators.sh web` and `scripts/check_generators.sh api` to compile every generator family together and exercise lazy-compiled message, job, validator and component paths. Release CI requires these checks, the generated-app end-to-end matrix, and `scripts/check_joobq_adapter.sh` against published JoobQ 0.4.2 and the pinned revision with atomic DLQ support.
