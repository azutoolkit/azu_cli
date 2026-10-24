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

## Brute force: throttling

Sign-in and sign-up are throttled by `Blog::AuthThrottle` (`src/services/auth_throttle.cr`, with a spec in
`spec/services/auth_throttle_spec.cr`): a fixed-window counter per key, in memory. An attempt over the limit answers
**429** with a **`Retry-After`** header (seconds) and is not processed. Defaults, per window of 60 seconds:

| Setting                     | Default | Key                                                           |
| --------------------------- | ------- | ------------------------------------------------------------- |
| `AUTH_THROTTLE_LOGIN`       | 5       | client address and email (sign-in)                            |
| `AUTH_THROTTLE_ADDRESS`     | 20      | client address, any email (sign-in), against one address trying many accounts |
| `AUTH_THROTTLE_REGISTER`    | 5       | client address (sign-up)                                      |
| `AUTH_THROTTLE_WINDOW`      | 60      | seconds in a window                                           |
| `AUTH_THROTTLE_TRUST_PROXY` | unset   | `true`: the client address is the last `X-Forwarded-For` entry (exactly one trusted hop) |

- Attempts are counted before the password is checked, so a right and a wrong password cost the same; requests that fail
  validation (`422`) or the CSRF check (`403`) never reach the endpoint and are not counted.
- There is no counter per email alone: one would let anyone lock a known account out by failing sign-ins for it from
  their own address. Each source address has its own budget per account (`AUTH_THROTTLE_LOGIN`) and an overall
  budget for trying many accounts (`AUTH_THROTTLE_ADDRESS`). Guessing spread over many addresses is not stopped by
  this; use a shared store, a CAPTCHA or an account lock the owner can clear.
- At most 10,000 counters are kept (an attacker can invent keys): expired ones go first, then the oldest, so memory
  and the time per attempt stay bounded.
- The counters live in the process: several processes or hosts each allow the limit, and a restart forgets them. Count
  in a shared store (Redis) when that matters.
- The client address is the peer of the connection. Behind a reverse proxy that is the proxy's address, so every client
  shares the sign-up limit and only the email part of the sign-in key tells users apart; set
  `AUTH_THROTTLE_TRUST_PROXY=true` only when exactly one proxy you run sits in front of the app and appends the real
  address to `X-Forwarded-For`: the last entry is used, so a second proxy hop would make every client share the proxy's
  address (the header is client-controlled otherwise).
- It is generated code rather than `Azu::Handler::Throttle` because that handler keys by client address only, counts every
  request on every path, and blocks the address for its whole `duration` once over the threshold; a per-account,
  per-path limit needs a key the handler cannot see.

## Not generated

JWT or OAuth (Authly), roles and permissions, password reset, email confirmation.
