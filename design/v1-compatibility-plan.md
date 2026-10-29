# Azu and CQL v1 compatibility plan

## Implementation status — 2026-10-29

Implementation is on `codex/azu-cql-v1-compatibility`, based on the CLI PR #53 work and its pending operational-safety follow-up. PR #53 merged during validation; this branch is aligned with master 0.1.56. The alignment changed only the CLI version declaration; a fresh build verifies that metadata. This is **not a release sign-off**. Stable tags were rechecked: Azu `1.0.2`, CQL `1.0.0`. Azu `1.0.2` appeared during this work.

| Area | Implementation and remaining acceptance |
| --- | --- |
| Dependency baseline | CLI and generated apps pin CQL `1.0.0`; isolated install and CLI build passed. Generated Azu temporarily pins `69163988a48e28b809ad09929f5d7f9bfb1079ee`, based on `1.0.2`. The private-constant bridge fix is now released in `1.0.2`; request-telemetry redaction is still an explicit unreleased patch. |
| Azu prerequisite | `codex/cql-v1-private-constants` includes the released private-alias fix and additionally redacts query secrets in request metrics. The bridge passed 114 integration specs; redaction has a failing-before/passing-after regression (7 telemetry specs). Merge and publish a compatible Azu release, then replace the temporary pin through full compatibility CI. |
| Direct CQL commands | MySQL uses optional `cql/mysql`; CLI includes SQLite. Seeds load app configuration/schema/models, discover legacy/shared/environment files, track project-relative completion names, propagate failures and preserve child environment isolation. Seeds must be idempotent; effects and completion records are not one transaction. Migration runner files use exclusive random names and mode 0600. |
| Generated APIs | Date fields now expose `Time` and use the SQL date DSL; UUID fields use portable text columns and typed DB converters; request forms decode UUID/JSON/date values. Expanded generator validation compiles scalars/relationships and executes persistence. CQL `1.0.0` cannot persist `JSON::Any` ActiveRecord attributes; model/scaffold generation rejects that case before writing files. Standalone JSON requests and migration columns remain supported. |
| Runtime coverage | Added disposable PostgreSQL 18 and MySQL 8.4 web/API generate–migrate–rollback–seed–reset–HTTP CRUD tests, including verified MySQL TLS/CA rejection and real SQL/error/pool telemetry with secret redaction. Browser and Redis-worker gates remain required. Local results are recorded below. |
| CI | Required database and production-image matrices, daisyUI plus Spark browser tests, frozen CLI installs, explicit Azu/CQL test inputs and evidence uploads. Weekly stable-v1 update workflow proposes draft PRs and explicitly dispatches compatibility CI. Release guard rejects unreleased/stale pins. Hosted results on the final commit are still required. |
| Packaging | Docker validation reached generated image dependency installation, then exhausted this cloud workspace's disk space before compilation. This is not a successful packaging result; the hosted production-image gate remains mandatory. |

The intended released-pair acceptance criteria below remain unchanged. An explicit patch pin permits testing and review; it does not satisfy those criteria. The separate CLI release-version/artifact gate and legacy JoobQ operator defects remain in [the readiness review](final-readiness-review.md).

## Local validation evidence

All runs used Crystal **1.22.1** and real installed shards in isolated worktrees/projects. Logs are under `/workspace/setup/logs/`; temporary fixture evidence contains its actual resolved `shard.lock`.

| Validation | Result and evidence |
| --- | --- |
| PostgreSQL 18 web | Passed lifecycle, seeds/reset/failures, HTTP CRUD and redacted telemetry. `azu-cli-v1-postgres-web-final.log`; `/tmp/azu-db-e2e-12rj5nzs/evidence`. |
| PostgreSQL 18 API | Passed the same checks. `azu-cli-v1-postgres-api-final.log`; `/tmp/azu-db-e2e-wvf19r6l/evidence`. |
| MySQL 8.4 API | Passed lifecycle, verified TLS/caching_sha2 authentication, untrusted CA rejection, seeds and HTTP/telemetry. `azu-cli-v1-mysql-api-final.log`; `/tmp/azu-db-e2e-0yvvujpk/evidence`. |
| MySQL 8.4 web | Passed the same checks. `azu-cli-v1-mysql-web-final.log`; `/tmp/azu-db-e2e-gyswsnf9/evidence`. |
| Complete generators | Web/API compile and execute scalar/date/UUID/nullable-UUID persistence, belongs_to mapping, form decoding, generated mailers/jobs, validator and component. Web additionally passes its generated Spark spec. `azu-cli-v1-generators-web-final.log`, `azu-cli-v1-generators-api-complete.log`. |
| Generated web lifecycle | Passed HTTP CRUD/authentication/CSRF, production-secret failures, `azu dev` rebuild/restart/failure recovery and a real Redis worker round-trip/SIGTERM. `azu-cli-v1-web-final.log`. |
| Browser | **13 checks passed**, including mobile/no-JavaScript paths, authentication, WebSockets, incremental migration/rollback/data preservation, restart and generated specs. `/tmp/azu-browser-e2e-v8KMr2/evidence/report.json` and its resolved lockfile. |
| Spark live CRUD | **10 browser checks and 4 generated specs passed** in `/tmp/azu-spark-e2e-whfvFN`; `azu-cli-v1-spark.log`. |
| Existing 0.x application upgrade | Copied an existing Azu 0.10.5/CQL 0.0.604 browser app; changed dependencies only, built, migrated its database, preserved all 5 product rows and served `/health` and `/products`. All `src`, `config` and `public` files remained byte-identical. `/tmp/azu-v1-upgrade-dwsfl_rm/report.json`. This is one tested generated SQLite app, not certification of every customized 0.x app. |
| Full CLI suite | **1,479 examples, zero failures/errors**, `azu-cli-v1-complete-suite.log`. The final dependency-selector contract refinement additionally passed its 51 focused specs. |
| Focused regressions | **407 generator/command specs**, **51 dependency-selector contract specs**, **7 Azu telemetry specs**, **3 dependency-promotion guard tests** passed. |
| Static/documentation checks | Source/spec formatting, shell/Python syntax, workflow YAML parsing, diff whitespace and all **46 documentation pages** passed. |

The first PostgreSQL-web/MySQL-API and Redis-worker runs used Azu `aaf286a…`; the final PostgreSQL-API/MySQL-web, generator, browser and upgrade fixtures use `6916398…`. The latter merges released Azu 1.0.2 and differs from `aaf286a…` only in its version declaration. The earlier Spark run used `5af867a…`, before the request-telemetry redaction patch. Retained lockfiles identify these precisely. Hosted CI must run all gates on the final reviewed dependency inputs; these local runs do not substitute for it.

## Goal and verified starting point

Make Azu CLI and its generated applications work with the latest stable Azu and CQL v1 releases. This is an implementation plan, not a compatibility sign-off.

Historical baseline at the start of 2026-10-29, before Azu 1.0.2 was released:

| Dependency | Latest observed v1 tag | Current CLI/generated application configuration |
| --- | --- | --- |
| Azu | `v1.0.1` | Generated projects use `~> 0.10.1` |
| CQL | `v1.0.0` | Generated projects use `0.0.604`; CLI uses `branch: master`, with `0.0.578+git.commit.f7fe5246…` in its lockfile |

Recheck tags when implementation starts. Verify each tag's shard manifest, release notes and Crystal requirements before selecting it. Existing 0.x test results do not establish v1 compatibility.

## 1. Establish reproducible v1 dependency inputs

- Inspect released Azu/CQL code and migration guidance, including transitive constraints on crystal-db, PostgreSQL/MySQL/SQLite drivers, session and JoobQ.
- Start in an isolated checkout with its own installed shards; do not use the workspace's shared `lib` symlink as evidence of clean installation.
- Replace the CLI's CQL master dependency with the tested v1 release and regenerate `shard.lock`.
- Update `src/azu_cli/templates/project/shard.yml.ecr` to the tested Azu/CQL v1 releases. Initially pin exact versions; automated update PRs will keep these pins current within v1.
- Retain dependency-free generated CLI applications; apply framework/ORM requirements to web/API applications and to optional features that need them.
- Audit hardcoded versions and dependency injection in examples, specs, scripts and documentation. Add explicit version inputs for both Azu and CQL to compatibility tests, replacing the Azu-only branch override as the release-validation mechanism.

Acceptance: clean dependency installation resolves the intended released versions for the CLI and fresh web/API projects; committed locks and test reports identify the resolved versions. No dependency silently resolves to an unreleased checkout.

## 2. Adapt the CLI's direct CQL integration

- Compile the CLI against CQL v1 and inventory API changes in schema construction, adapters, query execution, migration runners, schema dumps and seeds.
- Update database create/drop/setup/migrate/status/rollback/reset/seed commands and generator schema registration to the released API.
- Preserve TLS options, credentials, deadlines and failure exit codes. Use CQL's supported optional MySQL integration where required by its released MySQL 8.4 authentication API; validate this against the actual release.
- Consolidate seed entry points: generated seed instructions, directory discovery and setup/reset must agree. Propagate failures and verify repeat execution does not duplicate seed effects.

Acceptance: CLI builds and its specs pass on the supported Crystal floor and latest stable Crystal. Real database tests demonstrate migration, rollback, seed failure reporting and repeat-run behavior.

## 3. Adapt every generated application surface

- Compare generated startup and configuration with Azu v1: routing, endpoint contracts, middleware order, sessions, authentication, CSRF, static assets, templates, WebSockets and Spark lifecycle.
- Check CQL v1 model/schema mappings, relationships, field types, validations, migrations and CRUD operations emitted by every applicable generator.
- Update standalone generators as well as project/scaffold templates; a standalone generator must work inside a v1 application it did not create.
- Validate generated specs, example tasks, worker entry points and application startup/shutdown against the new dependency graph.
- Preserve daisyUI pages and automatic navigation registration, including repeated generation and existing customized navigation.

Acceptance: the generator inventory maps every generator to a compile test or executable behavioral test. Web/API fixtures compile with all applicable outputs, with no reliance on 0.x-only methods.

## 4. Validate telemetry and live components against released APIs

- Verify that released Azu v1 exposes the Errors/request telemetry hooks used by `azu dev`; remove assumptions about the companion development branch.
- Verify CQL v1 query instrumentation, latency and pool snapshots through the supported Azu/CQL integration. Test bounded delivery and parameter/secret redaction.
- Exercise Errors and SQL tabs with a real exception and real database queries, including oversized details and unavailable telemetry.
- Exercise Spark create/edit/save/delete, validation failure, reconnect and navigation in a browser. Synchronize browser tests on application state rather than timing delays.

Acceptance: telemetry and Spark evidence comes from released Azu/CQL tags. Missing optional capabilities are reported clearly; the default generated app cannot advertise unsupported tabs as working.

## 5. Expand end-to-end and release CI

Use staged coverage to keep the matrix practical:

| Gate | Required coverage |
| --- | --- |
| CLI build/spec | Tested v1 lockfile on minimum supported and latest stable Crystal |
| All generators | Web/API generator compilation on the released dependency pair |
| Generated app E2E | Web/API on SQLite, PostgreSQL and MySQL 8.4; dependency-free CLI build/spec/run |
| Database behavior | Create, migrate twice, schema registration, CRUD, rollback/reapply, seed/reset and intentional failure exit codes |
| Browser | daisyUI navigation, authentication/session/CSRF and full Spark CRUD on SQLite; PostgreSQL persistence smoke |
| Telemetry | Real exception/query events reach the dev HUD, with redaction and bounded payloads |
| Jobs | Real Redis worker roundtrip and supported JoobQ adapter versions with the v1 dependency graph |
| Packaging | Generated production Docker build and boot using the same tested dependency versions |

- PostgreSQL must execute migrations and CRUD; the current compile/boot-only PostgreSQL job is insufficient.
- MySQL must validate the authentication/TLS configuration required by the supported release, including rejection of invalid certificates where verification is enabled.
- Run the whole suite on the final reviewed commit and upload resolved lockfiles, failing logs and browser evidence.
- Run a scheduled compatibility job that checks the latest stable 1.x tags. It should propose dependency/lockfile updates and pass these gates before generated defaults change. Master-branch canaries may be informative but must not substitute for release tests.

Acceptance: all required hosted gates pass on the reviewed commit, with no skipped mandatory integrations. Expected unsupported-feature tests are explicit and do not mask compilation failures.

## 6. Documentation and release acceptance

- Publish a tested compatibility table: CLI version, Azu/CQL versions, Crystal range, database versions and optional capabilities.
- Document upgrades for existing 0.x generated projects separately from fresh v1 generation. Include dependency changes, migration/seed changes, middleware/session configuration and telemetry setup. Do not silently rewrite customized applications.
- Replace stale dependency comments and development-branch-only instructions with released APIs verified by the tests.
- Update the readiness review with evidence for each resolved gap. Carry forward unrelated blockers: legacy queue key assumptions, non-atomic retry and the absent PostgreSQL History Store provider are not solved merely by upgrading dependencies.
- Before an Azu CLI v1 release, assert the intended version and verify that the tested source, lockfile, tag and release artifact agree. Dependency compatibility and CLI release readiness are separate acceptance decisions.

## Completion criteria

1. A clean installation builds the CLI against released CQL v1.
2. Fresh web/API apps resolve the latest tested Azu/CQL v1 pair and pass generation, migration, runtime and browser gates.
3. Existing applications have a documented, tested upgrade path.
4. Hosted CI is green on the exact reviewed commit and records its resolved versions.
5. Latest stable v1 releases are checked automatically, with failures blocking dependency promotion.

Implementation order: dependency baseline → direct CQL commands → generated APIs → telemetry/Spark → full CI → documentation and release review. Land reviewable commits in that order; do not merge or publish a release as part of planning.
