# Azu - Command Line Interface

AZU is a toolkit for artisans with expressive, elegant syntax that
offers great performance to build rich, interactive type safe, applications
quickly, with less code and conhesive parts that adapts to your prefer style.

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

1. Run `make`:

````shell
make install
```

2. Run `make install` - It might required `sudo`

3. `azu` command should be installed and ready to use

## Usage

```bash
azu project name
```

## Commands

```shell
AZU Toolkit - Command Line Interface

  AZU is a toolkit for artisans with expressive, elegant syntax that
  offers great performance to build rich, interactive type safe,
  applications quickly, with less code and conhesive parts that adapts
  to your prefer style.

  Documentation

  - Azu - https://azutopia.gitbook.io/azu/
  - ORM - https://imdrasil.github.io/jennifer.cr/docs/

  Examples

  azu project name -db postgres

  Subcommands

  project    - Generates a new Azu project
  task       - Generates a task definition file
  scaffold   - Generates a resource for your application
  dev        - Recompiles on crystal file changes
  db         - Manages database versions and schema

Usage

  azu builder

Options

  --help     Show this help.
  --version  Print the version and exit.

Builder 0.0.1+13 [547daf2] (2022-11-14)
```

## Contributing

1. Fork it (<https://github.com/azutoolkit/azu_cli/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Elias J. Perez](https://github.com/eliasjpr) - creator and maintainer
````
