# azu_cli

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
Azu 0.1.0 [a519b94] (2021-05-05)

Command Line tool for Azu. 

AZU is a toolkit for artisans with expressive, elegant syntax that 
offers great performance to build rich, interactive type safe, applications 
quickly, with less code and conhesive parts that adapts to your prefer style.

Documentation: https://azutoolkit.github.io/azu/

Commands:
  dev       - Watches for file changes and recompiles your project in the 
              background
  component - Generates an Azu::Component to the ./src/components directory
  endpoint  - Generate an Azu::Endpoint
  request   - Generate an Azu::Request
  response  - Generate an Azu::Response
  template  - Generate a Crinja Template
  channel   - Generate a Crinja Template

  clear.migrator [up|down|set|seed|status|rollback] default: apply_all
  clear.migration
  clear.model
```

## Contributing

1. Fork it (<https://github.com/azutoolkit/azu_cli/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Elias J. Perez](https://github.com/eliasjpr) - creator and maintainer
