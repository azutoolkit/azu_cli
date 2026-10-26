# azu doctor

Diagnoses the environment the project runs in. Nothing is changed and no value of a variable and no password of a URL is printed. A `DATABASE_URL` is cut at its last `@` before the first `?` or `#`; when an `@` follows a `?` or `#` the host cannot be told from a piece of the password, so the check only warns (no host printed). The same goes for a URL without `@` whose `:` is not followed by a valid port (`postgres://user:secret`, `postgres://user:12345678`), which could be a user and password that lost their `@`; a port after the `@` that is not 1-65535 fails without being printed. Only `postgres://user:1234` (digits that are a valid port) reads as host `user`, which is what a URL parser would also do and asks you to percent-encode `@ ? # /` in the user and password. Write `crystal:` in shard.yml as a quoted string (`'>= 1.10'`): an unquoted `1.10` is read by YAML as the number 1.1.

```bash
azu doctor [--json]
```

| Check          | What it verifies                                                                                                                          |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `crystal`      | Crystal is installed and not older than the first version in the `crystal:` line of `shard.yml` (fail otherwise)                          |
| `shards`       | `shards` is installed                                                                                                                     |
| `dependencies` | `shards check` passes (installed shards match `shard.yml` and `shard.lock`: fail otherwise); a missing `shard.lock` is a warning           |
| `database`     | `DATABASE_URL` (or `AZU_DATABASE_URL`): a SQLite file is writable (a file that does not exist yet is a warning, a missing directory a failure); a PostgreSQL or MySQL host accepts a TCP connection within 3 s (credentials are not tried; IPv6 literals work; the output shows scheme, host, port and the database name only; a unix-socket URL such as `postgres:///db?host=/var/run/postgresql` is a warning, not tested). Unset: a warning in a project that uses CQL |
| `env`          | Every variable `.env.example` declares without a value is set (`SESSION_SECRET` only when the project has `src/initializers/session.cr`). Names only |
| `secrets`      | `CSRF_SECRET` and `SESSION_SECRET`, when set, are at least 32 characters and not a placeholder (`changeme`, `secret`, ...); no `secret = "literal"` in `src/` |
| `port`         | `PORT` (default 4000) is a valid port and free. In use is a warning, since the app may be running; so is a port below 1024 the user may not bind (reported as such, not as in use). The check binds `0.0.0.0` and releases it at once; on macOS a port held only on `127.0.0.1` or `::1` can show as free. The URL in the output never shows the user or password, nor anything before the last `@`; `--json` counts are `ok`/`warn`/`fail`, the text summary says warnings/failures                                          |
| `docker`       | docker is installed. Only a warning when the project has a `Dockerfile`                                                                    |
| `gitignore`    | `.env`, if present, is git-ignored and not tracked (`git check-ignore`, falling back to `.gitignore`)                                      |

The variables come from the environment `azu` runs in, which includes the project's `.env` files. With
`CRYSTAL_ENV=production` the `env` and `secrets` problems are failures instead of warnings.

## Output

```text
ok    crystal        Crystal 1.22.1 (the project needs 1.22.1 or newer)
ok    shards         Shards 0.19.1
ok    dependencies   installed and in sync with shard.lock
warn  database       SQLite file ./db/blog_development.db does not exist yet
                     hint: run 'azu db:setup'
...

8 ok, 1 warnings, 0 failures
```

`--json` prints `{"checks": [{"id", "status", "message", "hint"}], "summary": {"ok", "warn", "fail"}}`; `status` is
`ok`, `warn` or `fail`, `hint` is `null` for `ok`.

## Exit codes

`0` no check failed (warnings are allowed), `1` at least one check failed, `2` invalid usage.
