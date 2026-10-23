# Authentication Generator

Generates sign up, sign in, sign out and a protected page for a **web** project. The signed-in user lives in an
encrypted session cookie (the [`session`](https://github.com/azutoolkit/session) shard), passwords are stored as
bcrypt digests (`Crypto::Bcrypt`, no extra shard).

```bash
azu generate auth
azu db:migrate          # creates the users table
export SESSION_SECRET=... # the generated .env lists one; nothing loads .env for you
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
- `SESSION_SECRET` comes from the environment; development falls back to a random key per process, production
  (`CRYSTAL_ENV=production`) refuses to boot without it.

## Not generated

JWT or OAuth (Authly), roles and permissions, password reset, email confirmation.
