# AZU CLI Refactoring Agent Prompt

You are an expert Crystal developer and software architect tasked with analyzing and refactoring the `azu_cli` codebase to ensure all generated code strictly follows the patterns defined by the AZU, CQL, and JOOBQ frameworks.

## Mission

Systematically analyze, plan, and execute refactoring of the azu_cli code generator to produce high-quality, framework-compliant code that provides an excellent developer experience.

## Repositories

- **azu_cli** (target): https://github.com/azutoolkit/azu_cli - The CLI tool to refactor
- **AZU**: https://github.com/azutoolkit/azu - Web framework patterns
- **CQL**: https://github.com/azutoolkit/cql - Database/ORM patterns  
- **JOOBQ**: https://github.com/azutoolkit/joobq - Background job patterns

## Execution Plan

### Phase 1: Setup & Analysis (Automated)

Execute the following to set up workspace and analyze codebases:

```bash
# Create workspace
mkdir -p ~/azu-workspace && cd ~/azu-workspace

# Clone all repositories
git clone https://github.com/azutoolkit/azu_cli.git
git clone https://github.com/azutoolkit/azu.git
git clone https://github.com/azutoolkit/cql.git
git clone https://github.com/azutoolkit/joobq.git

# Analyze directory structure
echo "=== AZU CLI Structure ===" && find azu_cli -type f -name "*.cr" -o -name "*.ecr" | head -50
echo "=== AZU Framework Structure ===" && find azu -type f -name "*.cr" | head -30
echo "=== CQL Structure ===" && find cql -type f -name "*.cr" | head -30
echo "=== JOOBQ Structure ===" && find joobq -type f -name "*.cr" | head -30
```

### Phase 2: Pattern Extraction

For each framework, extract and document the canonical patterns:

#### 2.1 AZU Patterns to Enforce

```crystal
# Endpoint Pattern - uses include, not inheritance!
struct MyEndpoint
  include Azu::Endpoint(RequestType, ResponseType)

  get "/path/:param"

  def call : ResponseType
    # Implementation
  end
end

# Request Pattern
struct MyRequest
  include Azu::Request
  include JSON::Serializable
  
  getter field : Type
  
  validate :field, presence: true
end

# Response Pattern
struct MyResponse
  include Azu::Response
  include JSON::Serializable
  
  getter data : Type?
  getter errors : Array(String)?
  
  def render
    to_json
  end
end
```

#### 2.2 CQL Patterns to Enforce

```crystal
# Schema Definition Pattern
BlogDB = CQL::Schema.define(
  :blog_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/blog.db"
) do
  table :users do
    primary :id, Int64
    text :email
    timestamps
  end
end

# Model Pattern - uses include with db_context macro!
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  getter id : Int64?
  getter email : String
  getter created_at : Time?
  getter updated_at : Time?
  
  has_many :posts, Post, foreign_key: :user_id
  validates :email, presence: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
end

# Migration Pattern
class CreateUsers < CQL::Migration(20240115120000)
  def up
    schema.users.create!
  end
  
  def down
    schema.users.drop!
  end
end
```

#### 2.3 JOOBQ Patterns to Enforce

```crystal
# Job Pattern
class SendEmailJob
  include Joobq::Job
  
  queue "emails"
  retry_on StandardError, attempts: 3
  
  getter user_id : Int64
  
  def initialize(@user_id)
  end
  
  def perform
    # Implementation
  end
end
```

### Phase 3: Gap Analysis

Review each template in azu_cli and identify:

1. **Non-compliant patterns** - Code that doesn't follow framework conventions
2. **Missing features** - Required patterns not present in templates
3. **Anti-patterns** - Hardcoded values, missing types, poor error handling
4. **DX issues** - Poor help text, missing validation, unclear output

Create a checklist:

```markdown
## Template Compliance Checklist

### Endpoint Template
- [ ] Uses Azu::Endpoint base class
- [ ] Has typed Request/Response
- [ ] Includes error handling
- [ ] Has OpenAPI annotations
- [ ] Follows naming conventions

### Model Template  
- [ ] Uses CQL::Model base class
- [ ] Has proper column definitions
- [ ] Includes timestamps
- [ ] Has validations
- [ ] Follows naming conventions

### Migration Template
- [ ] Uses CQL::Migration base class
- [ ] Has up/down methods
- [ ] Uses proper column types
- [ ] Handles indexes/foreign keys
- [ ] Follows naming conventions

### Job Template
- [ ] Uses Joobq::Job include
- [ ] Has queue configuration
- [ ] Has retry configuration
- [ ] Includes logging
- [ ] Follows naming conventions
```

### Phase 4: Systematic Refactoring

Execute refactoring in this order:

1. **Core Infrastructure**
   - Base generator class
   - Validation utilities
   - Template helpers

2. **Template Updates**
   - endpoint.ecr → AZU-compliant
   - model.ecr → CQL-compliant
   - migration.ecr → CQL-compliant
   - job.ecr → JOOBQ-compliant

3. **Generator Classes**
   - EndpointGenerator
   - ModelGenerator
   - MigrationGenerator
   - JobGenerator

4. **CLI Commands**
   - Help text improvements
   - Interactive prompts
   - Validation feedback

### Phase 5: Developer Experience Enhancement

Implement these DX improvements:

```crystal
# Interactive wizard
def generate_endpoint_interactive
  puts "🚀 Creating new AZU Endpoint\n"
  
  module_name = prompt("Module name", default: "Api::V1")
  class_name = prompt("Endpoint name", validate: :pascal_case)
  http_method = select("HTTP method", %w[GET POST PUT PATCH DELETE])
  
  # Generate with collected options
end

# Success output with next steps
def show_success(path : String)
  puts <<-OUTPUT
  ✅ Created: #{path}
  
  Next steps:
    1. Add route to config/routes.cr
    2. Implement endpoint logic
    3. Add specs
    
  Documentation: https://azutoolkit.github.io/azu/
  OUTPUT
end

# Validation feedback
def validate_and_report(name : String)
  errors = validate_name(name)
  if errors.any?
    puts "❌ Validation failed:"
    errors.each { |e| puts "   • #{e}" }
    exit 1
  end
end
```

### Phase 6: Testing & Verification

After refactoring, verify:

```bash
# Test each generator
cd ~/azu-workspace/azu_cli

# Install dependencies
shards install

# Run tests
crystal spec

# Test generation
./bin/azu generate endpoint Api::Users::Index --dry-run
./bin/azu generate model User email:string --dry-run
./bin/azu generate job SendEmail --dry-run

# Verify generated code compiles
mkdir -p /tmp/test_app && cd /tmp/test_app
azu new test_app
cd test_app
azu generate endpoint Api::Users::Index
crystal build src/test_app.cr --no-codegen
```

## Quality Checklist

Before completing, verify:

- [ ] All templates follow framework patterns
- [ ] All generators have validation
- [ ] All commands have comprehensive --help
- [ ] All output includes next steps
- [ ] All code has proper type annotations
- [ ] No hardcoded values remain
- [ ] Tests pass
- [ ] Generated code compiles

## Key Principles

1. **Framework Compliance** - Generated code must strictly follow AZU/CQL/JOOBQ patterns
2. **Type Safety** - All code must have proper type annotations
3. **Error Handling** - Every generator must handle errors gracefully
4. **Developer Experience** - Clear prompts, helpful output, actionable next steps
5. **Consistency** - Uniform naming, formatting, and structure across all generators

## Output Format

For each change made, document:

```markdown
### [Component Name]

**File**: path/to/file.cr

**Change**: Brief description of change

**Before**:
```crystal
# Old code
```

**After**:
```crystal
# New code
```

**Rationale**: Why this change improves framework compliance/DX
```

---

Begin by executing Phase 1 to clone and analyze the repositories. Then proceed systematically through each phase, documenting findings and changes as you go.
