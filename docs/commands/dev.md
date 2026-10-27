# azu dev

Runs the app and keeps it current while you edit: it rebuilds (`shards build <target>`, **not** a release build) and
restarts the app when the code changes.

```bash
azu dev [--port PORT] [--host HOST] [--env NAME] [--debounce MS] [--interval MS] [--ui rich|plain]
```

## The dashboard

On a terminal of at least 60x16 (and not in CI) `azu dev` opens a full-screen dashboard; `--ui plain` (or `AZU_UI=plain`)
keeps the line output described below.

| Panel    | Shows                                                                                                   |
| -------- | ------------------------------------------------------------------------------------------------------- |
| Build    | The compiler's stage while it builds (`crystal build --progress`, passed through `shards build`), the build time, the last builds, the changed files |
| App      | pid, uptime, restarts, crashes, resident memory with its trend, the GC heap                             |
| Requests | Rate, p50/p95, 4xx/5xx and the last requests, from the app                                               |
| SQL      | Query count, average, slow queries, the connection pool, N+1 alerts with the endpoint and caller, the slowest statements, from the app |
| Jobs     | Pending, busy and failed jobs per queue of `config/jobs.yml`, read from `REDIS_URL`                      |
| Log      | The app's stdout and stderr (the dashboard reads them through pipes)                                     |

A failed build covers the dashboard with the error location and the compiler's excerpt while the previous build keeps
serving; Esc goes back. Keys: `1`-`7` panels, `r` rebuild now, `l` log, `c` clear the log, `q` or Ctrl-C quit. Quitting
prints a one-line summary of the session.

Requests and SQL come from the app: `azu dev` listens on a Unix socket (mode 0600) and passes its path to the app as
`AZU_TELEMETRY_SOCKET`; an app that requires `azu/dev` and runs in development writes one JSON snapshot per second
(azu's `Dev::Telemetry`, from the same performance monitor and query store as `/dev-dashboard`; requests need
`PERFORMANCE_MONITORING=true`; azu 0.10.1 and newer, which projects generated now pin). With an older azu the two
panels say what they need.

## What happens on a change

Files are polled (modification time and size) every `--interval` ms (about three system calls per watched file each time, so a very large `src/` or `public/templates` tree costs CPU: raise `--interval`; symlinked directories are not followed); there is no file system event watcher and no new
dependency. Changes are collected until the files have been quiet for `--debounce` ms, so saving several files, or switching
branches, costs one rebuild.

| Changed                                      | Action                                                                                           |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `src/**`, `config/**`, `shard.yml`, `shard.lock` | Build, then restart the app. A **failed build prints the compiler's output and keeps the previous app running**; save a fix to build again |
| `public/templates/**`                        | **No build and no restart.** Templates are read from disk, and the running app reloads them when template hot reload is on (the default in `development`; `TEMPLATE_HOT_RELOAD=false` turns it off, then restart `azu dev`). Whether a given Azu release reloads them is Azu's behaviour, not something `azu dev` can change |
| `.env`, `.env.local`, `.env.<env>`           | Restart without a build (the app reads them at boot)                                              |
| anything else (`public/assets/**`, `spec/**`, `lib/**`, `bin/**`, editor swap files) | Ignored                                                                |

The first build runs at startup; if it fails the command keeps watching and starts the app after the next good build. The
app's own output goes to your terminal as it writes it; the compiler's output is streamed as it is produced.

Ctrl-C and SIGTERM stop the app (SIGTERM, then SIGKILL after 5 s) and then the command.

A build is "incremental" only in the sense that Crystal caches the code it generates for unchanged modules in a debug
(non-release) build; the compiler still analyses the whole program each time, so a build takes seconds to a minute, not milliseconds.

## Options

| Option            | Description                                                                            |
| ----------------- | -------------------------------------------------------------------------------------- |
| `--port PORT`     | `PORT` for the app. Without it the app keeps what your environment / `.env` say (else its own 4000) |
| `--host HOST`     | `HOST` for the app (same rule)                                                          |
| `--env NAME`      | `CRYSTAL_ENV` for the app (same rule)                                                   |
| `--debounce MS`   | Quiet time before a change is acted on (default 300)                                    |
| `--interval MS`   | Polling interval (default 250)                                                          |
| `--ui MODE`       | `rich` (the dashboard) or `plain` (lines)                                               |
| `--help`          | Show the help                                                                           |

## `azu dev` or `azu serve`

[`azu serve`](serve.md) is the older command: it builds with `--production` (a release build, slow) and also rebuilds for
template changes. Prefer `azu dev` while developing.

## Exit codes

`0` stopped by Ctrl-C or SIGTERM, `1` not an Azu project, `2` invalid usage.

## Manual checklist

The end-to-end script (`scripts/e2e_generated_app.sh`) drives all of this against a generated project: start, template
change (no build), broken source (old app keeps serving), fixed source (restart with the new code), SIGTERM (app gone).

Stopping: Ctrl-C and SIGTERM end a build in progress (and the compiler it started; `pgrep` or `/proc` finds it) and the app, and no app is started after that. SIGKILL of `azu dev` cannot be handled: the app keeps running and holding its port until you end it.

On shutdown the compiler's partial output that was already printed stays on the terminal; only the "build failed" message is suppressed. `SIGTERM` is not followed by `SIGKILL`: a build that traps `SIGTERM` keeps running.

## Commands panel (the control plane)

Panel `2` runs the CLI's own commands for you and keeps their last outcome. Each one runs as `azu <command>` with
plain output, one at a time, and never while the app builds (they compile too):

| Command           | Runs                                                              |
| ----------------- | ----------------------------------------------------------------- |
| `doctor`          | at start and when `.env*`, `shard.yml`/`shard.lock` or the CLI config changes |
| `config:validate` | same as `doctor`                                                   |
| `routes`          | after each successful build                                       |
| `test`            | on Enter; `w` also runs it after each build                       |
| `db:status`       | at start and when `src/db/migrations` changes                     |
| `db:migrate`      | on Enter, then `y` (it changes the database); `db:status` runs after it |
| `session:clear`   | on Enter, then `y` (`--force`: the dashboard asked already)       |
| `config:show`, `config:env --list`, `version` | at start (and on config changes) |
| `completion <shell>` | on Enter, for the shell in `SHELL` (bash when it is another)   |

The list shows each command's mark (`✔` ok, `▲` needs a look, `✖` failed), a one-line outcome and its age; the card
beside it shows the selected command's output and when it runs. Keys: `↑`/`↓` select, Enter run, `a` run every check
again (not the tests, not the commands that change things). The overview sums the commands up in one line. Run from
the dashboard (`AZU_CONTROL=1`), `doctor` counts the port the app holds as expected, not as a warning.

## Console panel

Panel `3` is a console with the app loaded, like `rails console`. Type Crystal; Enter runs it when the code is
finished (an open `def`, `do`, bracket or string gets a new line instead, and `end` dedents itself), Alt-Enter adds a
line, `↑`/`↓` walk the history (kept per project in `$XDG_STATE_HOME/azu/`), Ctrl-L clears, Esc cancels a run or gives
the keyboard back to the panels (Enter takes it again).

```text
demo_app(dev)> post = Post.last
=> #<Post @id=2, @title="Hello", ...>
▸ post kept for the next snippets
demo_app(dev)> post.try(&.title)
=> "Hello"  11.0s
demo_app(dev)> def titles(n = 3)
          ...>   Post.all.first(n).map(&.title)
          ...> end
✔ declared: kept for the next snippets
demo_app(dev)> titles(5)
=> ["Hello", "World"]
```

How it runs: each snippet is compiled with the app (`crystal run --progress` of `.azu_console.cr` in the project
root, removed after the run; one file name, so later runs reuse the app's object files). After the app's first build
the console compiles the app once in the background (the title says `warming up`, then `ready`), so the first snippet
does not pay for a cold compile. A run shows the compiler's progress. Snippets typed while one compiles wait (`waits:
runs with the next compile`) and all go into the next compile, each answering its own `=> value`; one that fails to
compile or crashes fails alone and the others run again. While the console compiles, the Commands panel holds its
next command. Expect 10 to 20 s a run for a mid-size app on a 4-core machine: Crystal type-checks and generates the
whole program for every compile, and has no incremental mode. An expression answers `=> value` (its `inspect`); what it prints comes
before. Declarations (`def`, `class`, `module`, `struct`, `macro`, ...) are kept and come before every later snippet.
A local assignment (`post = Post.first`) is kept too and runs again before each snippet, so its locals carry over;
one that would write if run again (`create`, `save`, `update`, `delete`, `destroy`, a `!` method, ...) is not kept,
and the transcript says so. `locals` and `declarations` list what is kept, `forget` drops it, `help` explains, `exit`
leaves the console. Snippets run against the database `DATABASE_URL` points at.

With a Crystal that has the interpreter (`crystal i --help` works; Homebrew and the crystal-lang.org packages have it,
the official Docker images and Linux tarballs do not), Ctrl-O (or `i` when the panels have the keyboard) leaves the
terminal to `crystal i` with the app and your declarations loaded, and `exit` brings the dashboard back. Crystal
1.22.1's interpreter cannot load an Azu app yet: it stops with a compiler bug in Crinja (azu's templates: "doesn't
implement instance_vars") and another in CQL's PostgreSQL session ("has no type"). Its REPL answers in a fraction of
a second, so the console will use it once those are fixed.
