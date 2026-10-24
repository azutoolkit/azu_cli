# Authentication Generator

Generates sign up, sign in, sign out and a protected page for a **web** project. The signed-in user lives in an
encrypted session cookie (the [`session`](https://github.com/azutoolkit/session) shard), passwords are stored as
bcrypt digests (`Crypto::Bcrypt`, no extra shard).

```bash
azu generate auth
azu db:migrate          # creates the users table
# SESSION_SECRET is already in the git-ignored .env, which the app loads at boot
azu serve
```

API projects have no generated authentication yet (no JWT or OAuth), and `--strategy` only accepts `session`.

## What it generates

| Route            | Constant                          | File                                   |
| ---------------- | --------------------------------- | -------------------------------------- |
| `GET /register`  | `Blog::Registrations::NewEndpoint`    | `src/endpoints/registrations/new_endpoint.cr` |
| `POST /register` | `Blog::Registrations::CreateEndpoint` | `src/endpoints/registrations/create_endpoint.cr` |
| `GET /login`     | `Blog::Sessions::NewEndpoint`     | `src/endpoints/sessions/new_endpoint.cr` |
| `POST /login`    | `Blog::Sessions::CreateEndpoint`  | `src/endpoints/sessions/create_endpoint.cr` |
| `DELETE /logout` | `Blog::Sessions::DestroyEndpoint` | `src/endpoints/sessions/destroy_endpoint.cr` |
| `GET /account`   | `Blog::Account::ShowEndpoint`     | `src/endpoints/account/show_endpoint.cr` (needs a signed-in user) |

Also: the `User` model and its migration (`email` unique, `password_digest`), `src/initializers/session.cr`
(`UserSession`, the cookie store), `src/middleware/authentication.cr` (`current_user`, `authenticate`),
requests, pages and Jinja templates under `public/templates/<app>/`. The generator adds
`Session::SessionHandler(UserSession)` to `Blog.handlers` and a random `SESSION_SECRET` to `.env`.

## Behaviour

- Forms carry the CSRF field; writes redirect with `303`; a failed sign in redirects back to `/login` with a flash message.
- Signing in gives the session a new id (no session fixation); signing out discards it.
- The email is stripped and downcased; an unknown email costs the same bcrypt check as a wrong password.
- Visiting `/account` signed out answers `303` to `/login`. To protect another page, `include Authentication` in its endpoint and do the same with `current_user`.
- `SESSION_SECRET` comes from the environment or the git-ignored `.env` (`Azu::Env.secret`); development falls back to a random key per process, production
  (`CRYSTAL_ENV=production`) refuses to boot without it.

- Passwords are limited to 72 bytes (bcrypt's limit; a multi-byte character counts for each of its bytes). The contracts answer `422` for longer ones instead of failing.
- The session cookie is `Secure`, `HttpOnly` and `SameSite=Strict` (the session shard sets these) and expires after
  `config.timeout` (8 hours). It is a cookie store: signing out clears the browser's cookie, but a copy of it stays
  valid until it expires. For server-side revocation shorten the timeout or switch to `Session::RedisStore`.
- Registration looks the email up, then inserts; two simultaneous sign-ups for one email end in one account and one "email taken" answer. The "email taken" answer does reveal which emails are registered.

## Running it again, and other generators

`azu generate auth` refuses to run when a `User` model, `src/initializers/session.cr`, the session/registration/account
endpoints or a `create_users` migration exist already (a scaffold named `User` counts), and when the app file has no
`Azu::Handler::RequestId.new,` line to put the session handler after. Remove what it names, or add the handler by hand.
Do not combine it with `azu session:setup`: both define the session initializer and handler.

## Brute force

Nothing throttles sign-in attempts, and each attempt costs a bcrypt check. Put a limit in front of `/login` and `/register`
(a reverse proxy, or `Azu::Handler::Throttle` once it fits your traffic: it counts every request per client, not only failures).

## Not generated

JWT or OAuth (Authly), roles and permissions, password reset, email confirmation.
