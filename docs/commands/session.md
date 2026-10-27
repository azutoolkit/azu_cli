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

The backend is `--backend`, or the store `src/initializers/session.cr` sets, or `SESSION_BACKEND` when the file sets
none. The command deletes data on that answer, so it reads the file strictly: a store counts only as
`Session.use_store(Session::<Store>(UserSession))` or `config.store = Session::<Store>(UserSession).new(...)` (the
forms `azu session:setup` and `azu generate auth` write, over several lines too) at the top level or in a `do` block,
and comments, strings, heredocs and other literals do not count. It refuses (exit code 1), whatever `SESSION_BACKEND`
says, when the stores in the file differ, when anything else sets a store (`config.store ||=`, a store that is not
`Session::...`, one behind an `if` or in a `def`, ...) or when it cannot read the file; pass `--backend` then. When
nothing says which backend, it refuses too. An unknown backend or option, or an argument, is refused with exit code 2; `-h` /
`--help` shows the help.

- Redis: deletes every `session:*` key (the keys the session shard's `RedisStore` writes) in the database of
  `REDIS_URL` (default `redis://localhost:6379`), with `SCAN`, never `KEYS`. The prefix is not per app: an app
  sharing that Redis database loses its sessions too. Before deleting, with or without `--force`, it prints the
  target as `redis://host:port/database` (never the user or password in `REDIS_URL`) and says so. A `REDIS_URL` that is
  not `redis[s]://[[user]:password@]host[:port][/database]` (an IPv6 host in brackets, an `@` in the password as `%40`)
  is refused (exit code 1); a database the server does not have (16 by default, 0 to 15) fails before deleting anything.
- Cookie sessions live in the browsers, so the command cannot clear them and says so (exit code 1) without asking:
  change `SESSION_SECRET` and restart, and every existing cookie stops working.
- Memory sessions live in the app process: the command says so (exit code 1); restart the app to end them.

## Environment variables

| Variable         | Used for                                           |
| ---------------- | -------------------------------------------------- |
| `SESSION_SECRET` | Encrypts and signs sessions; required in production |
| `REDIS_URL`      | The Redis backend                                  |
