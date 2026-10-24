# azu routes

Lists the routes of the application in the current directory.

```bash
azu routes [--format table|json] [--method METHOD] [--path TEXT]
```

The application's code is compiled and loaded (its server is **not** started) by a small script the command writes to
the project directory, runs with `crystal run` and deletes. The script prints `Azu::CONFIG.router.route_info`, plus the
`Request` and `Response` type arguments of every `Azu::Endpoint(Request, Response)` it finds at compile time. Because of
the compile, the first run takes about as long as a build.

**It runs your project's top-level code.** Requiring `src/<project name>.cr` executes everything that file loads at
require time: initializers, `.env` loading, database connections, anything with side effects. Only the server start
(`src/server.cr`) is skipped. Do not run it against a production environment. The scratch file
(`tmp_routes_<pid>.cr`) is created exclusively with a random name (`tmp_routes_<random>.cr`), is git-ignored in generated projects (add `/tmp_routes_*.cr` and `/.azu_console_*.cr` to the `.gitignore` of an existing project) and is deleted when the command ends, also on Ctrl-C or SIGTERM. After a crash or SIGKILL it can remain; delete it. `src/<project name>.cr` must exist (every generated web and api
project has it).

## Options

| Option              | Description                                                                                          |
| ------------------- | ---------------------------------------------------------------------------------------------------- |
| `--format FORMAT`   | `table` (default) or `json`                                                                          |
| `--method METHOD`   | Only routes of this HTTP method, any case. The `HEAD` and `OPTIONS` routes Azu adds for the routes you declare are hidden unless you ask for that method |
| `--path TEXT`       | Only routes whose path contains `TEXT`                                                               |
| `--help`            | Show the help                                                                                        |

With `--format json` stdout is only the JSON array (`method`, `path`, `endpoint`, `request`, `response`); the CLI adds no log lines.

## Output

```text
METHOD  PATH             ENDPOINT                        REQUEST                        RESPONSE                  HELPERS
GET     /                Blog::Welcome::IndexEndpoint    Blog::Welcome::IndexRequest    Blog::Welcome::IndexPage  link_to_get_welcome_index
GET     /posts           Blog::Posts::IndexEndpoint      Blog::Posts::IndexRequest      Blog::Posts::IndexPage    link_to_get_posts_index
POST    /posts           Blog::Posts::CreateEndpoint     Blog::Posts::CreateRequest     Azu::Response::Empty      link_to_post_posts_create, form_for_post_posts_create
DELETE  /posts/:id       Blog::Posts::DestroyEndpoint    Blog::Posts::DestroyRequest    Azu::Response::Empty      link_to_delete_posts_destroy, form_for_delete_posts_destroy, button_to_delete_posts_destroy
```

`HELPERS` are the template helpers Azu registers for an endpoint, named from the last two segments of its class
(`link_to_<verb>_<resource>`, `form_for_<verb>_<resource>` for writes, `button_to_delete_<resource>`). They are derived
from the class name by the same rule as Azu's `Endpoint` macro, not read from the registry. Routes that are not endpoints
(WebSocket channels, `Azu::Handler::Static`) show `-` for the types and helpers.

## Exit codes

`0` success, `1` the app could not be loaded (the compiler's last lines are shown) or this is not a project, `2` invalid usage.
