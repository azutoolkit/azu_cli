---
description: What configures your app (.env files), what configures the CLI itself (azu.yml), and which wins.
---

# Configuration

Two separate things get configured, and mixing them up is the usual source of confusion. Your **app** is configured by environment variables, loaded from `.env` files. The **CLI** has an optional `azu.yml` that affects its own logging and checks.

## Overview & visual demo

<figure><img src="../assets/terminal-ui/14-doctor.png" alt="azu doctor checking the database, env, secrets and port"><figcaption><p><code>azu doctor</code> reads the same environment your app does: the database URL, every variable <code>.env.example</code> lists, the secrets and the port.</p></figcaption></figure>

```mermaid
flowchart TD
  P["Process environment"] --> L[".env.local"]
  L --> E[".env.CRYSTAL_ENV"]
  E --> D[".env"]
  D --> APP["Your app and azu db:*, azu dev, azu test"]
  Y["azu.yml (optional)"] --> CLI["CLI only: logging, config:*, startup warnings"]
  P --> CLI
```

## Quickstart & command syntax

### The app: `.env` files

Precedence, highest first: the process environment, `.env.local`, `.env.<CRYSTAL_ENV>`, `.env`. A file never overrides a variable the process already has.

| File                     | Committed | Holds                                                        |
| ------------------------ | --------- | ------------------------------------------------------------ |
| `.env`                   | no        | Random secrets, written with mode 0600 by `azu new`          |
| `.env.development`       | yes       | `DATABASE_URL`, `PERFORMANCE_MONITORING=true`                |
| `.env.test`              | yes       | `DATABASE_URL` for tests                                     |
| `.env.example`           | yes       | Every name the app uses, secrets blank                       |
| `.env.local`             | no        | Your machine's overrides                                     |

| Variable                 | Used for                                                              |
| ------------------------ | --------------------------------------------------------------------- |
| `CRYSTAL_ENV`            | `development`, `test` or `production`                                 |
| `PORT`, `HOST`           | Where the app listens (default port 4000). `azu dev --port` sets `PORT` |
| `DATABASE_URL`           | The database for the app and every `azu db:*` command                 |
| `CSRF_SECRET`            | Required in production; at least 32 characters                        |
| `SESSION_SECRET`         | Required in production once you generate authentication               |
| `PERFORMANCE_MONITORING` | `true` feeds the request stats in the `azu dev` dashboard             |
| `TEMPLATE_HOT_RELOAD`    | `false` turns off template reloading in development                   |

{% tabs %}
{% tab title="Development" %}
{% code title=".env.development" %}
```bash
DATABASE_URL=sqlite3://./db/blog_development.db
PERFORMANCE_MONITORING=true
```
{% endcode %}
{% endtab %}

{% tab title="Production" %}
```bash
CRYSTAL_ENV=production \
CSRF_SECRET="$(openssl rand -hex 32)" \
SESSION_SECRET="$(openssl rand -hex 32)" \
DATABASE_URL=postgres://user@db/blog ./bin/blog
```
Real environment variables win over any `.env` file, so set production secrets in your platform, not in a file.
{% endtab %}
{% endtabs %}

### The CLI: `azu.yml`

The CLI looks for the file in this order and takes the first hit: `./config/azu.yml` (what `azu new` generates), `./azu.yml`, `~/.config/azu/config.yml`, `~/.azu.yml`.

{% code title="config/azu.yml" %}
```yaml
global:
  debug_mode: false
  verbose: false
  quiet: false

general:
  colored_output: true

logging:
  level: "info"          # debug, info, warn, error, fatal
```
{% endcode %}

| Section      | Keys the CLI reads                                                                          |
| ------------ | ------------------------------------------------------------------------------------------- |
| `global`     | `debug_mode`, `verbose`, `quiet`, `show_help_on_empty`                                      |
| `general`    | `project_name`, `project_path`, `database_adapter`, `template_engine`, `colored_output`     |
| `filesystem` | `templates_path`, `output_path`                                                             |
| `database`   | `url`, `name`, `host`, `port`, `user`, `password`                                           |
| `server`     | `host`, `port`, `watch`, `rebuild`                                                          |
| `logging`    | `level`, `format`                                                                           |
| `project`    | `type`: how the CLI tells web, api and cli projects apart                                   |

Other keys are ignored. CLI-only variables: `AZU_ENV` (else `CRYSTAL_ENV`), `AZU_DEBUG`, `AZU_VERBOSE`, `AZU_QUIET`, `AZU_UI`, `NO_COLOR`, `FORCE_COLOR`.

```bash
azu config:show --section logging --format json
azu config:validate
azu config:env --list
```

## Realistic output

{% code title="terminal: azu doctor --ui plain" %}
```text
ok    database       SQLite file ./db/blog_development.db is writable
ok    env            every variable .env.example leaves blank is set
ok    secrets        no weak or hard-coded secrets found
ok    port           port 4000 is free
```
{% endcode %}

*Four of the nine checks. With `CRYSTAL_ENV=production`, a missing variable or a weak secret is a failure instead of a warning.*

## Do's and don'ts

{% hint style="info" %}
**Pro tip:** `azu doctor` is the quickest way to see what your environment looks like to the app. It never prints a secret or a password.
{% endhint %}

{% hint style="success" %}
Commit `.env.example` with every name your app reads, and keep real values in `.env` or your platform's secret store.
{% endhint %}

{% hint style="warning" %}
`azu.yml` does not configure the app. `azu dev` and `azu serve` read `PORT` and `HOST`, and `azu db:*` reads `DATABASE_URL`, from the environment, not from `server:` or `database:` in the file.
{% endhint %}

{% hint style="danger" %}
Don't rely on file values for `global.debug_mode`, `verbose`, `quiet`, `database.url` or `database.name`. The CLI reassigns them from the environment after reading the file, so they revert when the variable is unset. A top-level section named after the environment (such as `production:`) also replaces the rest of the file instead of merging with it.
{% endhint %}

<details>

<summary>How the CLI keeps <code>.env</code> files safe</summary>

The CLI loads the `.env*` files of whatever project it runs in, for every command except `new`, `init`, `help`, `version` and `completion`. It always skips names such as `PATH`, `HOME`, `LD_*`, `GIT_*` and compiler flags, and applies any other name only if it looks like an app setting (`DATABASE_URL`, `PORT`, `*_SECRET`, `*_URL`, ...) or is listed in `.env.example`. This is best effort, not a sandbox: the CLI still compiles and runs the project's own code.

</details>
