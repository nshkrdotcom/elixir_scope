# AST Parsing Pipeline

**Version**: 1.0  
**Date**: June 2025  
**Component**: Parsing Subsystem  
**Purpose**: Detailed parsing architecture and implementation guidance

## Parsing Pipeline Overview

The AST Parsing Pipeline transforms Elixir source code into enhanced AST structures with instrumentation points and correlation metadata. This document details the multi-stage parsing process and architectural decisions.

## Parsing Pipeline Architecture

```mermaid
graph TB
    subgraph "Input Layer"
        SOURCE[Source Files]
        CHANGE_EVENTS[File Change Events]
        BATCH_INPUT[Batch Input Queue]
    end

    subgraph "Parsing Pipeline"
        LEX[Lexical Analysis]
        SYNTAX[Syntax Analysis]
        AST_BUILD[AST Builder]
        ENHANCE[Enhancement Stage]
        INSTRU[Instrumentation Mapper]
        VALIDATE[Validation Stage]
    end

    subgraph "Output Layer"
        CORE_REPO[Core Repository]
        ENH_REPO[Enhanced Repository]
        TELEMETRY[Telemetry Events]
        ERROR_LOG[Error Log]
    end

    subgraph "Support Systems"
        ERROR_RECOVERY[Error Recovery]
        CACHE[Parser Cache]
        WORKER_POOL[Worker Pool]
        PROGRESS[Progress Tracker]
    end

    SOURCE --> LEX
    CHANGE_EVENTS --> LEX
    BATCH_INPUT --> LEX

    LEX --> SYNTAX
    SYNTAX --> AST_BUILD
    AST_BUILD --> ENHANCE
    ENHANCE --> INSTRU
    INSTRU --> VALIDATE

    VALIDATE --> CORE_REPO
    VALIDATE --> ENH_REPO
    VALIDATE --> TELEMETRY

    LEX --> ERROR_RECOVERY
    SYNTAX --> ERROR_RECOVERY
    AST_BUILD --> ERROR_RECOVERY
    ERROR_RECOVERY --> ERROR_LOG

    ENHANCE --> CACHE
    INSTRU --> WORKER_POOL
    VALIDATE --> PROGRESS

    style LEX fill:#e1f5fe
    style SYNTAX fill:#f3e5f5
    style AST_BUILD fill:#e8f5e8
    style ENHANCE fill:#fff3e0
    style INSTRU fill:#ffebee
```

## Lexical Analysis Engine

### Token Recognition Architecture

```mermaid
graph TB
    subgraph "Lexical Analyzer"
        INPUT[Character Stream]
        SCANNER[Token Scanner]
        CLASSIFIER[Token Classifier]
        VALIDATOR[Token Validator]
        OUTPUT[Token Stream]
    end

    subgraph "Token Types"
        KEYWORDS[Keywords: def, defmodule, if, case]
        OPERATORS[Operators: +, -, *, /, |>, <|]
        LITERALS[Literals: atoms, strings, numbers]
        DELIMITERS[Delimiters: (), [], {}, do/end]
        IDENTIFIERS[Identifiers: variables, functions]
        SPECIAL[Special: @, &, ^, _]
    end

    subgraph "Recognition Patterns"
        REGEX[Regex Patterns]
        FINITE_STATE[Finite State Machine]
        CONTEXT[Context Awareness]
        LOOKAHEAD[Lookahead Buffer]
    end

    INPUT --> SCANNER
    SCANNER --> CLASSIFIER
    CLASSIFIER --> VALIDATOR
    VALIDATOR --> OUTPUT

    SCANNER --> KEYWORDS
    SCANNER --> OPERATORS
    SCANNER --> LITERALS
    SCANNER --> DELIMITERS
    SCANNER --> IDENTIFIERS
    SCANNER --> SPECIAL

    CLASSIFIER --> REGEX
    CLASSIFIER --> FINITE_STATE
    CLASSIFIER --> CONTEXT
    CLASSIFIER --> LOOKAHEAD

    style SCANNER fill:#e1f5fe
    style CLASSIFIER fill:#f3e5f5
    style KEYWORDS fill:#e8f5e8
```

### Token Processing State Machine

```mermaid
stateDiagram-v2
    [*] --> Start
    Start --> Identifier : letter | _
    Start --> Number : digit
    Start --> String : "
    Start --> Atom : :
    Start --> Operator : operator_char
    Start --> Comment : #
    Start --> Whitespace : space | tab | newline

    Identifier --> Identifier : alphanumeric | _
    Identifier --> [*] : delimiter

    Number --> Number : digit | .
    Number --> [*] : delimiter

    String --> String : any_char
    String --> Escape : \
    String --> [*] : "
    Escape --> String : any_char

    Atom --> AtomQuoted : "
    Atom --> AtomUnquoted : letter
    AtomQuoted --> AtomQuoted : any_char
    AtomQuoted --> [*] : "
    AtomUnquoted --> AtomUnquoted : alphanumeric | _
    AtomUnquoted --> [*] : delimiter

    Operator --> Operator : operator_continuation
    Operator --> [*] : non_operator

    Comment --> Comment : any_char
    Comment --> [*] : newline

    Whitespace --> Whitespace : space | tab
    Whitespace --> [*] : non_whitespace
```

## Syntax Analysis Engine

### Parser Architecture

```mermaid
graph TB
    subgraph "Parsing Strategy"
        RD[Recursive Descent]
        PREC[Precedence Climbing]
        ERROR_REC[Error Recovery]
        CONTEXT[Context Tracking]
    end

    subgraph "Grammar Rules"
        MODULE[Module Declaration]
        FUNCTION[Function Definition]
        EXPRESSION[Expression Parsing]
        PATTERN[Pattern Matching]
        BLOCK[Block Structures]
        MACRO[Macro Handling]
    end

    subgraph "Parse Tree"
        MODULE_NODE[Module Node]
        FUNC_NODE[Function Node]
        EXPR_NODE[Expression Node]
        PATTERN_NODE[Pattern Node]
        BLOCK_NODE[Block Node]
        MACRO_NODE[Macro Node]
    end

    subgraph "Validation Layer"
        SYNTAX_CHECK[Syntax Validation]
        SEMANTIC_CHECK[Semantic Validation]
        SCOPE_CHECK[Scope Validation]
        TYPE_HINT[Type Inference]
    end

    RD --> MODULE
    RD --> FUNCTION
    PREC --> EXPRESSION
    ERROR_REC --> PATTERN
    CONTEXT --> BLOCK
    CONTEXT --> MACRO

    MODULE --> MODULE_NODE
    FUNCTION --> FUNC_NODE
    EXPRESSION --> EXPR_NODE
    PATTERN --> PATTERN_NODE
    BLOCK --> BLOCK_NODE
    MACRO --> MACRO_NODE

    MODULE_NODE --> SYNTAX_CHECK
    FUNC_NODE --> SEMANTIC_CHECK
    EXPR_NODE --> SCOPE_CHECK
    PATTERN_NODE --> TYPE_HINT

    style RD fill:#e1f5fe
    style MODULE fill:#f3e5f5
    style MODULE_NODE fill:#e8f5e8
    style SYNTAX_CHECK fill:#fff3e0
```

### Expression Parsing with Precedence

```mermaid
graph LR
    subgraph "Operator Precedence Levels"
        LEVEL1[Level 1: |>]
        LEVEL2[Level 2: ||, &&]
        LEVEL3[Level 3: ==, !=, <, >]
        LEVEL4[Level 4: ++, --]
        LEVEL5[Level 5: +, -]
        LEVEL6[Level 6: *, /, div]
        LEVEL7[Level 7: **]
        LEVEL8[Level 8: Unary +, -]
        LEVEL9[Level 9: Function calls]
    end

    subgraph "Parsing Algorithm"
        CLIMB[Precedence Climbing]
        LEFT_ASSOC[Left Associative]
        RIGHT_ASSOC[Right Associative]
        UNARY[Unary Operators]
    end

    LEVEL1 --> LEFT_ASSOC
    LEVEL2 --> LEFT_ASSOC
    LEVEL3 --> LEFT_ASSOC
    LEVEL4 --> RIGHT_ASSOC
    LEVEL5 --> LEFT_ASSOC
    LEVEL6 --> LEFT_ASSOC
    LEVEL7 --> RIGHT_ASSOC
    LEVEL8 --> UNARY
    LEVEL9 --> LEFT_ASSOC

    LEFT_ASSOC --> CLIMB
    RIGHT_ASSOC --> CLIMB
    UNARY --> CLIMB

    style CLIMB fill:#e1f5fe
    style LEVEL1 fill:#ffebee
    style LEVEL9 fill:#e8f5e8
```

## AST Builder Architecture

### Node Creation Pipeline

```mermaid
graph TB
    subgraph "Node Factory"
        FACTORY[Node Factory]
        TYPE_DEF[Type Definitions]
        VALIDATOR[Node Validator]
        LINKER[Node Linker]
    end

    subgraph "AST Node Types"
        MODULE_AST[Module AST]
        FUNCTION_AST[Function AST]
        EXPR_AST[Expression AST]
        PATTERN_AST[Pattern AST]
        LITERAL_AST[Literal AST]
        CALL_AST[Call AST]
    end

    subgraph "Node Enhancement"
        METADATA[Metadata Attachment]
        LOCATION[Location Tracking]
        SCOPE[Scope Information]
        DEPS[Dependency Extraction]
    end

    subgraph "Validation Checks"
        STRUCTURE[Structure Validation]
        SEMANTIC[Semantic Validation]
        REFERENCE[Reference Validation]
        COMPLETENESS[Completeness Check]
    end

    FACTORY --> MODULE_AST
    FACTORY --> FUNCTION_AST
    FACTORY --> EXPR_AST
    FACTORY --> PATTERN_AST
    FACTORY --> LITERAL_AST
    FACTORY --> CALL_AST

    TYPE_DEF --> FACTORY
    VALIDATOR --> STRUCTURE
    VALIDATOR --> SEMANTIC
    VALIDATOR --> REFERENCE
    VALIDATOR --> COMPLETENESS

    LINKER --> METADATA
    LINKER --> LOCATION
    LINKER --> SCOPE
    LINKER --> DEPS

    MODULE_AST --> VALIDATOR
    FUNCTION_AST --> VALIDATOR
    EXPR_AST --> LINKER

    style FACTORY fill:#e1f5fe
    style MODULE_AST fill:#f3e5f5
    style METADATA fill:#e8f5e8
    style STRUCTURE fill:#fff3e0
```

## Instrumentation Mapper

### Instrumentation Point Detection

```mermaid
graph TB
    subgraph "Detection Strategies"
        FUNCTION_ENTRY[Function Entry Points]
        FUNCTION_EXIT[Function Exit Points]
        CONTROL_FLOW[Control Flow Points]
        EXPRESSION_EVAL[Expression Evaluation]
        PATTERN_MATCH[Pattern Matching]
        EXCEPTION_HANDLE[Exception Handling]
    end

    subgraph "Instrumentation Types"
        TIMING[Timing Instrumentation]
        TRACING[Call Tracing]
        PROFILING[Performance Profiling]
        COVERAGE[Code Coverage]
        DEBUGGING[Debug Points]
        MONITORING[Health Monitoring]
    end

    subgraph "Correlation Metadata"
        STATIC_ID[Static Analysis ID]
        RUNTIME_ID[Runtime Correlation ID]
        SOURCE_LOC[Source Location]
        CALL_STACK[Call Stack Context]
        PERFORMANCE[Performance Hints]
        SEMANTIC[Semantic Context]
    end

    FUNCTION_ENTRY --> TIMING
    FUNCTION_EXIT --> TIMING
    CONTROL_FLOW --> TRACING
    EXPRESSION_EVAL --> PROFILING
    PATTERN_MATCH --> COVERAGE
    EXCEPTION_HANDLE --> DEBUGGING

    TIMING --> STATIC_ID
    TRACING --> RUNTIME_ID
    PROFILING --> SOURCE_LOC
    COVERAGE --> CALL_STACK
    DEBUGGING --> PERFORMANCE
    MONITORING --> SEMANTIC

    style FUNCTION_ENTRY fill:#e1f5fe
    style TIMING fill:#f3e5f5
    style STATIC_ID fill:#e8f5e8
```

### Correlation ID Generation

```mermaid
sequenceDiagram
    participant Parser
    participant InstrumentationMapper
    participant CorrelationGenerator
    participant Repository

    Parser->>InstrumentationMapper: process_function(ast_node)
    InstrumentationMapper->>CorrelationGenerator: generate_id(node_context)
    
    Note over CorrelationGenerator: Combines:<br/>- Module hash<br/>- Function signature<br/>- Source location<br/>- Timestamp seed
    
    CorrelationGenerator-->>InstrumentationMapper: correlation_id
    InstrumentationMapper->>InstrumentationMapper: create_instrumentation_point()
    InstrumentationMapper->>Repository: store_correlation_mapping()
    InstrumentationMapper-->>Parser: instrumented_ast_node
```

## Error Recovery and Handling

### Error Recovery Strategies

```mermaid
stateDiagram-v2
    [*] --> Parsing
    Parsing --> Error : syntax_error
    Error --> SkipToken : skip_strategy
    Error --> InsertToken : insert_strategy
    Error --> DeleteToken : delete_strategy
    Error --> SyncPoint : sync_strategy
    
    SkipToken --> Parsing : continue
    InsertToken --> Parsing : continue
    DeleteToken --> Parsing : continue
    SyncPoint --> Parsing : continue
    
    Error --> Fatal : unrecoverable
    Fatal --> [*] : abort
    
    Parsing --> Success : complete
    Success --> [*] : done

    Error : Log error details
    Error : Preserve partial AST
    Error : Mark error location
    
    Fatal : Generate error report
    Fatal : Save recovery state
    Fatal : Clean up resources
```

### Partial Parsing Support

```mermaid
graph TB
    subgraph "Partial AST Generation"
        PARTIAL[Partial AST Builder]
        ERROR_NODE[Error Node Placeholder]
        CONTEXT_PRESERVE[Context Preservation]
        RECOVERY_POINT[Recovery Point Marking]
    end

    subgraph "Error Classification"
        SYNTAX_ERR[Syntax Errors]
        SEMANTIC_ERR[Semantic Errors]
        REFERENCE_ERR[Reference Errors]
        INCOMPLETE[Incomplete Code]
    end

    subgraph "Recovery Actions"
        SKIP[Skip Invalid Tokens]
        INSERT[Insert Missing Tokens]
        SUBSTITUTE[Substitute Valid Tokens]
        CHECKPOINT[Return to Checkpoint]
    end

    SYNTAX_ERR --> SKIP
    SEMANTIC_ERR --> INSERT
    REFERENCE_ERR --> SUBSTITUTE
    INCOMPLETE --> CHECKPOINT

    SKIP --> PARTIAL
    INSERT --> ERROR_NODE
    SUBSTITUTE --> CONTEXT_PRESERVE
    CHECKPOINT --> RECOVERY_POINT

    PARTIAL --> ERROR_NODE
    ERROR_NODE --> CONTEXT_PRESERVE
    CONTEXT_PRESERVE --> RECOVERY_POINT

    style PARTIAL fill:#ffebee
    style SYNTAX_ERR fill:#e1f5fe
    style SKIP fill:#e8f5e8
```

## Performance Optimization

### Parsing Performance Pipeline

```mermaid
graph LR
    subgraph "Input Optimization"
        STREAMING[Streaming Input]
        BUFFERING[Smart Buffering]
        PREPROCESSING[Preprocessing]
        CACHING[Source Caching]
    end

    subgraph "Parser Optimization"
        MEMOIZATION[Parse Memoization]
        LAZY_EVAL[Lazy Evaluation]
        PARALLEL[Parallel Parsing]
        INCREMENTAL[Incremental Updates]
    end

    subgraph "Output Optimization"
        COMPRESSION[AST Compression]
        DEDUPLICATION[Node Deduplication]
        BATCH_STORE[Batch Storage]
        ASYNC_WRITE[Async Writing]
    end

    STREAMING --> MEMOIZATION
    BUFFERING --> LAZY_EVAL
    PREPROCESSING --> PARALLEL
    CACHING --> INCREMENTAL

    MEMOIZATION --> COMPRESSION
    LAZY_EVAL --> DEDUPLICATION
    PARALLEL --> BATCH_STORE
    INCREMENTAL --> ASYNC_WRITE

    style STREAMING fill:#e1f5fe
    style MEMOIZATION fill:#f3e5f5
    style COMPRESSION fill:#e8f5e8
```

### Memory Usage Optimization

```mermaid
graph TB
    subgraph "Memory Management"
        ARENA[Memory Arena]
        POOL[Object Pool]
        RECYCLE[Node Recycling]
        COMPACT[Compaction]
    end

    subgraph "Data Structures"
        SPARSE[Sparse Arrays]
        INTERNING[String Interning]
        FLYWEIGHT[Flyweight Pattern]
        COW[Copy-on-Write]
    end

    subgraph "Garbage Collection"
        INCREMENTAL_GC[Incremental GC]
        GENERATIONAL[Generational GC]
        WEAK_REF[Weak References]
        CLEANUP[Explicit Cleanup]
    end

    ARENA --> SPARSE
    POOL --> INTERNING
    RECYCLE --> FLYWEIGHT
    COMPACT --> COW

    SPARSE --> INCREMENTAL_GC
    INTERNING --> GENERATIONAL
    FLYWEIGHT --> WEAK_REF
    COW --> CLEANUP

    style ARENA fill:#e1f5fe
    style SPARSE fill:#f3e5f5
    style INCREMENTAL_GC fill:#e8f5e8
```

## API Specifications

### Parser Interface

```elixir
defmodule ElixirScope.AST.Parser do
  @moduledoc """
  Main parser interface for converting Elixir source code to enhanced AST.
  
  Performance Targets:
  - Small files (<1KB): < 10ms
  - Medium files (1KB-100KB): < 100ms  
  - Large files (>100KB): < 1000ms
  """

  @type parse_options :: %{
    instrumentation: boolean(),
    error_recovery: :strict | :permissive,
    cache_enabled: boolean(),
    correlation_metadata: boolean()
  }

  @spec parse_file(Path.t(), parse_options()) :: 
    {:ok, enhanced_ast()} | {:error, parse_error()}
  @spec parse_string(String.t(), parse_options()) :: 
    {:ok, enhanced_ast()} | {:error, parse_error()}
  @spec parse_batch([Path.t()], parse_options()) :: 
    {:ok, [enhanced_ast()]} | {:error, batch_error()}
end
```

### Instrumentation Mapper Interface

```elixir
defmodule ElixirScope.AST.InstrumentationMapper do
  @moduledoc """
  Maps AST nodes to instrumentation points for runtime correlation.
  """

  @type instrumentation_point :: %{
    id: binary(),
    type: instrumentation_type(),
    location: source_location(),
    metadata: map()
  }

  @spec map_instrumentation(enhanced_ast()) :: 
    {:ok, [instrumentation_point()]} | {:error, term()}
  @spec generate_correlation_id(ast_node(), context()) :: binary()
  @spec extract_performance_hints(ast_node()) :: [performance_hint()]
end
```

## Testing Strategy

### Parser Testing Pyramid

```mermaid
graph TB
    subgraph "Testing Levels"
        UNIT[Unit Tests: Individual Components]
        INTEGRATION[Integration Tests: Pipeline Flow]
        SYSTEM[System Tests: End-to-End]
        PERFORMANCE[Performance Tests: Benchmarks]
    end

    subgraph "Test Categories"
        FUNCTIONALITY[Functionality Tests]
        ERROR_HANDLING[Error Handling Tests]
        EDGE_CASES[Edge Case Tests]
        REGRESSION[Regression Tests]
    end

    subgraph "Test Data"
        SYNTHETIC[Synthetic Code]
        REAL_WORLD[Real Elixir Projects]
        EDGE_SYNTAX[Edge Syntax Cases]
        MALFORMED[Malformed Code]
    end

    UNIT --> FUNCTIONALITY
    INTEGRATION --> ERROR_HANDLING
    SYSTEM --> EDGE_CASES
    PERFORMANCE --> REGRESSION

    FUNCTIONALITY --> SYNTHETIC
    ERROR_HANDLING --> REAL_WORLD
    EDGE_CASES --> EDGE_SYNTAX
    REGRESSION --> MALFORMED

    style UNIT fill:#e1f5fe
    style FUNCTIONALITY fill:#f3e5f5
    style SYNTHETIC fill:#e8f5e8
```

## Implementation Guidelines

### Development Phases

1. **Phase 1**: Basic lexical and syntax analysis
2. **Phase 2**: AST building and validation
3. **Phase 3**: Instrumentation mapping
4. **Phase 4**: Error recovery and optimization
5. **Phase 5**: Performance tuning and caching

### Quality Gates

1. **Code Coverage**: >95% for parser core
2. **Performance**: Meet specified response times
3. **Memory Usage**: <50MB for 10K LOC project
4. **Error Recovery**: Handle 99% of syntax errors gracefully

## Next Steps

1. **Study Pattern Matching**: Review `04_ast_pattern_matching.md`
2. **Examine Query System**: Review `05_ast_query_system.md` 
3. **Implement Lexer**: Start with token recognition
4. **Build Parser**: Implement recursive descent parser
5. **Add Instrumentation**: Integrate correlation mapping
