# Azu CLI final readiness review

Reviewed 2026-10-29. Original review: `codex/joobq-dev-telemetry-hud`, starting from `e4d25b3`. Compatibility follow-up: `codex/azu-cql-v1-compatibility`, based on `d61c24d`.

The project is **not yet ready for an unqualified v1 production release**. The generated application paths have substantial local evidence, but the following operator-command defects and integration gaps remain. Passing unit tests alone did not reveal these defects.

## Open release blockers

1. **P1: Legacy queue commands operate on the wrong storage contract.** `src/azu_cli/commands/jobs/status.cr`, `clear.cr`, and `retry.cr` assume `joobq:queue:*` and `joobq:failed:*`. Supported JoobQ 0.4.2 stores a pending queue under its queue name (`RedisStore#queue_size` and `#clear_queue`). An isolated Redis reproduction seeded one job under `audit_queue`: `jobs:status` returned success with “No queues found”; `jobs:clear --queue audit_queue --force` returned success, and the queue still contained one job. These commands need the typed runtime adapter already used by `azu joobq`, with real store integration tests. Their presence in the dev command panel makes this relevant to the HUD too.
2. **P1: Legacy retry is not atomic.** `jobs/retry.cr` removes the payload with `RPOP` and then separately calls `LPUSH`. Failure between the calls loses that payload. Migrate retry to the runtime's atomic DLQ redrive API and report unsupported capabilities explicitly on older JoobQ releases. Do not emulate replay by guessing Redis keys.
3. **Release gate is incomplete.** `shard.yml` remains in the 0.x series (`0.1.56` on current master). `.github/workflows/crystal.yaml` computes a version from commits, changes the shard version after tests, and publishes automatically on master. Before v1, verify the squash/version strategy, assert the intended `1.0.0`, and ensure the tested tree, version bump, tag and release describe the same artifact. Hosted CI on the final reviewed commit still needs verification; the GitHub API is inaccessible from this environment.

## Missing integration and validation

- **Resolved in the compatibility follow-up:** Seed entry points previously needed consolidation: the generated `src/db/seed.cr` says `db:seed` loads it, but `SeedRunner` discovers environment/shared directories instead. Setup/reset gate directory-based seeding on that legacy file existing, and setup still ignores seed failures. The reset failure-propagation fix in this pass addresses only its ignored result. The follow-up unifies entry points, propagates setup/reset failures, tracks directory seeds and adds repeat-run/failure/reset tests against both server databases. See the compatibility evidence for completed runs.
- The requested PostgreSQL History Store dashboard binding is not implemented. `joobq_agent.cr` reports this explicitly; a custom provider interface exists. Runtime workflows alone do not satisfy historical PostgreSQL integration.
- `jobs:worker --workers/--queues` exports environment variables, but the generated initializer does not consume them. Configure queues and worker counts in the initializer until this behavior is implemented or these options are removed.
- **Hosted results pending:** Added actual PostgreSQL 18/MySQL 8.4 web/API generate–migrate–CRUD–rollback gates, including seed/reset failures, MySQL authentication with verified TLS, and telemetry. Adding gates is not a hosted pass.
- Docker smoke testing is now a required hosted release prerequisite for web and API. Local production-image validation exhausted cloud workspace disk space before compilation; packaging remains unverified.
- Azu 1.0.1 contains Errors/native SQL telemetry, but its CQL bridge cannot compile with CQL 1.0.0. Azu 1.0.2 released the bridge fix during this follow-up. Generated apps temporarily pin an explicit request-telemetry redaction patch on 1.0.2. Publish and test a compatible Azu release before release acceptance.
- CLI and generated CQL now pin 1.0.0; installs use the committed CLI lockfile. Stable framework update proposals and a release guard prevent silent canary promotion. Generated transitive dependencies still resolve at install time; evidence records each resolved lockfile.
- CQL 1.0.0 does not support persisting `JSON::Any` model attributes. The CLI rejects these models/scaffolds before writing broken code. Typed JSON persistence needs an upstream fix and its own release validation.

## Fixes applied during this review

- Preview application now detects stale targets, avoids nested symlink traversal, and writes recovery manifests/backups before changing project files. A later replacement failure can be undone. This is recoverable partial application, not an atomic multi-file transaction.
- Administrative database URLs preserve TLS/deadline query options, correctly round-trip credentials, and handle IPv6. Database identifiers are quoted for PostgreSQL/MySQL, and connection termination binds the database name as data.
- Database reset returns a seed failure instead of reporting complete success.
- Worker/UI launchers inherit stdout/stderr, avoiding unread pipe backpressure, and return failure on unsuccessful child exit. Missing JoobQUI is an error; a sibling JoobQUI checkout uses the correct path. Unsupported daemon mode is rejected.
- Configuration logging redacts URL passwords, including Redis password-only authentication.
- Added the generated CLI application to the hosted E2E matrix after verifying its generate/build/spec/run path locally.
- Updated generator recovery and job-command documentation, including the outstanding legacy queue limitation.

## Compatibility follow-up evidence

The [compatibility plan](v1-compatibility-plan.md#local-validation-evidence) records successful PostgreSQL 18/MySQL 8.4 web/API lifecycle and telemetry tests, 13 fresh browser checks, complete generator compilation/runtime checks, a real Redis worker round-trip, and a dependency-only upgrade of an existing 0.x generated SQLite app preserving five rows. Resolved lockfiles distinguish the temporary Azu commits used by each run. Docker packaging and hosted CI remain unverified; the Azu telemetry patch is not yet released.

## Earlier validation evidence

Local logs are under `/workspace/setup/logs/`; they are environment evidence, not committed artifacts.

- Initial complete suite: **1,459 examples, zero failures/errors** (`azu-cli-final-suite.log`).
- Updated complete suite: **1,469 examples, zero failures/errors** (`azu-cli-final-updated-suite.log`). Final URL serialization/redaction refinements made while this run was in progress were subsequently checked by the focused suite and a fresh CLI build; hosted CI must run the complete final tree.
- Fresh final CLI build, source formatting, shell/Python script syntax and all 46 documentation pages passed.
- Final focused database/job/preview regressions: **260 examples, zero failures/errors** (`azu-cli-final-safety.log`). These include encoded credentials, IPv6, TLS option retention, SQL identifier quoting, child compiler failures, missing UI, daemon rejection, password redaction, stale previews, symlinks and interrupted writes.
- Generated API: migration/CRUD, compilation, boot/HTTP and development-command checks passed (`azu-cli-final-api.log`). This run did not request a Redis worker roundtrip.
- Generated CLI: generate/build, one generated spec and execution passed (`azu-cli-final-cli.log`).
- Isolated legacy queue reproduction: `azu-cli-final-legacy-jobs.log`. Only a disposable Redis instance was mutated.
- Earlier evidence on this branch: web E2E including authentication, CSRF, development restart and a Redis worker roundtrip (`pr53-generated-web-fixed.log`); fresh Spark app generation/migration/build, four app specs and ten browser checks (`pr53-spark-fixed-e2e.log`); web/API generator compilation and both JoobQ adapter versions. These were not all rerun in this final pass.

Business-logic placeholders in jobs, services and custom middleware are intentional extension points. Mailer content and production delivery configuration still require application-specific implementation; generated starters do not demonstrate a real mail delivery integration.
