# ETS_SCHEMA.md - AST Layer Data Storage Architecture

**Version:** 1.0  
**Date:** December 2024  
**Layer:** AST Layer (Layer 2)  
**Status:** Implementation Ready

## Table of Contents

1. [ETS Table Architecture Overview](#1-ets-table-architecture-overview)
2. [Core Data Tables](#2-core-data-tables)
3. [Index Tables](#3-index-tables)
4. [Cache Tables](#4-cache-tables)
5. [Table Configuration](#5-table-configuration)
6. [Key Generation Strategies](#6-key-generation-strategies)
7. [Performance Optimization](#7-performance-optimization)
8. [Memory Management](#8-memory-management)

---

## 1. ETS Table Architecture Overview

### Table Categories
```elixir
# Primary Data Tables - Core AST storage
:ast_modules          # Module data with AST and metadata
:ast_functions        # Function-level data and analysis
:ast_nodes            # Individual AST nodes with instrumentation

# Correlation Tables - Runtime mapping
:correlation_index    # correlation_id -> ast_node_id mapping
:instrumentation_map  # Instrumentation point metadata

# Analysis Tables - Cached analysis results
:pattern_cache        # Pattern matching results
:complexity_cache     # Complexity analysis cache
:dependency_cache     # Module dependency analysis

# Query Tables - Query optimization and caching
:query_cache          # Query result caching
:query_stats          # Query performance statistics

# Memory Management Tables
:memory_stats         # Table size and access tracking
:cleanup_schedule     # Scheduled cleanup tasks
```

### Table Hierarchy
```
Repository Core
├── Primary Data (set tables)
│   ├── ast_modules
│   ├── ast_functions
│   └── ast_nodes
├── Correlation (bag tables)
│   ├── correlation_index
│   └── instrumentation_map
├── Analysis Cache (set tables)
│   ├── pattern_cache
│   ├── complexity_cache
│   └── dependency_cache
└── Query System (set tables)
    ├── query_cache
    └── query_stats
```

---

## 2. Core Data Tables

### 2.1 AST Modules Table

**Table Name**: `:ast_modules`  
**Type**: `:set`  
**Options**: `[:public, {:read_concurrency, true}, {:write_concurrency, false}]`

```elixir
# Key Structure
@type module_key :: atom()  # Module name (e.g., MyApp.User)

# Value Structure  
@type module_record :: {
  module_key(),                    # Primary key
  ModuleData.t(),                  # Full module data structure
  compilation_hash :: binary(),    # SHA256 of source content
  last_updated :: integer(),       # Monotonic timestamp
  access_count :: non_neg_integer(), # For LRU tracking
  memory_size :: non_neg_integer()   # Estimated memory usage
}

# Example Record
{
  MyApp.User,
  %ModuleData{
    module_name: MyApp.User,
    ast: {:defmodule, [line: 1], [...]},
    source_file: "/path/to/user.ex",
    # ... full ModuleData structure
  },
  "a1b2c3d4...",  # compilation_hash
  1234567890123,  # last_updated
  42,             # access_count
  2048            # memory_size in bytes
}
```

**Indexes Required**:
- Primary: `module_name` (automatic ETS key)
- Secondary: `source_file` (via separate index table)
- Cleanup: `last_updated` (for TTL cleanup)

### 2.2 AST Functions Table

**Table Name**: `:ast_functions`  
**Type**: `:set`  
**Options**: `[:public, {:read_concurrency, true}, {:write_concurrency, false}]`

```elixir
# Key Structure
@type function_key :: {module_name :: atom(), function_name :: atom(), arity :: non_neg_integer()}

# Value Structure
@type function_record :: {
  function_key(),                  # Primary key
  FunctionData.t(),               # Full function data structure
  complexity_score :: float(),     # Cached complexity
  instrumentation_points :: [map()], # Runtime correlation points
  last_analyzed :: integer(),      # Analysis timestamp
  access_count :: non_neg_integer()  # LRU tracking
}

# Example Record
{
  {MyApp.User, :create_user, 2},
  %FunctionData{
    function_key: {MyApp.User, :create_user, 2},
    ast: {:def, [line: 15], [...]},
    # ... full FunctionData structure
  },
  8.5,            # complexity_score
  [%{type: :function_entry, ...}], # instrumentation_points
  1234567890500,  # last_analyzed
  15              # access_count
}
```

**Indexes Required**:
- Primary: `{module, function, arity}` (automatic ETS key)
- Secondary: `module_name` (for module-level function queries)
- Performance: `complexity_score` (for complexity-based queries)

### 2.3 AST Nodes Table

**Table Name**: `:ast_nodes`  
**Type**: `:set`  
**Options**: `[:public, {:read_concurrency, true}, {:write_concurrency, false}]`

```elixir
# Key Structure
@type ast_node_id :: binary()  # UUID v4 format

# Value Structure
@type ast_node_record :: {
  ast_node_id(),                   # Primary key
  node_type :: atom(),             # :function_def, :pipe_op, :case_stmt, etc.
  ast_fragment :: term(),          # The actual AST node
  parent_node_id :: ast_node_id() | nil, # Tree structure
  children_ids :: [ast_node_id()], # Child nodes
  metadata :: map(),               # Node-specific metadata
  location :: {pos_integer(), pos_integer()}, # {line, column}
  instrumentation_type :: atom() | nil # :entry, :exit, :branch, etc.
}

# Example Record
{
  "550e8400-e29b-41d4-a716-446655440000",
  :function_def,
  {:def, [line: 15], [:create_user, [...]]},
  "550e8400-e29b-41d4-a716-446655440001", # parent
  ["550e8400-e29b-41d4-a716-446655440002"], # children
  %{visibility: :public, exported: true},
  {15, 3},        # location
  :function_entry # instrumentation_type
}
```

---

## 3. Index Tables

### 3.1 Correlation Index Table

**Table Name**: `:correlation_index`  
**Type**: `:bag`  
**Options**: `[:public, {:read_concurrency, true}, {:write_concurrency, true}]`

```elixir
# Key Structure
@type correlation_id :: binary()  # Runtime correlation identifier

# Value Structure
@type correlation_record :: {
  correlation_id(),               # Primary key (allows duplicates in bag)
  ast_node_id(),                 # Mapped AST node
  correlation_type :: atom(),     # :function_call, :state_change, etc.
  timestamp :: integer(),         # When correlation was created
  metadata :: map()               # Additional correlation data
}

# Example Records (multiple per correlation_id in bag table)
{
  "corr_123abc",
  "550e8400-e29b-41d4-a716-446655440000",
  :function_call,
  1234567890123,
  %{call_depth: 2, context: "user_creation"}
}
```

### 3.2 Source File Index Table

**Table Name**: `:source_file_index`  
**Type**: `:bag`  
**Options**: `[:public, {:read_concurrency, true}, {:write_concurrency, false}]`

```elixir
# Key Structure
@type file_path :: binary()  # Absolute file path

# Value Structure
@type file_index_record :: {
  file_path(),                    # Primary key
  module_name :: atom(),          # Module defined in this file
  last_modified :: integer(),     # File system timestamp
  file_size :: non_neg_integer(), # File size in bytes
  parse_status :: :ok | :error   # Last parse result
}
```

### 3.3 Module Dependency Index

**Table Name**: `:module_dependencies`  
**Type**: `:bag`  
**Options**: `[:public, {:read_concurrency, true}, {:write_concurrency, false}]`

```elixir
# Key Structure
@type dependent_module :: atom()

# Value Structure
@type dependency_record :: {
  dependent_module(),             # Module that depends
  dependency :: atom(),           # Module being depended on
  dependency_type :: :import | :alias | :use | :call,
  strength :: :weak | :strong    # Dependency strength
}
```

---

## 4. Cache Tables

### 4.1 Pattern Analysis Cache

**Table Name**: `:pattern_cache`  
**Type**: `:set`  
**Options**: `[:public, {:read_concurrency, true}, {:write_concurrency, true}]`

```elixir
# Key Structure
@type pattern_cache_key :: {module_name :: atom(), pattern_type :: atom(), pattern_version :: binary()}

# Value Structure
@type pattern_cache_record :: {
  pattern_cache_key(),            # Composite key
  pattern_matches :: [map()],     # Pattern analysis results
  confidence_score :: float(),    # Overall confidence
  analysis_time_ms :: non_neg_integer(), # Performance tracking
  cached_at :: integer(),         # Cache timestamp
  ttl :: integer()               # Time to live
}
```

### 4.2 Query Result Cache

**Table Name**: `:query_cache`  
**Type**: `:set`  
**Options**: `[:public, {:read_concurrency, true}, {:write_concurrency, true}]`

```elixir
# Key Structure
@type query_cache_key :: binary()  # SHA256 hash of normalized query

# Value Structure
@type query_cache_record :: {
  query_cache_key(),              # Query hash
  query_result :: term(),         # Cached result
  result_count :: non_neg_integer(), # Number of results
  execution_time_ms :: non_neg_integer(), # Original execution time
  cached_at :: integer(),         # Cache timestamp
  access_count :: non_neg_integer(), # LRU tracking
  dependencies :: [atom()]        # Modules this query depends on
}
```

---

## 5. Table Configuration

### 5.1 Table Creation Specifications

```elixir
defmodule ElixirScope.AST.Repository.ETSSchema do
  @table_configs %{
    # Core Data Tables
    ast_modules: [
      :set, :public, :named_table,
      {:read_concurrency, true},
      {:write_concurrency, false},
      {:decentralized_counters, true}
    ],
    
    ast_functions: [
      :set, :public, :named_table,
      {:read_concurrency, true},
      {:write_concurrency, false},
      {:decentralized_counters, true}
    ],
    
    ast_nodes: [
      :set, :public, :named_table,
      {:read_concurrency, true},
      {:write_concurrency, false}
    ],
    
    # Correlation Tables (bag for 1:many relationships)
    correlation_index: [
      :bag, :public, :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ],
    
    # Cache Tables (frequent updates)
    pattern_cache: [
      :set, :public, :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true},
      {:decentralized_counters, true}
    ],
    
    query_cache: [
      :set, :public, :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true},
      {:decentralized_counters, true}
    ]
  }
  
  def create_tables do
    Enum.each(@table_configs, fn {name, options} ->
      :ets.new(name, options)
    end)
  end
end
```

### 5.2 Memory Limits and Monitoring

```elixir
@memory_limits %{
  ast_modules: %{
    max_entries: 10_000,
    max_memory_mb: 500,
    cleanup_threshold: 0.8
  },
  ast_functions: %{
    max_entries: 100_000,
    max_memory_mb: 200,
    cleanup_threshold: 0.8
  },
  pattern_cache: %{
    max_entries: 50_000,
    max_memory_mb: 100,
    cleanup_threshold: 0.9,
    ttl_seconds: 3600
  },
  query_cache: %{
    max_entries: 10_000,
    max_memory_mb: 50,
    cleanup_threshold: 0.9,
    ttl_seconds: 1800
  }
}
```

---

## 6. Key Generation Strategies

### 6.1 AST Node ID Generation

```elixir
defmodule ElixirScope.AST.NodeIDGenerator do
  @moduledoc "Deterministic AST node ID generation"
  
  def generate_node_id(ast_node, context) do
    # Create deterministic ID based on AST structure and location
    source_hash = :crypto.hash(:sha256, inspect(ast_node))
    location_hash = :crypto.hash(:sha256, inspect(context.location))
    
    # Combine with module context for uniqueness
    combined = source_hash <> location_hash <> context.module_name
    
    # Generate UUID v5 (deterministic) from combined hash
    UUID.uuid5(:dns, combined)
  end
  
  def generate_correlation_id() do
    # Generate UUID v4 (random) for runtime correlation
    UUID.uuid4()
  end
end
```

### 6.2 Cache Key Generation

```elixir
defmodule ElixirScope.AST.CacheKeyGenerator do
  def query_cache_key(query) do
    query
    |> normalize_query()
    |> inspect()
    |> (&:crypto.hash(:sha256, &1)).()
    |> Base.encode16(case: :lower)
  end
  
  def pattern_cache_key(module, pattern_type, pattern_spec) do
    {module, pattern_type, :crypto.hash(:sha256, inspect(pattern_spec))}
  end
  
  defp normalize_query(query) do
    # Normalize query for consistent caching
    query
    |> Map.drop([:execution_id, :timestamp])
    |> Enum.sort()
  end
end
```

---

## 7. Performance Optimization

### 7.1 Read Optimization

```elixir
# Optimized read patterns
def get_module_fast(module_name) do
  case :ets.lookup(:ast_modules, module_name) do
    [{^module_name, module_data, _hash, _updated, _access, _size}] ->
      # Update access count for LRU (async)
      Task.start(fn -> increment_access_count(:ast_modules, module_name) end)
      {:ok, module_data}
    [] ->
      {:error, :not_found}
  end
end

# Batch read optimization
def get_modules_batch(module_names) do
  # Use :ets.select for batch operations
  match_spec = 
    Enum.map(module_names, fn name -> 
      {name, :"$2", :_, :_, :_, :_}
    end)
  
  :ets.select(:ast_modules, match_spec)
end
```

### 7.2 Write Optimization

```elixir
# Batched writes to reduce GenServer bottleneck
def store_modules_batch(modules) do
  # Prepare ETS operations
  operations = 
    Enum.map(modules, fn module_data ->
      key = module_data.module_name
      hash = calculate_hash(module_data)
      timestamp = System.monotonic_time()
      
      {key, module_data, hash, timestamp, 0, estimate_size(module_data)}
    end)
  
  # Single ETS insert for better performance
  :ets.insert(:ast_modules, operations)
end
```

### 7.3 Query Optimization

```elixir
# Index-based queries for better performance
def find_functions_by_complexity(min_complexity) do
  # Use match specifications for server-side filtering
  match_spec = [
    {
      {:"$1", :"$2", :"$3", :_, :_, :_},  # Pattern
      [{:>=, :"$3", min_complexity}],      # Guard
      [{{:"$1", :"$2", :"$3"}}]           # Result
    }
  ]
  
  :ets.select(:ast_functions, match_spec)
end
```

---

## 8. Memory Management

### 8.1 LRU Eviction Strategy

```elixir
defmodule ElixirScope.AST.LRUEviction do
  def evict_lru_entries(table_name, target_count) do
    # Get all entries sorted by access count
    entries = :ets.tab2list(table_name)
    
    sorted_entries = 
      entries
      |> Enum.sort_by(fn record -> access_count(record) end)
      |> Enum.take(target_count)
    
    # Remove least recently used entries
    Enum.each(sorted_entries, fn record ->
      :ets.delete(table_name, primary_key(record))
    end)
    
    target_count
  end
  
  defp access_count(record) do
    case record do
      {_, _, _, _, access_count, _} -> access_count
      {_, _, _, _, access_count} -> access_count
      _ -> 0
    end
  end
end
```

### 8.2 Memory Pressure Response

```elixir
defmodule ElixirScope.AST.MemoryPressure do
  def handle_memory_pressure(pressure_level) do
    case pressure_level do
      :low ->
        # Clear query cache
        :ets.delete_all_objects(:query_cache)
        
      :medium ->
        # Clear pattern cache and compress old data
        :ets.delete_all_objects(:pattern_cache)
        compress_old_ast_data()
        
      :high ->
        # Aggressive cleanup - keep only recent data
        cleanup_old_modules(hours: 24)
        cleanup_old_functions(hours: 12)
        
      :critical ->
        # Emergency cleanup - keep only essential data
        emergency_cleanup()
    end
  end
  
  defp emergency_cleanup do
    # Keep only most recently accessed 1000 modules
    evict_lru_entries(:ast_modules, 1000)
    evict_lru_entries(:ast_functions, 10000)
    
    # Clear all caches
    :ets.delete_all_objects(:pattern_cache)
    :ets.delete_all_objects(:query_cache)
    
    # Force garbage collection
    :erlang.garbage_collect()
  end
end
```

### 8.3 Monitoring and Statistics

```elixir
defmodule ElixirScope.AST.TableStats do
  def collect_table_statistics do
    tables = [:ast_modules, :ast_functions, :ast_nodes, :correlation_index, 
              :pattern_cache, :query_cache]
    
    Enum.map(tables, fn table ->
      info = :ets.info(table)
      
      %{
        table: table,
        size: info[:size],
        memory_words: info[:memory],
        memory_bytes: info[:memory] * :erlang.system_info(:wordsize),
        type: info[:type],
        read_concurrency: info[:read_concurrency],
        write_concurrency: info[:write_concurrency]
      }
    end)
  end
  
  def memory_usage_report do
    stats = collect_table_statistics()
    total_memory = Enum.sum(Enum.map(stats, & &1.memory_bytes))
    
    %{
      total_memory_mb: total_memory / (1024 * 1024),
      table_breakdown: stats,
      recommendations: generate_recommendations(stats)
    }
  end
end
```

---

This ETS schema provides a robust foundation for the AST Layer with optimized performance characteristics, efficient memory management, and comprehensive monitoring capabilities.