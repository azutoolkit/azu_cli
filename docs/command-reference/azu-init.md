---
description: Prepare an existing Crystal project for the Azu CLI by creating the directories the generators write to.
---

# azu init

## Overview & visual demo

Add Azu CLI configuration to an existing project. Review the generated setup before using development commands, especially when the application already has custom boot or migration behavior.

<figure><img src="../assets/terminal-ui/04-new-progress.png" alt="The azu new progress card, with a spinner on the step that is running"><figcaption><p>The progress card of <code>azu new</code>. <code>azu init</code> has no card: it prints the plain lines shown under Realistic output.</p></figcaption></figure>

```mermaid
flowchart LR
  A["cd my_crystal_app"] --> B{"shard.yml in this directory?"}
  B -->|no| C["Error: not a valid project directory"]
  B -->|yes| E["Create the generator directories"]
  E --> F["Add azu, cql and a driver to shard.yml yourself"]
```

## Quickstart & command syntax

```bash
cd my_crystal_app
azu init
```

Then add the dependencies the generated code uses. `azu init` does not do this for you:

{% code title="shard.yml (dependencies)" %}
```yaml
dependencies:
  azu:
    github: azutoolkit/azu
    version: ~> 1.0.4
  cql:
    github: azutoolkit/cql
    version: ~> 1.0.1
  sqlite3:
    github: crystal-lang/crystal-sqlite3
    version: ~> 0.24.0
```
{% endcode %}

`azu init` takes no options. It looks for `shard.yml` in the current directory only.

## Realistic output

{% code title="terminal: azu init (stdout is not a terminal)" %}
```text
[hh:mm:ss] [INFO ] Initializing Azu in current project...
[hh:mm:ss] [INFO ] Creating project structure...
[hh:mm:ss] [INFO ] Azu initialized successfully!
```
{% endcode %}

*Log lines as the logger writes them outside a terminal; `hh:mm:ss` is the time, and the emoji on the last line is left out.*

{% code title="terminal: azu init (no shard.yml here)" %}
```text
ERROR: Not in a valid Crystal project directory. Run this command from your project root.
```
{% endcode %}

*Nothing is written without a `shard.yml`; the exit code is 1.*

## Do's and don'ts

{% hint style="info" %}
**Pro tip:** run `azu init` from the project root, the directory that holds `shard.yml`. The command does not search upwards.
{% endhint %}

{% hint style="success" %}
Run it again whenever you like. It only creates directories that are missing and never touches existing files.
{% endhint %}

{% hint style="warning" %}
`azu init` does not add `azu`, `cql` or a database driver to `shard.yml`. Add them yourself, or the generated code has nothing to build against.
{% endhint %}

{% hint style="danger" %}
Don't expect `azu init` to scaffold an app. It creates empty directories. Use [azu new](azu-new.md) for a project that runs.
{% endhint %}

<details>

<summary>What it creates</summary>

These directories, created if missing:

- `src/models`, `src/endpoints`, `src/services`, `src/pages`, `src/middleware`, `src/validators`, `src/channels`, `src/handlers`, `src/requests`, `src/responses`, `src/components`
- `src/db/migrations`
- `spec/models`, `spec/endpoints`, `spec/services`
- `public/templates`, `public/assets`

</details>
