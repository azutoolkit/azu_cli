---
description: Show the azu CLI version, the Crystal it was built with and, inside a project, the azu, cql and joobq versions it is locked to.
---

# azu version

`azu version` prints the version of the CLI, the Crystal the binary was built with and the built-in plugins. Inside a project it also reads `shard.lock` and shows the `azu`, `cql` and `joobq` versions the project uses.

## Overview & visual demo

Put its output in a bug report: the CLI version and the locked framework versions are the two things a maintainer asks for first. On a color terminal it draws a card; `--ui plain` gives the text.

<figure><img src="../assets/terminal-ui/18-version.png" alt="azu version card listing Azu CLI v0.1.44, Crystal 1.22.1, and the azu, cql and joobq versions from shard.lock"><figcaption><p><code>azu version</code> in a project, from an older build (v0.1.44). The three lines under the CLI and Crystal come from the project's <code>shard.lock</code>.</p></figcaption></figure>

```mermaid
flowchart LR
  A["azu version"] --> B{"color terminal, not CI, not --ui plain?"}
  B -->|yes| C["card: CLI, Crystal, shard.lock versions"]
  B -->|no| D["plain text: CLI, Crystal, plugins"]
```

## Quickstart & command syntax

```bash
azu version
azu version --ui plain
```

| Option      | Meaning                                    | Default                               |
| ----------- | ------------------------------------------ | ------------------------------------- |
| `--ui MODE` | `rich` (the card) or `plain` (the text)    | `rich` on a color terminal outside CI |

The command takes no other options. `azu --version` is not understood; it exits with `Unknown command`. The version of the CLI is the `version` in the `shard.yml` it was built from.

## Realistic output

{% code title="terminal: azu version --ui plain" %}
```text
Azu CLI v0.1.46
Crystal 1.22.1
Topia CLI Framework

Plugins:
  - Generator Plugin v1.0.0
  - Database Plugin v1.0.0
  - Development Plugin v1.0.0
```
{% endcode %}

*The plain form. `Crystal` is the version the binary was built with (the repository pins 1.22.1). The plugin list is fixed text.*

## Do's and don'ts

{% hint style="info" %}
**Pro tip:** `azu version --ui plain` is the form to paste into an issue or a CI log, because it has no box characters to clean up.
{% endhint %}

{% hint style="success" %}
Quote the `azu`, `cql` and `joobq` lines when you report a problem. They are the versions the project's `shard.lock` resolves, which is what actually ran.
{% endhint %}

{% hint style="warning" %}
The locked versions come from `shard.lock` in the current directory. Run the command in the project root, or those lines are missing.
{% endhint %}

{% hint style="danger" %}
Don't read the plugin list as the set of installed extensions. The three plugins are the CLI's own internal hooks, and the list is fixed text.
{% endhint %}
