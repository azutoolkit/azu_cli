---
description: How one azu command travels through the CLI, and where to change it.
---

# CLI architecture

Every command is a class that returns a `Result`. The CLI finds it by name, parses its arguments, runs it through
middleware and plugin hooks, and turns the result into an exit code.

## Overview & visual demo

<figure><img src="../assets/terminal-ui/04-new-progress.png" alt="azu new mid-run: a review screen above a progress card with a spinner"><figcaption><p>One command, three layers: the wizard and review (UI), the steps it runs (command), and the files it writes (generator).</p></figcaption></figure>

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
  J --> K["exit code 0, 1 or 2"]
  I -. raises .-> L["middleware.error, plugins.on_error, exit 1"]
```

`load_project_env` runs for every command except `new`, `init`, `help`, `version` and `completion`.

## Quickstart & command syntax

Where to look:

| Part       | Path                      | What it does                                                           |
| ---------- | ------------------------- | ---------------------------------------------------------------------- |
| Registry   | `src/azu_cli/cli.cr`      | `CLI#setup_commands` registers every command and alias                 |
| Commands   | `src/azu_cli/commands/`   | `Commands::Base` subclasses; `db/`, `jobs/`, `config/` are subfolders  |
| Generators | `src/azu_cli/generators/` | `Teeplate::FileTree` subclasses, one per generator                     |
| Templates  | `src/azu_cli/templates/`  | ECR files: `project/`, `scaffold/`, `auth/`, `joobq/`, ...             |
| Middleware | `src/azu_cli/middleware/` | Logging, error handling, configuration                                 |
| Plugins    | `src/azu_cli/plugins/`    | Three built-in hook sets: generator, database, development             |
| UI engine  | `src/azu_cli/ui/`         | See [Terminal UI](terminal-ui.md)                                      |

{% code title="src/azu_cli/cli.cr (shape of a registration)" %}
```crystal
register_command("generate", Commands::Generate)
register_command("g", Commands::Generate) # alias
```
{% endcode %}

| Exit code | Meaning        |
| --------- | -------------- |
| `0`       | Success        |
| `1`       | Failure        |
| `2`       | Invalid usage  |

Aliases: `g` for `generate`, `s` and `server` for `serve`, `t` for `test`.

## Realistic output

{% code title="terminal" %}
```text
$ azu nope
Unknown command: nope
Run 'azu help' to see available commands
$ echo $?
1
```
{% endcode %}

*An unknown command exits 1 and points at `azu help`.*

## Do's and don'ts

{% hint style="info" %}
**Pro tip:** commands whose output is data (`routes`, `doctor`) keep the CLI's own log lines off stdout, so
`azu routes --format json | jq` just works.
{% endhint %}

{% hint style="success" %}
Add a command by subclassing `Commands::Base`, returning a `Result`, and registering it. The wiring is automatic from there.
{% endhint %}

{% hint style="warning" %}
The plugin system is internal. There's no `azu plugin` command, no plugin installation and no external plugin loading.
See [Custom tasks](../advanced/custom-tasks.md) for how to extend the CLI.
{% endhint %}

{% hint style="danger" %}
Don't document or register a flag or command you didn't implement. `azu help` and `CLI_REFERENCE.md` list exactly what exists.
{% endhint %}

<details>

<summary>Plugin hooks</summary>

`Plugins::Base` defines `on_load` (once at start), `before_command(cmd, args)`, `after_command(cmd, result)` and
`on_error(cmd, error)`. A plugin can reject arguments by raising in `before_command`. `on_unload` is defined but never
called. Registered in `CLI#load_builtin_plugins`: `GeneratorPlugin`, `DatabasePlugin`, `DevelopmentPlugin`.

More: [Generator system](generator-system.md) and [Template engine](template-engine.md).

</details>
