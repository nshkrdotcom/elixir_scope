# ElixirScope

ElixirScope is a unified AST-based debugging and code intelligence platform for Elixir applications. Built on a clean 8-layer architecture with Foundation as an external hex dependency for optimal modularity and deployment simplicity.

## Architecture

ElixirScope implements a clean 8-layer architecture built on top of the Foundation dependency:

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
│           Foundation                │ ← Core utilities (DEPENDENCY)
└─────────────────────────────────────┘
```

## Dependencies

- **Foundation Layer**: Available as hex dependency `foundation ~> 0.1.0` ([HexDocs](https://hexdocs.pm/foundation/0.1.0/api-reference.html))
- **Development Tools**: Credo, Dialyzer, ExCoveralls, ExDoc
- **Testing**: Mox, StreamData

## Current Status

- ✅ **Foundation Layer**: Available as production-ready hex dependency
- ✅ **Project Structure**: Clean 8-layer skeleton created
- ✅ **Testing Framework**: Smoke, unit, integration test structure
- ✅ **Foundation Integration**: Successfully integrated and tested
- 🚧 **Upper 8 Layers**: Skeleton created, ready for implementation

## Quick Start

```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run tests
mix test

# Run smoke tests (Foundation integration)
mix test.smoke

# Development check (format, credo, compile, smoke tests)
mix dev.check
```

## Development Commands

```bash
# Test categories
mix test.unit          # Fast unit tests
mix test.integration   # Cross-layer integration tests
mix test.smoke         # Quick health checks
mix test.all           # Complete test suite

# Quality assurance
mix dev.check          # Format check, Credo, compile, smoke tests
```

## Layer Implementation

Each layer is a skeleton ready for implementation:

- `ElixirScope.AST` - AST parsing and repository
- `ElixirScope.Graph` - Graph algorithms and data structures
- `ElixirScope.CPG` - Code Property Graph construction
- `ElixirScope.Analysis` - Architectural pattern detection
- `ElixirScope.Capture` - Runtime instrumentation and correlation
- `ElixirScope.Query` - Advanced querying system
- `ElixirScope.Intelligence` - AI/ML integration
- `ElixirScope.Debugger` - Complete debugging interface

## Foundation Services

The Foundation layer provides enterprise-grade OTP services:

- **ConfigServer**: Dynamic configuration with validation
- **EventStore**: Comprehensive event system
- **TelemetryService**: Advanced metrics and monitoring
- **ProcessRegistry**: Service discovery with namespace isolation
- **Infrastructure Protection**: Circuit breakers, rate limiting, connection pooling

## Examples

```elixir
# Start the application
{:ok, _} = Application.ensure_all_started(:elixir_scope)

# Check layer status
ElixirScope.layers()
# [:ast, :graph, :cpg, :analysis, :capture, :query, :intelligence, :debugger]

# Parse Elixir code (basic AST layer functionality)
{:ok, ast} = ElixirScope.AST.parse("defmodule Test, do: :ok")

# Check current implementation status
ElixirScope.AST.status()
# :not_implemented
```

## Implementation Plan

This project is ready for implementation following a comprehensive architecture plan:

### Documentation
- **Complete Architecture Plan**: [`docs/claudeCodeArchPlan.md`](docs/claudeCodeArchPlan.md)
- **Reference Implementation**: [`docs/reference_implementation/`](docs/reference_implementation/) (302 files, 54k LOC)
- **Implementation Guides**: [`docs/implementation/`](docs/implementation/) - Layer-by-layer instructions
- **Full Documentation**: [`docs/README.md`](docs/README.md)

### Implementation Priority
1. **Graph Layer** (Week 2) - Lowest complexity, validates architecture (11 files, 506 LOC)
2. **AST Layer** (Weeks 3-4) - Core functionality, central hub (70 files, 16k LOC)
3. **Remaining Layers** (Weeks 5-16) - CPG, Analysis, Capture, Query, Intelligence, Debugger

### Unified Package Benefits
- **Single Dependency**: `{:elixir_scope, "~> 0.1.0"}`
- **Atomic Deployments**: All layers versioned together
- **Direct Integration**: Function calls vs. message passing
- **Shared Memory**: Efficient ETS table and cache sharing

Each layer is ready for implementation with the Foundation layer providing robust enterprise-grade infrastructure.