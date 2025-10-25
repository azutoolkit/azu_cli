# Table of contents

## Overview

- [Introduction](README.md)
- [Installation](getting-started/installation.md)
- [Quick Start](getting-started/quick-start.md)
- [Project Structure](getting-started/project-structure.md)
- Configuration
  - [Configuration Overview](configuration/README.md)
  - [Project Configuration](configuration/project-config.md)
  - [Database Configuration](configuration/database-config.md)
  - [Development Server Configuration](configuration/dev-server-config.md)
  - [Generator Configuration](configuration/generator-config.md)
  - [Environment Variables](configuration/environment.md)

## Command Reference

- [Command Overview](commands/README.md)
- [azu new](commands/new.md)
- [azu init](commands/init.md)
- [azu generate](commands/generate.md)
- [azu serve](commands/serve.md)
- [azu dev](commands/dev.md)
- [azu test](commands/test.md)
- [Background Jobs Commands](commands/jobs.md)
  - [azu jobs:worker](commands/jobs.md#azu-jobsworker)
  - [azu jobs:status](commands/jobs.md#azu-jobsstatus)
  - [azu jobs:clear](commands/jobs.md#azu-jobsclear)
  - [azu jobs:retry](commands/jobs.md#azu-jobsretry)
  - [azu jobs:ui](commands/jobs.md#azu-jobsui)
- [Session Management Commands](commands/session.md)
  - [azu session:setup](commands/session.md#azu-sessionsetup)
  - [azu session:clear](commands/session.md#azu-sessionclear)
- [Database Commands](commands/database.md)
  - [azu db:create](commands/database.md#azu-dbcreate)
  - [azu db:migrate](commands/database.md#azu-dbmigrate)
  - [azu db:rollback](commands/database.md#azu-dbrollback)
  - [azu db:seed](commands/database.md#azu-dbseed)
  - [azu db:reset](commands/database.md#azu-dbreset)
  - [azu db:status](commands/database.md#azu-dbstatus)
  - [azu db:setup](commands/database.md#azu-dbsetup)
  - [azu db:drop](commands/database.md#azu-dbdrop)
- [OpenAPI Commands](commands/openapi.md)
  - [azu openapi:generate](commands/openapi.md#azu-openapigenerate)
  - [azu openapi:export](commands/openapi.md#azu-openapiexport)
- [azu plugin](commands/plugin.md)
- [azu help](commands/help.md)
- [azu version](commands/version.md)
- [CLI Options Reference](reference/cli-options.md)

## Generators

- [Generators Overview](generators/README.md)
- [Endpoint Generator](generators/endpoint.md)
- [Model Generator](generators/model.md)
- [Service Generator](generators/service.md)
- [Middleware Generator](generators/middleware.md)
- [Contract Generator](generators/contract.md)
- [Page Generator](generators/page.md)
- [Component Generator](generators/component.md)
- [Custom Validator Generator](generators/custom-validator.md)
- [Migration Generator](generators/migration.md)
- [Data Migration Generator](generators/data-migration.md)
- [Authentication Generator](generators/auth.md)
- [Channel Generator](generators/channel.md)
- [Mailer Generator](generators/mailer.md)
- [Scaffold Generator](generators/scaffold.md)

## Architecture & Internals

- [Architecture Overview](architecture/README.md)
- [CLI Framework (Topia)](architecture/cli-framework.md)
- [Generator System](architecture/generator-system.md)
- [Template Engine (ECR)](architecture/template-engine.md)
- [Configuration System](architecture/configuration.md)
- [Plugin System](architecture/plugins.md)

## Help & Contributing

- [Common Issues](troubleshooting/README.md)
- [Contributing Guide](contributing/README.md)
