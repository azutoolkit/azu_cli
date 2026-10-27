# CLI architecture

How one `azu ...` invocation travels through the CLI, and where you would change it.

## Overview

Every command is a class that returns a `Result`. The CLI looks it up by name, parses its arguments, runs it through a
middleware chain and the built-in plugin hooks, and turns the `Result` into an exit code. Generators render ECR
templates with [Teeplate](https://github.com/crystal-loot/teeplate).

```mermaid
flowchart TD
  A["azu db:migrate --steps 2"] --> B["AzuCLI.run"]
  B --> C["load_project_env (.env files)"]
  C --> D["Config.load! (azu.yml, env vars)"]
  D --> E["CLI#run: find command by name"]
  E --> F["command.parse_args"]
  F --> G["middleware.before: Logging, ErrorHandler, Configuration"]
  G --> H["plugins.before_command"]
  H --> I["command.execute : Result"]
  I --> J["middleware.after, plugins.after_command"]
  J --> K["exit code: 0, 1 or 2"]
  I -. raises .-> L["middleware.error, plugins.on_error, exit 1"]
```

`load_project_env` runs for every command except `new`, `init`, `help`, `version` and `completion`.

## Quickstart

The parts, and the file to open for each:

| Part        | Where                       | What it does                                                           |
| ----------- | --------------------------- | ---------------------------------------------------------------------- |
| Registry    | `src/azu_cli/cli.cr`        | `CLI#setup_commands` registers every command and alias                 |
| Commands    | `src/azu_cli/commands/`     | Subclasses of `Commands::Base`; `db:*`, `jobs:*`, `config:*` live in subdirectories |
| Generators  | `src/azu_cli/generators/`   | `Teeplate::FileTree` subclasses, one per generator type                |
| Templates   | `src/azu_cli/templates/`    | ECR files: `project/`, `scaffold/`, `auth/`, `joobq/`, ...             |
| Middleware  | `src/azu_cli/middleware/`   | Logging, error handling, configuration                                 |
| Plugins     | `src/azu_cli/plugins/`      | Three built-in hook sets (generator, database, development)            |
| UI engine   | `src/azu_cli/ui/`           | Terminal detection, frames, reporters; see [Terminal UI](terminal-ui.md) |

Exit codes: `0` success, `1` failure, `2` invalid usage.

## Output

`azu help` lists what is registered. Aliases: `g` for `generate`, `s` and `server` for `serve`, `t` for `test`.

```text
$ azu nope
Unknown command: nope
Run 'azu help' to see available commands
$ echo $?
1
```

## Do's and don'ts

{% hint style="info" %}
A command prints data to its `stdout` and keeps the CLI's own log lines off it when the data is the product (`routes`,
`doctor`). That is why `azu routes --format json | jq` works.
{% endhint %}

{% hint style="warning" %}
The plugin system is internal. There is no `azu plugin` command, no plugin installation and no loading of external
plugins. See [Custom tasks](../advanced/custom-tasks.md) for how to extend the CLI.
{% endhint %}

{% hint style="danger" %}
Do not document or register a flag or command you did not implement. `azu help` and `CLI_REFERENCE.md` must list exactly
what exists.
{% endhint %}

<details>

<summary>Plugin hooks</summary>

`Plugins::Base` defines `on_load` (once at start), `before_command(cmd, args)`, `after_command(cmd, result)` and
`on_error(cmd, error)`. A plugin may reject arguments by raising in `before_command`. `on_unload` is defined but never
called. Registered in `CLI#load_builtin_plugins`: `GeneratorPlugin`, `DatabasePlugin`, `DevelopmentPlugin`.

Details: [Plugin system](../architecture/plugins.md), [CLI framework](../architecture/cli-framework.md),
[Generator system](../architecture/generator-system.md).

</details>
