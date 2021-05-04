# azu_cli

azu endpoint :path :request :response
azu request :name [query:name:string ...]
azu response :name [name:string ...]
azu component :name
azu template :name
azu channel :name
azu dev - runs watcher and recompiles project
azu run - shards build and runs project
azu routes

azu i.clear - installs clear shard and generates config
azu clear.migrate
azu clear.undo
azu clear.redo
azu clear.migration
azu clear.model

i.joobq -- installs JoobQ shard and generates config
joobq.job :name field:type 



## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     azu_cli:
       github: your-github-user/azu_cli
   ```

2. Run `shards install`

## Usage

```crystal
require "azu_cli"
```

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/azu_cli/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Elias J. Perez](https://github.com/your-github-user) - creator and maintainer
