# AST Repository Deep Dive

**Version**: 1.0  
**Date**: June 2025  
**Component**: Repository Subsystem  
**Purpose**: Detailed repository architecture and implementation guidance

## Repository Architecture Overview

The AST Repository subsystem serves as the high-performance data backbone for the AST Layer, providing efficient storage, retrieval, and management of parsed AST data with runtime correlation capabilities.

## Repository Component Architecture

```mermaid
graph TB
    subgraph "Repository Supervision Tree"
        REPO_SUP[Repository.Supervisor]
        CORE_REPO[Core Repository]
        ENH_REPO[Enhanced Repository]
        MEM_SUP[Memory Manager Supervisor]
    end

    subgraph "Memory Management Subsystem"
        MEM_MON[Memory Monitor]
        CACHE_MGR[Cache Manager]
        CLEANER[Memory Cleaner]
        PRESSURE[Pressure Handler]
    end

    subgraph "Storage Layer"
        ETS_MODULES[(ETS: Modules)]
        ETS_FUNCTIONS[(ETS: Functions)]
        ETS_CORRELATIONS[(ETS: Correlations)]
        ETS_CACHE[(ETS: Cache)]
        ETS_STATS[(ETS: Statistics)]
    end

    subgraph "External Clients"
        PARSER[AST Parser]
        PATTERN[Pattern Matcher]
        QUERY[Query Engine]
        SYNC[Synchronizer]
    end

    REPO_SUP --> CORE_REPO
    REPO_SUP --> ENH_REPO
    REPO_SUP --> MEM_SUP

    MEM_SUP --> MEM_MON
    MEM_SUP --> CACHE_MGR
    MEM_SUP --> CLEANER
    MEM_SUP --> PRESSURE

    CORE_REPO --> ETS_MODULES
    CORE_REPO --> ETS_FUNCTIONS
    ENH_REPO --> ETS_CORRELATIONS
    CACHE_MGR --> ETS_CACHE
    MEM_MON --> ETS_STATS

    PARSER --> CORE_REPO
    PATTERN --> ENH_REPO
    QUERY --> ENH_REPO
    SYNC --> CORE_REPO

    style CORE_REPO fill:#e1f5fe
    style ENH_REPO fill:#f3e5f5
    style MEM_MON fill:#fff3e0
    style ETS_MODULES fill:#e8f5e8
```

## Core Repository Design

### Data Structure Specifications

```mermaid
erDiagram
    ModuleData {
        atom module_name PK
        binary compilation_hash
        list instrumentation_points
        map correlation_metadata
        integer complexity_score
        datetime last_updated
        binary ast_digest
    }

    FunctionData {
        tuple function_key PK
        atom module_name FK
        atom function_name
        integer arity
        binary ast_fragment
        integer complexity_score
        list correlation_slots
        map performance_hints
    }

    ASTNode {
        binary ast_node_id PK
        atom node_type
        map node_data
        binary correlation_id
        list children_ids
        binary parent_id
        map instrumentation_metadata
    }

    CorrelationMapping {
        binary correlation_id PK
        binary ast_node_id FK
        atom event_type
        map runtime_data
        datetime timestamp
        integer sequence_number
    }

    ModuleData ||--o{ FunctionData : contains
    FunctionData ||--o{ ASTNode : references
    ASTNode ||--o{ CorrelationMapping : correlates
```

### ETS Table Specifications

```mermaid
graph LR
    subgraph "ETS Table Design"
        subgraph "Modules Table"
            MOD_TABLE[modules_table]
            MOD_KEY[Key: module_name]
            MOD_VAL[Value: ModuleData.t()]
            MOD_OPT[Options: named_table, public, read_concurrency]
        end

        subgraph "Functions Table"
            FUNC_TABLE[functions_table]
            FUNC_KEY[Key: {module, function, arity}]
            FUNC_VAL[Value: FunctionData.t()]
            FUNC_OPT[Options: named_table, public, read_concurrency]
        end

        subgraph "AST Nodes Table"
            AST_TABLE[ast_nodes_table]
            AST_KEY[Key: ast_node_id]
            AST_VAL[Value: ASTNode.t()]
            AST_OPT[Options: named_table, public, read_concurrency]
        end

        subgraph "Correlations Table"
            CORR_TABLE[correlations_table]
            CORR_KEY[Key: correlation_id]
            CORR_VAL[Value: CorrelationMapping.t()]
            CORR_OPT[Options: named_table, public, read_concurrency]
        end

        subgraph "Cache Table"
            CACHE_TABLE[cache_table]
            CACHE_KEY[Key: cache_key]
            CACHE_VAL[Value: {data, timestamp, access_count}]
            CACHE_OPT[Options: named_table, private, write_concurrency]
        end
    end

    MOD_KEY --> MOD_VAL
    FUNC_KEY --> FUNC_VAL
    AST_KEY --> AST_VAL
    CORR_KEY --> CORR_VAL
    CACHE_KEY --> CACHE_VAL

    style MOD_TABLE fill:#e1f5fe
    style FUNC_TABLE fill:#f3e5f5
    style AST_TABLE fill:#e8f5e8
    style CORR_TABLE fill:#fff3e0
    style CACHE_TABLE fill:#fce4ec
```

## Memory Management Architecture

### Memory Pressure Handling

```mermaid
stateDiagram-v2
    [*] --> Normal
    Normal --> Warning : Memory > 80%
    Warning --> Critical : Memory > 90%
    Critical --> Emergency : Memory > 95%
    
    Warning --> Normal : Memory < 75%
    Critical --> Warning : Memory < 85%
    Emergency --> Critical : Memory < 90%

    Normal : Cache: Full Capacity
    Normal : Cleaner: Disabled
    Normal : Pressure: Monitoring

    Warning : Cache: Reduced Capacity
    Warning : Cleaner: Soft Cleanup
    Warning : Pressure: Active Monitoring

    Critical : Cache: Minimal Capacity
    Critical : Cleaner: Aggressive Cleanup
    Critical : Pressure: Frequent Monitoring

    Emergency : Cache: Disabled
    Emergency : Cleaner: Emergency Cleanup
    Emergency : Pressure: Continuous Monitoring
```

### Cache Management Strategy

```mermaid
graph TB
    subgraph "Cache Hierarchy"
        L1[L1: Hot Data Cache]
        L2[L2: Warm Data Cache]
        L3[L3: Cold Data Cache]
        STORAGE[ETS Storage]
    end

    subgraph "Access Patterns"
        FREQUENT[Frequent Access]
        MODERATE[Moderate Access]
        RARE[Rare Access]
        ARCHIVE[Archive Access]
    end

    subgraph "Eviction Policies"
        LRU[LRU Eviction]
        TTL[TTL Expiration]
        SIZE[Size-based Eviction]
        PRESSURE[Pressure-based Eviction]
    end

    FREQUENT --> L1
    MODERATE --> L2
    RARE --> L3
    ARCHIVE --> STORAGE

    L1 --> LRU
    L2 --> TTL
    L3 --> SIZE
    L1 --> PRESSURE
    L2 --> PRESSURE
    L3 --> PRESSURE

    L1 -.-> L2
    L2 -.-> L3
    L3 -.-> STORAGE

    style L1 fill:#ffebee
    style L2 fill:#f3e5f5
    style L3 fill:#e8f5e8
    style STORAGE fill:#e1f5fe
```

## Repository API Specifications

### Core Repository Interface

```elixir
defmodule ElixirScope.AST.Repository.Core do
  @moduledoc """
  Core repository for AST data storage and retrieval.
  
  Performance Targets:
  - Module lookup: < 1ms (99th percentile)
  - Function lookup: < 2ms (99th percentile)
  - Batch operations: < 100ms for 1000 items
  """

  # Public API
  @spec store_module(ModuleData.t()) :: :ok | {:error, term()}
  @spec get_module(atom()) :: {:ok, ModuleData.t()} | {:error, :not_found}
  @spec store_function(FunctionData.t()) :: :ok | {:error, term()}
  @spec get_function(function_key()) :: {:ok, FunctionData.t()} | {:error, :not_found}
  @spec batch_store([ModuleData.t() | FunctionData.t()]) :: :ok | {:error, term()}
  @spec list_modules() :: [atom()]
  @spec cleanup_module(atom()) :: :ok
end
```

### Enhanced Repository Interface

```elixir
defmodule ElixirScope.AST.Repository.Enhanced do
  @moduledoc """
  Enhanced repository with correlation and analysis capabilities.
  
  Performance Targets:
  - Correlation lookup: < 5ms (95th percentile)
  - Pattern queries: < 50ms (95th percentile)
  - Complex analysis: < 200ms (90th percentile)
  """

  # Public API
  @spec store_correlation(CorrelationMapping.t()) :: :ok | {:error, term()}
  @spec get_correlations(binary()) :: [CorrelationMapping.t()]
  @spec find_patterns(pattern_spec()) :: {:ok, [match_result()]} | {:error, term()}
  @spec analyze_complexity(atom()) :: {:ok, complexity_analysis()} | {:error, term()}
  @spec get_instrumentation_points(atom()) :: [instrumentation_point()]
end
```

## Data Persistence Strategy

### Write Operations Flow

```mermaid
sequenceDiagram
    participant Client
    participant Repository
    participant MemoryManager
    participant ETSTable
    participant Telemetry

    Client->>Repository: store_module(module_data)
    Repository->>MemoryManager: check_memory_pressure()
    
    alt Memory OK
        MemoryManager-->>Repository: :ok
        Repository->>ETSTable: insert(module_data)
        ETSTable-->>Repository: :ok
        Repository->>Telemetry: emit_metric(:module_stored)
        Repository-->>Client: :ok
    else Memory Pressure
        MemoryManager-->>Repository: {:warn, pressure_level}
        Repository->>MemoryManager: trigger_cleanup()
        MemoryManager->>ETSTable: cleanup_old_entries()
        Repository->>ETSTable: insert(module_data)
        Repository->>Telemetry: emit_metric(:module_stored_with_pressure)
        Repository-->>Client: :ok
    else Memory Critical
        MemoryManager-->>Repository: {:error, :memory_critical}
        Repository->>Telemetry: emit_metric(:storage_rejected)
        Repository-->>Client: {:error, :insufficient_memory}
    end
```

### Read Operations Flow

```mermaid
sequenceDiagram
    participant Client
    participant Repository
    participant Cache
    participant ETSTable
    participant Telemetry

    Client->>Repository: get_module(module_name)
    Repository->>Cache: lookup(module_name)
    
    alt Cache Hit
        Cache-->>Repository: {:hit, module_data}
        Repository->>Telemetry: emit_metric(:cache_hit)
        Repository-->>Client: {:ok, module_data}
    else Cache Miss
        Cache-->>Repository: :miss
        Repository->>ETSTable: lookup(module_name)
        
        alt ETS Hit
            ETSTable-->>Repository: module_data
            Repository->>Cache: store(module_name, module_data)
            Repository->>Telemetry: emit_metric(:cache_miss, :ets_hit)
            Repository-->>Client: {:ok, module_data}
        else ETS Miss
            ETSTable-->>Repository: :not_found
            Repository->>Telemetry: emit_metric(:cache_miss, :ets_miss)
            Repository-->>Client: {:error, :not_found}
        end
    end
```

## Performance Optimization Strategies

### Concurrent Access Patterns

```mermaid
graph TB
    subgraph "Read Concurrency"
        READER1[Reader Process 1]
        READER2[Reader Process 2]
        READER3[Reader Process N]
        READ_COORD[Read Coordinator]
    end

    subgraph "Write Coordination"
        WRITER[Writer Process]
        WRITE_QUEUE[Write Queue]
        BATCH_PROC[Batch Processor]
    end

    subgraph "ETS Access Layer"
        ETS_READ[ETS Read Operations]
        ETS_WRITE[ETS Write Operations]
        ETS_LOCK[ETS Lock Management]
    end

    READER1 --> READ_COORD
    READER2 --> READ_COORD
    READER3 --> READ_COORD
    READ_COORD --> ETS_READ

    WRITER --> WRITE_QUEUE
    WRITE_QUEUE --> BATCH_PROC
    BATCH_PROC --> ETS_WRITE

    ETS_READ --> ETS_LOCK
    ETS_WRITE --> ETS_LOCK

    style READ_COORD fill:#e8f5e8
    style BATCH_PROC fill:#fff3e0
    style ETS_LOCK fill:#ffebee
```

### Memory Layout Optimization

```mermaid
graph LR
    subgraph "Memory Zones"
        HOT[Hot Zone: Recently Accessed]
        WARM[Warm Zone: Moderately Accessed]
        COLD[Cold Zone: Rarely Accessed]
        FROZEN[Frozen Zone: Archive Data]
    end

    subgraph "Data Types"
        MODULE[Module Data]
        FUNCTION[Function Data]
        AST[AST Nodes]
        CORRELATION[Correlations]
    end

    subgraph "Storage Strategy"
        COMPRESSED[Compressed Storage]
        INDEXED[Indexed Access]
        BATCHED[Batched Updates]
        LAZY[Lazy Loading]
    end

    MODULE --> HOT
    FUNCTION --> WARM
    AST --> COLD
    CORRELATION --> FROZEN

    HOT --> INDEXED
    WARM --> COMPRESSED
    COLD --> LAZY
    FROZEN --> BATCHED

    style HOT fill:#ffebee
    style WARM fill:#fff3e0
    style COLD fill:#e8f5e8
    style FROZEN fill:#e1f5fe
```

## Implementation Guidelines

### Repository Initialization

1. **ETS Table Creation**: Configure tables with appropriate options
2. **Memory Manager Setup**: Initialize monitoring and cleanup processes
3. **Cache Warming**: Pre-load frequently accessed data
4. **Telemetry Integration**: Set up performance metrics collection

### Error Handling Strategy

1. **Graceful Degradation**: Continue operation with reduced functionality
2. **Recovery Mechanisms**: Automatic restart and data restoration
3. **Data Integrity**: Validate data consistency during operations
4. **Performance Monitoring**: Track and alert on performance degradation

### Testing Strategy

1. **Unit Tests**: Individual component functionality
2. **Integration Tests**: Cross-component interactions
3. **Performance Tests**: Load and stress testing
4. **Chaos Engineering**: Fault injection and recovery testing

## Next Steps

1. **Examine Parsing Pipeline**: Review `03_ast_parsing_pipeline.md` for parser integration
2. **Study Memory Management**: Deep dive into memory optimization strategies
3. **Implement Core Repository**: Start with basic storage and retrieval
4. **Add Enhanced Features**: Extend with correlation and analysis capabilities
5. **Performance Tuning**: Optimize based on real-world usage patterns
