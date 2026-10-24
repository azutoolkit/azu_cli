# azu console

Opens Crystal's interpreter (`crystal i`) with the application loaded.

```bash
azu console
```

The command writes a scratch file in the project directory that requires `src/<project name>.cr` (the server is not
started) and ends with `debugger`, runs `crystal i` on it, so you land at a prompt inside the loaded app, and deletes
the file afterwards. Type `exit` to leave.

## Limits

Loading the application runs the top-level code of `src/<project name>.cr` (initializers, `.env` loading, database
connections), and what you type runs against whatever the environment points at: do not use it against production by
accident. The scratch file `.azu_console_<pid>.cr` is git-ignored in generated projects and deleted when the command ends.

This is the interpreter, not a Rails-style console, and it is not a mock of one:

- It needs a Crystal built **with** the interpreter (`crystal i --help` must work). The packages from
  crystal-lang.org/install and Homebrew include it; **the official Docker images do not**. Without it the command prints
  how to get it and exits with **2**.
- Code that links native libraries (SQLite, OpenSSL, libpq) runs only if the shared libraries are installed.
- The interpreter is slower than compiled code and does not support every Crystal feature, so some apps do not load in it.
- Nothing is reloaded: restart the console after changing code.

## Exit codes

`0` the session ended, `1` not a project or the interpreter failed (its exit code is used), `2` no interpreter in this
Crystal, or invalid usage.
