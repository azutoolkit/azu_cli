# Session Commands

Give your app sessions in one command. `azu session:setup` writes a typed `UserSession` backed by the
[session shard](https://github.com/azutoolkit/session), mounts its handler and puts a random `SESSION_SECRET`
in your git-ignored `.env`. Signed-in users? Use `azu generate auth` instead: it sets up the same session for you.

## `azu session:setup`

```bash
azu session:setup                    # encrypted cookie sessions (default)
azu session:setup --backend redis    # sessions in Redis (REDIS_URL, default redis://localhost:6379)
azu session:setup --backend memory   # in-process, one instance only (development)
```

| Option             | Short | Description                              | Default  |
| ------------------ | ----- | ---------------------------------------- | -------- |
| `--backend <type>` | `-b`  | `cookie`, `redis` or `memory`            | `cookie` |
| `--force`          | `-f`  | Replace an existing initializer          | `false`  |

Any other backend, an unknown option, an argument or a `--backend` without a value is refused with exit code 2
(the session shard has no database store). `-h` / `--help` shows the help and changes nothing.

It refuses (exit code 1, nothing written) when:

- `src/initializers/session.cr` exists: run again with `--force` to replace it (what you added to `UserSession` is lost);
- authentication is generated (`src/endpoints/sessions` or `src/services/auth_throttle.cr` exists), even with
  `--force` and even when its initializer was deleted: sign-in needs the `UserSession` of `azu generate auth`
  (`user_id`, `authenticated?`). To change its store, edit `config.store` in `src/initializers/session.cr`;
- `src/initializers/session.cr` looks like it was written by `azu generate auth` (its marker line, or a
  `def authenticated?`), even with `--force`. To change its store, edit `config.store`; to have `session:setup`
  write a new one, delete the file and run it again;
- `src/<project>.cr` is missing, or has no `Azu::Handler::RequestId.new,` line to put the session handler after:
  add `Session::SessionHandler(UserSession).new(Session.session),` to its handlers yourself.

What it does:

- writes `src/initializers/session.cr`: `UserSession < Session::Base`, the store, a 24-hour timeout, and
  `config.secret = Azu::Env.secret("SESSION_SECRET")` (random per process in development, required in production);
- adds `Session::SessionHandler(UserSession).new(Session.session),` after `Azu::Handler::RequestId.new,` in
  `src/<project>.cr`;
- appends `SESSION_SECRET=<random>` to `.env` (mode 0600) unless it is there.

Then add what you keep to the session and use it in an endpoint:

```crystal
class UserSession < Session::Base
  property user_id : Int64? = nil
end

Session.session.current_session.user_id = user.id
Session.session.flash["notice"] = "Welcome back"
```

After a sign-in, set the user and call `Session.session.regenerate_id`: it gives the session a new id, so an id
planted before the sign-in is worthless (session fixation). This is what the generated authentication does:

```crystal
Session.session.current_session.user_id = user.id
Session.session.regenerate_id
```

Do not combine it with `azu generate auth`: both write `src/initializers/session.cr`, so `azu generate auth` refuses
once `session:setup` has run, and `session:setup` refuses once authentication is generated.

## `azu session:clear`

```bash
azu session:clear                    # asks first
azu session:clear --force
azu session:clear --backend redis    # instead of reading src/initializers/session.cr
```

| Option             | Short | Description                                         |
| ------------------ | ----- | --------------------------------------------------- |
| `--backend <type>` | `-b`  | `cookie`, `redis` or `memory`                       |
| `--force`          | `-f`  | Do not ask first                                    |

The backend is `--backend`. Without it, the command infers the backend only when `src/initializers/session.cr` is,
as written, a file the generators write for this project: what `azu session:setup --backend cookie|redis|memory`
writes (its session key holds the project name from `shard.yml`) or what `azu generate auth` writes (cookie, with or
without its first marker line). The comparison is exact, apart from CRLF line ends and whitespace or blank lines at the
end of the file. Any other file (a comment added, a store changed, a guard, a file from another azu_cli version)
makes it refuse with exit code 1 and ask for `--backend`, whatever `SESSION_BACKEND` says: the command deletes data on
this answer, so it does not guess what edited code does. `SESSION_BACKEND` is used only when there is no
`src/initializers/session.cr`; with neither, it refuses too. An unknown backend or option, or an argument, is refused
with exit code 2; `-h` / `--help` shows the help.

- Redis: deletes every `session:*` key (the keys the session shard's `RedisStore` writes) in the database of
  `REDIS_URL` (default `redis://localhost:6379`), with `SCAN`, never `KEYS`. The prefix is not per app: an app
  sharing that Redis database loses its sessions too. Before deleting, with or without `--force`, it prints the
  target as `redis://host:port/database` (never the user or password in `REDIS_URL`) and says so. A `REDIS_URL` that is
  not `redis[s]://[[user]:password@]host[:port][/database]` (an IPv6 host in brackets, an `@` in the password as `%40`)
  is refused (exit code 1); a database the server does not have (16 by default, 0 to 15) fails before deleting anything.
  `user:password@` authenticates as that ACL user (`AUTH user password`, Redis 6+), `:password@` with the password only
  (`AUTH password`), and userinfo without a `:` sends no `AUTH`. It waits 5 seconds to connect (the TLS handshake of
  `rediss://` included) and 10 seconds for each reply, then stops with exit code 1 (for instance `rediss://` against a
  plain Redis port).
- Cookie sessions live in the browsers, so the command cannot clear them and says so (exit code 1) without asking:
  change `SESSION_SECRET` and restart, and every existing cookie stops working.
- Memory sessions live in the app process: the command says so (exit code 1); restart the app to end them.

## Environment variables

| Variable         | Used for                                           |
| ---------------- | -------------------------------------------------- |
| `SESSION_SECRET` | Encrypts and signs sessions; required in production |
| `REDIS_URL`      | The Redis backend                                  |
