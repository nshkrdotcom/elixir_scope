# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ElixirScope is a revolutionary AST-based debugging and code intelligence platform for Elixir applications built with a clean 9-layer architecture. The project provides "execution cinema" capabilities through deep static analysis, runtime correlation, and AI-powered insights.

**Current Status**: Foundation layer is production-ready with enterprise-grade OTP patterns. Upper 8 layers have framework structures in place but need implementation completion.

## Development Commands

### Primary Testing Commands
```bash
# Quick development validation
mix dev.check                    # Format check, Credo, compile, smoke tests
make dev-check                   # Same via Makefile

# Test categories  
mix test.unit                    # Fast unit tests
mix test.smoke                   # Quick health checks  
mix test.integration             # Cross-layer integration tests
mix test.contract                # API contract validation
mix test.all                     # Complete test suite

# Quality assurance
mix qa.format                    # Code formatting check
mix qa.credo                     # Static analysis
mix qa.dialyzer                  # Type checking
mix qa.all                       # Complete QA pipeline

# CI pipeline
mix ci.test                      # Full CI validation
make ci-check                    # Same via Makefile
```

### Development Workflow
```bash
# Setup
mix setup                        # Install deps, compile, setup Dialyzer PLT
make setup                       # Same via Makefile

# Development scripts
mix dev.workflow                 # Interactive Foundation layer testing
mix run scripts/benchmark.exs    # Performance benchmarking

# Architecture validation
mix validate_architecture        # Layer dependency validation
```

### Key Make Targets
```bash
make help                        # Show all available commands
make smoke                       # Run smoke tests
make watch                       # Auto-run tests on file changes
make benchmark                   # Performance benchmarks
```

## Architecture

ElixirScope implements a clean 9-layer architecture with strict dependency rules (each layer only depends on lower layers):

```
┌─────────────────────────────────────┐
│             Debugger                │ ← Complete debugging interface
├─────────────────────────────────────┤
│           Intelligence              │ ← AI/ML integration  
├─────────────────────────────────────┤
│      Capture          Query         │ ← Runtime correlation & querying
├─────────────────────────────────────┤
│            Analysis                 │ ← Architectural analysis
├─────────────────────────────────────┤
│              CPG                    │ ← Code Property Graph
├─────────────────────────────────────┤
│             Graph                   │ ← Graph algorithms
├─────────────────────────────────────┤
│              AST                    │ ← AST parsing & repository
├─────────────────────────────────────┤
│           Foundation                │ ← Core utilities (COMPLETE)
└─────────────────────────────────────┘
```

## Foundation Layer (Production Ready)

The Foundation layer is **complete and production-ready** with enterprise-grade OTP patterns:

### Core Services
- **ConfigServer**: Dynamic configuration with validation and hot reloading
- **EventStore**: Comprehensive event system with serialization  
- **TelemetryService**: Advanced metrics and monitoring
- **ProcessRegistry**: Registry-based service discovery with namespace isolation

### Infrastructure Protection
- **Circuit Breaker**: Fuse-based failure protection with telemetry
- **Rate Limiter**: Hammer-based rate limiting with entity support
- **Connection Manager**: Poolboy-based connection pooling
- **Unified Infrastructure**: Single facade for all protection patterns

### Key Patterns
- **Perfect Test Isolation**: Concurrent tests with namespace separation
- **Graceful Degradation**: Fallback strategies for service failures
- **Performance Monitoring**: Sub-millisecond operations, telemetry integration

## Critical File Filtering

The project uses `mix.exs` filtering to exclude incomplete upper layers from compilation:

```elixir
# Currently excluded from compilation:
excluded_dirs = [
  "analysis/", "ast/", "capture/", "cpg/", 
  "debugger/", "graph/", "integration/", 
  "intelligence/", "query/"
]
```

When implementing upper layers, remove directories from `excluded_dirs` in `mix.exs:get_filtered_lib_paths/0`.

## Testing Architecture

ElixirScope implements enterprise-grade testing with multiple categories:

### Test Organization
- **unit/** - Fast, isolated layer-specific tests  
- **integration/** - Cross-layer integration testing
- **contract/** - API contract validation
- **property/** - Property-based testing
- **smoke/** - Quick health checks
- **support/** - Test utilities and helpers

### Test Isolation
- **Namespace Separation**: Tests use isolated Registry namespaces
- **Concurrent Safe**: All tests can run concurrently without conflicts
- **Property Testing**: 30+ properties ensure algorithmic correctness

## Performance Characteristics

### Registry Performance (Validated)
- **ProcessRegistry.lookup**: 2,000 ops/ms
- **ServiceRegistry.lookup**: 2,000 ops/ms
- **ServiceRegistry.health_check**: 2,500 ops/ms
- **Memory Usage**: Sub-MB for typical workloads

### Development Validation
Run `mix run scripts/benchmark.exs` to validate documented performance characteristics.

## Code Conventions

### Module Structure and Naming
```elixir
# Module naming pattern:
ElixirScope.[Layer].[Component].[SubComponent]

# Examples:
ElixirScope.Foundation.Infrastructure.CircuitBreaker
ElixirScope.AST.Repository.Enhanced  
ElixirScope.Graph.Algorithms.Centrality
```

### Structs and Type Specifications
Following docs/CODE_QUALITY.md standards:

```elixir
defmodule ElixirScope.Foundation.Config.StartOpts do
  @moduledoc """
  Configuration struct for service initialization.
  See `@type t` for complete type specification.
  """
  
  @enforce_keys [:name, :namespace, :options]
  defstruct @enforce_keys
  
  @type t :: %__MODULE__{
    name: atom(),
    namespace: atom(), 
    options: keyword()
  }
  
  @doc """
  Creates a new StartOpts struct.
  
  ## Examples
  
      iex> StartOpts.new(:service, :production, [timeout: 5000])
      %StartOpts{name: :service, namespace: :production, options: [timeout: 5000]}
  """
  @spec new(atom(), atom(), keyword()) :: t()
  def new(name, namespace, options) do
    %__MODULE__{name: name, namespace: namespace, options: options}
  end
end
```

### Documentation Standards
- Every public module has `@moduledoc`
- Every public function has `@doc` with examples
- Every struct has `@type t` specification
- Use `@spec` for all public functions
- Reference types in documentation (`See @type t`)

### Naming Conventions
- **Modules**: CamelCase (e.g., `NodeSelectorBroadcaster`)
- **Functions/Variables**: snake_case (e.g., `start_link`, `config_server`)
- **Struct Fields**: snake_case (e.g., `execution_broadcaster_reference`)
- **Types**: snake_case (e.g., `@type pool_config :: keyword()`)
- **Atoms**: snake_case (e.g., `:rate_limit_exceeded`)

### Layer Dependencies
Each layer can only depend on lower layers:
```elixir
debugger: [:intelligence, :capture, :query, :analysis, :cpg, :graph, :ast, :foundation]
intelligence: [:query, :analysis, :cpg, :graph, :ast, :foundation]
# ... etc (foundation depends on nothing)
```

### Error Handling
Use structured errors with ElixirScope.Foundation.Types.Error:
```elixir
{:error, Error.new([
  code: 6001,
  error_type: :rate_limit_exceeded,
  message: "Rate limit exceeded",
  severity: :medium,
  context: %{entity_id: entity_id, operation: operation}
])}
```

## Key Dependencies

### Production
- `{:telemetry, "~> 1.2"}` - Metrics and monitoring
- `{:jason, "~> 1.4"}` - JSON serialization
- `{:poolboy, "~>1.5.2"}` - Connection pooling
- `{:hammer, "~>7.0.1"}` - Rate limiting
- `{:fuse, "~>2.5.0"}` - Circuit breakers

### Development/Testing  
- `{:mox, "~> 1.2"}` - Mocking framework
- `{:stream_data, "~> 1.1"}` - Property-based testing
- `{:excoveralls, "~> 0.18"}` - Test coverage
- `{:credo, "~> 1.7"}` - Static analysis
- `{:dialyxir, "~> 1.4"}` - Type checking

## Development Notes

### Next Implementation Priority
1. **AST Layer**: Complete parser implementation and repository patterns
2. **Graph Layer**: Implement mathematical graph algorithms  
3. **CPG Layer**: Code Property Graph construction pipeline
4. **Analysis Layer**: Architectural pattern detection

### Important Files
- `DEV.md` - Comprehensive technical development guide
- `mix.exs` - Contains layer filtering configuration
- `scripts/dev_workflow.exs` - Interactive Foundation testing
- `docs/FOUNDATION_OTP_IMPLEMENT_NOW/` - Foundation implementation guides

### Testing Strategy
Always run `mix dev.check` before committing. The Foundation layer has comprehensive test coverage with property-based testing ensuring algorithmic correctness.

### Performance Monitoring
Use `scripts/benchmark.exs` to validate performance characteristics. The Foundation layer maintains sub-millisecond operation performance with telemetry integration.