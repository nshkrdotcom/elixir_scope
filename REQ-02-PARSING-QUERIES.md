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