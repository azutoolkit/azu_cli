---
description: Show the effective configuration of your app: server, TLS, templates, database, limits and more, with secrets masked.
---

# azu config

## Overview & visual demo

`azu config` shows what your application is actually configured with. It compiles the project, loads it without starting the server, and prints the settings Azu holds once your initializers and `.env` files have been applied: the server, TLS, templates, database, limits, uploads, WebSocket, i18n and asset settings. Use it when a value isn't what you expected, or to attach to a bug report. Nothing secret is printed.

<figure><img src="../assets/terminal-ui/14-doctor.png" alt="azu doctor, a sibling command that checks the same environment and prints a card"><figcaption><p>No screenshot of <code>azu config</code> yet; this is its sibling <code>azu doctor</code>, which checks the same environment. On a color terminal <code>azu config</code> draws a card the same way, with a heading per section.</p></figcaption></figure>

```mermaid
flowchart LR
  A["azu config"] --> B["Write tmp_config_*.cr"]
  B --> C["crystal run: require src/blog.cr"]
  C --> D["Read Azu::CONFIG"]
  D --> E["Mask the database password, report secrets as set or not set"]
  E --> F{"--format"}
  F -->|table| G["Card on a color terminal, text otherwise"]
  F -->|json| H["JSON object of sections on stdout"]
  C --> I["Delete tmp_config_*.cr"]
```

## Quickstart & command syntax

```bash
azu config
azu config --section database
azu config --format json
CRYSTAL_ENV=production azu config --section server
```

| Option             | Meaning                                                                  | Default             |
| ------------------ | ------------------------------------------------------------------------ | ------------------- |
| `--format FORMAT`  | `table` or `json`                                                        | `table`             |
| `--section NAME`   | One section: `server`, `tls`, `templates`, `errors`, `session`, `secrets`, `database`, `limits`, `uploads`, `websocket`, `i18n` or `assets` | all |
| `--ui MODE`        | `rich` (a card) or `plain` (text)                                        | rich on a terminal  |
| `--help`           | Show the help                                                            |                     |

The values come from the environment your app would start in: the process environment first, then `.env.local`, `.env.<CRYSTAL_ENV>` and `.env`. To see another environment, set `CRYSTAL_ENV` for the command.

## Realistic output

{% code title="terminal: azu config --ui plain (abridged)" %}
```text
SERVER
  environment         development
  host                127.0.0.1
  port                4000
  loopback only       true
  port reuse          true
  container           false
  shutdown timeout    30s

TLS
  enabled             false
  mode                none

SECRETS
  CSRF_SECRET         set
  SESSION_SECRET      not set

DATABASE
  url                 sqlite3://./db/cfgapp_development.db
  lazy connect        true
  slow query          50.0ms
  n+1 threshold       3

LIMITS
  read timeout        30s
  write timeout       60s
  max connections     10000
```
{% endcode %}

*A new web project, run from its root. Host `127.0.0.1` means the app is only reachable from this machine, which is Azu's default outside production and containers. `SESSION_SECRET` is "not set" until you run `azu g auth` or `azu session:setup`.*

{% code title="terminal: PORT=8080 DATABASE_URL=postgres://admin:s3cr3t@db.internal:5432/app azu config --section database --format json" %}
```json
{
  "database": {
    "url": "postgres://admin:***@db.internal:5432/app",
    "driver": "-",
    "lazy connect": "true",
    "slow query": "50.0ms",
    "n+1 threshold": "3",
    "playground": "true"
  }
}
```
{% endcode %}

*The password is masked, whatever it was. Every value in the JSON is a string, as it was printed. Exit codes: `0` success, `1` the app could not be loaded or this isn't a project, `2` invalid usage.*

{% code title="terminal: azu config --section nope" %}
```text
ERROR: Unknown section 'nope': use server, tls, templates, errors, session, secrets, database, limits, uploads, websocket, i18n, assets
```
{% endcode %}

*The error lists the sections the app reported; the exit code is 2.*

## Do's and don'ts

{% hint style="info" %}
**Pro tip:** `azu config --format json | jq '.limits'` gives one section for a script or a bug report. The output is safe to paste: secrets are masked or reported only as set.
{% endhint %}

{% hint style="success" %}
Run `azu config` and `azu doctor` together when a deploy misbehaves: `doctor` says what's wrong with the environment, `config` shows what the app ends up using.
{% endhint %}

{% hint style="warning" %}
The first run takes about as long as a build, because it compiles the app. It also runs your project's top-level code (initializers, `.env` loading, database connections); only the server start is skipped.
{% endhint %}

{% hint style="danger" %}
Don't point it at production. Loading the app there connects to the real database and runs real initializers. Use a copy of the production environment variables with a test database instead.
{% endhint %}

<details>

<summary>What it does not show</summary>

It shows Azu's settings, not your own constants or the values you read yourself with `ENV[...]`. The handlers list is built when the server starts, so it isn't included. `CSRF_SECRET` and `SESSION_SECRET` are reported as set or not set and never printed. The CLI's own variables (`AZU_DEBUG`, `AZU_UI`, ...) are in [Configuration](../advanced/configuration.md).

If the app can't be loaded, the last lines of the compiler's output are shown. A scratch file `tmp_config_*.cr` is deleted when the command ends, also on Ctrl-C; after a crash delete it by hand. Generated projects git-ignore it.

</details>
