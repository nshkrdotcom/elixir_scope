# ElixirScope AST Layer Technical Specification

**Version:** 1.0  
**Date:** December 2024  
**Layer:** AST Layer (Layer 2)  
**Status:** Implementation Ready

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Components](#core-components)
3. [Data Models](#data-models)
4. [API Specifications](#api-specifications)
5. [Performance Specifications](#performance-specifications)
6. [Integration Points](#integration-points)
7. [Implementation Guidelines](#implementation-guidelines)
8. [File Structure](#file-structure)

## Architecture Overview

### System Boundaries
The AST Layer operates as a high-performance static analysis engine that:
- Parses Elixir source code into enhanced ASTs with instrumentation metadata
- Stores parsed data in optimized ETS-based repositories
- Provides sophisticated pattern matching and query capabilities
- Maintains runtime correlation between static analysis and dynamic events
- Supports real-time file watching and incremental updates

### Core Design Principles
1. **Performance-First**: O(1) lookups, O(log n) complex queries
2. **Memory Efficiency**: Hierarchical caching with LRU eviction
3. **Runtime Correlation**: Bidirectional mapping between static and dynamic data
4. **Incremental Processing**: File-change driven updates
5. **Type Safety**: Comprehensive Dialyzer specifications

## Core Components

### 1. Repository System (`lib/elixir_scope/ast/repository/`)

#### Core Repository (`core.ex`)
```elixir
defmodule ElixirScope.ASTRepository.Repository do
  @moduledoc "Central AST storage with runtime correlation"
  
  # Performance targets:
  # - O(1) module lookup
  # - O(log n) correlation mapping
  # - O(1) instrumentation retrieval
  
  defstruct [
    :repository_id,
    :modules_table,          # ETS: {module_name, ModuleData.t()}
    :functions_table,        # ETS: {function_key, FunctionData.t()}  
    :ast_nodes_table,        # ETS: {ast_node_id, AST_node}
    :correlation_index,      # ETS: {correlation_id, ast_node_id}
    :instrumentation_points, # ETS: {ast_node_id, InstrumentationPoint.t()}
    :performance_metrics
  ]
end
```

**ETS Table Specifications:**
- `:set` tables with `:public`, `{:read_concurrency, true}`, `{:write_concurrency, true}`
- `:bag` tables for correlation indices
- Automatic cleanup with TTL and LRU eviction

#### Enhanced Repository (`enhanced.ex`)
Extended repository with advanced analytics capabilities:
- Complex query optimization
- Pattern-based analysis results caching
- Cross-module dependency tracking
- Historical analysis data retention

#### Memory Manager (`memory_manager/`)
Sophisticated memory management subsystem:

```elixir
# cache_manager.ex - LRU cache with configurable size limits
# monitor.ex - Memory pressure detection and alerting  
# cleaner.ex - Garbage collection and cleanup strategies
# compressor.ex - Data compression for cold storage
# pressure_handler.ex - Dynamic memory pressure response
```

#### Project Population (`project_population/`)
Batch processing system for analyzing entire projects:

```elixir
# project_populator.ex - Main orchestrator
# file_discovery.ex - Recursive source file discovery
# file_parser.ex - Parallel AST parsing
# module_analyzer.ex - Module-level analysis
# complexity_analyzer.ex - Cyclomatic complexity calculation
# dependency_analyzer.ex - Import/alias/use tracking
# quality_analyzer.ex - Code quality metrics
# security_analyzer.ex - Security pattern detection
```

#### Synchronization (`synchronization/`)
Real-time file watching and incremental updates:

```elixir
# file_watcher.ex - FileSystem event handling (NEEDS REFACTORING - 28K)
# synchronizer.ex - Incremental update coordination
```

### 2. Parsing System (`lib/elixir_scope/ast/parsing/`)

#### Core Parser (`parser.ex`)
Enhanced AST parser with instrumentation injection:

```elixir
@spec assign_node_ids(Macro.t()) :: {:ok, Macro.t()} | {:error, term()}
@spec extract_instrumentation_points(Macro.t()) :: {:ok, [map()]} | {:error, term()}
@spec build_correlation_index(Macro.t(), [map()]) :: {:ok, map()} | {:error, term()}
```

**Instrumentable AST Nodes:**
- Function definitions (`def`, `defp`)
- Pipe operations (`|>`)
- Case statements
- Try-catch blocks
- Module attributes (`@`)

#### Instrumentation Mapper (`instrumentation_mapper.ex`)
Runtime correlation between AST nodes and execution events:

```elixir
# Maps correlation_ids to ast_node_ids
# Handles temporal correlation queries
# Provides execution frequency tracking
# Supports pattern-based event correlation
```

#### Analysis Modules (`analysis/`)
Specialized analysis components:

```elixir
# ast_analyzer.ex - Module type detection, export extraction
# complexity_calculator.ex - Cyclomatic and cognitive complexity
# dependency_extractor.ex - Import/alias/use analysis
# pattern_detector.ex - Anti-pattern and code smell detection
# attribute_extractor.ex - Module attribute analysis
```

### 3. Pattern Matching Engine (`lib/elixir_scope/ast/analysis/pattern_matcher/`)

High-performance pattern analysis system with 9 specialized modules:

#### Core Engine (`core.ex`)
```elixir
@spec match_ast_pattern_with_timing(pid(), map()) :: {:ok, pattern_result()} | {:error, term()}
@spec match_behavioral_pattern_with_timing(pid(), map(), atom()) :: {:ok, pattern_result()} | {:error, term()}
@spec match_anti_pattern_with_timing(pid(), map(), atom()) :: {:ok, pattern_result()} | {:error, term()}
```

#### Specialized Components
```elixir
# types.ex - Pattern type definitions and specifications
# validators.ex - Pattern validation and normalization
# analyzers.ex - Pattern matching algorithms
# pattern_library.ex - Pre-defined pattern repository
# pattern_rules.ex - Custom pattern rule engine
# cache.ex - Pattern result caching
# config.ex - Pattern matching configuration
# stats.ex - Pattern analysis statistics
```

### 4. Query System (`lib/elixir_scope/ast/querying/`)

SQL-like query interface for AST data:

#### Query Executor (`executor.ex`)
```elixir
@spec execute_query(pid(), query_t()) :: {:ok, query_result()} | {:error, term()}

# Supports:
# - FROM :functions | :modules | :patterns
# - WHERE with complex filtering
# - ORDER BY with multiple fields
# - LIMIT/OFFSET for pagination
# - SELECT for field projection
```

#### Query Components
```elixir
# optimizer.ex - Query plan optimization
# cache.ex - Query result caching
# validator.ex - Query validation
# normalizer.ex - Query normalization
# types.ex - Query type definitions
# supervisor.ex - Query process supervision
```

### 5. Data Models (`lib/elixir_scope/ast/data/`)

#### Module Data (`module_data.ex`)
```elixir
defstruct [
  # Core AST Information
  :module_name, :ast, :source_file, :compilation_hash,
  
  # Instrumentation Metadata
  :instrumentation_points, :ast_node_mapping, :correlation_metadata,
  
  # Static Analysis Results
  :module_type, :complexity_metrics, :dependencies, :exports,
  :callbacks, :patterns, :attributes,
  
  # Runtime Correlation Data
  :runtime_insights, :execution_frequency, :performance_data,
  :error_patterns, :message_flows
]
```

#### Function Data (`function_data.ex`)
```elixir
defstruct [
  :function_key, :ast, :complexity_score, :dependencies,
  :call_graph_data, :instrumentation_metadata,
  :runtime_correlation_data, :performance_metrics
]
```

#### Supporting Structures
```elixir
# complexity_metrics.ex - Complexity calculation algorithms
# variable_data.ex - Variable scope and usage tracking
# shared_data_structures.ex - Common type definitions
# supporting_structures.ex - Utility data structures
```

### 6. Transformation System (`lib/elixir_scope/ast/transformation/`)

Code transformation and instrumentation injection:

```elixir
# transformer.ex - Core AST transformation
# enhanced_transformer.ex - Advanced transformation patterns
# orchestrator.ex - Transformation pipeline coordination
# injector_helpers.ex - Instrumentation injection utilities
```

### 7. Performance Optimization (`lib/elixir_scope/ast/analysis/performance_optimizer/`)

```elixir
# batch_processor.ex - Batch analysis optimization
# cache_manager.ex - Multi-level caching
# lazy_loader.ex - On-demand data loading
# optimization_scheduler.ex - Analysis job scheduling
# statistics_collector.ex - Performance metrics collection
```

### 8. Compilation Integration (`lib/elixir_scope/ast/compilation/`)

```elixir
# mix_task.ex - Mix compiler integration
# Hooks into compilation pipeline for AST extraction
# Provides incremental compilation support
```

## Data Models

### Core Types

```elixir
@type module_name :: atom()
@type function_key :: {module_name(), atom(), non_neg_integer()}
@type ast_node_id :: binary()
@type correlation_id :: binary()
@type pattern_result :: %{
  matches: [match()],
  total_analyzed: non_neg_integer(),
  pattern_stats: map(),
  analysis_time_ms: non_neg_integer()
}
```

### Performance Data Structures

```elixir
@type instrumentation_point :: %{
  ast_node_id: ast_node_id(),
  instrumentation_type: :function_entry | :pipe_operation | :case_branch,
  metadata: map(),
  correlation_hints: [correlation_id()]
}

@type correlation_index :: %{
  correlation_id() => ast_node_id()
}
```

## API Specifications

### Repository API

```elixir
# Module Operations
ElixirScope.ASTRepository.Repository.store_module(repo, module_data)
ElixirScope.ASTRepository.Repository.get_module(repo, module_name)
ElixirScope.ASTRepository.Repository.update_module(repo, module_name, update_fn)

# Function Operations  
ElixirScope.ASTRepository.Repository.store_function(repo, function_data)
ElixirScope.ASTRepository.Repository.get_function(repo, function_key)

# Correlation Operations
ElixirScope.ASTRepository.Repository.correlate_event(repo, runtime_event)
ElixirScope.ASTRepository.Repository.get_instrumentation_points(repo, ast_node_id)
```

### Query API

```elixir
# Query Building
query = ElixirScope.ASTRepository.QueryBuilder.new()
  |> from(:functions)
  |> where([{:complexity_score, :gt, 10}])
  |> order_by({:complexity_score, :desc})
  |> limit(50)

# Query Execution
{:ok, result} = ElixirScope.ASTRepository.QueryBuilder.Executor.execute_query(repo, query)
```

### Pattern Matching API

```elixir
# Pattern Analysis
pattern_spec = %{
  pattern_type: :anti_pattern,
  criteria: %{max_complexity: 15, min_function_length: 50}
}

{:ok, result} = ElixirScope.ASTRepository.PatternMatcher.Core.match_anti_pattern_with_timing(
  repo, pattern_spec, :default_library
)
```

## Performance Specifications

### Lookup Performance
- **Module Lookup**: O(1) - Target: < 1ms for 10K modules
- **Function Lookup**: O(1) - Target: < 1ms for 100K functions
- **Correlation Mapping**: O(log n) - Target: < 5ms for 1M correlations
- **Pattern Matching**: O(n) - Target: < 100ms for 1K modules

### Memory Usage
- **Base Repository**: < 50MB for typical Elixir project
- **Pattern Cache**: Configurable LRU with 100MB default limit
- **Correlation Index**: < 10MB for 100K correlations
- **Memory Pressure Response**: Auto-cleanup at 80% threshold

### Concurrency
- **Read Operations**: Unlimited concurrent reads via ETS `:read_concurrency`
- **Write Operations**: Batched writes via GenServer
- **Pattern Analysis**: Parallel processing with configurable worker pools
- **File Watching**: Non-blocking incremental updates

## Integration Points

### Foundation Layer Integration

```elixir
# Uses Foundation Layer services:
alias ElixirScope.Storage.DataAccess          # ETS storage patterns
alias ElixirScope.Utils                       # Utility functions
alias ElixirScope.Foundation.Config           # Configuration management
```

### Runtime Layer Integration

```elixir
# Provides correlation services to Runtime Layer:
# - ast_node_id lookup from correlation_id
# - instrumentation_point metadata
# - execution frequency tracking
```

### Interface Layer Integration

```elixir
# Provides query and analysis services:
# - Complex AST queries
# - Pattern detection results
# - Code quality metrics
# - Dependency analysis
```

## Implementation Guidelines

### Error Handling
```elixir
# All public functions return {:ok, result} | {:error, reason}
# Internal functions may raise for programming errors
# Graceful degradation for memory pressure
# Comprehensive logging for debugging
```

### Testing Strategy
```elixir
# Unit tests for all core components
# Property-based testing for pattern matching
# Performance benchmarks for critical paths
# Integration tests with Foundation Layer
```

### Configuration
```elixir
# Memory limits configurable per table
# Pattern matching timeout controls
# Cache TTL and size limits
# File watching debounce settings
```

### Monitoring
```elixir
# Repository statistics via get_statistics/1
# Performance metrics collection
# Memory pressure monitoring
# Query performance tracking
```

## File Structure

```
lib/elixir_scope/ast/
├── analysis/
│   ├── pattern_matcher/           # 9 modules - Pattern analysis engine
│   └── performance_optimizer/     # 5 modules - Performance optimization
├── compilation/
│   └── mix_task.ex               # Mix compiler integration
├── data/
│   ├── module_data.ex            # Core module data structure
│   ├── function_data.ex          # Function-level data
│   ├── complexity_metrics.ex     # Complexity calculations
│   └── supporting_structures.ex  # Utility data types
├── parsing/
│   ├── parser.ex                 # Core AST parser (16K)
│   ├── instrumentation_mapper.ex # Runtime correlation (20K)
│   └── analysis/                 # 5 specialized analyzers
├── querying/
│   ├── executor.ex               # Query execution engine
│   ├── optimizer.ex              # Query optimization
│   └── cache.ex                  # Query result caching
├── repository/
│   ├── core.ex                   # Main repository (20K)
│   ├── enhanced.ex               # Advanced features (24K)
│   ├── memory_manager/           # 8 modules - Memory management
│   ├── project_population/       # 11 modules - Batch analysis
│   └── synchronization/
│       ├── file_watcher.ex       # File watching (28K - NEEDS REFACTOR)
│       └── synchronizer.ex       # Update coordination
└── transformation/
    ├── transformer.ex            # Core transformations
    ├── orchestrator.ex           # Pipeline coordination
    └── injector_helpers.ex       # Instrumentation injection
```

### Priority Refactoring Targets

1. **file_watcher.ex (28K)** - Extract into multiple focused modules
2. **enhanced.ex (24K)** - Split advanced features into separate modules  
3. **Enhanced repository core (20K)** - Modularize complex functionality
4. **instrumentation_mapper.ex (20K)** - Extract correlation algorithms

### Implementation Order

1. **Phase 1**: Core data structures and repository
2. **Phase 2**: Basic parsing and query functionality  
3. **Phase 3**: Pattern matching engine
4. **Phase 4**: Advanced features and optimization
5. **Phase 5**: File watching and incremental updates

---

**Next Steps**: Begin implementation with Phase 1 focusing on the core repository and data structures, ensuring solid foundations before building advanced features. 