# Plugin System

The CLI has an internal hook system. It is not an extension mechanism for users: there is no `azu plugin` command,
no plugin installation and no loading of external plugins.

## What exists

`AzuCLI::Plugins::Base` (`src/azu_cli/plugins/base.cr`) defines four hooks, called by `CLI#execute_command`:

| Hook                     | When                                   |
| ------------------------ | -------------------------------------- |
| `on_load`                | once, when the CLI starts              |
| `before_command(cmd, args)` | before a command executes           |
| `after_command(cmd, result)` | after a command finished           |
| `on_error(cmd, error)`   | when a command raised                  |
| `on_unload`              | defined, never called                  |

`Base` also has `enable`, `disable` and `info` (name, version, description, enabled); nothing calls them either.
There is no external plugin loading: the unused `ExternalPlugin` class and the `load_external_plugins` stub were removed.

Three plugins are registered in `CLI#load_builtin_plugins`: `GeneratorPlugin`, `DatabasePlugin` and
`DevelopmentPlugin`. `azu version` lists them (the list is fixed text).

## Adding behaviour

To change what the CLI does, add a command (`Commands::Base`, registered in `CLI#setup_commands`) or a generator
(`Teeplate::FileTree`, registered in `Commands::Generate#execute`); see CLAUDE.md. A hook plugin is only for
cross-cutting behaviour around every command.
