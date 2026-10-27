---
description: The wizard, cards, dashboard and live preview, and how to switch every one of them to plain text or JSON.
---

# Terminal UI

Every azu command that draws something has two other forms: plain lines and JSON. The rich form needs a color terminal; pipes, CI and `NO_COLOR` get the plain one automatically.

## Overview & visual demo

{% tabs %}
{% tab title="Wizard" %}
<figure><img src="../assets/terminal-ui/02-new-wizard-extras.png" alt="The extras step of the azu new wizard"><figcaption><p>Step 9 of 9: Space toggles Docker, GitHub Actions, Git and the example code. The right side keeps your answers.</p></figcaption></figure>
{% endtab %}

{% tab title="Spinner and progress" %}
<figure><img src="../assets/terminal-ui/04-new-progress.png" alt="A progress card with a spinner on the shards step"><figcaption><p>Done steps show ✔ and their time; the running step shows a spinner, a live timer and the last output line.</p></figcaption></figure>
{% endtab %}

{% tab title="Dashboard" %}
<figure><img src="../assets/terminal-ui/07-dev-dashboard.png" alt="The azu dev dashboard"><figcaption><p>Full-screen dashboard with five panels, switched by the number keys.</p></figcaption></figure>
{% endtab %}

{% tab title="Preview" %}
<figure><img src="../assets/terminal-ui/11-generate-preview.png" alt="The azu generate file browser with a diff"><figcaption><p>A file browser on the left, a diff on the right, a type-check result under them.</p></figcaption></figure>
{% endtab %}
{% endtabs %}

```mermaid
flowchart LR
  C["Command"] --> R["UI::Reporter"]
  R --> RICH["rich: cards, live frames"]
  R --> PLAIN["plain: lines"]
  R --> JSON["json: NDJSON events"]
  T["--ui flag, AZU_UI, terminal, CI"] --> R
```

## Quickstart & command syntax

```bash
azu doctor --ui plain
AZU_UI=json azu new blog --yes     # NDJSON events, for an editor or CI
NO_COLOR=1 azu routes              # glyphs stay, color goes
```

How the mode is chosen:

| Setting                   | Effect                                                              |
| ------------------------- | ------------------------------------------------------------------- |
| `--ui rich\|plain\|json`  | Per command                                                         |
| `AZU_UI=...`              | The same, for the session                                           |
| (neither)                 | `rich` on a terminal with color, outside CI; otherwise `plain`      |
| `NO_COLOR`                | Drops the color, keeps the glyphs. Wins over everything             |
| `FORCE_COLOR`             | Keeps color on a pipe                                               |

Keys:

| Screen                         | Command                          | Keys                                                                                  |
| ------------------------------ | -------------------------------- | ------------------------------------------------------------------------------------- |
| Wizard, review, progress       | `azu new`                        | arrows or `j`/`k` move, Space toggles, Enter continues, Shift-Tab back, Esc cancels   |
| Dashboard                      | `azu dev`                        | `1`-`5` panels, `r` rebuild, `l` log, `c` clear log, `q` quit                         |
| File browser and diff          | `azu generate`                   | Up/Down file, Enter writes, Esc cancels                                               |
| Cards (not interactive)        | `doctor`, `routes`, `version`, `db:*` | none                                                                             |

## Realistic output

<figure><img src="../assets/terminal-ui/14-doctor.png" alt="azu doctor card with nine checks"><figcaption><p><code>azu doctor</code> as a card: ✔ ok, ▲ warning, ✖ failure. The border turns amber or red when something is off.</p></figcaption></figure>

<figure><img src="../assets/terminal-ui/09-dev-build-failed.png" alt="azu dev showing a failed build"><figcaption><p>A failed build covers the dashboard with the error location. The previous build keeps serving; Esc goes back, <code>r</code> retries.</p></figcaption></figure>

<figure><img src="../assets/terminal-ui/13-undo.png" alt="azu undo listing deleted and restored files"><figcaption><p><code>azu undo</code>: every created file deleted, <code>src/db/schema.cr</code> restored.</p></figcaption></figure>

The same `doctor` result in plain mode:

{% code title="terminal: azu doctor --ui plain" %}
```text
ok    crystal        Crystal 1.22.1 (the project needs 1.22.1 or newer)
warn  database       SQLite file ./db/blog_development.db does not exist yet
                     hint: run 'azu db:setup'

8 ok, 1 warnings, 0 failures
```
{% endcode %}

*A warning prints its hint on the next line. Exit code stays 0; a failed check exits 1.*

## Do's and don'ts

{% hint style="info" %}
**Pro tip:** `--yes` and pipes never need a terminal, so scripts can call any command safely.
{% endhint %}

{% hint style="success" %}
Prefer `--ui plain` or `--format json` in scripts. They keep stdout for data and are stable across terminals.
{% endhint %}

{% hint style="warning" %}
Inline screens keep your terminal background. Only the full-screen dashboard paints one.
{% endhint %}

{% hint style="danger" %}
Don't parse the rich output. It uses box characters and colors that change between terminals. Use `--ui json` or `--format json`.
{% endhint %}
