# azu completion

Generate shell completion scripts for Azu CLI.

## Overview

The `completion` command generates shell-specific completion scripts that enable tab-completion for Azu CLI commands, options, and arguments.

## Usage

```bash
azu completion [shell] [options]
```

## Options

| Option        | Description           | Default    |
| ------------- | --------------------- | ---------- |
| `--shell, -s` | Shell type            | (detected) |
| `--help, -h`  | Show help             | -          |

## Supported Shells

- **bash** - Bash shell completion
- **zsh** - Zsh shell completion
- **fish** - Fish shell completion

## Installation

### Bash

Add to your `~/.bashrc` or `~/.bash_profile`:

```bash
eval "$(azu completion bash)"
```

Then reload your shell:

```bash
source ~/.bashrc
```

### Zsh

Add to your `~/.zshrc`:

```bash
eval "$(azu completion zsh)"
```

Then reload your shell:

```bash
source ~/.zshrc
```

### Fish

Save the completion script to Fish's completion directory:

```bash
azu completion fish > ~/.config/fish/completions/azu.fish
```

The completion will be available immediately in new Fish shells.

## Features

The completion scripts provide intelligent completion for:

### Commands

Press Tab after `azu` to see all available commands:

```bash
azu <TAB>
# Shows: new, init, generate, serve, test, db:migrate, ...
```

### Generators

Press Tab after `azu generate` to see all generator types:

```bash
azu generate <TAB>
# Shows: endpoint, model, service, middleware, request, ...
```

### Options

Press Tab after `-` to see available options:

```bash
azu new myapp --<TAB>
# Shows: --type, --db, --no-git, --docker, ...
```

### Option Values

Press Tab after certain options to see valid values:

```bash
azu new myapp --type <TAB>
# Shows: web, api, cli

azu new myapp --db <TAB>
# Shows: postgresql, mysql, sqlite

azu config:show --format <TAB>
# Shows: yaml, json, table
```

## Examples

### Generate Bash Completion

```bash
# Output to stdout
azu completion bash

# Redirect to file
azu completion bash > /etc/bash_completion.d/azu

# Or add to bashrc
echo 'eval "$(azu completion bash)"' >> ~/.bashrc
```

### Generate Zsh Completion

```bash
# Output to stdout
azu completion zsh

# Or add to zshrc
echo 'eval "$(azu completion zsh)"' >> ~/.zshrc
```

### Generate Fish Completion

```bash
# Save to completions directory
azu completion fish > ~/.config/fish/completions/azu.fish
```

### Specify Shell Explicitly

```bash
# Using --shell flag
azu completion --shell bash

# Using positional argument
azu completion zsh
```

## Troubleshooting

### Completions Not Working

1. Ensure the completion script is loaded:
   - Bash: Check `~/.bashrc` or `/etc/bash_completion.d/`
   - Zsh: Check `~/.zshrc`
   - Fish: Check `~/.config/fish/completions/`

2. Reload your shell:
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

3. Verify Azu is in your PATH:
   ```bash
   which azu
   ```

### Shell Detection Failed

If automatic shell detection fails, specify the shell explicitly:

```bash
azu completion --shell bash
```

### Permission Denied

If you get permission errors writing to system directories:

```bash
# Use sudo for system-wide installation
sudo azu completion bash > /etc/bash_completion.d/azu

# Or install to user directory
azu completion bash > ~/.local/share/bash-completion/completions/azu
```

---

**See Also:**

- [azu help](help.md) - Get help with commands
- [CLI Options Reference](../reference/cli-options.md) - All CLI options
