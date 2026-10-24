# azu doctor

Diagnoses the environment the project runs in. Nothing is changed and no value of a variable and no password of a URL is printed.

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
| `port`         | `PORT` (default 4000) is a valid port and free. In use is a warning, since the app may be running; so is a port below 1024 the user may not bind (reported as such, not as in use)                                          |
| `docker`       | docker is installed. Only a warning when the project has a `Dockerfile`                                                                    |
| `gitignore`    | `.env`, if present, is git-ignored and not tracked (`git check-ignore`, falling back to `.gitignore`)                                      |

The variables come from the environment `azu` runs in, which includes the project's `.env` files. With
`CRYSTAL_ENV=production` the `env` and `secrets` problems are failures instead of warnings.

## Output

```text
ok    crystal        Crystal 1.19.1 (the project needs 1.19.1 or newer)
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
