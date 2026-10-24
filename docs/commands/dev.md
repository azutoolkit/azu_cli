# azu dev

Runs the app and keeps it current while you edit: it rebuilds (`shards build <target>`, **not** a release build) and
restarts the app when the code changes.

```bash
azu dev [--port PORT] [--host HOST] [--env NAME] [--debounce MS] [--interval MS]
```

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
