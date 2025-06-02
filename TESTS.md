# ElixirScope Test Suite Documentation

## Overview

The ElixirScope project uses ExUnit for testing with a comprehensive tagging system that allows for selective test execution. The test suite is organized into multiple categories with specific exclusion tags to optimize development workflows.

## Test Configuration

### Main Configuration
- **Location**: `test/test_helper.exs`
- **Timeout**: 30 seconds per test
- **Max Failures**: 10 before stopping
- **Parallel Execution**: Up to 48 concurrent test cases
- **Logging**: Capture log enabled

### Excluded Tags by Default
The following tags are excluded during normal test runs:

| Tag | Purpose | Example Use Case |
|-----|---------|------------------|
| `:slow` | Performance-intensive tests | Property-based tests, large data processing |
| `:integration` | Cross-module integration tests | Service coordination, system-wide flows |
| `:end_to_end` | Complete system tests | Full application workflows |
| `:ai` | AI/ML related tests | Model training, inference testing |
| `:capture` | Output capture tests | Testing logging, output formatting |
| `:phoenix` | Phoenix framework tests | Web interface, controller tests |
| `:distributed` | Multi-node tests | Clustering, distributed coordination |
| `:real_world` | Real system interaction tests | External API calls, file system ops |
| `:benchmark` | Performance benchmarking | Speed measurements, optimization tests |
| `:stress` | System stress tests | High load, resource exhaustion |
| `:memory` | Memory usage tests | Memory leak detection, usage profiling |
| `:scalability` | Scalability tests | Performance under scale |
| `:regression` | Regression prevention tests | Bug reproduction, edge cases |
| `:scenario` | Complex scenario tests | Multi-step workflows |

## Running Tests

### Basic Test Execution

```bash
# Run all non-excluded tests (default)
mix test

# Run tests with verbose output
mix test --trace

# Run tests with coverage
mix test --cover
```

### Running Specific Test Categories

```bash
# Include slow tests
mix test --include slow

# Include integration tests
mix test --include integration

# Include end-to-end tests
mix test --include end_to_end

# Include AI-related tests
mix test --include ai

# Include benchmark tests
mix test --include benchmark
```

### Running Multiple Categories

```bash
# Include multiple tag types
mix test --include slow --include integration

# Include slow and benchmark tests
mix test --include slow --include benchmark

# Include integration and end-to-end tests
mix test --include integration --include end_to_end
```

### Running Only Specific Categories

```bash
# Run ONLY slow tests (exclude all others)
mix test --only slow

# Run ONLY integration tests
mix test --only integration

# Run ONLY benchmark tests
mix test --only benchmark
```

### Limiting Test Runs

```bash
# Stop after first failure
mix test --max-failures 1

# Stop after 3 failures
mix test --max-failures 3

# Run with specific seed for reproducibility
mix test --seed 12345
```

## Test Organization

### Directory Structure

```
test/
├── test_helper.exs              # Main test configuration
├── unit/                        # Unit tests
│   ├── foundation/             # Foundation layer unit tests
│   └── ...
├── integration/                 # Integration tests
│   ├── foundation/             # Foundation layer integration
│   └── concurrency_validation_test.exs
├── end_to_end/                 # End-to-end tests
├── performance/                # Performance and benchmark tests
└── support/                    # Test support modules
```

### Test Categories by Type

#### Unit Tests
- **Location**: `test/unit/`
- **Tags**: Usually no special tags (run by default)
- **Purpose**: Test individual modules and functions in isolation
- **Examples**: ConfigServer, EventStore, TelemetryService

#### Integration Tests
- **Location**: `test/integration/`
- **Tags**: `@moduletag :integration`
- **Purpose**: Test interactions between modules
- **Examples**: Service lifecycle, concurrency validation

#### Performance Tests
- **Tags**: `@moduletag :slow`, `@moduletag :benchmark`
- **Purpose**: Performance validation and benchmarking
- **Timeout**: Often longer than 30 seconds

#### End-to-End Tests
- **Tags**: `@moduletag :end_to_end`
- **Purpose**: Complete system workflow validation
- **Examples**: Full application scenarios

## Current Test Status

### Latest Test Run Results
- **Total Tests**: 211
- **Passed**: 206
- **Failed**: 5
- **Excluded**: 66
- **Skipped**: 1
- **Properties**: 57 (property-based tests)

### Known Issues

#### Service Lifecycle Test Failures
The following integration tests are currently failing:

1. **Graceful Shutdown Coordination**
   - Issue: TelemetryService remains available after stop
   - File: `test/integration/foundation/service_lifecycle_test.exs:127`

2. **Service Startup Dependency Failures**
   - Issue: ConfigServer remains available when it should be unavailable
   - File: `test/integration/foundation/service_lifecycle_test.exs:56`

3. **Recovery Scenarios**
   - Issue: EventStore availability not properly reset after crashes
   - File: `test/integration/foundation/service_lifecycle_test.exs:270`

4. **Multiple Service Failures**
   - Issue: ConfigServer availability state inconsistent
   - File: `test/integration/foundation/service_lifecycle_test.exs:322`

5. **Health Check Propagation**
   - Issue: ConfigServer availability not properly propagated
   - File: `test/integration/foundation/service_lifecycle_test.exs:441`

### Performance Characteristics
- **Property-based tests**: Some take 30+ seconds to complete
- **Integration tests**: Average 3.7 seconds total runtime
- **Async/Sync split**: ~1.1s async, ~2.6s sync

## Development Workflows

### During Development
```bash
# Quick feedback loop - run only fast tests
mix test

# Test specific module
mix test test/unit/foundation/services/config_server_test.exs

# Test with file watching (requires mix_test_watch)
mix test.watch
```

### Before Committing
```bash
# Run integration tests
mix test --include integration

# Run slow tests if touching performance-critical code
mix test --include slow
```

### CI/CD Pipeline
```bash
# Full test suite including all categories
mix test --include slow --include integration --include end_to_end --include benchmark

# With coverage reporting
mix test --cover --include slow --include integration
```

### Debugging Test Failures
```bash
# Run single failing test with trace
mix test test/integration/foundation/service_lifecycle_test.exs:127 --trace

# Run with maximum verbosity
mix test --trace --include integration

# Run with specific seed to reproduce
mix test --seed 470681 --include integration
```

## Test Writing Guidelines

### Tagging Tests

```elixir
# Module-level tags (applied to all tests in module)
@moduletag :slow
@moduletag :integration

# Individual test tags
@tag :benchmark
test "performance critical operation" do
  # test implementation
end

# Multiple tags
@tag [:slow, :memory]
test "memory-intensive operation" do
  # test implementation
end
```

### Performance Test Recommendations

```elixir
# For slow tests, increase timeout
@tag :slow
@tag timeout: 60_000  # 60 seconds
test "complex operation" do
  # long-running test
end

# For benchmark tests, use Benchee
@tag :benchmark
test "operation performance" do
  Benchee.run(%{
    "operation" => fn -> your_operation() end
  })
end
```

### Integration Test Patterns

```elixir
@moduletag :integration

setup do
  # Start required services
  {:ok, _} = start_supervised(ConfigServer)
  {:ok, _} = start_supervised(EventStore)
  :ok
end

test "service coordination" do
  # Test cross-service interactions
end
```

## Troubleshooting

### Common Issues

1. **Tests Timeout**
   - Increase timeout: `@tag timeout: 60_000`
   - Check for infinite loops or blocking operations

2. **Service Availability Assertions Fail**
   - Add delays for async operations: `Process.sleep(100)`
   - Use `eventually` helpers for async assertions

3. **Property Tests Take Too Long**
   - Reduce check count: `check all data <- generator, max_runs: 50`
   - Use smaller data generators

4. **Intermittent Failures**
   - Check for race conditions
   - Add proper synchronization
   - Use deterministic test data

### Performance Optimization

- Run tests in parallel when possible
- Use `async: true` for independent tests
- Mock external dependencies
- Use `setup_all` for expensive setup operations

## Useful Commands Reference

```bash
# Test execution
mix test                                    # Basic test run
mix test --include <tag>                   # Include specific tag
mix test --only <tag>                      # Run only specific tag
mix test --exclude <tag>                   # Exclude specific tag
mix test --max-failures N                  # Stop after N failures
mix test --trace                           # Verbose output
mix test --cover                           # With coverage
mix test --seed N                          # Specific seed

# File-specific
mix test path/to/test_file.exs             # Run specific file
mix test path/to/test_file.exs:line_number # Run specific test

# Combinations
mix test --include slow --include integration --max-failures 1 --trace
```

---

*Last updated: June 1, 2025*
*Test suite version: ElixirScope Foundation v0.1.0*
