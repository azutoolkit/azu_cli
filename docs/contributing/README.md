# Contributing to Azu CLI

Thank you for your interest in contributing to Azu CLI! This guide will help you get started with contributing to the project.

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- [Crystal](https://crystal-lang.org/install/) 1.16.0 or later
- [Git](https://git-scm.com/) for version control
- A GitHub account for submitting pull requests
- Basic knowledge of Crystal programming language

### Development Setup

1. **Fork the repository**

   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/your-username/azu_cli.git
   cd azu_cli
   ```

2. **Install dependencies**

   ```bash
   shards install
   ```

3. **Set up development environment**

   ```bash
   # Create development configuration
   cp config/application.yml.example config/development.yml

   # Set up database (if needed)
   azu db:create
   azu db:migrate
   ```

4. **Run tests**
   ```bash
   crystal spec
   ```

## Development Workflow

### 1. Create a Feature Branch

```bash
# Create and switch to a new branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/your-bug-description
```

### 2. Make Your Changes

Follow these guidelines when making changes:

- **Write tests** for new functionality
- **Update documentation** for any new features
- **Follow coding standards** (see below)
- **Keep commits atomic** and well-described

### 3. Test Your Changes

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/your_test_spec.cr

# Run with coverage
crystal spec --coverage

# Format code
crystal tool format

# Check for issues
ameba
```

### 4. Submit a Pull Request

1. **Push your branch**

   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create a pull request** on GitHub

   - Use the provided PR template
   - Describe your changes clearly
   - Link any related issues

3. **Wait for review** and address feedback

## Coding Standards

### Crystal Code Style

Follow Crystal's official style guide:

```crystal
# Good: Use 2 spaces for indentation
class MyClass
  def my_method
    puts "Hello, World!"
  end
end

# Good: Use snake_case for methods and variables
def calculate_total_price
  base_price + tax_amount
end

# Good: Use PascalCase for classes and modules
class UserService
  module Constants
    MAX_RETRIES = 3
  end
end
```

### File Organization

```crystal
# Good: Organize files logically
src/
├── azu_cli/
│   ├── commands/           # Command implementations
│   ├── generators/         # Generator implementations
│   ├── templates/          # ECR templates
│   ├── config.cr           # Configuration management
│   └── utils.cr            # Utility functions
```

### Documentation

Document all public APIs:

```crystal
# Good: Document public methods
class UserService
  # Creates a new user with the given attributes
  #
  # @param attributes [Hash(String, String)] User attributes
  # @return [User] The created user
  # @raise [ValidationError] If attributes are invalid
  def self.create_user(attributes : Hash(String, String)) : User
    # Implementation
  end
end
```

### Testing

Write comprehensive tests:

```crystal
# spec/services/user_service_spec.cr
describe UserService do
  describe ".create_user" do
    it "creates a user with valid attributes" do
      attributes = {"name" => "John Doe", "email" => "john@example.com"}

      user = UserService.create_user(attributes)

      user.name.should eq("John Doe")
      user.email.should eq("john@example.com")
    end

    it "raises error with invalid attributes" do
      attributes = {"name" => "", "email" => "invalid-email"}

      expect_raises(ValidationError) do
        UserService.create_user(attributes)
      end
    end
  end
end
```

### Testing CLI Commands and Generators

When testing CLI commands, especially those that generate projects or files, follow these conventions:

#### Use Temporary Directories

**Always** create test projects in temporary directories, not in the main repository:

```crystal
# Good: Use a temporary directory
it "generates a new project" do
  Dir.cd("/tmp") do
    Azu::Commands::New.new("test_project", {} of String => String).call
    Dir.exists?("/tmp/test_project").should be_true
    FileUtils.rm_rf("/tmp/test_project") # Clean up
  end
end

# Bad: Creates files in the repository
it "generates a new project" do
  Azu::Commands::New.new("test_project", {} of String => String).call
  Dir.exists?("test_project").should be_true
end
```

#### Manual Testing Cleanup

If you manually test CLI commands during development:

1. **Always use `/tmp` or a dedicated test directory**:

   ```bash
   # Good: Test in /tmp
   cd /tmp
   azu new test_project
   cd test_project
   # ... test functionality
   cd ..
   rm -rf test_project
   ```

2. **Clean up immediately after testing**:

   ```bash
   # Clean up test projects
   rm -rf /tmp/test_*
   rm -rf /tmp/*_test_project
   ```

3. **Never commit test projects** - The `.gitignore` file is configured to ignore:
   - `/test_*/` - Test projects starting with "test\_"
   - `/tmp_*/` - Temporary test projects
   - `/playground_*/` - Playground projects
   - `*_test_project/` - Projects ending with "\_test_project"
   - `/tmp/` - Temporary directory
   - `test_*.cr` - Test script files (except in `spec/`)
   - `/123*/` and `/*invalid*/` - Invalid project names

#### Integration Testing Best Practices

```crystal
# Use helper method for test projects
def with_test_project(name : String, &)
  test_dir = "/tmp/azu_test_#{Random::Secure.hex(8)}"
  Dir.mkdir_p(test_dir)

  begin
    Dir.cd(test_dir) do
      yield
    end
  ensure
    FileUtils.rm_rf(test_dir)
  end
end

# Usage
it "generates project structure" do
  with_test_project("myapp") do
    Azu::Commands::New.new("myapp", {} of String => String).call
    Dir.exists?("myapp/src").should be_true
  end
  # Cleanup happens automatically
end
```

#### Checklist Before Committing

- [ ] No test projects in repository root
- [ ] All test scripts removed or in proper location
- [ ] Manual test files cleaned up
- [ ] Integration tests use temporary directories
- [ ] Test cleanup code is present

## Adding New Commands

### 1. Create Command File

```crystal
# src/azu_cli/commands/my_command.cr
class Azu::Commands::MyCommand < Azu::Commands::Base
  def initialize(@name : String, @options : Hash(String, String))
  end

  def call
    # Command implementation
    puts "Executing my command: #{@name}"
  end

  def self.help : String
    "Description of what this command does"
  end
end
```

### 2. Add Command to Registry

```crystal
# src/azu_cli/command.cr
module Azu::Commands
  # Add your command to the registry
  COMMANDS["my-command"] = MyCommand
end
```

### 3. Write Tests

```crystal
# spec/azu_cli/commands/my_command_spec.cr
describe Azu::Commands::MyCommand do
  describe "#call" do
    it "executes the command successfully" do
      command = Azu::Commands::MyCommand.new("test", {} of String => String)

      # Test command execution
      command.call

      # Assert expected behavior
    end
  end
end
```

### 4. Update Documentation

````markdown
# docs/commands/my-command.md

# My Command

Description of the command and its usage.

## Usage

```bash
azu my-command NAME [OPTIONS]
```
````

## Examples

```bash
azu my-command example
```

````

## Adding New Generators

### 1. Create Generator Class

```crystal
# src/azu_cli/generators/my_generator.cr
class Azu::Generators::MyGenerator < Azu::Generators::Base
  def initialize(@name : String, @options : Hash(String, String))
  end

  def generate
    # Generator implementation
    create_file("src/models/#{@name.underscore}.cr", render_model_template)
    create_file("spec/models/#{@name.underscore}_spec.cr", render_spec_template)
  end

  private def render_model_template : String
    ECR.render("src/templates/generators/my_generator/model.cr.ecr")
  end

  private def render_spec_template : String
    ECR.render("src/templates/generators/my_generator/model_spec.cr.ecr")
  end
end
````

### 2. Create Templates

```crystal
# src/templates/generators/my_generator/model.cr.ecr
class <%= @name.camelcase %> < CQL::Model
  table :<%= @name.underscore.pluralize %>

  # Add your columns here
  # column :name, String

  timestamps
end
```

### 3. Add Generator to Command

```crystal
# src/azu_cli/commands/generate.cr
class Azu::Commands::Generate < Azu::Commands::Base
  def call
    case @subcommand
    when "my-generator"
      Azu::Generators::MyGenerator.new(@name, @options).generate
    # ... other generators
    end
  end
end
```

### 4. Write Tests

```crystal
# spec/azu_cli/generators/my_generator_spec.cr
describe Azu::Generators::MyGenerator do
  describe "#generate" do
    it "creates model file" do
      generator = Azu::Generators::MyGenerator.new("User", {} of String => String)

      generator.generate

      File.exists?("src/models/user.cr").should be_true
    end
  end
end
```

## Adding New Templates

### 1. Create Template Directory

```
src/templates/
└── generators/
    └── my_generator/
        ├── model.cr.ecr
        ├── model_spec.cr.ecr
        └── migration.cr.ecr
```

### 2. Write Template Files

```crystal
# src/templates/generators/my_generator/model.cr.ecr
class <%= @name.camelcase %> < CQL::Model
  table :<%= @name.underscore.pluralize %>

  <% @attributes.each do |attr| %>
  column :<%= attr.name %>, <%= attr.type %>
  <% end %>

  timestamps

  # Validations
  <% @attributes.select(&.required?).each do |attr| %>
  validates :<%= attr.name %>, presence: true
  <% end %>
end
```

### 3. Test Templates

```crystal
# spec/templates/my_generator_spec.cr
describe "MyGenerator templates" do
  it "renders model template correctly" do
    context = {
      "name" => "User",
      "attributes" => [
        {"name" => "name", "type" => "String", "required" => true},
        {"name" => "email", "type" => "String", "required" => true}
      ]
    }

    result = ECR.render("src/templates/generators/my_generator/model.cr.ecr", context)

    result.should contain("class User < CQL::Model")
    result.should contain("column :name, String")
    result.should contain("validates :name, presence: true")
  end
end
```

## Bug Reports

### Before Reporting

1. **Check existing issues** - Search for similar issues
2. **Reproduce the bug** - Create a minimal reproduction
3. **Check documentation** - Ensure it's not a configuration issue

### Bug Report Template

```markdown
## Bug Description

Brief description of the bug

## Steps to Reproduce

1. Run command: `azu command --option`
2. Expected: Expected behavior
3. Actual: Actual behavior

## Environment

- Crystal version: `crystal --version`
- Azu CLI version: `azu version`
- OS: macOS/Linux/Windows
- Database: PostgreSQL/MySQL/SQLite

## Additional Information

- Error messages
- Stack traces
- Configuration files
```

## Feature Requests

### Before Requesting

1. **Check roadmap** - Feature might already be planned
2. **Search issues** - Similar feature might be requested
3. **Consider scope** - Ensure it fits the project's goals

### Feature Request Template

```markdown
## Feature Description

Clear description of the feature

## Use Case

Why this feature is needed and how it would be used

## Proposed Implementation

Optional: How you think it could be implemented

## Alternatives Considered

Other approaches you've considered

## Additional Context

Any other relevant information
```

## Pull Request Guidelines

### PR Template

```markdown
## Description

Brief description of changes

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing

- [ ] Tests added/updated
- [ ] All tests pass
- [ ] Manual testing completed

## Documentation

- [ ] Documentation updated
- [ ] No documentation needed

## Checklist

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Corresponding issue linked
```

### Review Process

1. **Automated checks** must pass
2. **Code review** by maintainers
3. **Documentation review** if needed
4. **Final approval** before merge

## Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):

- **Major** (X.0.0): Breaking changes
- **Minor** (0.X.0): New features, backward compatible
- **Patch** (0.0.X): Bug fixes, backward compatible

### Release Steps

1. **Update version** in `shard.yml`
2. **Update changelog** in `CHANGELOG.md`
3. **Create release branch** from main
4. **Run full test suite**
5. **Create GitHub release**
6. **Tag release** with version number

## Community Guidelines

### Code of Conduct

- **Be respectful** to all contributors
- **Be inclusive** and welcoming
- **Be constructive** in feedback
- **Be patient** with newcomers

### Communication

- **GitHub Issues** for bug reports and feature requests
- **GitHub Discussions** for questions and ideas
- **Discord** for real-time chat and support
- **Email** for security issues

## Getting Help

### Resources

- [Documentation](README.md) - Comprehensive guides
- [Examples](examples/) - Code examples and tutorials
- [GitHub Issues](https://github.com/azutoolkit/azu_cli/issues) - Bug reports and discussions
- [Discord](https://discord.gg/azutoolkit) - Community chat

### Mentorship

New contributors can:

1. **Start with good first issues** - Look for `good first issue` label
2. **Ask for help** - Don't hesitate to ask questions
3. **Join discussions** - Participate in community conversations
4. **Review others' PRs** - Learn by reviewing code

## Recognition

### Contributors

All contributors are recognized in:

- **GitHub contributors** page
- **CHANGELOG.md** for significant contributions
- **README.md** for maintainers
- **Release notes** for each release

### Hall of Fame

Special recognition for:

- **Major contributors** - Significant code contributions
- **Documentation heroes** - Documentation improvements
- **Community leaders** - Community building efforts
- **Bug hunters** - Critical bug reports and fixes

## Related Documentation

- [Development Setup](development-setup.md) - Detailed setup instructions
- [Adding New Generators](new-generators.md) - Generator development guide
- [Adding New Commands](new-commands.md) - Command development guide
- [Testing Guidelines](testing.md) - Testing best practices
- [Documentation Guidelines](documentation.md) - Documentation standards
