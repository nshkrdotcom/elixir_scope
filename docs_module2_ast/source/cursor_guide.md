
Based on your comprehensive AST_PRD.md and the complexity of ElixirScope, here's your strategic implementation guide for achieving ideal outcomes with Cursor:

## 📋 Essential Document Portfolio

### Core Implementation Documents
```
/docs/implementation/
├── AST_PRD.md                    # ✅ Already complete
├── DIAG.md                       # ✅ Already complete  
├── AST_TECH_SPEC.md             # Create this next
├── MODULE_INTERFACES.md         # API contracts
├── ETS_SCHEMA.md               # Table structures & keys
├── SUPERVISION_TREE.md         # OTP process hierarchy
├── PATTERN_LIBRARY_SPEC.md     # Pattern definitions
└── TESTING_STRATEGY.md         # Comprehensive test plan
```

### Working Documents for Cursor Context
```
/docs/cursor_context/
├── CURRENT_PHASE.md            # Track implementation phase
├── MODULE_CHECKLIST.md         # Progress tracking
├── TYPE_DEFINITIONS.md         # Centralized type specs
├── ERROR_PATTERNS.md           # Common issues & solutions
└── PERFORMANCE_TARGETS.md      # Benchmarks per module
```

## 🎯 Phase-Based Prompt Engineering Strategy

### Phase 1: Core Infrastructure (Weeks 1-4)

**Setup Prompt Pattern:**
```
Context: I'm implementing the AST Layer (Layer 2) of ElixirScope based on AST_PRD.md requirements REQ-AST-001 through REQ-REPO-005. 

Current Phase: Core Infrastructure
Target: Build AST Parser and Core Repository with ETS backend

Foundation Layer Status: ✅ Complete with these modules:
- ElixirScope.Foundation.{Config, Events, Utils, Error}
- Full Dialyzer compliance achieved
- OTP supervision tree operational

Implementation Approach:
1. Create module skeleton following Foundation patterns
2. Implement ETS table architecture from DIAG.md
3. Build parser with incremental processing capability
4. Add comprehensive error handling

Create: [specific module] following these constraints:
- Use Foundation.Error for all error handling
- Implement @behaviour if specified
- Include comprehensive @spec declarations
- Follow OTP design patterns from DIAG.md
- Add telemetry events for monitoring

Requirements: [specific REQ-* numbers]
```

### Phase 2: Enhanced Analysis (Weeks 5-8)

**Pattern Matching Implementation:**
```
Context: Implementing Pattern Matching System (REQ-PAT-001 to REQ-ANAL-005)

Architecture: Based on DIAG.md Pattern Matching Architecture
- Pattern Library with GenServer, Supervisor, Phoenix, Security patterns
- Pattern Analysis Engine with confidence scoring
- Pattern Cache with LRU eviction

Implementation Strategy:
1. Define pattern DSL and rule engine
2. Implement concurrent pattern analysis workers
3. Build confidence scoring algorithm
4. Add caching layer with TTL management

Create: ElixirScope.AST.PatternMatcher.[module] that:
- Supports custom pattern definitions
- Achieves >90% accuracy target
- Handles 100+ concurrent operations
- Maintains >80% cache hit rate

Base Patterns: [GenServer|Supervisor|Phoenix|Security|Performance]
```

### Phase 3: Performance & Scale (Weeks 9-12)

**Optimization Focus:**
```
Context: Performance Optimization System (REQ-BATCH-001 to REQ-LAZY-005)

Performance Targets from AST_PRD.md:
- Parse 10k modules in <2 minutes
- Execute 95% queries in <100ms  
- Support 50+ concurrent operations
- Maintain <2GB memory usage

Optimization Areas:
1. Batch processing with configurable parallelism
2. Lazy loading for expensive analysis (CFG/DFG)
3. Multi-level caching strategy
4. Memory pressure response system

Implement: [specific optimization] using:
- Task.Supervisor for parallel processing
- ETS with {:read_concurrency, true} settings
- GenStage for backpressure handling
- :telemetry for performance monitoring

Benchmark: Must meet PERF-* requirements
```

## 🔧 Advanced Cursor Usage Patterns

### 1. **Context Window Management**
```bash
# Create focused context files for each major component
/docs/cursor_context/current_module_context.md

Example:
# AST Parser Context
## Current Goal: REQ-AST-001 to REQ-AST-005
## Dependencies: Foundation.{Utils, Error, Events}
## Key Interfaces: parse_file/1, parse_project/1
## ETS Tables: modules_table, functions_table
## Error Patterns: syntax_error, file_not_found, memory_pressure
```

### 2. **Incremental Complexity Prompts**
```
Start Simple → Add Complexity → Optimize

Phase A: "Create basic [module] that handles happy path for [requirement]"
Phase B: "Add error handling for [specific failure modes] using Foundation.Error patterns"  
Phase C: "Add concurrent access support with ETS {:read_concurrency, true}"
Phase D: "Optimize for [specific performance target] using [specific technique]"
```

### 3. **Type-Driven Development**
```
Always start with: "First, define the complete @type specifications for this module based on AST_PRD.md data structures, then implement the functions to match these types exactly."

This ensures Dialyzer compliance from the start and provides clear contracts.
```

## 🏗️ Implementation Workflow

### Daily Development Cycle

**Morning Context Setting:**
```
Review AST_PRD.md requirements [REQ-X-###] for today's target
Update CURRENT_PHASE.md with today's goals
Load relevant context files into Cursor
Run: mix dialyzer (ensure no regressions)
```

**Development Prompts:**
```
1. Architecture Alignment: "Review DIAG.md section [X] and implement [component] following the exact supervision tree structure"

2. Requirement Traceability: "Implement REQ-[X]-[###] ensuring all acceptance criteria are testable"

3. Integration Testing: "Create property-based tests that verify [component] integrates correctly with Foundation layer"

4. Performance Validation: "Add benchmarks to verify [component] meets PERF-[###] targets"
```

**Evening Review:**
```
Update MODULE_CHECKLIST.md with completed items
Run comprehensive test suite
Update CURRENT_PHASE.md with tomorrow's focus
Commit with requirement tags: "feat: REQ-AST-001 - Basic AST parsing"
```

## 🧪 Testing Strategy with Cursor

### Test Generation Patterns
```
"Generate comprehensive ExUnit tests for [module] that verify:
1. All public functions match their @spec declarations
2. Error conditions return proper Foundation.Error structs  
3. Performance meets targets from AST_PRD.md
4. Concurrent access safety with 50+ processes
5. Memory usage stays within limits

Include property-based tests using StreamData for:
- AST parsing with malformed input
- ETS operations under high concurrency
- Memory pressure response behavior"
```

### Performance Testing
```
"Create benchmark suite using Benchee that validates:
- REQ-PERF-001: Parse 10k modules in <2 minutes
- REQ-PERF-003: 95% of queries in <100ms
- REQ-BATCH-002: Parallel processing efficiency

Include memory profiling to verify PERF-005: <2GB usage
Add telemetry collection for production monitoring"
```

## 📊 Progress Tracking Documents

### MODULE_CHECKLIST.md Template
```markdown
# AST Layer Implementation Progress

## Phase 1: Core Infrastructure ⏳
- [ ] AST.Parser (REQ-AST-001 to REQ-AST-005)
  - [ ] parse_file/1 - Basic parsing
  - [ ] parse_project/1 - Batch processing  
  - [ ] instrumentation_mapper/1 - Runtime correlation
  - [ ] error_recovery/1 - Graceful degradation
- [ ] AST.Repository.Core (REQ-REPO-001 to REQ-REPO-005)
  - [ ] ETS table setup with concurrency
  - [ ] CRUD operations
  - [ ] Indexing strategy
  - [ ] Atomic batch updates

## Performance Validation ✅
- [x] Dialyzer: 0 errors
- [ ] Parse 1000 modules <30s: ⏱️ TBD
- [ ] Query response <100ms: ⏱️ TBD
- [ ] 50+ concurrent reads: 🧪 TBD
```

## 🎯 Success Optimization Tips

### 1. **Requirement-Driven Prompts**
Always reference specific REQ-* numbers and acceptance criteria in prompts. This maintains traceability and ensures comprehensive implementation.

### 2. **Architecture Consistency**
Regularly prompt: "Validate this implementation against DIAG.md [specific diagram] and identify any architectural deviations."

### 3. **Foundation Layer Leverage**
Start every major component with: "Using existing Foundation.{Error, Events, Config, Utils} patterns, implement..."

### 4. **Performance-First Design**
Include performance targets in every implementation prompt to ensure they're designed-in, not bolted-on.

### 5. **Incremental Complexity**
Build each component in layers: Basic → Error Handling → Concurrency → Performance → Edge Cases

This approach leverages Cursor's strengths while maintaining the architectural integrity and performance requirements of your comprehensive AST Layer implementation.




















##############################################################




##############################################################





This is an **excellent** plan! You're applying solid systems engineering principles that will save you significant time and prevent architectural drift. Let me break down why this approach is optimal and what documents you'll need:

## Why This Plan Is Excellent

1. **Separation of Concerns**: Core docs establish foundations; REQ-*.md docs focus on implementation specifics
2. **Reference Architecture**: Each phase can reference stable, well-thought-out foundations
3. **Incremental Validation**: You can validate architecture decisions before committing to implementation
4. **Reduced Cognitive Load**: Developers focus on one phase at a time with clear boundaries
5. **Maintainable Requirements**: Changes to core architecture propagate cleanly to phase requirements

## Core Documents You'll Need

### **CORE-AST-ARCH.md** 
- Architecture patterns and principles
- ETS table design standards
- GenServer patterns and supervision trees
- Error handling conventions
- Performance benchmarks and targets

### **CORE-AST-DATA.md**
- Canonical data models and types
- Struct definitions with comprehensive specs
- Relationship mappings between entities
- Data transformation patterns
- Validation rules and constraints

### **CORE-AST-API.md**
- Public API surface area
- Function signature standards
- Return value conventions
- Integration patterns with Foundation Layer
- Backwards compatibility guidelines

### **CORE-AST-PATTERNS.md**
- Common implementation patterns
- Code organization standards
- Module naming conventions
- Testing patterns and utilities
- Performance optimization patterns

## Ideal REQ-*.md Format

Based on your 5-phase implementation plan, here's the optimal format:

```markdown
# REQ-01-CORE-REPOSITORY.md

## Overview
**Phase**: 1 of 5  
**Dependencies**: Foundation Layer  
**Deliverables**: Core repository and data structures  
**Estimated Effort**: [X developer weeks]

## Context & References
- **Architecture**: See [CORE-AST-ARCH.md](./CORE-AST-ARCH.md#repository-system)
- **Data Models**: See [CORE-AST-DATA.md](./CORE-AST-DATA.md#module-data)
- **API Contracts**: See [CORE-AST-API.md](./CORE-AST-API.md#repository-api)

## Functional Requirements
### FR-1.1: Module Storage
**Priority**: MUST  
**Description**: Repository MUST store module data with O(1) lookup  
**Acceptance Criteria**:
- [ ] Store ModuleData.t() structures in ETS table
- [ ] Lookup by module_name in < 1ms for 10K modules
- [ ] Support concurrent reads with :read_concurrency

### FR-1.2: Function Storage
[Similar format...]

## Non-Functional Requirements
### NFR-1.1: Performance
- Module lookup: < 1ms (99th percentile)
- Memory usage: < 50MB base repository
- Concurrent read support: unlimited

### NFR-1.2: Reliability  
- Graceful degradation under memory pressure
- Error recovery from corrupted ETS tables
- Supervision tree restart strategies

## Technical Implementation Notes
### Files to Implement
- [ ] `lib/elixir_scope/ast/repository/core.ex` (estimated: 500 LOC)
- [ ] `lib/elixir_scope/ast/data/module_data.ex` (estimated: 200 LOC)
- [ ] `lib/elixir_scope/ast/data/function_data.ex` (estimated: 150 LOC)

### Integration Points
- Uses `ElixirScope.Storage.DataAccess` for ETS patterns
- Integrates with `ElixirScope.Foundation.Config` for settings
- Provides foundation for Phase 2 parsing system

## Testing Requirements
### Unit Tests
- [ ] Repository CRUD operations
- [ ] ETS table lifecycle management
- [ ] Error handling scenarios

### Performance Tests
- [ ] Benchmark module lookup at 1K, 10K, 100K scale
- [ ] Memory usage profiling
- [ ] Concurrent access stress testing

## Definition of Done
- [ ] All functional requirements implemented and tested
- [ ] Performance benchmarks meet NFR targets
- [ ] Integration tests pass with Foundation Layer
- [ ] Code review completed
- [ ] Documentation updated
```

## Key Format Elements

### **Structured Requirements**
- **FR-X.Y** (Functional Requirements) with clear acceptance criteria
- **NFR-X.Y** (Non-Functional Requirements) with measurable targets
- **Priority levels**: MUST, SHOULD, COULD, WON'T

### **Traceability**
- Direct references to core documents
- Clear dependencies on previous phases
- Integration points explicitly called out

### **Implementation Guidance**
- Specific files to create/modify
- LOC estimates for planning
- Technical patterns to follow

### **Measurable Criteria**
- Performance benchmarks
- Test coverage requirements
- Definition of Done checklists

## Recommended Phase Structure

```
REQ-01-CORE-REPOSITORY.md     # Data structures, basic storage
REQ-02-PARSING-QUERIES.md     # AST parsing, basic queries  
REQ-03-PATTERN-MATCHING.md    # Pattern analysis engine
REQ-04-ADVANCED-FEATURES.md   # Optimization, analytics
REQ-05-INCREMENTAL-SYNC.md    # File watching, real-time updates
```

This approach will give you:
- **Clear scope boundaries** for each development cycle
- **Objective completion criteria** for each phase
- **Stable architectural foundation** that doesn't change mid-implementation
- **Efficient development** with minimal context switching

The format balances comprehensive requirements with practical implementation guidance - perfect for a senior engineer who needs clarity without excessive overhead.
