# azu init

Prepares an existing Crystal project (one with a `shard.yml` in the current directory) for the Azu CLI.

```bash
cd my_crystal_app
azu init
```

## What it does

- creates `config/azu.yml` with the CLI settings (project name, database, server, generator paths); an existing file is left alone;
- creates the directories the generators write to, if missing: `src/models`, `src/endpoints`, `src/services`,
  `src/pages`, `src/middleware`, `src/validators`, `src/channels`, `src/handlers`, `src/requests`, `src/responses`,
  `src/components`, `src/db/migrations`, `spec/models`, `spec/endpoints`, `spec/services`, `public/templates`, `public/assets`.

## What it does not do

It takes no options, does not edit `shard.yml` (add `azu`, `cql` and a database driver yourself) and does not
create application code. To start a project from scratch use [`azu new`](new.md).

Outside a directory with a `shard.yml` it fails with "Not in a valid Crystal project directory".
