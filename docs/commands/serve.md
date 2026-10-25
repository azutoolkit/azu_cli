# azu serve

Compiles the project and runs it, rebuilding and restarting when source files change. Aliases: `azu server`, `azu s`.

```bash
azu serve [options]
```

## Options

| Option                  | Description                           | Default     |
| ----------------------- | ------------------------------------- | ----------- |
| `--port <port>`, `-p`   | Port the app listens on (`PORT`)      | 4000        |
| `--host <host>`, `-h`   | Host the app binds to (`HOST`), only passed when given | app default |
| `--env <env>`, `-e`     | Environment (`CRYSTAL_ENV`, `AZU_ENV`) | development |
| `--no-watch`            | Compile and run once, no file watching |            |
| `--verbose`, `-v`       | Show the app's output and every changed file |      |

## What it does

1. runs `shards build --production` in the current directory (the first target of `shard.yml` is the binary);
2. starts `./bin/<target>` with `PORT`, `CRYSTAL_ENV` and `AZU_ENV` set, and `HOST` only when you gave `--host` or exported it (otherwise azu binds `127.0.0.1` in development and `0.0.0.0` elsewhere);
3. unless `--no-watch`, polls the source files every 0.5 s; on a change it rebuilds and restarts. A failed build
   prints the compiler output and keeps the previous server running.

Stop it with Ctrl+C.

## Examples

```bash
azu serve
azu serve --port 8080 --host 0.0.0.0
azu serve --env test --no-watch
```

## Notes

- Azu reads `CRYSTAL_ENV` only. In `development` the generated app mounts the development dashboard and performance
  monitor (`dev_handlers` in the app file); any other environment does not.
- There are no `--workers`, `--ssl`, `--debug` or resource-limit options. For a production run build the binary
  yourself or use the generated `Dockerfile` (`azu new --docker`).
