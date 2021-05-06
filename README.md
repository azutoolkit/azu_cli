# Azu - Command Line Interface 

AZU is a toolkit for artisans with expressive, elegant syntax that 
offers great performance to build rich, interactive type safe, applications 
quickly, with less code and conhesive parts that adapts to your prefer style.

## Clear ORM Support

Clear is an ORM (Object Relation Mapping) built for Crystal language.

Clear is built especially for PostgreSQL, meaning it's not compatible with
MariaDB or SQLite for example. Therefore, it achieves to delivers a
tremendous amount of PostgreSQL advanced features out of the box.

> **Note** - Must define DATABSE_URL environment variable for Clear ORM commands 
> to work

## Documentation: 

  - Azu       - https://azutopia.gitbook.io/azu/
  - Clear ORM - https://clear.gitbook.io/


## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     azu_cli:
       github: azutoolkit/azu_cli
   ```

2. Run `shards install`

## Usage

```crystal
require "azu_cli"
```

## Commands

```crystal 
  project   - Generates a new Azu project
  dev       - Starts server, watches for file changes and recompiles 
              your project in the background
  component - Generates an Azu::Component
  endpoint  - Generate an Azu::Endpoint
  request   - Generate an Azu::Request
  response  - Generate an Azu::Response
  template  - Generate a Crinja Template
  channel   - Generate a Crinja Template

  clear.migrator  - Performs database maintenance tasks
  clear.migration - Generates a Clear ORM Migration
  clear.model     - Generates a Clear ORM Model and Migration
```

## Contributing

1. Fork it (<https://github.com/azutoolkit/azu_cli/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Elias J. Perez](https://github.com/eliasjpr) - creator and maintainer
