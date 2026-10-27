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
| `--force`          | `-f`  | Overwrite an existing initializer        | `false`  |

Any other backend is refused with exit code 2 (the session shard has no database store).

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

After a sign-in, call `Session.session.authenticate { |session| session.user_id = user.id }`: it gives the
session a new id, so an id planted before the sign-in is worthless.

Do not combine it with `azu generate auth`: both write `src/initializers/session.cr`.

## `azu session:clear`

```bash
azu session:clear            # asks first
azu session:clear --force
```

The backend is read from `src/initializers/session.cr` (or `--backend`). Memory sessions end when the app restarts.
Cookie sessions live in the browsers, so the command cannot clear them: change `SESSION_SECRET` and restart, and
every existing cookie stops working.

## Environment variables

| Variable         | Used for                                           |
| ---------------- | -------------------------------------------------- |
| `SESSION_SECRET` | Encrypts and signs sessions; required in production |
| `REDIS_URL`      | The Redis backend                                  |
