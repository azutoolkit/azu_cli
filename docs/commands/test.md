# Test Command

The `azu test` command runs your application's test suite with support for watch mode, filtering, and continuous testing.

## Synopsis

```bash
azu test [files] [options]
```

## Description

Execute your application's test suite using Crystal's built-in spec framework. The command provides a wrapper around `crystal spec` with additional features like file watching, filtering, and enhanced output formatting.

## Usage

### Basic Testing

```bash
# Run all tests
azu test

# Run specific test file
azu test spec/models/user_spec.cr

# Run all tests in a directory
azu test spec/models/
```

### Watch Mode

The watch mode automatically reruns tests when source or spec files change, providing immediate feedback during development:

```bash
# Run tests in watch mode
azu test --watch

# Watch specific directory
azu test spec/models/ --watch
```

When running in watch mode:
- Tests run initially on startup
- File changes trigger automatic test reruns
- Press `Ctrl+C` to stop watching
- Monitors both `src/` and `spec/` directories

### Filtering Tests

Filter tests by name or pattern to run specific test cases:

```bash
# Run tests matching pattern
azu test --filter User

# Run tests in specific file matching pattern
azu test spec/models/user_spec.cr --filter "validates email"
```

## Options

| Option | Short | Description |
|--------|-------|-------------|
| `--watch` | `-w` | Watch mode - automatically rerun tests on file changes |
| `--coverage` | `-c` | Enable coverage reporting (requires additional setup) |
| `--verbose` | `-v` | Verbose output with detailed test information |
| `--parallel` | `-p` | Run tests in parallel (if supported by test framework) |
| `--filter <pattern>` | `-f` | Filter tests by name pattern |

## Environment Variables

The test command respects the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `CRYSTAL_ENV` | Test environment | `test` |
| `DATABASE_URL` | Test database URL | |

## Examples

### Development Workflow

Run tests in watch mode during development:

```bash
# Terminal 1: Development server
azu serve

# Terminal 2: Continuous testing
azu test --watch
```

### Focused Testing

Run specific tests with verbose output:

```bash
# Test specific model
azu test spec/models/user_spec.cr --verbose

# Test with filter
azu test --filter "User creation" --verbose
```

### Pre-Commit Testing

Run all tests before committing:

```bash
# Run full test suite
azu test

# Or with verbose output for CI
azu test --verbose
```

## Test File Structure

The test command works with the standard Crystal spec structure:

```
spec/
├── spec_helper.cr           # Test configuration
├── support/                 # Test support files
│   └── test_helpers.cr
├── models/
│   ├── user_spec.cr
│   └── post_spec.cr
├── endpoints/
│   ├── users_spec.cr
│   └── posts_spec.cr
└── services/
    └── user_service_spec.cr
```

## Output Format

Test output includes:

- **Test Results**: Pass/fail indicators for each test
- **Duration**: Total test execution time
- **Errors**: Detailed error messages and stack traces
- **Summary**: Total tests, passed, failed counts

Example output:

```
🧪 Running tests...
Watch mode: disabled
Coverage: disabled
Parallel: disabled

Finished in 1.42 seconds
42 examples, 0 failures

✅ Tests passed in 1.42s
```

## Watch Mode Behavior

When file changes are detected:

1. Displays changed file path
2. Shows separator line for visual clarity
3. Reruns the test suite
4. Displays results
5. Waits for next change

Monitored file patterns:
- `src/**/*.cr` - Source files
- `spec/**/*.cr` - Spec files

## Coverage Reporting

Coverage reporting requires additional setup:

```bash
# Run with coverage flag
azu test --coverage
```

**Note**: Coverage reporting may require installing additional tools like `crystal-coverage`.

## Performance Considerations

### Parallel Testing

Enable parallel test execution for faster results:

```bash
azu test --parallel
```

**Note**: Parallel testing requires proper test isolation and may not be supported by all test frameworks.

### Test Database

For tests using the database:

1. Use a separate test database
2. Set `CRYSTAL_ENV=test`
3. Run migrations before tests:

```bash
CRYSTAL_ENV=test azu db:create
CRYSTAL_ENV=test azu db:migrate
azu test
```

## Best Practices

### 1. Use Watch Mode During Development

```bash
# Keep tests running while you code
azu test --watch
```

### 2. Keep Tests Fast

- Use factories instead of fixtures
- Mock external dependencies
- Minimize database operations

### 3. Organize Tests Logically

```
spec/
├── unit/        # Unit tests
├── integration/ # Integration tests
└── e2e/        # End-to-end tests
```

### 4. Use Filters for Focused Development

```bash
# Work on specific feature
azu test --filter "User authentication" --watch
```

### 5. Run Full Suite Before Commits

```bash
# Ensure everything passes
azu test
```

## Troubleshooting

### Tests Not Running

Ensure your test files:
- Are in the `spec/` directory
- End with `_spec.cr`
- Require `spec_helper`

### Watch Mode Not Detecting Changes

Check that:
- Files are in `src/` or `spec/` directories
- Files have `.cr` extension
- File system permissions are correct

### Parallel Tests Failing

If parallel tests fail but sequential tests pass:
- Check for shared state between tests
- Ensure proper test isolation
- Use separate database connections

### Database Connection Errors

Verify test database setup:

```bash
# Create test database
CRYSTAL_ENV=test azu db:create

# Run test migrations
CRYSTAL_ENV=test azu db:migrate

# Run tests
azu test
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Crystal
        uses: crystal-lang/install-crystal@v1
      - name: Install dependencies
        run: shards install
      - name: Setup database
        run: |
          CRYSTAL_ENV=test azu db:create
          CRYSTAL_ENV=test azu db:migrate
      - name: Run tests
        run: azu test --verbose
```

### GitLab CI Example

```yaml
test:
  stage: test
  script:
    - shards install
    - CRYSTAL_ENV=test azu db:create
    - CRYSTAL_ENV=test azu db:migrate
    - azu test --verbose
```

## Aliases

The test command can also be invoked using:

```bash
# Short form
azu t
```

## Related Commands

- [`azu serve`](serve.md) - Development server for running application
- [`azu db:migrate`](database.md#azu-dbmigrate) - Run database migrations
- [`azu generate`](generate.md) - Generate test files with scaffolds

## See Also

- [Crystal Spec Documentation](https://crystal-lang.org/reference/guides/testing.html)
- [Testing Best Practices](../best-practices/testing.md)
- [CI/CD Integration Guide](../guides/ci-cd.md)

