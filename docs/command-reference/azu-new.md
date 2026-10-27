---
description: Create a web, API or CLI project with secrets, git and shards in one reviewed step.
---

# azu new

`azu new <name>` writes a project, generates its `.env` secrets, initializes git, installs shards and type-checks the
result. On a terminal it asks a few questions first; with `--yes` it takes the defaults.

## Overview & visual demo

<figure><img src="../assets/terminal-ui/03-new-review.png" alt="The azu new review screen with the flight plan, the steps and the equivalent command line"><figcaption><p>The review screen: your choices on the left, what will happen on the right, the tools it found, and the same thing as one <code>azu new ... --yes</code> line.</p></figcaption></figure>

```mermaid
flowchart LR
  W["Wizard"] --> R["Review + equivalent command"]
  R -->|Enter| F["Files"]
  F --> S[".env secrets (0600)"]
  S --> G["git init + commit"]
  G --> SH["shards install"]
  SH --> T["Type-check"]
  T --> D["Next steps card"]
  R -->|Esc| X["Nothing written"]
```

## Quickstart & command syntax

```bash
azu new blog                                    # wizard
azu new blog --yes                              # defaults
azu new shop --docker --db postgresql --yes
```

| Option                           | Meaning                                      | Default          |
| -------------------------------- | -------------------------------------------- | ---------------- |
| `--type web\|api\|cli`           | Project type                                 | `web`            |
| `--api`                          | Shorthand for `--type api`                   |                  |
| `--db sqlite\|postgresql\|mysql` | Database (ignored for `cli`)                 | `sqlite`         |
| `--test spec\|minitest`          | Test framework                               | `spec`           |
| `--docker`                       | `Dockerfile` and `.dockerignore` (web, api)  | off              |
| `--ci "GitHub Actions"`, `--no-ci` | CI workflow                                | GitHub Actions   |
| `--git`, `--no-git`              | Initialize a repository                      | on               |
| `--example`, `--no-example`      | Include example code                         | on               |
| `--joobq`, `--no-joobq`          | Include JoobQ                                | on               |
| `--name`, `--module`, `--author`, `--email`, `--license` | Project metadata     |                  |
| `--yes`                          | Non-interactive                              |                  |
| `--ui rich\|plain\|json`         | Output mode                                  | auto             |

{% tabs %}
{% tab title="web" %}
```bash
azu new blog --yes
```
{% code title="blog/" %}
```text
src/        blog.cr  server.cr  endpoints/ requests/ pages/ services/ models/
            jobs/ channels/ middleware/ initializers/ db/{migrations,schema.cr,seed.cr}
public/templates/    # Jinja templates, never served as static files
spec/  config/  .env  .env.example  .env.development  .env.test  shard.yml
```
{% endcode %}
{% endtab %}

{% tab title="api" %}
```bash
azu new tracker --api --db postgresql --yes
```
JSON endpoints and request/response contracts. No HTML templates or static assets. Entry point is `src/api.cr`.
{% endtab %}

{% tab title="cli" %}
```bash
azu new tool --type cli --yes
```
An `OptionParser` program with `--help` and `--version`. No server, database, jobs or `.env`; no dependencies in
`shard.yml`. `shards build` produces `bin/tool`.
{% endtab %}
{% endtabs %}

## Realistic output

<figure><img src="../assets/terminal-ui/01-new-wizard-type.png" alt="The wizard asking for the project type"><figcaption><p>Each wizard step is one flag. Here: <code>--type</code>, with a one-line explanation of the highlighted choice.</p></figcaption></figure>

<figure><img src="../assets/terminal-ui/04-new-progress.png" alt="The progress card with a spinner on the shards step"><figcaption><p>Mid-run: a spinner and live timer on <code>shards install</code>, with the last line it printed.</p></figcaption></figure>

{% code title="terminal: azu new blog --yes --ui plain" %}
```text
✔ Files       63 written into ./blog
✔ Secrets     .env (0600) · CSRF_SECRET
✔ Git         init + 1 commit
✔ Shards      15 installed
✔ Type-check  src/server.cr
```
{% endcode %}

*One line per step. Exit code 0 means every step passed.*

## Do's and don'ts

{% hint style="info" %}
**Pro tip:** answer the wizard once, then copy the command line from the review screen into your CI or onboarding docs.
{% endhint %}

{% hint style="success" %}
Start on SQLite. It needs no server, and `--db postgresql` or `--db mysql` is a flag away when you do.
{% endhint %}

{% hint style="warning" %}
`--docker` is refused for `--type cli` (nothing to containerize). `azu new` never overwrites an existing directory.
{% endhint %}

{% hint style="danger" %}
Don't commit `.env`. It's git-ignored and holds random secrets. Commit `.env.example` (secrets blank) instead.
{% endhint %}

<details>

<summary>Full reference</summary>

Project types in depth, database notes, Docker and CI details: [commands/new.md](../commands/new.md). To add Azu to an
existing project, see [azu init](../commands/init.md).

</details>
