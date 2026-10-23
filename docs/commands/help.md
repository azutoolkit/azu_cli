# azu help

Shows the commands the CLI registers, or the options of one command.

## Usage

```bash
azu help [new|generate|db|serve|test|jobs|session]
```

`azu` with no arguments prints the same overview. `azu --help` and `azu --version` are not understood: use
`azu help` and `azu version`. For topics without detailed help (`azu help plugin`, ...) the command says so.

## Output of `azu help`

```
Azu CLI - Crystal web framework command line tool
Version: 0.0.1

Usage: azu <command> [options] [arguments]

Project Commands:
  new <project-name>     Create a new Azu project
  init                   Initialize Azu in existing project
  generate <type> <name> Generate code (alias: g)

Database Commands:
  db:create              Create the database
  db:migrate             Run pending migrations
  db:rollback            Rollback migrations
  db:seed                Seed the database with data
  db:reset               Reset database (drop, create, migrate)
  db:status              Show migration status
  db:setup               Setup database (create and migrate)
  db:drop                Drop the database

Development Commands:
  serve                  Start development server with hot reload (alias: s)
  test                   Run application tests (alias: t)

Job Queue Commands:
  jobs:worker            Start background job workers
  jobs:status            Show job queue status
  jobs:clear             Clear job queues
  jobs:retry             Retry failed jobs
  jobs:ui                Start JoobQUI web interface

Session Commands:
  session:setup          Setup session management
  session:clear          Clear all sessions

Other Commands:
  plugin <operation>     Plugin management
  version                Show version information
  help [command]         Show this help or command help

Generator Types:
  model, endpoint, service, request, page, migration, scaffold
  component, middleware, validator, job, mailer, channel, auth

Examples:
  azu new my-app
  azu generate model User name:string email:string
  azu generate auth
  azu db:create
  azu db:migrate
  azu serve
  azu test --watch
  azu jobs:worker --workers 4

For more information, visit: https://azutopia.gitbook.io/azu
```
