# GitHub Issues for TODO Technical Debt

This file contains drafts for GitHub issues to track technical debt items identified in TODO_ANALYSIS.md.

---

## Issue #1: Fix Build Issues in Generated Endpoint Projects

**Title**: [DEBT] Integration tests for endpoint generator disabled due to build issues

**Labels**: `technical-debt`, `testing`, `generators`, `priority:medium`

**Description**:
The endpoint generator integration tests are currently disabled because generated projects fail to compile. Tests only verify file generation but cannot validate that the generated code actually works.

**Location**:

- **File**: `spec/azu_cli/integration/endpoint_generator_spec.cr`
- **Lines**: 22, 53
- **Component**: Endpoint Generator

**Current State**:

```crystal
# TODO: Fix build issues in generated projects
# build_project(project_path).should be_true
```

Tests for both web and API project types skip:

- Project compilation verification
- Server startup testing
- HTTP endpoint response testing

**Desired State**:

- Generated projects should compile without errors
- Integration tests should build and run generated projects
- Tests should verify endpoints respond correctly

**Impact**:

- [x] Affects testing
- [x] Affects user experience
- [ ] Affects functionality
- [ ] Affects performance

**Root Causes to Investigate**:

1. Missing dependencies in generated `shard.yml`
2. Incorrect imports in generated endpoint files
3. Template syntax errors
4. Type mismatches in generated code
5. Missing initializers or configuration

**Acceptance Criteria**:

- [ ] Identify specific compilation errors in generated projects
- [ ] Fix template issues causing compilation failures
- [ ] Generated web projects compile successfully
- [ ] Generated API projects compile successfully
- [ ] Re-enable `build_project` test assertions
- [ ] Re-enable server integration tests
- [ ] Tests verify HTTP responses work correctly
- [ ] Document any requirements for generated projects

**Steps to Reproduce**:

```bash
# Create test project
cd /tmp
azu new testapp --type=web
cd testapp

# Generate endpoint
azu generate endpoint Posts index:get show:get

# Try to build
shards build
# Expected: Should build successfully
# Actual: Build may fail
```

**Priority**: Medium

**Estimated Effort**: Large (> 8 hours)

- Requires investigation of multiple generated project configurations
- May need template fixes across multiple files
- Needs comprehensive testing

---

## Issue #2: Fix Build Issues in Generated Validator Projects

**Title**: [DEBT] Integration tests for validator generator disabled due to build issues

**Labels**: `technical-debt`, `testing`, `generators`, `priority:medium`

**Description**:
The validator generator integration tests are disabled because generated projects with validators fail to compile. Tests verify file creation but cannot validate runtime functionality.

**Location**:

- **File**: `spec/azu_cli/integration/validator_generator_spec.cr`
- **Line**: 17
- **Component**: Validator Generator

**Current State**:

```crystal
# TODO: Fix build issues in generated projects
# build_project(project_path).should be_true
```

Tests skip:

- Project compilation with validator
- Validator instantiation testing
- Runtime validation testing

**Desired State**:

- Generated validators should compile without errors
- Integration tests should verify validators work at runtime
- Tests should validate that validators can be used in the application

**Impact**:

- [x] Affects testing
- [x] Affects user experience
- [ ] Affects functionality
- [ ] Affects performance

**Root Causes to Investigate**:

1. Missing validator base class or module
2. Incorrect imports in generated validator files
3. Template syntax errors
4. Missing validator registration
5. Type issues with validation methods

**Acceptance Criteria**:

- [ ] Identify compilation errors in projects with validators
- [ ] Fix validator template issues
- [ ] Generated validators compile successfully
- [ ] Re-enable `build_project` test assertion
- [ ] Re-enable runtime validator tests
- [ ] Tests verify validators can be instantiated and used
- [ ] Document validator usage requirements

**Steps to Reproduce**:

```bash
# Create test project
cd /tmp
azu new testapp --type=web
cd testapp

# Generate validator
azu generate validator Email

# Try to build and use
shards build
# Expected: Should build and validator should work
# Actual: May fail to build or use validator
```

**Priority**: Medium

**Estimated Effort**: Medium (2-8 hours)

- Similar to endpoint generator issues but smaller scope
- May share some root causes with Issue #1

---

## Issue #3: Add Tests to Main Spec File

**Title**: [DEBT] Main spec file contains only placeholder test

**Labels**: `technical-debt`, `testing`, `priority:low`, `good-first-issue`

**Description**:
The main `spec/azu_cli_spec.cr` file contains only a placeholder test with a TODO comment. While most CLI functionality is tested in other spec files, this looks unprofessional and may indicate missing test coverage.

**Location**:

- **File**: `spec/azu_cli_spec.cr`
- **Line**: 4
- **Component**: Main Spec

**Current State**:

```crystal
require "./spec_helper"

describe AzuCLI do
  # TODO: Write tests

  it "works" do
    true.should eq(true)
  end
end
```

**Desired State**:
Either:

1. Add meaningful tests for CLI entry point, or
2. Remove this file if all functionality is covered elsewhere

**Impact**:

- [ ] Affects testing (minimal)
- [x] Affects maintainability
- [ ] Affects functionality
- [ ] Affects performance

**Recommendations**:

**Option A**: Add meaningful tests

```crystal
describe AzuCLI do
  describe ".version" do
    it "returns the version string" do
      AzuCLI.version.should eq("0.0.1+13")
    end
  end

  describe ".run" do
    it "parses command line arguments" do
      # Test CLI entry point
    end

    it "displays help when no arguments" do
      # Test default behavior
    end
  end
end
```

**Option B**: Remove file if redundant

- Verify all CLI functionality is tested in other files
- Remove `spec/azu_cli_spec.cr`
- Update test documentation

**Acceptance Criteria**:

- [ ] Decide whether to keep or remove file
- [ ] If keeping: Add meaningful tests for CLI entry point
- [ ] If removing: Verify coverage elsewhere and delete file
- [ ] Remove TODO comment

**Priority**: Low

**Estimated Effort**: Small (< 2 hours)

- Simple decision and implementation
- Good for new contributors

---

## Testing Improvements Checklist

After resolving these issues:

- [ ] All integration tests pass
- [ ] Generated projects compile successfully
- [ ] Generated projects run without errors
- [ ] Test coverage is comprehensive
- [ ] No placeholder tests remain
- [ ] Documentation updated with test requirements
- [ ] CI/CD includes generated project builds

---

## Additional Context

These issues were identified during a comprehensive TODO/FIXME audit. See `TODO_ANALYSIS.md` for the complete analysis.

**Related Documentation**:

- [TODO Analysis](../TODO_ANALYSIS.md)
- [Contributing Guide](contributing/README.md)
- [Testing Documentation](commands/test.md)

**Impact on Users**:
While these are test-related issues, they affect confidence in generated code quality. Users expect generated code to work out-of-the-box.

**Timeline**:

- Issue #1: Target next sprint (highest priority)
- Issue #2: Target next sprint (can be done alongside #1)
- Issue #3: Target backlog (low priority, good for contributors)

---

**Generated**: October 30, 2025
**Review Status**: Ready for GitHub issue creation
**Action**: Create issues on GitHub with above content
