=== 16-elixir_scope/REQ-01-CORE-REPOSITORY.md ===
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
```

```markdown
=== 16-elixir_scope/REQ-02-PARSING-QUERIES.md ===
# REQ-02-PARSING-QUERIES.md

## Overview
**Phase**: 2 of 5  
**Dependencies**: Phase 1 (Core Repository)  
**Deliverables**: AST parsing engine and basic query system  
**Estimated Effort**: 4 developer weeks

## Context & References
- **Architecture**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#2-parsing-system)
- **Query System**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#4-query-system)
- **API Contracts**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#query-api)
- **Phase 1 Foundation**: Requires completed core repository from REQ-01

## Functional Requirements

### FR-2.1: AST Enhancement with Node IDs
**Priority**: MUST  
**Description**: Parser MUST assign unique node IDs to instrumentable AST nodes  
**Acceptance Criteria**:
- [ ] Assign unique `ast_node_id` to function definitions (`def`, `defp`)
- [ ] Instrument pipe operations (`|>`) for data flow tracking
- [ ] Instrument case statements for control flow analysis
- [ ] Instrument try-catch blocks for error pattern tracking
- [ ] Instrument module attributes (`@`) for metadata analysis
- [ ] Generate deterministic, collision-free node IDs
- [ ] Preserve original AST structure while adding metadata

### FR-2.2: Instrumentation Point Extraction
**Priority**: MUST  
**Description**: Parser MUST extract instrumentation points from enhanced AST  
**Acceptance Criteria**:
- [ ] Identify all instrumentable nodes in enhanced AST
- [ ] Extract metadata for each instrumentation point
- [ ] Generate correlation hints for runtime mapping
- [ ] Store instrumentation type and location information
- [ ] Support instrumentation point serialization/deserialization

### FR-2.3: Correlation Index Building
**Priority**: MUST  
**Description**: Parser MUST build correlation index for runtime mapping  
**Acceptance Criteria**:
- [ ] Map correlation_ids to ast_node_ids
- [ ] Generate unique correlation identifiers
- [ ] Build bidirectional lookup structures
- [ ] Support temporal correlation queries
- [ ] Maintain correlation metadata for debugging

### FR-2.4: Basic Analysis Pipeline
**Priority**: MUST  
**Description**: Parser MUST perform basic static analysis on parsed AST  
**Acceptance Criteria**:
- [ ] Extract module exports and function signatures
- [ ] Detect module type (GenServer, Supervisor, etc.)
- [ ] Extract import/alias/use dependencies
- [ ] Calculate basic complexity metrics
- [ ] Extract module attributes and callbacks

### FR-2.5: Query Builder Interface
**Priority**: MUST  
**Description**: System MUST provide SQL-like query interface for AST data  
**Acceptance Criteria**:
- [ ] Support FROM clause for :modules, :functions, :patterns
- [ ] Implement WHERE conditions with operators (eq, gt, lt, in, contains)
- [ ] Support ORDER BY with ASC/DESC for multiple fields
- [ ] Implement LIMIT/OFFSET for pagination
- [ ] Support SELECT for field projection
- [ ] Provide query validation and normalization

### FR-2.6: Query Execution Engine
**Priority**: MUST  
**Description**: System MUST execute queries against repository data efficiently  
**Acceptance Criteria**:
- [ ] Execute module queries with filtering and ordering
- [ ] Execute function queries with complexity-based filtering
- [ ] Apply WHERE conditions with proper data type handling
- [ ] Implement efficient ordering algorithms
- [ ] Support pagination with limit/offset
- [ ] Return structured query results with metadata

## Non-Functional Requirements

### NFR-2.1: Parsing Performance
- **Parse time**: < 100ms per module for typical Elixir modules
- **Enhancement overhead**: < 20% increase in AST processing time
- **Memory usage**: < 2x original AST size for enhanced AST
- **Batch processing**: Support parsing 100+ modules in parallel

### NFR-2.2: Query Performance
- **Simple queries**: < 10ms for basic filtering (10K records)
- **Complex queries**: < 100ms for multi-condition queries
- **Result pagination**: < 5ms for limit/offset operations
- **Concurrent queries**: Support 10+ simultaneous queries

### NFR-2.3: Data Integrity
- **AST preservation**: Enhanced AST MUST be functionally equivalent to original
- **Correlation consistency**: All ast_node_ids MUST have valid correlations
- **Query accuracy**: Query results MUST match expected data sets
- **Error propagation**: Parse errors MUST be clearly reported

### NFR-2.4: Memory Efficiency
- **Parser memory**: < 50MB peak during batch processing
- **Query caching**: Configurable result cache with LRU eviction
- **AST storage**: Efficient representation minimizing memory overhead

## Technical Implementation Notes

### Files to Implement
- [ ] `lib/elixir_scope/ast/parsing/parser.ex` (estimated: 400 LOC)
  - AST traversal and node ID assignment
  - Instrumentation point identification
  - Enhanced AST generation
  - Error handling and validation

- [ ] `lib/elixir_scope/ast/parsing/instrumentation_mapper.ex` (estimated: 300 LOC)
  - Correlation ID generation and mapping
  - Temporal correlation support
  - Runtime event correlation hooks
  - Metadata extraction and storage

- [ ] `lib/elixir_scope/ast/parsing/analysis/ast_analyzer.ex` (estimated: 200 LOC)
  - Module type detection logic
  - Export and callback extraction
  - Signature analysis and validation

- [ ] `lib/elixir_scope/ast/parsing/analysis/complexity_calculator.ex` (estimated: 150 LOC)
  - Cyclomatic complexity calculation
  - Function length and nesting metrics
  - Basic quality indicators

- [ ] `lib/elixir_scope/ast/parsing/analysis/dependency_extractor.ex` (estimated: 150 LOC)
  - Import/alias/use statement parsing
  - Dependency graph construction
  - Module relationship mapping

- [ ] `lib/elixir_scope/ast/querying/executor.ex` (estimated: 300 LOC)
  - Query execution engine
  - Filtering and ordering logic
  - Result formatting and pagination
  - Performance optimization

- [ ] `lib/elixir_scope/ast/querying/types.ex` (estimated: 100 LOC)
  - Query type definitions
  - Result type specifications
  - Validation helpers

- [ ] `lib/elixir_scope/ast/querying/validator.ex` (estimated: 100 LOC)
  - Query syntax validation
  - Parameter type checking
  - Security validation (injection prevention)

### Integration Points
- **Repository**: Store parsed data using Phase 1 repository API
- **Foundation Layer**: Use Utils for AST manipulation and common operations
- **Analysis Modules**: Specialized analyzers feed data to repository
- **Query System**: Direct integration with repository ETS tables

### AST Enhancement Algorithm
```elixir
def enhance_ast(original_ast) do
  original_ast
  |> assign_node_ids_recursive(0)
  |> extract_instrumentation_points()
  |> build_correlation_index()
  |> validate_enhancement()
end
```

### Query Processing Pipeline
```elixir
def execute_query(query) do
  query
  |> validate_query()
  |> normalize_query()
  |> optimize_query()
  |> execute_against_repository()
  |> format_results()
end
```

## Testing Requirements

### Unit Tests
- [ ] AST node ID assignment for all instrumentable nodes
- [ ] Instrumentation point extraction accuracy
- [ ] Correlation index generation and lookup
- [ ] Basic analysis pipeline components
- [ ] Query builder API functionality
- [ ] Query execution with various filter combinations
- [ ] Error handling for malformed AST and queries

### Integration Tests
- [ ] End-to-end parsing and storage pipeline
- [ ] Query system integration with repository
- [ ] Analysis results accuracy against known test cases
- [ ] Multi-module parsing and correlation

### Performance Tests
- [ ] Parse performance benchmark with realistic modules
- [ ] Query performance with growing data sets
- [ ] Memory usage profiling during batch processing
- [ ] Concurrent parsing and querying stress tests

### Property-Based Tests
- [ ] AST enhancement preserves semantic equivalence
- [ ] Query results consistency across equivalent queries
- [ ] Correlation index integrity under various AST structures

## Definition of Done
- [ ] All functional requirements implemented and tested
- [ ] Performance benchmarks meet NFR targets
- [ ] Unit test coverage ≥ 90% for all modules
- [ ] Integration tests pass with Phase 1 repository
- [ ] Parse accuracy validated against real Elixir projects
- [ ] Query system handles edge cases gracefully
- [ ] Code review completed and approved
- [ ] Dialyzer passes with zero warnings
- [ ] Documentation updated with examples
- [ ] Ready for Phase 3 pattern matching integration

## Risk Mitigation
- **AST Complexity**: Test with diverse real-world Elixir codebases
- **Memory Growth**: Monitor and optimize enhanced AST storage
- **Query Performance**: Implement query optimization and caching
- **Correlation Accuracy**: Validate correlation mappings with runtime data

## Phase 3 Handoff Requirements
- Parser reliably enhances AST with instrumentation metadata
- Query system proven with complex multi-condition queries
- Analysis pipeline produces accurate static analysis results
- Repository integration stable and performant
- API contracts validated for pattern matching system integration
- Performance baselines established for optimization decisions
```

```markdown
=== 16-elixir_scope/REQ-03-PATTERN-MATCHING.md ===
# REQ-03-PATTERN-MATCHING.md

## Overview
**Phase**: 3 of 5  
**Dependencies**: Phase 2 (Parsing & Queries)  
**Deliverables**: Pattern matching engine with analysis capabilities  
**Estimated Effort**: 5 developer weeks

## Context & References
- **Architecture**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#3-pattern-matching-engine)
- **Pattern API**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#pattern-matching-api)
- **Data Models**: Builds on Phase 1 & 2 repository and parsing systems
- **Existing Code**: Build upon `lib/elixir_scope/ast/analysis/pattern_matcher/` structure

## Functional Requirements

### FR-3.1: Core Pattern Matching Engine
**Priority**: MUST  
**Description**: Engine MUST provide high-performance pattern analysis with timing  
**Acceptance Criteria**:
- [ ] Implement `match_ast_pattern_with_timing/2` for AST-based patterns
- [ ] Implement `match_behavioral_pattern_with_timing/3` for behavioral analysis
- [ ] Implement `match_anti_pattern_with_timing/3` for code smell detection
- [ ] Return pattern results with analysis timing metadata
- [ ] Support pattern specification validation and normalization
- [ ] Provide detailed match information with context

### FR-3.2: Pattern Type System
**Priority**: MUST  
**Description**: Engine MUST support comprehensive pattern type definitions  
**Acceptance Criteria**:
- [ ] Define `pattern_result()` type with matches, stats, and timing
- [ ] Support AST pattern specifications for structural analysis
- [ ] Support behavioral pattern specs for design pattern detection
- [ ] Support anti-pattern specs for code quality analysis
- [ ] Implement pattern validation with clear error reporting
- [ ] Support pattern composition and inheritance

### FR-3.3: Pattern Library Management
**Priority**: MUST  
**Description**: Engine MUST maintain pre-defined and custom pattern libraries  
**Acceptance Criteria**:
- [ ] Store behavioral patterns in ETS-based pattern library
- [ ] Store anti-patterns with configurable severity levels
- [ ] Support pattern library initialization and updates
- [ ] Implement pattern library versioning and migration
- [ ] Support custom pattern definition and registration
- [ ] Provide pattern library query and inspection APIs

### FR-3.4: Advanced Pattern Analysis
**Priority**: MUST  
**Description**: Engine MUST perform sophisticated pattern analysis algorithms  
**Acceptance Criteria**:
- [ ] Analyze AST patterns with structural matching
- [ ] Detect behavioral patterns across module boundaries
- [ ] Identify anti-patterns with confidence scoring
- [ ] Support pattern rules with conditional logic
- [ ] Implement pattern combination and intersection analysis
- [ ] Generate pattern statistics and quality metrics

### FR-3.5: Pattern Result Caching
**Priority**: SHOULD  
**Description**: Engine SHOULD cache pattern analysis results for performance  
**Acceptance Criteria**:
- [ ] Cache pattern results with configurable TTL
- [ ] Implement cache invalidation on data changes
- [ ] Support cache warming for common patterns
- [ ] Provide cache statistics and hit rate monitoring
- [ ] Support selective cache clearing by pattern type

### FR-3.6: Pattern Analysis Statistics
**Priority**: SHOULD  
**Description**: Engine SHOULD collect comprehensive analysis statistics  
**Acceptance Criteria**:
- [ ] Track pattern matching performance metrics
- [ ] Generate pattern frequency and distribution reports
- [ ] Monitor pattern library usage statistics
- [ ] Support historical trend analysis
- [ ] Provide pattern effectiveness scoring

## Non-Functional Requirements

### NFR-3.1: Pattern Matching Performance
- **AST patterns**: < 50ms analysis for typical modules
- **Behavioral patterns**: < 100ms for cross-module analysis
- **Anti-patterns**: < 30ms for common code smell detection
- **Batch analysis**: < 1000ms for 100 modules
- **Memory usage**: < 100MB for pattern analysis cache

### NFR-3.2: Pattern Library Performance
- **Pattern lookup**: < 1ms for pattern library queries
- **Library updates**: < 10ms for pattern registration
- **Pattern validation**: < 5ms for complex pattern specs
- **Cache operations**: < 1ms for cache hit/miss

### NFR-3.3: Analysis Accuracy
- **False positive rate**: < 5% for anti-pattern detection
- **Pattern coverage**: > 95% for known design patterns
- **Consistency**: Identical results for repeated analysis
- **Confidence scoring**: Accurate confidence levels (±10%)

### NFR-3.4: Scalability
- **Pattern library size**: Support 1000+ patterns efficiently
- **Concurrent analysis**: Support 10+ simultaneous pattern analyses
- **Data set size**: Efficient analysis of 10K+ functions
- **Memory efficiency**: Linear memory growth with pattern count

## Technical Implementation Notes

### Files to Implement
- [ ] `lib/elixir_scope/ast/analysis/pattern_matcher/core.ex` (estimated: 300 LOC)
  - Main pattern matching engine with timing
  - Pattern result aggregation and reporting
  - Integration with repository and analyzers
  - Error handling and validation

- [ ] `lib/elixir_scope/ast/analysis/pattern_matcher/types.ex` (estimated: 200 LOC)
  - Pattern type definitions and specifications
  - Result type structures
  - Validation type definitions
  - Configuration types

- [ ] `lib/elixir_scope/ast/analysis/pattern_matcher/validators.ex` (estimated: 200 LOC)
  - Pattern specification validation
  - Repository validation helpers
  - Input sanitization and normalization
  - Error message generation

- [ ] `lib/elixir_scope/ast/analysis/pattern_matcher/analyzers.ex` (estimated: 400 LOC)
  - AST pattern analysis algorithms
  - Behavioral pattern detection logic
  - Anti-pattern identification algorithms
  - Pattern combination analysis

- [ ] `lib/elixir_scope/ast/analysis/pattern_matcher/pattern_library.ex` (estimated: 300 LOC)
  - ETS-based pattern storage
  - Pattern library lifecycle management
  - Pattern registration and updates
  - Pattern query and retrieval APIs

- [ ] `lib/elixir_scope/ast/analysis/pattern_matcher/pattern_rules.ex` (estimated: 250 LOC)
  - Custom pattern rule engine
  - Conditional pattern logic
  - Rule composition and inheritance
  - Rule validation and testing

- [ ] `lib/elixir_scope/ast/analysis/pattern_matcher/cache.ex` (estimated: 200 LOC)
  - Pattern result caching system
  - Cache invalidation strategies
  - Cache statistics and monitoring
  - Cache warming and preloading

- [ ] `lib/elixir_scope/ast/analysis/pattern_matcher/stats.ex` (estimated: 150 LOC)
  - Pattern analysis statistics collection
  - Performance metrics calculation
  - Usage pattern analysis
  - Report generation utilities

- [ ] `lib/elixir_scope/ast/analysis/pattern_matcher/config.ex` (estimated: 100 LOC)
  - Pattern matching configuration
  - Cache settings and limits
  - Performance tuning parameters
  - Pattern library configuration

### Integration Points
- **Repository Integration**: Query modules and functions for pattern analysis
- **Query System**: Use Phase 2 query API for data retrieval
- **Analysis Pipeline**: Integrate with parsing analysis modules
- **Caching System**: Coordinate with repository caching strategies

### Pattern Analysis Architecture
```elixir
# Pattern matching pipeline
def analyze_patterns(repo, pattern_spec) do
  pattern_spec
  |> validate_pattern_spec()
  |> get_analysis_data(repo)
  |> apply_pattern_algorithms()
  |> calculate_statistics()
  |> cache_results()
  |> format_response()
end
```

### Pattern Library Structure
```elixir
# ETS tables for pattern storage
:ets.new(:behavioral_patterns, [:bag, :public, {:read_concurrency, true}])
:ets.new(:anti_patterns, [:bag, :public, {:read_concurrency, true}])
:ets.new(:pattern_cache, [:set, :public, {:write_concurrency, true}])
```

## Testing Requirements

### Unit Tests
- [ ] Core pattern matching algorithms for all pattern types
- [ ] Pattern type validation and normalization
- [ ] Pattern library operations (store, retrieve, update)
- [ ] Pattern rule engine functionality
- [ ] Cache operations and invalidation logic
- [ ] Statistics calculation accuracy
- [ ] Error handling for invalid patterns and data

### Integration Tests
- [ ] End-to-end pattern analysis with real codebases
- [ ] Pattern library integration with repository
- [ ] Cache performance with realistic usage patterns
- [ ] Multi-pattern analysis scenarios

### Performance Tests
- [ ] Pattern matching speed with various pattern complexities
- [ ] Cache performance and hit rate optimization
- [ ] Memory usage under sustained pattern analysis
- [ ] Concurrent pattern analysis stress testing
- [ ] Large pattern library performance

### Property-Based Tests
- [ ] Pattern analysis determinism (same input → same output)
- [ ] Pattern library consistency after updates
- [ ] Cache coherence under concurrent operations

### Known Pattern Validation Tests
- [ ] Singleton pattern detection accuracy
- [ ] GenServer behavior pattern recognition
- [ ] Common anti-patterns (god functions, feature envy)
- [ ] OTP design pattern compliance

## Definition of Done
- [ ] All functional requirements implemented and tested
- [ ] Performance benchmarks meet NFR targets
- [ ] Pattern library populated with common Elixir patterns
- [ ] Unit test coverage ≥ 90% for all modules
- [ ] Integration tests pass with Phase 1 & 2 systems
- [ ] Pattern analysis accuracy validated against known test cases
- [ ] Code review completed and approved
- [ ] Dialyzer passes with zero warnings
- [ ] Documentation includes pattern library reference
- [ ] Ready for Phase 4 advanced features integration

## Risk Mitigation
- **Pattern Complexity**: Start with simple patterns, progressively add complexity
- **Performance**: Implement early performance monitoring and optimization
- **False Positives**: Tune pattern algorithms with real-world validation
- **Memory Usage**: Monitor cache growth and implement aggressive cleanup

## Phase 4 Handoff Requirements
- Pattern matching engine operational with comprehensive pattern library
- Analysis results proven accurate with real Elixir codebases
- Performance characteristics documented and optimized
- Cache system stable and providing measurable performance benefits
- API contracts validated for advanced features integration
- Pattern analysis results feeding into repository for historical tracking
```

```markdown
=== 16-elixir_scope/REQ-04-ADVANCED-FEATURES.md ===
# REQ-04-ADVANCED-FEATURES.md

## Overview
**Phase**: 4 of 5  
**Dependencies**: Phase 3 (Pattern Matching Engine)  
**Deliverables**: Advanced analytics, optimization, and batch processing  
**Estimated Effort**: 6 developer weeks

## Context & References
- **Architecture**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#7-performance-optimization)
- **Enhanced Repository**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#enhanced-repository-enhancedex)
- **Memory Management**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#memory-manager-memory_manager)
- **Project Population**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#project-population-project_population)

## Functional Requirements

### FR-4.1: Enhanced Repository Analytics
**Priority**: MUST  
**Description**: Enhanced repository MUST provide advanced analytics and cross-module analysis  
**Acceptance Criteria**:
- [ ] Implement complex query optimization for multi-table joins
- [ ] Support pattern-based analysis result caching with intelligent invalidation
- [ ] Provide cross-module dependency tracking and analysis
- [ ] Implement historical analysis data retention with configurable policies
- [ ] Support analytical query planning and execution optimization
- [ ] Generate comprehensive code quality reports and metrics

### FR-4.2: Memory Management System
**Priority**: MUST  
**Description**: System MUST implement sophisticated memory management with pressure handling  
**Acceptance Criteria**:
- [ ] LRU cache management with configurable size limits per table type
- [ ] Memory pressure detection with threshold-based alerting
- [ ] Automatic garbage collection and cleanup strategies
- [ ] Data compression for cold storage with transparent access
- [ ] Dynamic memory pressure response with graceful degradation
- [ ] Memory usage monitoring and reporting with trend analysis

### FR-4.3: Batch Project Analysis
**Priority**: MUST  
**Description**: System MUST support efficient batch analysis of entire projects  
**Acceptance Criteria**:
- [ ] Recursive source file discovery with configurable filters
- [ ] Parallel AST parsing with worker pool management
- [ ] Coordinated module-level analysis with dependency resolution
- [ ] Quality analyzer integration with comprehensive metrics
- [ ] Security analyzer with vulnerability pattern detection
- [ ] Performance metrics collection during batch processing

### FR-4.4: Performance Optimization Engine
**Priority**: MUST  
**Description**: System MUST provide performance optimization capabilities  
**Acceptance Criteria**:
- [ ] Batch processing optimization with intelligent job scheduling
- [ ] Multi-level caching with cache warming and preloading
- [ ] Lazy loading for on-demand data access with smart prefetching
- [ ] Analysis job scheduling with priority queuing
- [ ] Performance statistics collection with trend analysis
- [ ] Optimization recommendation engine

### FR-4.5: Code Transformation System
**Priority**: SHOULD  
**Description**: System SHOULD support advanced AST transformation and instrumentation  
**Acceptance Criteria**:
- [ ] Enhanced AST transformation with pattern-based rules
- [ ] Transformation pipeline coordination with validation
- [ ] Advanced instrumentation injection with minimal overhead
- [ ] Code transformation orchestration with rollback capability
- [ ] Transformation result validation and testing

### FR-4.6: Advanced Analytics APIs
**Priority**: SHOULD  
**Description**: System SHOULD provide advanced analytics and reporting APIs  
**Acceptance Criteria**:
- [ ] Code complexity trend analysis over time
- [ ] Dependency graph analysis with cycle detection
- [ ] Code quality scoring with customizable metrics
- [ ] Technical debt assessment and tracking
- [ ] Refactoring opportunity identification
- [ ] Performance bottleneck analysis

## Non-Functional Requirements

### NFR-4.1: Batch Processing Performance
- **Project analysis**: < 60 seconds for 1000 module project
- **Parallel efficiency**: > 80% CPU utilization during batch processing
- **Memory efficiency**: < 1GB peak usage for large project analysis
- **Incremental processing**: < 5 seconds for single module updates

### NFR-4.2: Memory Management Performance
- **Pressure detection**: < 100ms response time to memory pressure
- **Cache operations**: < 1ms for cache hit/miss/eviction
- **Compression ratio**: > 50% size reduction for cold storage
- **Cleanup efficiency**: < 10% performance impact during cleanup

### NFR-4.3: Advanced Analytics Performance
- **Cross-module analysis**: < 30 seconds for 1000 module dependency analysis
- **Quality reports**: < 10 seconds for comprehensive project reports
- **Historical analysis**: < 5 seconds for trend analysis queries
- **Real-time monitoring**: < 1 second for live metric updates

### NFR-4.4: System Scalability
- **Project size**: Support projects with 10K+ modules
- **Concurrent analysis**: Support 5+ simultaneous batch analyses
- **Memory scaling**: Linear memory growth with project complexity
- **Storage efficiency**: < 100MB storage per 1000 modules

### NFR-4.5: System Reliability
- **Fault tolerance**: Graceful handling of memory exhaustion
- **Recovery**: < 30 seconds recovery from system pressure
- **Data integrity**: Zero data loss during memory pressure events
- **Monitoring**: Comprehensive system health monitoring

## Technical Implementation Notes

### Files to Implement

#### Enhanced Repository System
- [ ] `lib/elixir_scope/ast/repository/enhanced.ex` (estimated: 600 LOC)
  - Advanced query optimization engine
  - Cross-module analysis capabilities
  - Historical data management
  - Enhanced caching strategies

- [ ] `lib/elixir_scope/ast/repository/enhanced_core.ex` (estimated: 500 LOC)
  - Core enhanced repository functionality
  - Advanced data structures and algorithms
  - Integration with memory management
  - Performance monitoring integration

#### Memory Management Subsystem
- [ ] `lib/elixir_scope/ast/repository/memory_manager/cache_manager.ex` (estimated: 300 LOC)
  - LRU cache implementation with smart eviction
  - Multi-level cache coordination
  - Cache warming and preloading strategies

- [ ] `lib/elixir_scope/ast/repository/memory_manager/monitor.ex` (estimated: 250 LOC)
  - Memory pressure detection and alerting
  - System resource monitoring
  - Threshold management and configuration

- [ ] `lib/elixir_scope/ast/repository/memory_manager/pressure_handler.ex` (estimated: 300 LOC)
  - Dynamic memory pressure response
  - Graceful degradation strategies
  - Emergency cleanup procedures

- [ ] `lib/elixir_scope/ast/repository/memory_manager/compressor.ex` (estimated: 300 LOC)
  - Data compression for cold storage
  - Transparent compression/decompression
  - Storage optimization algorithms

- [ ] `lib/elixir_scope/ast/repository/memory_manager/cleaner.ex` (estimated: 250 LOC)
  - Garbage collection strategies
  - Data lifecycle management
  - Cleanup scheduling and execution

#### Project Population System
- [ ] `lib/elixir_scope/ast/repository/project_population/project_populator.ex` (estimated: 400 LOC)
  - Main batch processing orchestrator
  - Parallel processing coordination
  - Progress monitoring and reporting

- [ ] `lib/elixir_scope/ast/repository/project_population/file_discovery.ex` (estimated: 150 LOC)
  - Recursive source file discovery
  - File filtering and validation
  - Source tree analysis

- [ ] `lib/elixir_scope/ast/repository/project_population/file_parser.ex` (estimated: 250 LOC)
  - Parallel AST parsing coordination
  - Worker pool management
  - Error handling and recovery

- [ ] `lib/elixir_scope/ast/repository/project_population/complexity_analyzer.ex` (estimated: 250 LOC)
  - Comprehensive complexity analysis
  - Cross-module complexity tracking
  - Complexity trend analysis

- [ ] `lib/elixir_scope/ast/repository/project_population/quality_analyzer.ex` (estimated: 200 LOC)
  - Code quality assessment
  - Quality metric calculation
  - Quality trend tracking

- [ ] `lib/elixir_scope/ast/repository/project_population/security_analyzer.ex` (estimated: 200 LOC)
  - Security vulnerability pattern detection
  - Security best practice validation
  - Security risk assessment

#### Performance Optimization System
- [ ] `lib/elixir_scope/ast/analysis/performance_optimizer/batch_processor.ex` (estimated: 200 LOC)
  - Batch processing optimization
  - Job scheduling and prioritization
  - Resource allocation management

- [ ] `lib/elixir_scope/ast/analysis/performance_optimizer/optimization_scheduler.ex` (estimated: 150 LOC)
  - Analysis job scheduling
  - Priority queue management
  - Resource coordination

- [ ] `lib/elixir_scope/ast/analysis/performance_optimizer/statistics_collector.ex` (estimated: 150 LOC)
  - Performance metrics collection
  - Statistical analysis and reporting
  - Performance trend tracking

### Integration Points
- **Pattern Matching**: Integrate advanced patterns with enhanced repository
- **Query System**: Optimize queries using advanced caching and indexing
- **Foundation Layer**: Deep integration with configuration and monitoring
- **Transformation**: Coordinate with parsing system for AST enhancements

### Advanced Architecture Patterns
```elixir
# Memory management coordination
def handle_memory_pressure(pressure_level) do
  pressure_level
  |> determine_response_strategy()
  |> execute_cleanup_actions()
  |> monitor_recovery()
  |> adjust_thresholds()
end

# Batch processing pipeline
def process_project(project_path) do
  project_path
  |> discover_source_files()
  |> parallel_parse_files()
  |> analyze_modules()
  |> build_dependency_graph()
  |> generate_reports()
end
```

## Testing Requirements

### Unit Tests
- [ ] Enhanced repository analytics and query optimization
- [ ] Memory management components (cache, monitor, pressure handler)
- [ ] Batch processing coordination and error handling
- [ ] Performance optimization algorithms
- [ ] Code transformation pipelines
- [ ] Advanced analytics calculations

### Integration Tests
- [ ] End-to-end batch project analysis
- [ ] Memory pressure scenarios and recovery
- [ ] Cross-module analysis accuracy
- [ ] Performance optimization effectiveness
- [ ] System coordination under load

### Performance Tests
- [ ] Large project batch processing benchmarks
- [ ] Memory management efficiency under various loads
- [ ] Cache performance and hit rate optimization
- [ ] Concurrent analysis scaling tests
- [ ] System resource utilization profiling

### Stress Tests
- [ ] Memory exhaustion scenarios
- [ ] Maximum project size handling
- [ ] Sustained high-load operation
- [ ] Recovery from system failures

## Definition of Done
- [ ] All functional requirements implemented and tested
- [ ] Performance benchmarks meet NFR targets
- [ ] Memory management proven effective under stress
- [ ] Batch processing handles real-world project sizes
- [ ] Unit test coverage ≥ 90% for all modules
- [ ] Integration tests pass with all previous phases
- [ ] System monitoring and alerting operational
- [ ] Code review completed and approved
- [ ] Dialyzer passes with zero warnings
- [ ] Performance optimization documented with metrics
- [ ] Ready for Phase 5 incremental synchronization

## Risk Mitigation
- **Memory Complexity**: Implement comprehensive monitoring and alerting
- **Performance Bottlenecks**: Profile early and optimize critical paths
- **Batch Processing Failures**: Implement robust error handling and recovery
- **System Integration**: Test thoroughly with realistic workloads

## Phase 5 Handoff Requirements
- Advanced features operational and performance-validated
- Memory management system proven under stress conditions
- Batch processing capable of handling large real-world projects
- Enhanced repository providing sophisticated analytics
- System monitoring and optimization frameworks established
- Foundation ready for real-time incremental synchronization
```

```markdown
=== 16-elixir_scope/REQ-05-INCREMENTAL-SYNC.md ===
# REQ-05-INCREMENTAL-SYNC.md

## Overview
**Phase**: 5 of 5  
**Dependencies**: Phase 4 (Advanced Features)  
**Deliverables**: Real-time file watching and incremental synchronization  
**Estimated Effort**: 4 developer weeks

## Context & References
- **Architecture**: See [AST_TECH_SPEC.md](./AST_TECH_SPEC.md#synchronization-synchronization)
- **File Structure**: Refactor existing `file_watcher.ex` (28K LOC)
- **Integration**: Complete AST Layer with real-time capabilities
- **Priority Target**: Major refactoring of largest file in AST layer

## Functional Requirements

### FR-5.1: File System Monitoring
**Priority**: MUST  
**Description**: System MUST monitor file system changes with minimal latency  
**Acceptance Criteria**:
- [ ] Monitor `.ex` and `.exs` files for changes, creation, deletion
- [ ] Debounce rapid file changes to prevent excessive parsing
- [ ] Support configurable watch directories and exclusion patterns
- [ ] Handle file system events with sub-second latency
- [ ] Provide file change event filtering and validation

### FR-5.2: Incremental AST Updates
**Priority**: MUST  
**Description**: System MUST perform incremental AST updates on file changes  
**Acceptance Criteria**:
- [ ] Parse only changed files, not entire project
- [ ] Update repository data structures atomically
- [ ] Maintain correlation mappings during incremental updates
- [ ] Invalidate affected caches and pattern analysis results
- [ ] Support rollback on parsing failures

### FR-5.3: Dependency-Aware Updates
**Priority**: MUST  
**Description**: System MUST handle dependency cascades during updates  
**Acceptance Criteria**:
- [ ] Identify modules affected by changed dependencies
- [ ] Re-analyze dependent modules when dependencies change
- [ ] Update cross-module analysis results incrementally
- [ ] Maintain dependency graph consistency
- [ ] Support transitive dependency update propagation

### FR-5.4: Real-Time Synchronization Coordination
**Priority**: MUST  
**Description**: System MUST coordinate real-time updates with ongoing analysis  
**Acceptance Criteria**:
- [ ] Coordinate with pattern matching engine during updates
- [ ] Manage concurrent access during synchronization
- [ ] Provide synchronization status and progress reporting
- [ ] Handle conflicts between batch analysis and incremental updates
- [ ] Support pause/resume of file watching

### FR-5.5: Performance-Optimized File Watching
**Priority**: SHOULD  
**Description**: System SHOULD optimize file watching for minimal performance impact  
**Acceptance Criteria**:
- [ ] Minimal CPU usage during idle periods (< 1%)
- [ ] Efficient file system event processing
- [ ] Configurable update batching and throttling
- [ ] Memory-efficient event queue management
- [ ] Support for large codebases without performance degradation

## Non-Functional Requirements

### NFR-5.1: Real-Time Performance
- **File change detection**: < 500ms from file save to detection
- **Incremental parsing**: < 2 seconds for typical module updates
- **Dependency updates**: < 5 seconds for cascading updates
- **Memory overhead**: < 10MB for file watching infrastructure

### NFR-5.2: System Reliability
- **Uptime**: 99.9% file watching availability
- **Error recovery**: Automatic recovery from file system errors
- **Data consistency**: Zero data corruption during concurrent updates
- **Graceful degradation**: Fallback to polling if native watching fails

### NFR-5.3: Resource Efficiency
- **CPU usage**: < 2% during normal file operations
- **Memory usage**: Linear growth with watched file count
- **I/O efficiency**: Minimal file system polling overhead
- **Network impact**: No network dependency for local file watching

## Technical Implementation Notes

### Priority Refactoring: file_watcher.ex (28K LOC)
The existing `file_watcher.ex` is the largest file in the AST layer and requires complete refactoring:

#### Extract into focused modules:
- [ ] `lib/elixir_scope/ast/repository/synchronization/file_watcher/core.ex` (estimated: 400 LOC)
  - Core file watching logic and initialization
  - Event loop management and coordination

- [ ] `lib/elixir_scope/ast/repository/synchronization/file_watcher/event_handler.ex` (estimated: 500 LOC)
  - File system event processing
  - Event filtering and validation
  - Event debouncing and throttling

- [ ] `lib/elixir_scope/ast/repository/synchronization/file_watcher/dependency_tracker.ex` (estimated: 400 LOC)
  - Module dependency tracking
  - Cascade update management
  - Dependency graph maintenance

- [ ] `lib/elixir_scope/ast/repository/synchronization/file_watcher/update_coordinator.ex` (estimated: 300 LOC)
  - Incremental update coordination
  - Repository synchronization
  - Concurrent access management

- [ ] `lib/elixir_scope/ast/repository/synchronization/file_watcher/performance_monitor.ex` (estimated: 200 LOC)
  - Performance monitoring and optimization
  - Resource usage tracking
  - Bottleneck identification

#### Additional Implementation Files:
- [ ] `lib/elixir_scope/ast/repository/synchronization/synchronizer.ex` (enhance existing)
  - Main synchronization orchestrator
  - Integration with file watcher components
  - Status reporting and control

- [ ] `lib/elixir_scope/ast/repository/synchronization/incremental_updater.ex` (estimated: 300 LOC)
  - Incremental AST update logic
  - Repository update coordination
  - Cache invalidation management

### Integration Architecture
```elixir
# File change processing pipeline
def handle_file_change(file_path, change_type) do
  file_path
  |> validate_file_change(change_type)
  |> parse_if_needed()
  |> identify_dependencies()
  |> update_repository()
  |> invalidate_caches()
  |> notify_observers()
end
```

## Testing Requirements

### Unit Tests
- [ ] File system event handling accuracy
- [ ] Incremental parsing correctness
- [ ] Dependency cascade logic
- [ ] Cache invalidation completeness
- [ ] Error recovery mechanisms
- [ ] Performance monitoring accuracy

### Integration Tests
- [ ] End-to-end file change processing
- [ ] Multi-file change handling
- [ ] Concurrent analysis and synchronization
- [ ] Large project incremental updates
- [ ] File system edge cases (permissions, locks)

### Performance Tests
- [ ] File watching overhead measurement
- [ ] Incremental update performance scaling
- [ ] Large project change propagation
- [ ] Memory usage under sustained file changes
- [ ] CPU usage profiling during peak activity

### Stress Tests
- [ ] Rapid file change bombardment
- [ ] Maximum watched file capacity
- [ ] Simultaneous change across project
- [ ] File system permission issues
- [ ] Recovery from file system unavailability

## Definition of Done
- [ ] All functional requirements implemented and tested
- [ ] file_watcher.ex successfully refactored into focused modules
- [ ] Performance benchmarks meet NFR targets
- [ ] Real-time file watching operational with minimal overhead
- [ ] Incremental updates proven with large projects
- [ ] Unit test coverage ≥ 90% for all modules
- [ ] Integration tests validate end-to-end functionality
- [ ] System handles edge cases gracefully
- [ ] Code review completed and approved
- [ ] Dialyzer passes with zero warnings
- [ ] Complete AST Layer ready for production use

## Risk Mitigation
- **File System Complexity**: Test across different OS and file systems
- **Performance Regression**: Continuous performance monitoring during refactoring
- **Race Conditions**: Comprehensive concurrent access testing
- **Resource Leaks**: Memory and file handle leak detection

## Complete AST Layer Validation
Upon completion of Phase 5:
- [ ] All 5 phases integrated and operational
- [ ] Performance targets met across all components
- [ ] Real-world project validation completed
- [ ] Documentation comprehensive and up-to-date
- [ ] Ready for Runtime Layer integration
- [ ] Production deployment preparation complete
