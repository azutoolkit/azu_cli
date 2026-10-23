# azu version

Prints the CLI version, the Crystal version it was built with and the built-in plugins.

```bash
azu version
```

```
Azu CLI v0.1.17
Crystal 1.19.1
Topia CLI Framework

Plugins:
  - Generator Plugin v1.0.0
  - Database Plugin v1.0.0
  - Development Plugin v1.0.0
```

The CLI version is the `version` of the shard this binary was built from. The command takes no options, and
`azu --version` is not understood (it reports an unknown command). The plugin list is fixed text: the plugins are
internal hooks of the CLI, not installable packages.
