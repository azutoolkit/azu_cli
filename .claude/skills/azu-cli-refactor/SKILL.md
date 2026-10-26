---
name: azu-cli-refactor
description: |
  Automated analysis, review, and refactoring of the azu_cli codebase to ensure generated code strictly follows AZU, CQL, and JOOBQ framework patterns. Use this skill when asked to: (1) Analyze or audit azu_cli templates, (2) Refactor CLI generators for framework compliance, (3) Improve developer experience in azu_cli, (4) Ensure generated scaffolds follow best practices, (5) Create or update azu_cli code generators.
---

# AZU CLI Refactor Skill

Systematically analyze and refactor the azu_cli codebase to ensure all generated code follows AZU, CQL, and JOOBQ patterns strictly.

## Overview

This skill enables autonomous analysis and refactoring of Crystal's azu_cli tool to:
- Generate code that strictly adheres to AZU web framework patterns
- Produce CQL-compliant database schemas and migrations
- Create JOOBQ-compatible background job implementations
- Provide a productive, friendly developer workflow

## What the generators emit today (authoritative)

Read `CLAUDE.md` at the repository root first: it lists the emitted APIs and the quality rules. In short:

- CQL: `include CQL::ActiveRecord::Model(Int64)` + `db_context`, `CQL::Migration(<version>)` with `schema.table`, tables
  declared in `src/db/schema.cr`
- Azu: `struct Blog::Posts::CreateEndpoint` with `include Azu::Endpoint(Request, Response)`, ONE response type
  (`Azu::Response::Empty` + `redirect to:, status: 303`, or a page); naming `Blog::<Plural>::<Action><Layer>`
- Generators are Teeplate file trees (`Teeplate::FileTree`, ECR templates under `src/azu_cli/templates/`), not `ECR.render` classes
- Rules from review: validate names, no hard-coded secrets (ENV, random dev fallback, raise in production), escape output
  (`| e`), refuse to overwrite, 303 after writes, specs that can fail, never document commands that are not registered
- The gate is end-to-end: `scripts/e2e_generated_app.sh [web|api]` (compile, boot, curl) and `scripts/e2e_docker.sh`
  (the generated Dockerfile); a generator change is not done until the e2e passes

The code samples further down illustrate style; where they differ from the generators, the generators and CLAUDE.md win.

## Phase 1: Repository Analysis

### Step 1.1: Clone and Explore Repositories

```bash
# Create workspace
mkdir -p ~/azu-workspace && cd ~/azu-workspace

# Clone all repositories
git clone https://github.com/azutoolkit/azu_cli.git
git clone https://github.com/azutoolkit/azu.git
git clone https://github.com/azutoolkit/cql.git
git clone https://github.com/azutoolkit/joobq.git
```

### Step 1.2: Analyze AZU CLI Structure

Examine the azu_cli codebase structure:

```bash
# Identify key directories
find azu_cli -type f -name "*.cr" | head -50
find azu_cli -type f -name "*.ecr" | head -50  # Template files
ls -la azu_cli/src/
```

**Focus Areas:**
- `src/generators/` - Code generation logic
- `src/templates/` or `*.ecr` files - Template definitions
- `src/commands/` - CLI command implementations
- `shard.yml` - Dependencies and versioning

### Step 1.3: Extract Framework Patterns

For each framework, identify and document:

**AZU Framework Patterns** - See `references/azu-patterns.md`:
- Endpoint structure and conventions
- Request/Response handling
- Middleware patterns
- Router configuration
- Error handling patterns

**CQL Patterns** - See `references/cql-patterns.md`:
- Schema definitions
- Migration structure
- Query building conventions
- Model relationships
- Repository patterns

**JOOBQ Patterns** - See `references/joobq-patterns.md`:
- Job class structure
- Queue configuration
- Worker patterns
- Retry/failure handling
- Scheduling patterns

## Phase 2: Gap Analysis

### Step 2.1: Template Audit Checklist

For each template in azu_cli, verify compliance:

| Template | AZU Compliant | CQL Compliant | JOOBQ Compliant | DX Score |
|----------|---------------|---------------|-----------------|----------|
| endpoint | [ ] | N/A | N/A | /10 |
| model | N/A | [ ] | N/A | /10 |
| migration | N/A | [ ] | N/A | /10 |
| job | N/A | N/A | [ ] | /10 |
| channel | [ ] | N/A | N/A | /10 |

**DX Score Criteria:**
- Clear naming conventions (2 pts)
- Helpful comments/documentation (2 pts)
- Proper error handling (2 pts)
- Type safety (2 pts)
- Extensibility (2 pts)

### Step 2.2: Identify Anti-Patterns

Search for common issues:

```bash
# Hardcoded values
grep -rn "localhost\|127.0.0.1\|:3000" azu_cli/

# Missing type annotations
grep -rn "def.*\)" azu_cli/src/ | grep -v ":"

# Outdated patterns
grep -rn "HTTP::Server" azu_cli/  # Should use Azu patterns
```

### Step 2.3: Generate Gap Report

Create structured findings:

```markdown
## Gap Analysis Report

### Critical Issues (Must Fix)
1. [Issue]: [Description]
   - Location: [file:line]
   - Current: [code snippet]
   - Required: [expected pattern]
   - Priority: P0

### Improvements (Should Fix)
...

### Enhancements (Nice to Have)
...
```

## Phase 3: Systematic Refactoring

### Step 3.1: Refactoring Order

Execute in this sequence to minimize breakage:

1. **Foundation** - Core utilities and shared code
2. **Templates** - ECR templates for code generation
3. **Generators** - Generator classes that use templates
4. **Commands** - CLI command implementations
5. **Integration** - End-to-end workflows

### Step 3.2: Template Refactoring Pattern

For each template file:

```crystal
# BEFORE: Non-compliant template
class <%= name %>Endpoint
  include HTTP::Handler
  
  def call(context)
    # ... generic HTTP handling
  end
end

# AFTER: what the endpoint template emits (include, not inheritance; ONE response type)
module <%= @app_module %>
  struct <%= @plural %>::<%= @action %>Endpoint
    include Azu::Endpoint(<%= @plural %>::<%= @action %>Request, Azu::Response::Empty)

    post "/<%= @resource_plural %>"

    def call : Azu::Response::Empty
      record = <%= @plural %>::<%= @action %>Service.new.call(<%= @snake_action %>_request)
      redirect to: "/<%= @resource_plural %>/#{record.id}", status: 303
    end
  end
end
```

### Step 3.3: Generator Class Pattern

```crystal
module AzuCLI
  module Generate
    class Channel < Teeplate::FileTree
      directory "#{__DIR__}/../templates/channel"
      OUTPUT_DIR = "./src/channels"

      getter name : String

      def initialize(@name : String)
        # validate before anything is rendered: the name becomes Crystal code and a file name
      end
    end
  end
end
```

Templates live under `src/azu_cli/templates/<generator>/`; `{{ivar}}` in a file name is replaced by the instance
variable, a `.ecr` suffix is dropped. Register the generator in `Commands::Generate#execute`, and refuse to overwrite
what exists (see `Generate::Auth.conflict`).

## Phase 4: Developer Experience Enhancement

### Step 4.1: Interactive Prompts

Implement user-friendly prompts:

```crystal
module AzuCli
  class InteractivePrompt
    def self.endpoint_wizard
      puts "🚀 Creating new AZU Endpoint\n"
      
      module_name = prompt("Module name", default: "Api::V1")
      class_name = prompt("Endpoint name", validate: :pascal_case)
      http_method = select("HTTP method", %w[GET POST PUT PATCH DELETE])
      path = prompt("Route path", default: "/#{class_name.underscore}")
      
      {
        module_name: module_name,
        class_name: class_name,
        http_method: http_method,
        path: path
      }
    end
  end
end
```

### Step 4.2: Help Text Standards

Every command must include:

```crystal
class GenerateCommand < Admiral::Command
  define_help description: <<-DESC
    Generate AZU application components.
    
    USAGE:
      azu generate <component> <name> [options]
    
    COMPONENTS:
      endpoint    Create a new API endpoint
      model       Create a CQL model with migration
      job         Create a JOOBQ background job
      channel     Create a WebSocket channel
    
    EXAMPLES:
      azu generate endpoint Users::Show
      azu generate model User email:string name:string
      azu generate job SendWelcomeEmail --queue=emails
    
    For component-specific help:
      azu generate <component> --help
  DESC
end
```

### Step 4.3: Validation & Feedback

```crystal
module AzuCli
  module Validators
    def self.validate_and_report(context : GeneratorContext) : ValidationResult
      errors = [] of String
      warnings = [] of String
      
      # Check naming conventions
      unless valid_module_name?(context.module_name)
        errors << "Module name '#{context.module_name}' should be PascalCase"
      end
      
      # Check for conflicts
      if file_exists?(context.output_path)
        warnings << "File already exists: #{context.output_path}"
      end
      
      # Check dependencies
      unless shard_installed?("azu")
        errors << "AZU framework not found in shard.yml"
      end
      
      ValidationResult.new(errors, warnings)
    end
  end
end
```

## Phase 5: Testing & Validation

### Step 5.1: Generate Test Fixtures

For each generator, create expected output fixtures:

```
spec/
├── fixtures/
│   ├── endpoints/
│   │   ├── basic_endpoint.cr
│   │   ├── crud_endpoint.cr
│   │   └── authenticated_endpoint.cr
│   ├── models/
│   │   ├── simple_model.cr
│   │   └── model_with_relations.cr
│   └── jobs/
│       ├── basic_job.cr
│       └── scheduled_job.cr
└── generators/
    ├── endpoint_generator_spec.cr
    ├── model_generator_spec.cr
    └── job_generator_spec.cr
```

### Step 5.2: End-to-end gate

```bash
# Build the CLI, then generate, compile, boot and drive a project
shards build
scripts/e2e_generated_app.sh web      # or api; E2E_DB=postgresql only boots
scripts/e2e_docker.sh web             # needs a docker daemon; builds and runs the generated Dockerfile
```

Without Crystal on the host, run the first two inside `crystallang/crystal:1.22.1` (see CLAUDE.md). Extend the
script first with the assertion the change should satisfy, watch it fail, then change the generator.

## Phase 6: Documentation

### Step 6.1: Update CLI Help

Ensure all commands have comprehensive `--help`:

```
$ azu --help
AZU CLI - Crystal Web Framework Code Generator

VERSION: x.x.x

COMMANDS:
  new <name>        Create a new AZU application
  generate <type>   Generate application components
  routes            Display application routes
  db                Database management commands
  server            Start development server

OPTIONS:
  -h, --help        Show this help
  -v, --version     Show version
  --verbose         Enable verbose output

EXAMPLES:
  azu new my_api --api-only
  azu generate endpoint Users::Show
  azu db migrate

DOCUMENTATION:
  https://azutoolkit.github.io/azu/
```

### Step 6.2: Generator Documentation

Each generator should output helpful next steps:

```
✅ Created endpoint: src/endpoints/users/show.cr

Next steps:
  1. Add route to config/routes.cr:
     
     get "/users/:id", Users::Show
     
  2. Implement the endpoint logic in:
     src/endpoints/users/show.cr
     
  3. Add specs in:
     spec/endpoints/users/show_spec.cr

Documentation: https://azutoolkit.github.io/azu/endpoints
```

## Execution Checklist

Use this checklist to track refactoring progress:

```markdown
## AZU CLI Refactor Progress

### Phase 1: Analysis
- [ ] Clone all repositories
- [ ] Map azu_cli directory structure
- [ ] Document AZU patterns
- [ ] Document CQL patterns  
- [ ] Document JOOBQ patterns

### Phase 2: Gap Analysis
- [ ] Audit all templates
- [ ] Identify anti-patterns
- [ ] Generate gap report
- [ ] Prioritize issues

### Phase 3: Refactoring
- [ ] Refactor core utilities
- [ ] Update endpoint templates
- [ ] Update model templates
- [ ] Update migration templates
- [ ] Update job templates
- [ ] Update channel templates
- [ ] Update generator classes
- [ ] Update CLI commands

### Phase 4: Developer Experience
- [ ] Implement interactive prompts
- [ ] Standardize help text
- [ ] Add validation feedback
- [ ] Improve error messages

### Phase 5: Testing
- [ ] Create test fixtures
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Manual testing

### Phase 6: Documentation
- [ ] Update CLI help
- [ ] Add generator docs
- [ ] Update README
- [ ] Create CHANGELOG
```

## Quick Reference Commands

```bash
# Analyze current templates
find . -name "*.ecr" -exec echo "=== {} ===" \; -exec cat {} \;

# Find all generator classes
grep -rn "class.*Generator" src/

# Check for AZU imports
grep -rn "require.*azu" src/

# Verify CQL patterns
grep -rn "CQL\|Cql" src/

# Find JOOBQ references
grep -rn "Joobq\|JOOBQ" src/

# Run tests
crystal spec

# Build CLI
crystal build src/azu_cli.cr -o bin/azu
```
