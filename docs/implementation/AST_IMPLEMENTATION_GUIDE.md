# AST Layer Implementation Guide

**Version:** 2.0  
**Date:** December 6, 2025  
**Layer:** AST Layer (Layer 2)  
**Status:** Implementation Ready for Unified ElixirScope Package

## Overview

The AST Layer is the core intelligence engine of ElixirScope, providing deep static code analysis through Abstract Syntax Tree manipulation, pattern matching, and intelligent code understanding. This implementation guide is updated for the unified ElixirScope package architecture with Foundation as an external hex dependency.

## Architecture Changes from Monolith

### Unified Package Benefits
- **Simplified Integration**: Direct function calls between AST and other layers (CPG, Query, Analysis)
- **Performance Optimization**: No inter-process communication overhead
- **Atomic Deployments**: All layers versioned and deployed together
- **Shared Memory**: ETS tables and caches efficiently shared across layers

### Foundation Integration (External Dependency)
```elixir
# Foundation services accessed via global names
Foundation.ProcessRegistry.whereis(:ast_repository)
Foundation.EventStore.store(analysis_event)
Foundation.TelemetryService.emit_counter([:ast, :parsing, :completed])
Foundation.ConfigServer.get([:ast, :batch_size])
```

## Implementation Structure

### Module Organization
```
lib/elixir_scope/ast/
├── repository/                 # Core AST storage and management
│   ├── core.ex                # Main repository implementation
│   ├── enhanced.ex            # Advanced repository features
│   ├── memory_manager/        # Memory pressure handling
│   ├── project_population/    # Batch project analysis
│   └── synchronization/       # File watching and updates
├── parsing/                   # AST parsing and analysis
│   ├── parser.ex              # Core AST parser
│   ├── instrumentation_mapper.ex # Runtime correlation
│   └── analysis/              # Specialized analyzers
├── analysis/                  # Pattern matching and optimization
│   ├── pattern_matcher/       # 9-module pattern engine
│   └── performance_optimizer/ # Performance optimization
├── querying/                  # Query engine
│   ├── executor.ex            # Query execution
│   ├── optimizer.ex           # Query optimization
│   └── cache.ex               # Result caching
├── data/                      # Data structures
│   ├── module_data.ex         # Module representation
│   ├── function_data.ex       # Function representation
│   └── complexity_metrics.ex # Complexity calculations
└── transformation/            # Code transformation
    ├── transformer.ex         # AST transformations
    └── injector_helpers.ex    # Instrumentation injection
```

## Implementation Phases

### Phase 1: Core Infrastructure (Week 2-3)
1. **Basic AST Parsing** (`lib/elixir_scope/ast/parsing/parser.ex`)
   - Code.string_to_quoted!/1 wrapper with error handling
   - File parsing with syntax error recovery
   - Basic AST node identification

2. **Core Repository** (`lib/elixir_scope/ast/repository/core.ex`)
   - ETS-based storage with `:read_concurrency`
   - Module/function indexing
   - Basic CRUD operations

3. **Foundation Integration**
   - Configuration management for AST settings
   - Event emission for parsing completion
   - Telemetry for performance metrics

### Phase 2: Enhanced Features (Week 3-4)
1. **Pattern Matching Engine** (`lib/elixir_scope/ast/analysis/pattern_matcher/`)
   - Core pattern analysis engine
   - Pre-defined Elixir pattern library
   - Pattern validation and scoring

2. **Memory Management** (`lib/elixir_scope/ast/repository/memory_manager/`)
   - Memory pressure detection
   - Graduated cleanup strategies
   - LRU cache implementation

3. **Project Population** (`lib/elixir_scope/ast/repository/project_population/`)
   - Batch file discovery and parsing
   - Parallel processing with worker pools
   - Progress tracking and cancellation

### Phase 3: Advanced Analysis (Week 4)
1. **Query Engine** (`lib/elixir_scope/ast/querying/`)
   - SQL-like DSL implementation
   - Query optimization and execution
   - Result caching with TTL

2. **File Synchronization** (`lib/elixir_scope/ast/repository/synchronization/`)
   - FileSystem event monitoring
   - Incremental updates and debouncing
   - Change conflict resolution

## Key Implementation Decisions

### 1. ETS Table Strategy
```elixir
# Single namespace approach - no complex multi-tenancy
@modules_table_name :elixir_scope_ast_modules
@functions_table_name :elixir_scope_ast_functions
@correlation_table_name :elixir_scope_ast_correlation

# Read-heavy optimization
:ets.new(@modules_table_name, [
  :set, 
  :public, 
  :named_table,
  {:read_concurrency, true},
  {:write_concurrency, true}
])
```

### 2. Layer Integration Pattern
```elixir
# Direct module dependencies (no message passing)
defmodule ElixirScope.CPG.Builder do
  alias ElixirScope.AST.Repository
  
  def build_from_ast(module_name) do
    case Repository.get_module(module_name) do
      {:ok, module_data} -> build_cpg(module_data)
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### 3. Foundation Service Integration
```elixir
defmodule ElixirScope.AST.Repository.Core do
  @impl true
  def handle_info({:memory_pressure, level}, state) do
    # Respond to Foundation memory management signals
    case level do
      :low -> cleanup_cache()
      :medium -> cleanup_old_data()
      :high -> emergency_cleanup()
    end
    {:noreply, state}
  end
  
  defp emit_telemetry(event, measurements, metadata \\ %{}) do
    Foundation.TelemetryService.execute(
      [:elixir_scope, :ast | event],
      measurements,
      metadata
    )
  end
end
```

## Performance Targets

### Parsing Performance
- **10,000 modules** in <2 minutes (cold start)
- **1,000 functions/second** for pattern matching
- **<100ms** for 95% of queries
- **50+ concurrent** operations without degradation

### Memory Efficiency
- **<2GB** total memory for large projects (50k+ LOC)
- **Graduated pressure response** at 80%, 90%, 95% thresholds
- **LRU eviction** for cold data
- **Compression** for long-term storage

## Integration Points

### Direct Layer Dependencies
```elixir
# CPG Layer consumes AST data
ElixirScope.CPG.Builder.build_from_ast(module_name)

# Query Layer operates on AST repository  
ElixirScope.Query.Executor.execute_ast_query(query)

# Analysis Layer uses AST patterns
ElixirScope.Analysis.PatternDetector.analyze_module(module_data)

# Intelligence Layer correlates AST with runtime data
ElixirScope.Intelligence.Correlator.map_ast_to_runtime(correlation_id)
```

### Foundation Service Usage
```elixir
# Configuration access
{:ok, batch_size} = Foundation.ConfigServer.get([:ast, :batch_size])

# Event reporting
{:ok, event} = Foundation.EventStore.new_event(:ast_parsing_complete, %{
  modules_parsed: count,
  duration_ms: duration
})

# Performance metrics
Foundation.TelemetryService.emit_gauge([:ast, :memory_usage], memory_bytes)
```

## Testing Strategy

### Unit Testing
- **Parser component tests** with various Elixir syntax
- **Repository CRUD operations** with concurrent access
- **Pattern matching accuracy** with known pattern library
- **Memory management behavior** under simulated pressure

### Integration Testing
- **Foundation service integration** (Config, Events, Telemetry)
- **Cross-layer data flow** (AST → CPG → Analysis)
- **File watching and synchronization** with real file system changes
- **Performance benchmarks** with large codebases

### Property-Based Testing
- **AST roundtrip consistency** (parse → serialize → parse)
- **Pattern matching properties** (precision, recall, consistency)
- **Memory cleanup invariants** (no leaks, proper eviction)
- **Concurrent operation safety** (race condition detection)

## Migration from Reference Implementation

### Code Porting Strategy
1. **Namespace Updates**: `ElixirScope.*` → `ElixirScope.*` (minimal changes)
2. **Foundation Integration**: Replace internal infrastructure with Foundation calls
3. **Layer Dependencies**: Convert message passing to direct function calls
4. **Test Adaptation**: Update test fixtures for unified package structure

### Reference Implementation Mapping
```
docs/reference_implementation/ast/ → lib/elixir_scope/ast/
├── repository/core.ex → repository/core.ex
├── parsing/parser.ex → parsing/parser.ex  
├── analysis/pattern_matcher/ → analysis/pattern_matcher/
└── querying/executor.ex → querying/executor.ex
```

## Risk Mitigation

### Performance Risks
- **Memory pressure monitoring** with Foundation Infrastructure coordination
- **Query optimization** to prevent long-running operations
- **Concurrent access patterns** with proper ETS configuration

### Integration Risks  
- **Layer coupling management** through well-defined interfaces
- **Foundation service dependencies** with circuit breaker patterns
- **Data consistency** during concurrent updates

### Scalability Risks
- **Horizontal processing** with configurable worker pools
- **Incremental analysis** to avoid full project rescans
- **Cache efficiency** to minimize repeated computations

## Success Metrics

- **Parse 10k modules** in <2 minutes
- **95% queries** complete in <100ms  
- **>95% test coverage** across all components
- **Zero memory leaks** in 24+ hour runs
- **Clean Foundation integration** with <5ms service call latency

---

This implementation guide provides the roadmap for building the AST layer within the unified ElixirScope package, leveraging the Foundation dependency for infrastructure concerns while maintaining high performance and clean architectural boundaries.