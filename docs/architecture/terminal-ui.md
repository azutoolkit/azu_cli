# Terminal UI: the azu HUD

Status: **proposal**. Nothing on this page is implemented yet. It describes how `azu new`, `azu dev` and
`azu generate` would look and work, the Crystal engine needed to draw them, and five larger features the
engine makes possible. Each part says what the code does today and what has to be built.

The design has three goals:

1. **Show what is happening.** A build, a request, a query or a job shows up on screen as it happens,
   so you don't have to scroll back through logs to find it.
2. **Every screen is a plain command.** Each wizard answer maps to a flag, and every rich screen has a
   plain-text and a JSON form. CI, pipes, screen readers and `NO_COLOR` get the same information
   without the animation.
3. **Fast and small.** The engine uses only the standard library and a small `ioctl` binding. It writes
   one buffer per frame and draws nothing while nothing changes.

---

## 1. Design system

### 1.1 Color tokens

Code refers to colors by token, never by an escape code. Each token has a true-color value, a 256-color
value and a 16-color value. The engine picks one set when it starts (see 2.2).

| Token       | True color | 256 | 16           | Used for                                        |
| ----------- | ---------- | --- | ------------ | ----------------------------------------------- |
| `backplate` | `#0B0E14`  | 233 | (default bg) | HUD background (full-screen mode only)          |
| `text`      | `#C9D1D9`  | 252 | white        | Body text                                       |
| `muted`     | `#8B949E`  | 246 | bright black | Labels, timestamps, key hints                   |
| `faint`     | `#2A313C`  | 236 | bright black | Card borders, rules, the empty part of a gauge  |
| `cyan`      | `#22D3EE`  | 44  | cyan         | Focus, the selected item, live values, spinners |
| `purple`    | `#A78BFA`  | 141 | magenta      | Card titles, the brand ▲, the end of gradients  |
| `green`     | `#34D399`  | 42  | green        | ✔, success, healthy state                       |
| `amber`     | `#FBBF24`  | 214 | yellow       | ▲ warnings, slow queries, 4xx                   |
| `red`       | `#F87171`  | 203 | red          | ✖, build failures, 5xx, crashes                 |
| `blue`      | `#60A5FA`  | 75  | blue         | Links, paths, `GET`                             |

Gradients (the ▲ AZU wordmark, progress fills and sparklines) run from `cyan` to `purple`. In true color
each cell gets its own interpolated color, quantized to 16 steps so the style table stays small. With 256
colors there are 6 steps, and with 16 colors the gradient is plain `cyan`.

The full-screen HUD is the only screen that paints a background. Inline screens (the wizard, progress,
generate) keep the user's terminal background, because painting your own background over someone's theme
looks like a bug in a light theme.

### 1.2 Glyphs, and why none of them are wide

Box borders only line up if every glyph inside them is one column wide. Emoji and CJK characters are two
columns wide (East Asian Width W/F), so they are **not allowed inside a frame**. The `Text` widget
measures display width and truncates with `…`; it never cuts a character in half. Some glyphs below are
East Asian *Ambiguous* (●, ○, ▲, ◆). They are one column wide in Western locales. When `LANG` names a
CJK locale, or when `AZU_AMBIGUOUS_WIDE=1` is set, the engine switches to the ASCII set.

| Meaning               | Unicode                                | ASCII fallback (`TERM=dumb`, non-UTF-8 locale) |
| --------------------- | -------------------------------------- | ---------------------------------------------- |
| Done / failed         | `✔` / `✖`                              | `[ok]` / `[!!]`                                |
| Warning               | `▲`                                    | `/!\`                                          |
| Selected / unselected | `●` / `○`                              | `(*)` / `( )`                                  |
| Checkbox              | `[x]` / `[ ]`                          | `[x]` / `[ ]`                                  |
| In progress           | `◆`                                    | `>`                                            |
| Cursor / pointer      | `▸`                                    | `>`                                            |
| Gauge                 | `▮▯` (meters), `▰▱` (progress)         | `#-`                                           |
| Sparkline             | `▁▂▃▄▅▆▇█`                             | `_.-=*#`                                       |
| Spinner               | `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` (Braille, 80 ms per frame) | `- \ \| /`                                     |
| Frame                 | `╭─╮│╰╯`                               | `+-+\|++`                                      |

Emoji such as ⚡ and 🚀 can still appear in the plain reporter's one-line messages, where nothing has to
line up. They never appear in a frame.

### 1.3 Layout grammar

- **Cards** are the unit of layout. Each has a rounded `faint` border, a `purple` title in the top
  border, an optional right-hand badge (`2.4s`, `✔`) and one column of padding. Two cards side by side
  share no border; the two edges touching (`╮╭`) are what separate them.
- **Title bar** (top line): `▲ AZU`, the command, the project name, and the live state on the right
  (clock and spinner).
- **Key bar** (second-to-last line in full-screen mode): only the keys that work in the current state.
  Keys are written as `[Enter] Select`: the key in `cyan`, the action in `muted`.
- **Status line** (last line in full-screen mode): continuous diagnostics such as CLI memory, CPU, cwd,
  git branch and how many files are watched. It updates at 1 Hz and never adds lines.
- **Breakpoints:** 100 columns or more gives two card columns. Narrower than 100 stacks the cards and
  drops the sparklines and tables first, then the less important lines. Below 60 columns, or 16 rows,
  the HUD switches to the plain reporter.
- **Motion:** spinners only run while something is pending. Nothing else moves on its own. Values that
  change flash `cyan` for one second and then fade back to `text`. `AZU_REDUCED_MOTION=1` (also set when
  `CI` is set) turns spinners into a static `◆` and turns the flash off.
- **Color is never the only signal.** Every state has a glyph (✔ ✖ ▲ ●) as well as a color, so the
  screens can be read without color, for example by someone who is color-blind.

---

## 2. Mockups

The mockups below were generated by a script that measures display width, so their borders line up in
any monospace font. Each mockup is followed by a list of which color token paints which part.

### 2.1 `azu new`: the onboarding wizard

The wizard runs **inline**. It redraws its own block of lines in place and leaves the final summary in
your scrollback, so the terminal history still records what you chose. There are eight steps: Project,
Type, Database, Driver, Frontend, Jobs, Delivery, Review. A step that doesn't apply is skipped, for
example Driver for SQLite or Jobs for a `cli` project. The *Stack so far* card is filled in as you go.

**Step 4: Driver** (single select)

```text
 ▲ AZU  new · blog                                                    step 4 of 8  ▮▮▮▮▯▯▯▯
╭─ Wizard ───────────────────────────────────╮╭─ Stack so far ─────────────────────────────╮
│                                            ││                                            │
│ Database driver                            ││ ✔ Project    blog · module Blog            │
│ How should CQL reach PostgreSQL?           ││ ✔ Type       web                           │
│                                            ││ ✔ Database   PostgreSQL                    │
│ ● CQL engine pool      native · default    ││ ◆ Driver     choosing…                     │
│ ○ crystal-db           DB::Database + pg   ││ ○ Frontend   —                             │
│                                            ││ ○ Jobs       —                             │
│ ▸ The engine pool is CQL's default for     ││ ○ Delivery   —                             │
│   postgres:// URLs. Switch later with      ││                                            │
│   AZU_CQL_DRIVER=db, no code change.       ││ ── Will write ──────────────────────────── │
│                                            ││ 41 files  ·  2 migrations  ·  1 .env       │
╰────────────────────────────────────────────╯╰────────────────────────────────────────────╯
 [↑/↓] Move   [Enter] Select   [Tab] Next   [⇧Tab] Back   [?] Why   [Esc] Quit
```

Colors: `▲ AZU` uses the gradient. The step meter is `cyan` (▮) on `faint` (▯). `● CQL engine pool` is
`cyan` and bold, `○ crystal-db` is `text`, and their descriptions are `muted`. The `▸` note is `muted`
with `AZU_CQL_DRIVER=db` in `blue`. In the right card, `✔` is `green`, `◆` is `cyan` with a spinner
when a lookup is running, and `○ … —` is `faint`.

**Step 5: Frontend** (single select plus toggles, with a live file preview)

```text
 ▲ AZU  new · blog                                                    step 5 of 8  ▮▮▮▮▮▯▯▯
╭─ Wizard ───────────────────────────────────╮╭─ Preview ──────────────────────────────────╮
│                                            ││                                            │
│ Frontend                                   ││ public/templates/blog/                     │
│ What renders your pages?                   ││   layout.jinja           + spark.js        │
│                                            ││   home/index_page.jinja                    │
│ ● Azu templates + Spark live views         ││ src/components/                            │
│ ○ Nuxt 3 · Vue 3 in ./frontend             ││   counter_component.cr   Spark demo        │
│ ○ None — JSON API only                     ││ public/css/app.css       tailwind out      │
│                                            ││ bin/tailwindcss          fetched once      │
│ Extras                                     ││                                            │
│ [x] Tailwind CSS (standalone, no node)     ││ Dev: azu dev rebuilds CSS on save          │
│ [ ] Component gallery at /components       ││                                            │
│                                            ││                                            │
╰────────────────────────────────────────────╯╰────────────────────────────────────────────╯
 [↑/↓] Move   [Space] Toggle   [Enter] Confirm   [Tab] Next   [⇧Tab] Back   [Esc] Quit
```

The Preview card shows the files the current choices would add. It is the same data the generator
renders (see 3.6), so the preview always matches what gets written.

> **New work, not available today.** The generator offers `web`, `api` and `cli` and has no frontend
> choice. *Nuxt 3 · Vue 3 in ./frontend* and *Tailwind (standalone binary, no Node)* would be new
> generator variants. "Azu templates + Spark" is what `web` generates now.

**Review: the summary before anything is written**

```text
 ▲ AZU  new · blog                                                         review  ▮▮▮▮▮▮▮▮
╭─ Flight plan ──────────────────────────────╮╭─ What happens next ────────────────────────╮
│                                            ││                                            │
│ Project     blog            module Blog    ││ 1  Write 41 files into ./blog              │
│ Author      Ada Lovelace <ada@acme.dev>    ││ 2  .env with fresh secrets (0600)          │
│ License     MIT                            ││ 3  git init, first commit                  │
│                                            ││ 4  shards install        ~25s cold         │
│ Type        web                            ││ 5  Type-check src/server.cr                │
│ Database    PostgreSQL · CQL engine pool   ││                                            │
│ Frontend    Azu templates + Spark          ││ Needs on this machine                      │
│             + Tailwind (standalone)        ││ ✔ crystal 1.22.1                           │
│ Jobs        JoobQ · Redis                  ││ ✔ shards 0.19.1                            │
│ Tests       spec                           ││ ✔ git 2.47                                 │
│ Delivery    Docker · GitHub Actions        ││ ▲ postgres not reachable on :5432          │
│ Git         init + first commit            ││   (only db:setup needs it)                 │
│                                            ││                                            │
╰────────────────────────────────────────────╯╰────────────────────────────────────────────╯
 [Enter] Launch   [e] Edit a step   [c] Copy as command   [Esc] Quit
```

The *Needs on this machine* checks reuse `azu doctor`'s `Diagnostics::System` checks, which have no side
effects. A failed check that only affects a later step is shown as `▲ amber` and does not block. `[c] Copy
as command` copies the same choices as flags, for example
`azu new blog --type web --database postgresql --docker --ci "GitHub Actions" --joobq --yes`. The wizard
is only a way to build those flags. It has no option you can't pass as a flag, so a scripted run and the
wizard always produce the same project.

**Launch: Compilation Progress and System Telemetry**

```text
 ▲ AZU  new · blog                                                                launching
╭─ Compilation Progress ───────────────────────────────────────────────────────────────────╮
│                                                                                          │
│ ✔ Files          41 written                     0.2s                                     │
│ ✔ Secrets        .env (0600) · CSRF, SESSION    0.0s                                     │
│ ✔ Git            init + 1 commit                0.3s                                     │
│ ⠼ Shards         ▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱  13/19     14.1s                                     │
│                  resolving cql @ master                                                  │
│ ○ Type-check     crystal build --no-codegen                                              │
│                                                                                          │
╰──────────────────────────────────────────────────────────────────────────────────────────╯
╭─ System Telemetry ───────────────────────────────────────────────────────────────────────╮
│ net ▂▃▅▇▆▅▃▂▁▁▂   1.8 MB/s   cpu ▃▄▄▅▅▆  38%   disk +62 MB   elapsed 14.9s               │
╰──────────────────────────────────────────────────────────────────────────────────────────╯
 [Ctrl-C] Stop (keeps written files)   [v] Show shards output
```

The stages are what `New#generate_project` and `#post_generation_tasks` already do (write files, git,
`shards install`, `crystal build --no-codegen`). Two things change: the output is no longer thrown away
with `> /dev/null`, and the stages run concurrently where that's safe (git and shards don't depend on
each other). Shards progress comes from counting the `Fetching` and `Installing` lines in shards' output.
`[v]` shows that output in place.

**Done card** (the last thing left in scrollback)

```text
╭─ blog is ready ────────────────────────────────────────────────────────────────────── ✔ ─╮
│                                                                                          │
│ ✔ 41 files · ✔ shards (19) · ✔ type-checks in 9.8s · total 31.6s                         │
│                                                                                          │
│   cd blog                                                                                │
│   azu db:setup          needs postgres: DATABASE_URL is in .env.development              │
│   azu dev               opens the HUD; app on http://localhost:4000                      │
│                                                                                          │
│ ▸ Try  azu g scaffold post title:string body:text  — then watch the HUD rebuild          │
│                                                                                          │
╰──────────────────────────────────────────────────────────────────────────────────────────╯
```

### 2.2 `azu dev`: the HUD

`azu dev` on a terminal at least 60×16 opens the HUD on the alternate screen. `azu dev --plain`, a pipe,
or `CI=1` keeps today's line output, unchanged. When you quit, the HUD prints a one-line session summary
to the normal screen: `azu dev · 12m41s · 7 rebuilds · 0 crashes · 2,184 requests`.

**Overview** (`[1]`, 100 columns)

```text
 ▲ AZU  dev · blog    ● running  pid 48213   :4000   development                        14:32:07  ⠹
╭─ Build ────────────────────────────────────────╮╭─ App ──────────────────────────────────────────╮
│ ✔ built in 6.2s · src/models/post.cr           ││ uptime 00:12:41  restarts 7  crashes 0         │
│ parse ▮ sem ▮▮▮▮▮▮▮▮▮▮ codegen ▮▮▮▮▮           ││ RSS 48.2 MB  ▁▁▂▂▂▃▃▃▄▄▄▄▅▅▅▅▅▅▅▅              │
│ next ~6s   history ▂▃▂▅▂▂▃▂▂▂ (10)             ││ templates hot · .env loaded (3)                │
╰────────────────────────────────────────────────╯╰────────────────────────────────────────────────╯
╭─ Requests ───────────────────────────────────────────────────────────────────────────────────────╮
│ 18.4 req/s   p50 2.1 ms   p95 9.8 ms   4xx 1   5xx 0     ▂▃▅▇▆▄▃▂▂▃▅▆▇█▇▅▃▂▁▂▃▄▅▆▅▄▃▂▂           │
│ 14:32:06  GET   /posts                 200    2.3 ms   Blog::Posts::IndexEndpoint                │
│ 14:32:05  POST  /posts                 303    8.9 ms   Blog::Posts::CreateEndpoint               │
│ 14:32:05  GET   /posts/41              200    1.7 ms   Blog::Posts::ShowEndpoint                 │
│ 14:32:02  POST  /sessions              422    3.0 ms   Blog::Sessions::CreateEndpoint            │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ SQL Telemetry ────────────────────────────────╮╭─ Workers · JoobQ ──────────────────────────────╮
│ 212 q  avg 0.8 ms  slow 2  pool ▮▮▮▯▯▯▯ 3/10   ││ ● 4 workers   busy 3   queued 128   failed 1   │
│ ▲ N+1  SELECT comments WHERE post_id = ?  ×20  ││ mailers   ▮▮▮▮▮▮▮▮▯▯  41/s  ▃▅▆▇▆▅▆▇           │
│        Posts::IndexEndpoint  index_page.cr:14  ││ default   ▮▮▮▯▯▯▯▯▯▯  12/s  ▁▂▂▃▂▂▁▂           │
│   9.1 ms  SELECT posts ORDER BY created_at     ││ retry     ▮▯▯▯▯▯▯▯▯▯   1    ✖ PublishJob       │
╰────────────────────────────────────────────────╯╰────────────────────────────────────────────────╯
╭─ Log ──────────────────────────────────────────────────────────────────── 2 of 318 · [l] expand ─╮
│ 14:32:05 INFO  Blog::Posts::CreateService created post 41                                        │
│ 14:32:02 WARN  validation failed: email (format)                                                 │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
 [1] Overview  [2] Requests  [3] SQL  [4] Jobs  [5] Spark   [⌃K] Command   [r] Rebuild  [q] Quit
 mem 61 MB · cpu 4% · ~/code/blog · main ✱2                         watching 87 files · poll 250 ms
```

Colors: the title bar shows `● running` in `green` (`amber` while restarting, `red` after a crash). The
port is `blue`. In the Build card, `parse`, `sem` and `codegen` are compiler stages drawn with the
gradient. Sparklines are drawn with the gradient. Status codes are `green` for 2xx and 3xx, `amber` for
4xx and `red` for 5xx. HTTP methods each have a fixed color (`GET` blue, `POST` cyan, `PATCH`/`PUT`
purple, `DELETE` red), and endpoint class names are `muted`. The N+1 line is `amber`, with its caller in
`blue` because `[o]` opens it. In the status line, the CLI's own figures (`mem`, `cpu`) are `muted` and
the `✱2` dirty-file count is `amber`.

**Build failed.** The app keeps serving the previous build, as `azu dev` already does. The HUD shows the
error as a card on top of the dashboard:

```text
 ▲ AZU  dev · blog    ✖ build failed   ● serving previous   :4000                         14:35:52
╭─ Build failed · app still running the previous build (pid 48213) ───────────────────────── 2.4s ─╮
│                                                                                                  │
│ ✖ src/endpoints/posts/create_endpoint.cr:18:9                                                    │
│                                                                                                  │
│    16 │   def call : Azu::Response::Empty                                                        │
│    17 │     post = Posts::CreateService.new(create_request).call                                 │
│    18 │     redirect to: "/posts/#{post.idd}", status: 303                                       │
│       │                             ^~~                                                          │
│                                                                                                  │
│    Error: undefined method 'idd' for Post                                                        │
│    Did you mean 'id'?                                                                            │
│                                                                                                  │
│ ▸ [o] Open in $EDITOR at 18:29   [c] Copy error   [f] Full compiler output                       │
│                                                                                                  │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
 [o] Open  [r] Retry  [esc] Back to HUD
```

The code excerpt is taken from the compiler output the `Builder` already captures (`Result#output`), and
`[o]` runs `$EDITOR +18:29 file` for editors that support that syntax. The card closes itself on the next
successful build.

**Spark tab** (`[5]`, also opened by `azu spark` = `azu dev --tab spark`)

```text
 ▲ AZU  dev · blog  › Spark    ● running  pid 48213   :4000                             14:32:07  ⠧
╭─ Spark · live views ───────────────────────────╮╭─ Last events ──────────────────────────────────╮
│ sockets ● 23 open    joins 4/min    drops 0    ││ 14:32:07 ChatComponent#send     ▸ 1 patch      │
│ patches 182/s  ▂▃▅▆▇█▇▆▅▅▆▇▆▅▃▂▃▅▆▇            ││ 14:32:07 CounterComponent#inc   ▸ 1 patch      │
│ avg patch 312 B   p95 render 0.6 ms            ││ 14:32:06 ChatComponent#typing   ▸ 0 patch      │
│                                                ││ 14:32:05 PresenceList join  room:lobby         │
│ Component          mounts  ev/s  p95           ││                                                │
│ CounterComponent       12   9.1  0.2 ms        ││ Hot reload                                     │
│ ChatComponent           8  31.4  0.9 ms        ││ ✔ chat_component.cr rebuilt 14:31:58           │
│ PresenceList            3   0.4  0.1 ms        ││   23 sockets reconnected, re-mounted           │
╰────────────────────────────────────────────────╯╰────────────────────────────────────────────────╯
```

**Narrow terminal** (62 columns): cards stack and the less important lines are dropped.

```text
 ▲ blog  ● :4000  pid 48213                                 ⠹
╭─ Build · App ──────────────────────────────────────────────╮
│ ✔ 6.2s  next ~6s   RSS 48 MB ▃▃▄▄▅▅▅▅                      │
│ restarts 7   crashes 0                                     │
╰────────────────────────────────────────────────────────────╯
╭─ Requests ─────────────────────────────────────────────────╮
│ 18 r/s  p95 9.8 ms  5xx 0  ▂▃▅▇▆▄▃▂▂▃▅▆                    │
│ POST /posts        303  8.9 ms                             │
╰────────────────────────────────────────────────────────────╯
╭─ SQL ──────────────────────────────────────────────────────╮
│ 212 q  slow 2  ▲ N+1 ×20 index_page.cr:14                  │
╰────────────────────────────────────────────────────────────╯
 [1-5] Panel  [⌃K] Command  [q] Quit
```

**Where each panel's data comes from**

| Panel             | Source                                                                       | Exists today?                                                  |
| ----------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Build             | `DevServer::Builder` output (shards forwards `--progress` to the compiler)   | Builder yes; stage parsing new                                 |
| Build forecast    | Past build times per stage, stored in `$XDG_STATE_HOME/azu/<project>/builds` | New                                                            |
| App: pid/restarts | `DevServer::Child`                                                           | Yes                                                            |
| App: RSS          | `/proc/<pid>/statm` (Linux), `ps -o rss= -p` (macOS), 1 Hz                   | New                                                            |
| Requests, SQL     | Telemetry socket (3.7) fed by `PerformanceMetrics` and `QueryStore`          | Both stores exist in `azu/dev`; the socket is new (azu change) |
| N+1 + caller      | `QueryStore` N+1 analysis (it records `caller`)                              | Analysis exists; sent over the socket (new)                    |
| Workers           | Redis LLEN on `joobq:queue/processing/failed:<q>` as `azu jobs:status` does  | Queries exist; see the note under 3.7                          |
| Spark             | Counters in `Azu::Spark` via `Azu::Instrumentation`                          | New (azu change)                                               |
| Log               | The child's stdout/stderr through a pipe instead of `Inherit`                | New (a `Child` option)                                         |

### 2.3 `azu generate`: the scaffolding menu with a live preview

With no arguments on a TTY, `azu generate` opens this menu. `azu g scaffold post title:string` still
works exactly as it does today. If a TTY is attached it prints the same plan as a static card before
writing, and `--yes` skips the confirmation.

**Pick a generator** (fuzzy filter)

```text
 ▲ AZU  generate · blog
╭─ Generate ─────────────────────────────────╮╭─ Live preview ─────────────────────────────────────╮
│                                            ││                                                    │
│ What are we building?                      ││ scaffold · Post   (type fields on the left)        │
│                                            ││                                                    │
│ ▸ scaffold    model + CRUD + pages         ││ + src/models/post.cr                               │
│   model       CQL model + migration        ││ + src/db/migrations/2026…_create_posts.cr          │
│   endpoint    Endpoint(Request, Response)  ││ ~ src/db/schema.cr                   +6 lines      │
│   channel     WebSocket channel            ││ + src/requests/posts/  create, update              │
│   component   Spark live view              ││ + src/endpoints/posts/ 7 endpoints                 │
│   job         JoobQ job                    ││ + src/pages/posts/     4 pages                     │
│   migration   schema change                ││ + public/templates/blog/posts/  4 templates        │
│   auth        session authentication       ││ + spec/endpoints/posts_spec.cr                     │
│                                            ││                                                    │
│ Filter: sc█                                ││ 18 new · 1 changed · 0 conflicts                   │
│                                            ││                                                    │
╰────────────────────────────────────────────╯╰────────────────────────────────────────────────────╯
 [↑/↓] Move   [Enter] Choose   type to filter   [Esc] Quit
```

**Edit fields: the preview shows the diff of the file in focus**

```text
 ▲ AZU  generate · blog  › scaffold
╭─ scaffold Post ────────────────────────────╮╭─ ~ src/db/schema.cr ───────────────────────────────╮
│                                            ││                                                    │
│ Name        Post                           ││   12   table :users do                             │
│ Fields                                     ││   ··        …                                      │
│   title      String     required           ││   19   end                                         │
│   body       Text                          ││ + 20   table :posts do                             │
│   published  Bool       default false      ││ + 21     primary :id, Int64, auto_increment: true  │
│ ▸ author_id  Int64 ref  users ▾            ││ + 22     text :title                               │
│   + add field                              ││ + 23     text :body, null: true                    │
│                                            ││ + 24     boolean :published, default: false        │
│ Options                                    ││ + 25     bigint :author_id                         │
│ ● Web pages   ○ JSON only                  ││ + 26     timestamps                                │
│ [x] timestamps   [ ] soft delete           ││ + 27   end                                         │
│                                            ││                                                    │
│                                            ││ [←/→] File 3 of 19          ✔ type-checks          │
╰────────────────────────────────────────────╯╰────────────────────────────────────────────────────╯
 [Tab] Next field   [Enter] Edit   [d] Delete   [←/→] Preview file   [⌃S] Write 19 files   [Esc] Back
```

The field editor uses the generator attribute syntax that already exists (`name:type[:modifier]`, `ref`).
Every change re-renders the shadow tree (3.6). This takes milliseconds because it is ECR into memory, so
the preview never lags behind what you type. `✔ type-checks` comes from a debounced background
`crystal build --no-codegen` against the shadow tree (innovation 3) and is shown as `◆ checking…` while it
runs.

**Apply**

```text
╭─ Writing scaffold Post ──────────────────────────────────────────────────────────────────────────╮
│                                                                                                  │
│ ✔ Shadow tree      19 files rendered in memory           12 ms                                   │
│ ✔ Type-check       crystal build --no-codegen (overlay)  3.9 s                                   │
│ ✔ Write            18 new · 1 changed                     4 ms                                   │
│ ⠙ Migrate          azu db:migrate  CreatePosts                                                   │
│                                                                                                  │
│ Routes added                                                                                     │
│   GET    /posts            Blog::Posts::IndexEndpoint                                            │
│   GET    /posts/:id        Blog::Posts::ShowEndpoint                                             │
│   POST   /posts            Blog::Posts::CreateEndpoint      → 303                                │
│   …4 more                                     [a] all                                            │
│                                                                                                  │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
 ● azu dev is running: it will rebuild on its own · [u] Undo this generate
```

`→ 303` reflects the contract the generators follow: writes answer 303. The routes come from the same
data `azu routes` prints. `[u] Undo` is innovation 3.

### 2.4 The same screens without a TTY

The plain reporter writes one line per event and nothing else. It is the default for pipes, `CI`,
`TERM=dumb`, `--plain`, and for commands that set `machine_output?`:

```text
azu new blog: web · postgresql (cql engine pool) · joobq · docker · github actions
[ok] files       41 written                 0.2s
[ok] git         init + 1 commit            0.3s
[ok] shards      19 installed              24.8s
[ok] type-check  src/server.cr              9.8s
next: cd blog && azu db:setup && azu dev
```

`--ui json` (also `AZU_UI=json`) writes the same events as NDJSON, for editors and CI annotations:

```json
{"v":1,"event":"task.done","task":"shards","detail":"19 installed","seconds":24.8,"ok":true}
```

---

## 3. Crystal architecture

### 3.1 Build it or wrap a shard?

**Build a small engine in the CLI using only the standard library.** The reasons:

- **Binary size and dependencies.** The CLI already links pg, mysql, redis and cql. The TUI should add
  tens of kilobytes, not another C library. Bindings such as termbox or notcurses add a native library
  to every install and every container image.
- **The surface we need is small.** That is raw mode (`IO::FileDescriptor#raw`, standard library),
  window size (one `ioctl`), `SIGWINCH` (`Signal::WINCH.trap`), and escape sequences written to an `IO`.
  The rest is a cell grid, a diff, and widgets.
- **Crystal's fibers already provide the event loop.** Keys, timers, signals, the build, the child's
  output and the telemetry socket each become a fiber sending to one `Channel`. One fiber owns the frame,
  so rendering needs no locks.
- **Existing Crystal TUI shards** fall into three groups: blessed-style ports, which are large and
  widget-heavy; bindings to C libraries; and small escape-code helpers. None of them offers an
  immediate-mode, testable, plain/JSON-degrading engine in the style of Ratatui or Bubble Tea without
  also bringing in dependencies or a retained widget tree. Check each candidate's current state before
  deciding. If one fits, use it only behind `UI::Backend` (3.3) so it can be swapped out.

Estimated size: about 1.5–2k lines for the engine and widgets, plus the screens.

### 3.2 Module map

```text
src/azu_cli/ui/
├── ui.cr                 # require entry point; UI.reporter picks Rich / Plain / Json
├── terminal.cr           # capability detection, size (ioctl), raw mode, alt screen, cursor, sync output
├── theme.cr              # Token enum, palette per ColorDepth, gradients, the glyph set + ASCII fallback
├── style.cr              # Style (fg, bg, attrs) and StyleTable: interned to UInt16, SGR cached per depth
├── width.cr              # display width of a Char (East Asian Width table), truncate with …
├── buffer.cr             # Cell grid (Char + style id), drawing primitives, clipping
├── renderer.cr           # Inline (redraw own block) and FullScreen (diff + DEC 2026 synchronized output)
├── layout.cr             # Rect, split rows/cols by Fixed | Percent | Min | Fill, breakpoints
├── input.cr              # byte stream -> Key events (CSI/SS3, Ctrl, bracketed paste)
├── program.cr            # the event loop: Channel(Event), coalescing, ticks, resize, teardown
├── screen.cr             # abstract Screen: update(event) -> Action, view(frame)
├── widgets/
│   ├── card.cr  key_bar.cr  status_line.cr  text.cr  table.cr
│   ├── select.cr  multi_select.cr  toggle.cr  input.cr  fuzzy_list.cr
│   ├── spinner.cr  gauge.cr  progress.cr  sparkline.cr
│   └── file_tree.cr  diff_view.cr  code_frame.cr
├── reporter/
│   ├── reporter.cr       # abstract: task / note / warn / result (commands talk to this, not to escapes)
│   ├── rich.cr  plain.cr  json.cr
└── screens/
    ├── new_wizard.cr     # steps are data: Step(T) with prompt, choices, flag name, skip-if
    ├── dev_hud.cr        # tabs: overview, requests, sql, jobs, spark; overlays: build error, palette
    └── generate_menu.cr
src/azu_cli/telemetry/
├── socket_server.cr      # azu dev listens; the app connects (3.7)
├── snapshot.cr           # JSON::Serializable, versioned
└── samplers.cr           # RSS sampler, JoobQ sampler, build-history store
```

Dependencies only point downward: `screens` → `widgets` → `buffer/style/layout` → `terminal`. The
commands (`Commands::Dev`, `New`, `Generate`) depend on `Reporter` and on a `Screen`, never on escape codes.

### 3.3 Terminal and capabilities

```crystal
lib LibTerm
  struct Winsize
    row : UInt16
    col : UInt16
    xpixel : UInt16
    ypixel : UInt16
  end

  fun ioctl(fd : LibC::Int, request : LibC::ULong, ...) : LibC::Int
end

module AzuCLI::UI
  enum ColorDepth
    None
    Basic16
    Ansi256
    TrueColor
  end

  class Terminal
    TIOCGWINSZ = {% if flag?(:darwin) || flag?(:bsd) %} 0x40087468_u64 {% else %} 0x5413_u64 {% end %}

    getter io : IO::FileDescriptor
    getter depth : ColorDepth
    getter? unicode : Bool

    def initialize(@io : IO::FileDescriptor, @depth : ColorDepth, @unicode : Bool)
    end

    # NO_COLOR wins over everything; FORCE_COLOR re-enables it on a pipe (for `script`, CI logs that render ANSI).
    def self.detect(io : IO::FileDescriptor = STDOUT, env = ENV) : Terminal
      unicode = (env["LC_ALL"]? || env["LC_CTYPE"]? || env["LANG"]? || "").matches?(/utf-?8/i) &&
                env["AZU_AMBIGUOUS_WIDE"]? != "1"
      new(io, color_depth(io, env), unicode)
    end

    def self.color_depth(io : IO::FileDescriptor, env) : ColorDepth
      return ColorDepth::None if env["NO_COLOR"]?.presence
      forced = env["FORCE_COLOR"]?.presence
      return ColorDepth::None unless io.tty? || forced
      return ColorDepth::None if env["TERM"]? == "dumb"
      return ColorDepth::TrueColor if env["COLORTERM"]?.in?("truecolor", "24bit")
      return ColorDepth::Ansi256 if env["TERM"]?.try(&.includes?("256color"))
      ColorDepth::Basic16
    end

    # {columns, rows}; COLUMNS/LINES, then 80x24, when the output is not a terminal.
    def size : {Int32, Int32}
      ws = LibTerm::Winsize.new
      if io.tty? && LibTerm.ioctl(io.fd, TIOCGWINSZ, pointerof(ws)) == 0 && ws.col > 0
        {ws.col.to_i, ws.row.to_i}
      else
        {ENV["COLUMNS"]?.try(&.to_i?) || 80, ENV["LINES"]?.try(&.to_i?) || 24}
      end
    end

    # Raw mode for the block, and the screen put back whatever happens (exceptions, Ctrl-C, a crash in a widget).
    def session(full_screen : Bool, &)
      STDIN.raw do
        begin
          io << "\e[?1049h" if full_screen # alternate screen
          io << "\e[?25l\e[?2004h"         # hide cursor, bracketed paste
          io.flush
          yield
        ensure
          io << "\e[?2004l\e[?25h\e[0m"
          io << "\e[?1049l" if full_screen
          io.flush
        end
      end
    end
  end
end
```

Raw mode turns off `ISIG`, so Ctrl-C arrives as byte `0x03` and does not raise `SIGINT`. The input parser
turns it into `Key::CtrlC`, and every screen treats that key as "stop, and leave the terminal clean". As a
safety net, `Process.on_terminate` (which `Commands::Dev` already uses) also restores the terminal.

### 3.4 Styles, cells and the diff renderer

```crystal
module AzuCLI::UI
  @[Flags]
  enum Attr : UInt8
    Bold
    Dim
    Italic
    Underline
  end

  record Style, fg : Token? = nil, bg : Token? = nil, attrs : Attr = Attr::None, rgb : Rgb? = nil

  # Styles are interned: a cell stores a UInt16, and each style's SGR string is built once for the terminal's depth.
  class StyleTable
    @ids = {} of Style => UInt16
    @sgr = [] of String

    def initialize(@theme : Theme)
      id(Style.new) # 0 is the reset style
    end

    def id(style : Style) : UInt16
      @ids[style] ||= begin
        @sgr << @theme.sgr(style) # "\e[0;1;38;2;34;211;238m", "\e[0;36m" or "" for ColorDepth::None
        (@sgr.size - 1).to_u16
      end
    end

    def sgr(id : UInt16) : String
      @sgr[id]
    end
  end

  record Cell, char : Char = ' ', style : UInt16 = 0_u16

  class Buffer
    getter width : Int32
    getter height : Int32
    @cells : Array(Cell)

    def initialize(@width, @height)
      @cells = Array.new(width * height, Cell.new)
    end

    def [](x : Int32, y : Int32) : Cell
      @cells[y * width + x]
    end

    # Writes `text` from (x, y), clipped to `max` columns; returns the column after the last cell written.
    def print(x : Int32, y : Int32, text : String, style : UInt16, max : Int32 = width - x) : Int32
      limit = x + Math.min(max, width - x)
      text.each_char do |char|
        break if x >= limit
        next if Width.of(char) != 1 # wide or zero-width: never inside a frame (1.2); Text truncates before this
        @cells[y * width + x] = Cell.new(char, style)
        x += 1
      end
      x
    end
  end

  # Full-screen renderer: compares with the previous frame and writes only the cells that changed, as one
  # write wrapped in synchronized output (DEC mode 2026) so terminals that support it never show half a frame.
  abstract class Renderer
    abstract def flush(frame : Buffer) : Nil
    abstract def full_screen? : Bool
  end

  class FullScreenRenderer < Renderer
    @previous : Buffer?

    def initialize(@io : IO, @styles : StyleTable)
    end

    def full_screen? : Bool
      true
    end

    def flush(frame : Buffer) : Nil
      previous = @previous.try { |buffer| buffer if buffer.width == frame.width && buffer.height == frame.height }
      output = String.build(frame.width * 8) do |out|
        out << "\e[?2026h"
        out << "\e[2J" unless previous
        style = UInt16::MAX
        frame.height.times do |y|
          cursor = -1
          frame.width.times do |x|
            cell = frame[x, y]
            next if previous && previous[x, y] == cell

            out << "\e[" << y + 1 << ';' << x + 1 << 'H' unless cursor == x
            out << @styles.sgr(cell.style) unless cell.style == style
            out << cell.char
            style = cell.style
            cursor = x + 1
          end
        end
        out << "\e[?2026l"
      end
      @io.write(output.to_slice) # one syscall per frame
      @io.flush
      @previous = frame
    end
  end
end
```

The **inline renderer**, used by the wizard and by progress output, remembers how many lines it drew last
time. To redraw, it moves up that many lines (`\e[{n}F`), clears down (`\e[J`), and writes the new block,
again inside 2026 synchronized output. Its last frame is left on screen and becomes part of the scrollback.
At 30 or fewer lines a full redraw is cheaper than diffing.

### 3.5 Event loop: the Elm architecture on fibers

Each screen is a pure state machine. `update` takes an event and returns what to do next, and `view` draws
the state into a `Frame`. Screens can be tested without a terminal: feed them keys and compare the text
of the frame (3.9).

```crystal
module AzuCLI::UI
  record Key, code : KeyCode, char : Char? = nil
  record Resize, columns : Int32, rows : Int32
  record Tick, at : Time::Instant

  # Data from sources (build, telemetry, samplers). A screen matches on the concrete type.
  abstract struct Message
  end

  alias Event = Key | Resize | Tick | Message

  enum Action
    Continue
    Redraw
    Quit
  end

  abstract class Screen
    abstract def update(event : Event) : Action
    abstract def view(frame : Frame) : Nil

    # Ticks only run while this is true (a spinner is on screen): an idle HUD draws nothing.
    def animating? : Bool
      false
    end
  end

  class Program
    FRAME = 33.milliseconds # at most 30 frames per second; most frames come from events, not ticks

    getter events = Channel(Event).new(256)

    def initialize(@screen : Screen, @terminal : Terminal, @renderer : Renderer, @styles : StyleTable)
    end

    # Sources call this from their own fibers.
    def send(message : Message) : Nil
      events.send(message)
    end

    def run : Nil
      @terminal.session(full_screen: @renderer.full_screen?) do
        spawn read_keys
        spawn tick
        Signal::WINCH.trap { events.send(Resize.new(*@terminal.size)) } # trap handlers run in a fiber, not in signal context
        draw
        loop do
          redraw = false
          event = events.receive
          # Drain what queued up meanwhile: a burst of log lines or telemetry becomes one frame, not one per message.
          while event
            case @screen.update(event)
            in .quit?     then return
            in .redraw?   then redraw = true
            in .continue? then nil
            end
            event = poll
          end
          draw if redraw
        end
      end
    ensure
      Signal::WINCH.reset
    end

    private def poll : Event?
      select
      when event = events.receive
        event
      else
        nil
      end
    end

    private def read_keys : Nil
      bytes = Bytes.new(64)
      while (count = STDIN.read(bytes)) > 0
        # Terminals send one escape sequence in one write, so a read that returns only "\e" is the Esc key.
        Input.parse(bytes[0, count]).each { |key| events.send(key) }
      end
    end

    private def tick : Nil
      loop do
        sleep FRAME
        events.send(Tick.new(Time.instant)) if @screen.animating?
      end
    end

    private def draw : Nil
      columns, rows = @terminal.size
      frame = Frame.new(columns, rows, @styles)
      @screen.view(frame)
      @renderer.flush(frame.buffer)
    end
  end
end
```

`azu dev` connects its existing pieces to the program as message sources, instead of having them call
`Logger` directly:

```crystal
# Commands::Dev, rich mode. Watcher, Batcher, Builder and Child stay as they are; their outcomes become messages.
hud = UI::Screens::DevHud.new(project: Utils.binary_name, port: port)
program = UI::Program.new(hud, terminal, UI::FullScreenRenderer.new(STDOUT, styles), styles)

spawn { serve_loop(target) { |event| program.send(event) } }            # Built, BuildFailed, Restarted, Exited, Changed
spawn { builder_lines.each { |line| program.send(BuildLine.new(line)) } } # --progress lines: stage gauges
spawn { child.output_lines.each { |line| program.send(LogLine.new(line)) } }
spawn { Telemetry::SocketServer.new(socket_path).each { |snapshot| program.send(snapshot) } }
spawn { Telemetry::RssSampler.new(child).every(1.second) { |rss| program.send(rss) } }
program.run
stop # the same shutdown as today: cancel the build, stop the app
```

The plain mode of `azu dev` is the same `serve_loop`, with its block calling `Reporter::Plain` instead.
The plain output therefore can't diverge from the HUD, because both are drawn from the same events.

### 3.6 Generator preview: a shadow tree, then apply

Today the generators are Teeplate `FileTree`s that render into a path (`generator.render(".", …)`), and
some of them also edit existing files (the model generator registers its table in `src/db/schema.cr`). For
the preview, nothing is written to the project until you confirm:

1. **Seam:** every generator writes through a root path it is given, never the current directory. This
   includes the code that edits existing files, such as the schema registration and the migration
   directory. This refactor is the prerequisite for the whole menu, and is also how the generators can be
   unit tested.
2. **Shadow render:** render into a scratch directory under the system temp directory (created and removed
   on exit and interrupt the way `ScratchFile` handles its temporary files). Copy the files the generator may edit into it first.
3. **Plan:** compare the scratch tree with the project, file by file. Each file is `new`, `changed`
   (with a unified diff), `identical` or a `conflict` (would overwrite a file the generator didn't create;
   the refusal rules that exist today apply). The Preview card and the static `--yes` card both draw from
   this plan.
4. **Apply:** copy each file into the project with write-to-temp-then-rename. Before that, save the
   previous contents of changed files to `$XDG_STATE_HOME/azu/<project-hash>/undo/<timestamp>/`, which
   gives you `[u] Undo` and `azu undo`.

```crystal
module AzuCLI::Generate
  record PlannedFile, path : String, kind : Kind, diff : String? do
    enum Kind
      New
      Changed
      Identical
      Conflict
    end
  end

  class Plan
    getter shadow : String
    getter files : Array(PlannedFile)

    def initialize(@shadow : String, @files : Array(PlannedFile))
    end

    # Previewable: a generator that renders into any root and lists the existing files it edits.
    def self.build(generator : Previewable, project : String) : Plan
      shadow = File.join(Dir.tempdir, "azu-shadow-#{Random::Secure.hex(6)}")
      generator.touched_files.each { |path| copy_into(shadow, project, path) }
      generator.render(shadow, force: true, interactive: false, list: false, color: false)
      new(shadow, compare(shadow, project))
    end
  end
end
```

### 3.7 Telemetry from the app: a Unix socket owned by `azu dev`

The HUD needs request and SQL figures from inside the app. `azu/dev` already collects them
(`PerformanceMetrics`, `QueryStore` with N+1 analysis and the pool figures), but today it only exposes
them as the `/dev-dashboard` HTML page. The proposal:

- `azu dev` creates a socket at `$XDG_RUNTIME_DIR/azu/dev-<pid>.sock` (falling back to the temp
  directory), with mode `0600`, and passes its path to the child as `AZU_TELEMETRY_SOCKET`.
- In azu, `require "azu/dev"` checks for that variable when the app starts. If it is set and the
  environment is development, a fiber connects and writes one NDJSON snapshot per second:
  `{"v":1,"requests":{…},"sql":{…},"cache":{…},"spark":{…},"runtime":{"gc_heap":…,"fibers":…}}`.
  It reconnects when it loses the connection and drops snapshots it can't send, so it never blocks or
  buffers.
- **Why a socket and not an HTTP endpoint:** no route is exposed, so there is nothing to protect with
  CSRF or a loopback check. It works whether or not the app mounts `DevDashboard`. Only processes running
  as your user can connect. Each restart of the app connects again, so the HUD doesn't care which pid is
  current.
- **Versioning:** a snapshot from an older azu without the socket support never arrives. The panels then
  show `telemetry needs azu ≥ <version> with require "azu/dev"` in `muted`, instead of empty charts.
  Unknown fields are ignored and missing ones are shown as `—`.

Workers: the HUD reads the JoobQ figures straight from Redis, as `azu jobs:status` does. `jobs:status`
uses `KEYS joobq:queue:*` to find the queues. That is fine for a single command, but the HUD polls once a
second, so it should read the queue names from `config/jobs.yml` (or use `SCAN`) and run `LLEN` in one
pipelined round trip.

### 3.8 Reporter: how existing commands migrate

Commands call `Logger.progress_start` / `progress_done` / `step` in many places today. A `Reporter`
replaces those calls without changing what the commands do:

```crystal
module AzuCLI::UI
  abstract class Reporter
    # Runs the block as a named task: Rich draws a live row (spinner, then ✔/✖ and time), Plain prints one
    # line when it finishes, Json prints task.start / task.done. An exception marks the task failed and re-raises.
    abstract def task(name : String, detail : String? = nil, & : Task -> T) : T forall T
    abstract def note(message : String) : Nil
    abstract def warn(message : String) : Nil

    def self.for(command : Commands::Base) : Reporter
      case ENV["AZU_UI"]? || command.ui_mode # ui_mode: a new --ui option on Commands::Base
      when "json"  then Json.new(command.stdout)
      when "plain" then Plain.new(command.stdout)
      else
        terminal = Terminal.detect
        rich = terminal.io.tty? && terminal.depth != ColorDepth::None && !ENV["CI"]? && !command.machine_output?
        rich ? Rich.new(terminal) : Plain.new(command.stdout)
      end
    end
  end
end

# New#post_generation_tasks, after:
ui.task("shards", "install") { |task| Shards.install(on_progress: ->(done : Int32, total : Int32) { task.progress(done, total) }) }
```

Migration order: `Reporter` first. It is visible right away, involves no TTY handling, and every command
benefits. Then prompts (the wizard), then the shadow-tree seam (generate), then the HUD and the azu-side
telemetry. Each step can be released on its own.

### 3.9 Testing

- **Screens are pure.** A spec builds a screen, sends it `Key` and `Message` events, calls `view` into a
  `Frame` of a fixed size, and compares `frame.to_text` with a golden file in
  `spec/fixtures/ui/<screen>/<case>.txt`. The mockups on this page are exactly that kind of text, so
  they can become the first golden files.
- **Time is injected.** Spinners, the flash on changed values and sparklines read a clock passed in, so
  frames are deterministic.
- **Renderer specs** check the escape sequences for a two-frame diff, for each `ColorDepth`.
- **Input specs** cover the escape-sequence table (CSI and SS3 arrows, `\e[Z` for Shift-Tab, bracketed
  paste, a lone `\e`).
- **Degradation specs** run each command with `NO_COLOR`, `TERM=dumb`, a pipe and `--ui json`, and
  assert that none of them writes an escape code.

### 3.10 Performance budget

| Concern               | Rule                                                                                         |
| --------------------- | -------------------------------------------------------------------------------------------- |
| Startup               | Nothing in `ui/` runs at require time. `azu --version` must not detect the terminal.         |
| Idle HUD              | 0 frames when nothing changes. Ticks only while a spinner is visible. Telemetry is 1 Hz.     |
| Frame cost            | One `write(2)` per frame. Cells are structs in one flat array. SGR strings are built once.   |
| Allocation per frame  | One `String.build` sized from the previous frame. No regexes in the render path.             |
| Binary                | Standard library only. Measure `bin/azu` (`--release --no-debug`) before and after; budget +100 KB. |
| Build output          | The compiler output keeps streaming into a ring buffer (last 2,000 lines) and is never lost. |

---

## 4. Five DX innovations

### 1. ⌃K: the dev loop becomes a cockpit

Ctrl-K in the HUD opens a fuzzy command palette over everything azu knows: commands (`CLI#command_names`),
routes (the `azu routes` data), generators, recent errors and files with changes. `g scaffold comment
post_id:ref` runs the generator inside the HUD with the shadow-tree preview, writes the files, and the
watcher already running picks them up and rebuilds. `db:migrate` runs and shows its result in a card.
You never leave the dashboard: you write the code, and it shows up running.

### 2. Contract probes: curl that knows your types

`[p]` on a route, or `azu probe POST /posts`, builds a form from the endpoint's `Azu::Request` contract.
The fields, types and `validate` rules come from the same macro pass that `azu routes` already uses to
collect `Endpoint(Request, Response)`, extended to collect the fields. Submitting it fires the request at
the running app with the CSRF token taken from a preliminary GET. The result card shows the status, the
negotiated content type, the validation errors next to the fields that caused them, and **the SQL that
request ran**, matched by `request_id` in `QueryStore`. `[r]` re-runs it after the next rebuild. You can
test an endpoint without writing a curl command and without a browser.

### 3. Compile-proven scaffolding, with undo

`azu generate` already renders into a shadow tree (3.6), so before writing it type-checks the shadow
project. `src/` is copied (it is small) and `lib/` is a symlink. It runs `crystal build --no-codegen` in
the background while you edit the fields, and the preview shows `✔ type-checks` or the exact compiler
error in a code-frame card. A scaffold that would break your build is never written. Every apply keeps an
undo record outside the repository, so `azu undo` restores the changed files and deletes the new ones,
even after the editor has saved over them, as long as the new files are unchanged since they were
generated. Crystal's compiler becomes the check on every generated file.

### 4. N+1 radar and query budgets

`QueryStore` already detects N+1 patterns and records the caller. The HUD shows a warning (`▲ N+1 ×20
index_page.cr:14`) on the request that caused it, and `[o]` opens `$EDITOR` at that line. `azu dev
--budget sql=10,p95=50ms` sets limits per request. An endpoint that goes over a limit gets an amber badge
in the Requests panel and a line in the session summary when you quit (`2 endpoints over budget:
Posts::IndexEndpoint 22 queries`). The same check can run in CI against the e2e scripts. The slow query
is flagged while you are writing the endpoint, not when it shows up in production metrics.

### 5. Rewind: replay a request against the new build

The HUD keeps the last 50 requests in memory: method, path, headers and up to 64 KB of body. This happens
in development only, and `Cookie` and `Authorization` are redacted unless you pass `--replay-auth`. After
a rebuild, `[R]` replays the selected request against the new process and shows a **response diff**:
status, headers, and a structural JSON diff or a text diff for HTML. If a fix changed the response, you
can see what changed. It works like a snapshot test, without writing a test.

**Smaller ideas the engine makes cheap:** `[s]` saves the current HUD frame or error card as an SVG (the
cell buffer drawn with the palette) to paste into a PR or issue. The build forecast learns how long each
compiler stage usually takes and shows an ETA bar. `azu new … [c] Copy as command` gives you a
reproducible one-liner from the wizard.

---

## 5. Changes outside this repository

| Repository | Change                                                                                        | Needed by          |
| ---------- | --------------------------------------------------------------------------------------------- | ------------------ |
| azu        | `AZU_TELEMETRY_SOCKET` client in `azu/dev` (NDJSON snapshot, 1 Hz, development only)          | HUD panels, probes |
| azu        | Spark counters through `Azu::Instrumentation` (sockets, joins, patches, render time)          | Spark tab          |
| azu        | Optional request capture (bounded, redacted) in the snapshot stream                           | Rewind             |
| azu_cli    | `Child` output via a pipe (option), `Builder` passes `--progress`, generator root-path seam   | HUD, preview       |
| azu_cli    | Frontend variants (Nuxt 3 / Vue 3 app in `./frontend`, standalone Tailwind) in `Generate::Project` | Wizard step 5 |
