# Azu shared development telemetry

`azu-dev-v1.json` is the unmodified output of `scripts/export_azu_dev_telemetry.cr`
run against azutoolkit/azu master commit
`505fff47272bc1d96edda6ede6f91061ea7e441a` (v1.0.4). All requests and query data
are synthetic. The probe obtains `Azu::Dev.metrics` inside `Azu.with_config`,
checks that it is the configured performance monitor's shared instance, and uses
the exporter's default lookup rather than injecting a separate metrics object.
It also verifies `Dev.metrics` returns nil when monitoring is disabled.
The fixture exercises the same PerformanceMetrics, QueryStore,
ErrorStore and Telemetry exporter used by Azu's development tooling, including
real rescuer redaction. Runtime sizes, timestamps and backtraces are incidental.

To revalidate against another installed Azu checkout, set `CRYSTAL_PATH` to a
dependency directory containing `azu/`, `cql/`, `sqlite3/` and the other installed
shards, followed by the Crystal standard library directory. These can be symlinks
to the checkouts. Do not add CQL's `src` directly: its `schema.cr` can shadow the
separate validation `schema` shard. Then run:

```sh
AZU_SNAPSHOT_OUTPUT=/tmp/azu-dev-v1.json crystal run scripts/export_azu_dev_telemetry.cr
# Restore the CLI's normal CRYSTAL_PATH before running its specs:
AZU_SHARED_SNAPSHOT=/tmp/azu-dev-v1.json crystal spec spec/azu_cli/dev_server/shared_telemetry_spec.cr
```

The spec sends the producer's JSON through the CLI's actual private Unix socket
and renders its requests, SQL, N+1 diagnostics, runtime and error details. The
exporter intentionally raises a synthetic exception through Rescuer, so an error
log while producing the fixture is expected. It does not require a database or
start an HTTP server. Keep the older SQL `slowest` fallback tests as well.

`azu-cql-v1.json` comes from `scripts/export_azu_cql_telemetry.cr` against the same
Azu commit and CQL v1.0.1, commit `b16b4d90ed1f993ba46c07c2a07d599420ab3b5b`.
This second probe executes queries against a private disposable SQLite database
through `Azu::CQL.schema` and checks the actual Instrumentor, request correlation,
transaction recording, pool stats, N+1 detection and redaction. It does not insert
synthetic events directly into QueryStore. Re-run with the shard paths above:

```sh
AZU_SNAPSHOT_OUTPUT=/tmp/azu-cql-v1.json crystal run scripts/export_azu_cql_telemetry.cr
# Restore the CLI's normal CRYSTAL_PATH before running its specs:
AZU_CQL_SNAPSHOT=/tmp/azu-cql-v1.json crystal spec spec/azu_cli/dev_server/shared_telemetry_spec.cr
```
