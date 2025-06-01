# REQ-01-CORE-REPOSITORY.md

## Overview
**Phase**: 1 of 5  
**Dependencies**: Foundation Layer  
**Deliverables**: Core repository and data structures  
**Estimated Effort**: 3 developer weeks

## Context & References
- **Architecture**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#1-repository-system)
- **Data Models**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#5-data-models)
- **API Contracts**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#repository-api)
- **Foundation Integration**: Uses `ElixirScope.Storage.DataAccess` patterns

## Functional Requirements

### FR-1.1: Module Data Storage
**Priority**: MUST  
**Description**: Repository MUST store module data with O(1) lookup performance  
**Acceptance Criteria**:
- [ ] Store `ModuleData.t()` structures in ETS table with module_name as key
- [ ] Support concurrent reads via `:read_concurrency` option
- [ ] Implement atomic updates with GenServer coordination
- [ ] Maintain compilation_hash for change detection
- [ ] Store instrumentation_points and correlation_metadata

### FR-1.2: Function Data Storage
**Priority**: MUST  
**Description**: Repository MUST store function-level data with efficient retrieval  
**Acceptance Criteria**:
- [ ] Store `FunctionData.t()` structures with function_key as primary key
- [ ] Support lookup by `{module_name, function_name, arity}` tuple
- [ ] Store AST fragments and complexity scores
- [ ] Maintain runtime correlation data slots

### FR-1.3: AST Node Mapping
**Priority**: MUST  
**Description**: Repository MUST maintain bidirectional AST node mappings  
**Acceptance Criteria**:
- [ ] Store AST nodes with unique `ast_node_id` identifiers
- [ ] Support correlation_id to ast_node_id mapping
- [ ] Implement instrumentation point storage and retrieval
- [ ] Maintain temporal correlation indices

### FR-1.4: Repository Lifecycle Management
**Priority**: MUST  
**Description**: Repository MUST support creation, cleanup, and monitoring  
**Acceptance Criteria**:
- [ ] GenServer-based repository with configurable name
- [ ] ETS table lifecycle management (creation, cleanup)
- [ ] Repository statistics collection and reporting
- [ ] Health check functionality
- [ ] Graceful shutdown with data preservation options

### FR-1.5: Configuration Management
**Priority**: SHOULD  
**Description**: Repository SHOULD support runtime configuration  
**Acceptance Criteria**:
- [ ] Configurable memory limits per table type
- [ ] Adjustable cleanup intervals and TTL settings
- [ ] Performance tracking enable/disable
- [ ] Maximum table size limits with overflow handling

## Non-Functional Requirements

### NFR-1.1: Performance
- **Module lookup**: < 1ms (99th percentile) for 10K modules
- **Function lookup**: < 1ms (99th percentile) for 100K functions
- **Correlation mapping**: < 5ms (99th percentile) for 1M correlations
- **Memory usage**: < 50MB base repository for typical Elixir project

### NFR-1.2: Reliability  
- **Availability**: 99.9% uptime during normal operation
- **Error recovery**: Automatic ETS table reconstruction on corruption
- **Memory pressure**: Graceful degradation with LRU eviction
- **Supervision**: OTP supervision tree integration

### NFR-1.3: Concurrency
- **Read operations**: Unlimited concurrent reads via ETS `:read_concurrency`
- **Write operations**: Serialized through GenServer with batching support
- **Lock contention**: < 1% under normal load patterns
- **Process isolation**: Repository failures don't affect Foundation Layer

### NFR-1.4: Scalability
- **Module capacity**: Support up to 10K modules
- **Function capacity**: Support up to 100K functions
- **AST node capacity**: Support up to 1M instrumented nodes
- **Linear memory growth**: O(n) memory usage with data size

## Technical Implementation Notes

### Files to Implement
- [ ] `lib/elixir_scope/ast/repository/core.ex` (estimated: 500 LOC)
  - GenServer implementation with ETS table management
  - CRUD operations for modules, functions, AST nodes
  - Correlation index management
  - Statistics collection and health checks

- [ ] `lib/elixir_scope/ast/data/module_data.ex` (estimated: 200 LOC)
  - ModuleData struct definition and type specifications
  - Constructor functions and validation
  - Update helpers and data transformation utilities
  - Runtime correlation integration points

- [ ] `lib/elixir_scope/ast/data/function_data.ex` (estimated: 150 LOC)
  - FunctionData struct with complexity tracking
  - Call graph data structures
  - Performance metrics slots
  - Runtime correlation hooks

- [ ] `lib/elixir_scope/ast/data/shared_data_structures.ex` (estimated: 100 LOC)
  - Common type definitions and utilities
  - Correlation ID generation and management
  - AST node ID utilities
  - Performance tracking structures

- [ ] `lib/elixir_scope/ast/data/supporting_structures.ex` (estimated: 100 LOC)
  - Instrumentation point definitions
  - Correlation metadata structures
  - Repository configuration types
  - Statistics and monitoring types

### Integration Points
- **Foundation Layer**: Uses `ElixirScope.Storage.DataAccess` for ETS patterns
- **Configuration**: Integrates with `ElixirScope.Foundation.Config` for settings
- **Utilities**: Uses `ElixirScope.Utils` for common operations
- **Error Handling**: Follows Foundation Layer error patterns

### ETS Table Design
```elixir
# Modules table: O(1) module lookup
:ets.new(:ast_modules, [:set, :public, {:read_concurrency, true}])

# Functions table: O(1) function lookup  
:ets.new(:ast_functions, [:set, :public, {:read_concurrency, true}])

# AST nodes table: instrumentation mapping
:ets.new(:ast_nodes, [:set, :public, {:read_concurrency, true}])

# Correlation index: runtime correlation
:ets.new(:correlation_index, [:bag, :public, {:read_concurrency, true}])
```

## Testing Requirements

### Unit Tests
- [ ] Repository GenServer lifecycle (start, stop, restart)
- [ ] Module CRUD operations with validation
- [ ] Function storage and retrieval
- [ ] AST node mapping functionality
- [ ] Correlation index operations
- [ ] Configuration validation and application
- [ ] Error handling for invalid data

### Integration Tests
- [ ] Foundation Layer DataAccess integration
- [ ] Configuration service integration
- [ ] Error handling with Foundation Layer patterns
- [ ] Multi-repository scenarios

### Performance Tests
- [ ] Module lookup benchmark: 1K, 10K, 100K scale
- [ ] Function lookup benchmark with various arity distributions
- [ ] Correlation mapping performance under load
- [ ] Memory usage profiling with realistic data sets
- [ ] Concurrent access stress testing (100+ processes)

### Property-Based Tests
- [ ] Repository state consistency under concurrent operations
- [ ] ETS table integrity after random operations
- [ ] Data serialization/deserialization round-trips

## Definition of Done
- [ ] All functional requirements implemented and tested
- [ ] Performance benchmarks meet or exceed NFR targets
- [ ] Unit test coverage ≥ 90% for all modules
- [ ] Integration tests pass with Foundation Layer
- [ ] Performance tests validate scalability targets
- [ ] Code review completed with senior developer approval
- [ ] Dialyzer passes with zero warnings
- [ ] Documentation updated in AST_TECH_SPEC.md
- [ ] Ready for Phase 2 dependency integration

## Risk Mitigation
- **ETS Memory Growth**: Implement configurable size limits with LRU eviction
- **Correlation Index Performance**: Monitor and optimize bag table operations
- **GenServer Bottleneck**: Design for future batching and parallel processing
- **Data Consistency**: Implement atomic operations and validation

## Phase 2 Handoff Requirements
- Core repository operational and tested
- Data structures proven with realistic data sets
- API contracts validated and stable
- Performance baselines established
- Integration patterns documented for Phase 2 parsing system 