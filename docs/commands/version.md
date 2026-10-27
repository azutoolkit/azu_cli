# azu version

Prints the CLI version, the Crystal version it was built with and the built-in plugins.

```bash
azu version
```

```
Azu CLI v0.1.17
Crystal 1.22.1
Topia CLI Framework

Plugins:
  - Generator Plugin v1.0.0
  - Database Plugin v1.0.0
  - Development Plugin v1.0.0
```

On a color terminal (not CI) it is a card instead: the CLI, the Crystal it was built with and, in a project, the
`azu`, `cql` and `joobq` versions its `shard.lock` holds. `--ui plain` prints the text above.

The CLI version is the `version` of the shard this binary was built from. The command takes only `--ui`, and
`azu --version` is not understood (it reports an unknown command). The plugin list is fixed text: the plugins are
internal hooks of the CLI, not installable packages.
