# Azu - Command Line Interface

AZU is a toolkit for artisans with expressive, elegant syntax that
offers great performance to build rich, interactive type safe, applications
quickly, with less code and conhesive parts that adapts to your prefer style.

## Clear ORM Support

Clear is an ORM (Object Relation Mapping) built for Crystal language.

Clear is built especially for PostgreSQL, meaning it's not compatible with
MariaDB or SQLite for example. Therefore, it achieves to delivers a
tremendous amount of PostgreSQL advanced features out of the box.

## Documentation

- Azu - <https://azutopia.gitbook.io/azu/>
- Clear ORM - <https://clear.gitbook.io/project/>

## Installation

1. Run `make`:

````shaell
make
```

2. Run `make install` - It might required `sudo`

3. `azu` command should be installed and ready to use

## Usage

```bash
azu project name --clear
azu clear.model name -column:psqltype column:psqltype
````

## Commands

```shell
Azu - Command Line Interface

  AZU is a toolkit for artisans with expressive, elegant syntax that
  offers great performance to build rich, interactive type safe, applications
  quickly, with less code and conhesive parts that adapts to your prefer style.

Documentation:
  - Azu       - https://azutopia.gitbook.io/azu/
  - Clear ORM - https://clear.gitbook.io/project/

Usage:
  - azu project name --clear
  - azu clear.model name -column:psqltype column:psqltype

Subcommands:

  project   - Generates a new Azu project
  db        - Manages database versions and schema
  dev       - Recompiles on crystal file changes
  channel   - Generates an Azu::Channel to handle websocket connections
  component - Generates an Azu::Component for building real time apps
  endpoint  - Generates an Azu::Endpoint for handling http resources
  request   - Generates an Azu::Request for validating and parsing http requests
  response  - Generates an Azu::Response that renders html response body
  template  - Generates a Crinja Template for building and rendering HTML
  migration - Generates a Clear ORM Migration to change Postgres databases
  model     - Generates a Clear ORM Model and Migration

  Note: Must define DATABSE_URL env variable for Clear ORM commands to work

Usage: azu Runner

Options:
  --help     Show this help.
  --version  Print the version and exit.

azu 0.1.0 [cf9f1fc] (2021-06-30)
```

> Note: Must define DATABSE_URL env variable for Clear ORM commands to work

## Contributing

1. Fork it (<https://github.com/azutoolkit/azu_cli/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Elias J. Perez](https://github.com/eliasjpr) - creator and maintainer
