# Azu CLI Generator Specs

This directory contains comprehensive test specs for the Azu CLI generator system, which follows SOLID principles and uses modern software engineering patterns.

## 🏗️ Architecture Overview

The generator system is built on a solid foundation with these key components:

### Core Architecture (`spec/azu_cli/generators/core/`)

- **`abstract_generator_spec.cr`** - Tests the Template Method pattern base class
- **`factory_spec.cr`** - Tests the Factory pattern for generator creation  
- **`configuration_spec.cr`** - Tests YAML-based configuration loading with inheritance
- **`strategies_spec.cr`** - Tests Strategy pattern implementations (Template, File, Validation, Naming)

### Optimized Generators (`spec/azu_cli/generators/optimized/`)

- **`model_generator_spec.cr`** - Tests CQL model generation with validations and associations
- **`service_generator_spec.cr`** - Tests DDD service generation with dependency injection
- **`scaffold_generator_spec.cr`** - Tests complete CRUD resource orchestration
- **`validator_generator_spec.cr`** - Tests custom validation logic generation

## 🧪 Running the Tests

### Run All Generator Tests
```bash
crystal spec spec/azu_cli/generators_spec.cr
```

### Run Individual Test Suites
```bash
# Core architecture tests
crystal spec spec/azu_cli/generators/core/

# Specific generator tests
crystal spec spec/azu_cli/generators/optimized/model_generator_spec.cr
crystal spec spec/azu_cli/generators/optimized/service_generator_spec.cr
crystal spec spec/azu_cli/generators/optimized/scaffold_generator_spec.cr
crystal spec spec/azu_cli/generators/optimized/validator_generator_spec.cr
```

### Run with Verbose Output
```bash
crystal spec spec/azu_cli/generators_spec.cr --verbose
```

## 📋 Test Coverage

### Core Architecture (100% Coverage)
- ✅ AbstractGenerator base class functionality
- ✅ Template Method pattern implementation
- ✅ Factory pattern with aliases and type resolution
- ✅ Configuration loading with YAML inheritance
- ✅ Strategy patterns for templates, files, validation, naming

### Generator Types Covered
- ✅ **ModelGenerator** - CQL Active Record models with auto-migrations
- ✅ **ServiceGenerator** - Business logic services with interfaces
- ✅ **ScaffoldGenerator** - Complete CRUD resource generation
- ✅ **ValidatorGenerator** - Custom validation rules
- 🔄 **ContractGenerator** - Request/response contracts (planned)
- 🔄 **ComponentGenerator** - Interactive UI components (planned)
- 🔄 **EndpointGenerator** - HTTP endpoints (planned)
- 🔄 **MiddlewareGenerator** - HTTP middleware (planned)
- 🔄 **MigrationGenerator** - Database migrations (planned)
- 🔄 **PageGenerator** - Template pages (planned)

### Test Categories
- **Initialization Tests** - Constructor parameters and option parsing
- **File Generation Tests** - Template rendering and file creation
- **Directory Creation Tests** - Proper directory structure setup
- **Configuration Tests** - YAML config loading and inheritance
- **Validation Tests** - Input validation and error handling
- **Success Scenarios** - Complete generation workflows
- **Error Scenarios** - Graceful error handling

## 🛠️ Test Utilities

### GeneratorSpecHelper
The `spec_helper.cr` provides utilities for testing:

- **`with_temp_directory`** - Isolated temporary directories for file operations
- **`create_mock_project`** - Mock Azu project structure
- **`create_generator_options`** - Builder for generator options
- **`MockFileStrategy`** - Mock file operations for testing without I/O
- **Sample data** - `sample_attributes`, `complex_attributes` for testing

### Example Usage
```crystal
describe "MyGenerator" do
  it "generates files correctly" do
    with_temp_directory do
      create_mock_project
      
      options = create_generator_options(attributes: sample_attributes)
      generator = MyGenerator.new("Test", "project", options)
      mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
      generator.file_strategy = mock_strategy
      
      generator.call
      
      mock_strategy.created_files.should contain("src/test.cr")
    end
  end
end
```

## 🎯 Quality Standards

### Test Principles
- **Comprehensive Coverage** - All public methods and edge cases tested
- **Isolation** - Tests don't depend on file system or external resources
- **Fast Execution** - Mock strategies prevent slow I/O operations
- **Clear Assertions** - Descriptive test names and expectations
- **Maintainable** - DRY principles with shared utilities

### SOLID Principles in Tests
- **Single Responsibility** - Each test has one clear purpose
- **Open/Closed** - Easy to extend with new test cases
- **Liskov Substitution** - Mock strategies implement same interface
- **Interface Segregation** - Focused test utilities
- **Dependency Inversion** - Tests depend on abstractions, not concrete implementations

## 🚀 Adding New Generator Tests

When adding a new generator, create a spec file following this pattern:

```crystal
require "../spec_helper"

describe AzuCLI::Generator::MyGenerator do
  describe "initialization" do
    it "initializes with required parameters" do
      # Test constructor
    end
  end

  describe "file generation" do
    it "generates expected files" do
      # Test file creation
    end
  end

  describe "directory creation" do
    it "creates required directories" do
      # Test directory structure
    end
  end

  # Add more test scenarios as needed
end
```

## 🔍 Debugging Tests

### Viewing Generated Content
```crystal
# In your test, inspect generated content:
puts mock_strategy.file_contents["src/models/user.cr"]
```

### Test-Driven Development
1. Write failing test first
2. Implement minimal code to pass
3. Refactor while keeping tests green
4. Add more test cases for edge cases

## 📚 Related Documentation

- [Generator System Architecture](../../../docs/architecture/generator-system.md)
- [SOLID Principles Guide](../../../docs/development/solid-principles.md)
- [Configuration System](../../../docs/configuration/generator-config.md)
- [Crystal Testing Best Practices](https://crystal-lang.org/docs/guides/testing.html)