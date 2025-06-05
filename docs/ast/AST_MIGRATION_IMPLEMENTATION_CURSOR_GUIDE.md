# AST Migration Implementation Guide - CURSOR Edition

**Version:** 1.0  
**Date:** June 2025  
**Context:** Step-by-Step Implementation Guide for AST-Foundation Integration  
**Status:** Implementation Ready

## Overview

This implementation guide provides detailed, step-by-step instructions for migrating the existing AST codebase to integrate with the enhanced Foundation Layer. Each step includes specific code changes, validation procedures, and rollback strategies.

## Table of Contents

1. [Pre-Migration Setup](#pre-migration-setup)
2. [Phase 1: Foundation Service Integration](#phase-1-foundation-service-integration)
3. [Phase 2: Infrastructure Component Integration](#phase-2-infrastructure-component-integration)
4. [Phase 3: Advanced Features Implementation](#phase-3-advanced-features-implementation)
5. [Phase 4: Validation and Production Readiness](#phase-4-validation-and-production-readiness)
6. [Migration Checklists](#migration-checklists)
7. [Testing Procedures](#testing-procedures)
8. [Rollback Procedures](#rollback-procedures)

## Pre-Migration Setup

### 1. Environment Preparation

```bash
# Create migration branch
git checkout -b feature/ast-foundation-integration

# Backup current AST implementation
cp -r lib/elixir_scope/ast lib/elixir_scope/ast_backup

# Create new directory structure
mkdir -p lib/elixir_scope/ast_v2/{data,repository,analysis,querying,parsing,transformation}
```

### 2. Foundation Dependencies Verification

```elixir
# In mix.exs, ensure Foundation dependencies
defp deps do
  [
    # Foundation Layer must be available
    {:elixir_scope_foundation, "~> 1.1"},
    # ... other deps
  ]
end
```

### 3. Configuration Schema Setup

```elixir
# Create config/ast_foundation_config.exs
config :elixir_scope, :ast,
  repository: %{
    max_modules: 50_000,
    max_functions: 500_000,
    health_check_interval_ms: 30_000
  },
  parser: %{
    timeout_ms: 30_000,
    max_file_size_bytes: 10_485_760,
    instrumentation_enabled: true
  },
  memory: %{
    pressure_thresholds: %{warning: 0.7, critical: 0.85, emergency: 0.95},
    cleanup_interval_ms: 60_000,
    report_interval_ms: 30_000
  },
  query: %{
    concurrent_limit: 50,
    rate_limiting: %{
      enabled: true,
      queries_per_minute: 100,
      complex_queries_per_minute: 10
    }
  }
```

## Phase 1: Foundation Service Integration

### Step 1.1: Data Structure Migration

**Target**: Migrate `data/module_data.ex` to use Foundation services

```elixir
# lib/elixir_scope/ast_v2/data/module_data.ex
defmodule ElixirScope.AST.Data.ModuleData do
  @moduledoc """
  Foundation-integrated module data structure.
  """

  # Foundation Integration
  alias ElixirScope.Foundation.{Config, Error, Telemetry}
  alias ElixirScope.Utils

  # Import original analyzers
  alias ElixirScope.ASTRepository.ModuleData.{
    ASTAnalyzer,
    ComplexityCalculator,
    DependencyExtractor,
    PatternDetector,
    AttributeExtractor
  }

  # Keep original structure, enhance with Foundation integration
  defstruct [
    # ... original fields ...
    :module_name,
    :ast,
    :source_file,
    # ... rest of fields ...
  ]

  @type t :: %__MODULE__{}

  @doc """
  Creates a new ModuleData structure with Foundation integration.
  """
  @spec new(atom(), term(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(module_name, ast, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)
    
    with {:ok, config} <- get_module_config(),
         {:ok, module_data} <- create_module_data(module_name, ast, opts, config) do
      
      # Emit success telemetry
      duration = System.monotonic_time(:microsecond) - start_time
      :ok = Telemetry.execute(
        [:elixir_scope, :ast, :data, :module_created],
        %{duration_microseconds: duration, ast_size: estimate_ast_size(ast)},
        %{module_name: module_name, source_file: Keyword.get(opts, :source_file)}
      )
      
      {:ok, module_data}
    else
      {:error, reason} -> 
        {:error, Error.new(:module_data_creation_failed, 
          "Failed to create module data for #{module_name}", 
          %{module_name: module_name, reason: reason})}
    end
  end

  # Private functions
  defp get_module_config() do
    Config.get([:ast, :data, :module_data], %{
      max_ast_size: 10_485_760,  # 10MB
      enable_complexity_analysis: true,
      enable_pattern_detection: true
    })
  end

  defp create_module_data(module_name, ast, opts, config) do
    timestamp = Utils.monotonic_timestamp()
    source_file = Keyword.get(opts, :source_file)
    
    # Validate AST size if configured
    ast_size = estimate_ast_size(ast)
    if ast_size > config.max_ast_size do
      {:error, :ast_too_large}
    else
      module_data = %__MODULE__{
        module_name: module_name,
        ast: ast,
        source_file: source_file,
        compilation_hash: generate_compilation_hash(ast, source_file),
        compilation_timestamp: timestamp,
        instrumentation_points: Keyword.get(opts, :instrumentation_points, []),
        ast_node_mapping: Keyword.get(opts, :ast_node_mapping, %{}),
        correlation_metadata: Keyword.get(opts, :correlation_metadata, %{}),
        module_type: ASTAnalyzer.detect_module_type(ast),
        complexity_metrics: maybe_calculate_complexity(ast, config),
        dependencies: DependencyExtractor.extract_dependencies(ast),
        exports: ASTAnalyzer.extract_exports(ast),
        callbacks: ASTAnalyzer.extract_callbacks(ast),
        patterns: maybe_detect_patterns(ast, config),
        attributes: AttributeExtractor.extract_attributes(ast),
        runtime_insights: nil,
        execution_frequency: %{},
        performance_data: %{},
        error_patterns: [],
        message_flows: [],
        created_at: timestamp,
        updated_at: timestamp,
        version: "2.0.0"
      }
      
      {:ok, module_data}
    end
  end

  defp maybe_calculate_complexity(ast, %{enable_complexity_analysis: true}), do: ComplexityCalculator.calculate_metrics(ast)
  defp maybe_calculate_complexity(_ast, _config), do: %{}

  defp maybe_detect_patterns(ast, %{enable_pattern_detection: true}), do: PatternDetector.detect_patterns(ast)
  defp maybe_detect_patterns(_ast, _config), do: []

  defp estimate_ast_size(ast), do: :erlang.external_size(ast)
  defp generate_compilation_hash(ast, source_file) do
    content = "#{inspect(ast)}#{source_file}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
```

**Validation**:
```bash
# Test the migrated module
mix test test/ast_v2/data/module_data_test.exs
```

### Step 1.2: Repository Core Migration

**Target**: Migrate repository core with Foundation integration

```elixir
# lib/elixir_scope/ast_v2/repository/core.ex
defmodule ElixirScope.AST.Repository.Core do
  @moduledoc """
  Foundation-integrated AST repository core.
  """
  
  use GenServer
  require Logger
  
  # Foundation Integration
  @behaviour ElixirScope.Foundation.HealthCheckable
  @behaviour ElixirScope.Foundation.Infrastructure.MemoryReporter
  
  alias ElixirScope.Foundation.{Config, Events, Telemetry, Error}
  alias ElixirScope.Foundation.Infrastructure.{MemoryManager, HealthAggregator}
  alias ElixirScope.Storage.DataAccess
  alias ElixirScope.AST.Data.{ModuleData, FunctionData}
  
  # Keep original structure
  defstruct [
    :repository_id,
    :creation_timestamp,
    :configuration,
    :modules_table,
    :functions_table,
    :correlation_index,
    :stats_table,
    :performance_metrics,
    :health_stats
  ]
  
  @type t :: %__MODULE__{}
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    {:ok, pid} = GenServer.start_link(__MODULE__, opts, name: name)
    
    # Register with Foundation Infrastructure
    register_with_foundation()
    
    {:ok, pid}
  end
  
  # Foundation Health Check Interface (MANDATORY)
  @impl ElixirScope.Foundation.HealthCheckable
  def health_check() do
    GenServer.call(__MODULE__, :health_check)
  end
  
  # Foundation Memory Reporter Interface (MANDATORY)
  @impl ElixirScope.Foundation.Infrastructure.MemoryReporter
  def report_memory_usage() do
    GenServer.call(__MODULE__, :report_memory_usage)
  end
  
  @impl ElixirScope.Foundation.Infrastructure.MemoryReporter
  def handle_pressure_signal(level) do
    GenServer.cast(__MODULE__, {:memory_pressure, level})
  end
  
  # Public API (enhanced with Foundation integration)
  def store_module(repository \\ __MODULE__, module_data) do
    GenServer.call(repository, {:store_module, module_data})
  end
  
  def get_module(repository \\ __MODULE__, module_name) do
    GenServer.call(repository, {:get_module, module_name})
  end
  
  #############################################################################
  # GenServer Callbacks
  #############################################################################
  
  @impl true
  def init(opts) do
    with {:ok, config} <- load_configuration(),
         {:ok, state} <- initialize_repository_state(config, opts) do
      
      # Subscribe to Foundation events
      :ok = Events.subscribe()
      
      # Schedule health checks
      schedule_health_check(config.health_check_interval_ms)
      
      Logger.info("AST Repository Core started with Foundation integration")
      {:ok, state}
    else
      {:error, reason} ->
        Logger.error("Failed to initialize AST Repository: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call(:health_check, _from, state) do
    health_status = calculate_health_status(state)
    {:reply, health_status, update_health_stats(state, health_status)}
  end
  
  @impl true
  def handle_call(:report_memory_usage, _from, state) do
    memory_report = calculate_memory_usage(state)
    {:reply, memory_report, state}
  end
  
  @impl true
  def handle_call({:store_module, module_data}, _from, state) do
    start_time = System.monotonic_time(:microsecond)
    
    case do_store_module(module_data, state) do
      {:ok, new_state} ->
        # Emit telemetry
        duration = System.monotonic_time(:microsecond) - start_time
        :ok = Telemetry.execute(
          [:elixir_scope, :ast, :repository, :module_stored],
          %{duration_microseconds: duration},
          %{module_name: module_data.module_name}
        )
        
        {:reply, :ok, new_state}
      
      {:error, reason} ->
        error = Error.new(:module_store_failed, 
          "Failed to store module", 
          %{module_name: module_data.module_name, reason: reason})
        {:reply, {:error, error}, state}
    end
  end
  
  @impl true
  def handle_cast({:memory_pressure, level}, state) do
    Logger.info("Received memory pressure signal: #{level}")
    
    case level do
      :critical -> 
        new_state = perform_emergency_cleanup(state)
        {:noreply, new_state}
      :high -> 
        new_state = perform_aggressive_cleanup(state)
        {:noreply, new_state}
      :medium -> 
        new_state = perform_gentle_cleanup(state)
        {:noreply, new_state}
      :low -> 
        {:noreply, state}
    end
  end
  
  # Private functions
  defp register_with_foundation() do
    :ok = HealthAggregator.register_health_check_source(
      :ast_repository_core,
      {__MODULE__, :health_check, []},
      interval_ms: 30_000
    )
    
    :ok = MemoryManager.register_memory_reporter(__MODULE__)
    
    :ok
  end
  
  defp load_configuration() do
    Config.get([:ast, :repository], %{
      max_modules: 50_000,
      max_functions: 500_000,
      health_check_interval_ms: 30_000,
      ets_options: [:set, :public, {:read_concurrency, true}]
    })
  end
  
  defp calculate_health_status(state) do
    stats = get_repository_statistics(state)
    
    cond do
      stats.error_count > 50 ->
        {:error, %{status: :critical, reason: "High error count", details: stats}}
      
      stats.error_count > 10 ->
        {:ok, %{status: :degraded, details: Map.put(stats, :reason, "Elevated error count")}}
      
      true ->
        {:ok, %{status: :healthy, details: stats}}
    end
  end
  
  defp calculate_memory_usage(state) do
    {:ok, %{
      component: :ast_repository_core,
      total_bytes: calculate_total_memory(state),
      breakdown: %{
        modules_table: get_table_memory(state.modules_table),
        functions_table: get_table_memory(state.functions_table),
        correlation_index: get_table_memory(state.correlation_index)
      },
      pressure_level: :low,  # Calculate based on usage
      last_cleanup: get_last_cleanup_time(state)
    }}
  end
end
```

### Step 1.3: Testing Foundation Integration

```elixir
# test/ast_v2/foundation_integration_test.exs
defmodule ElixirScope.AST.FoundationIntegrationTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.AST.Repository.Core
  alias ElixirScope.AST.Data.ModuleData
  alias ElixirScope.Foundation.{Config, Events, Telemetry}
  
  setup do
    # Start Foundation services
    start_supervised!({ElixirScope.Foundation.Application, []})
    start_supervised!({Core, name: :test_repo})
    
    on_exit(fn -> 
      :ok = GenServer.stop(:test_repo)
    end)
    
    :ok
  end
  
  test "repository integrates with Foundation Config" do
    # Test config integration
    {:ok, config} = Config.get([:ast, :repository])
    assert is_map(config)
    assert config.max_modules > 0
  end
  
  test "repository implements health check interface" do
    health_result = Core.health_check()
    
    assert {:ok, %{status: status, details: details}} = health_result
    assert status in [:healthy, :degraded]
    assert is_map(details)
    assert Map.has_key?(details, :uptime_seconds)
  end
  
  test "repository reports memory usage" do
    memory_report = Core.report_memory_usage()
    
    assert {:ok, %{component: :ast_repository_core, total_bytes: bytes}} = memory_report
    assert is_integer(bytes)
    assert bytes > 0
  end
  
  test "repository handles memory pressure signals" do
    # Test pressure signal handling
    :ok = Core.handle_pressure_signal(:medium)
    
    # Should not crash and should handle gracefully
    health_result = Core.health_check()
    assert {:ok, _} = health_result
  end
end
```

## Phase 2: Infrastructure Component Integration

### Step 2.1: Query System Rate Limiting

```elixir
# lib/elixir_scope/ast_v2/querying/protected_executor.ex
defmodule ElixirScope.AST.Querying.ProtectedExecutor do
  @moduledoc """
  Query executor with Foundation Infrastructure protection.
  """
  
  alias ElixirScope.Foundation.Infrastructure.{RateLimiter, CircuitBreakerWrapper}
  alias ElixirScope.Foundation.{Error, Telemetry}
  alias ElixirScope.AST.Querying.Types
  
  @behaviour ElixirScope.Foundation.HealthCheckable
  
  def execute_query(repo, query) do
    client_id = get_client_id()
    complexity = assess_query_complexity(query)
    
    start_time = System.monotonic_time(:microsecond)
    
    result = case complexity do
      :high -> execute_protected_complex_query(repo, query, client_id)
      _ -> execute_standard_query(repo, query)
    end
    
    # Emit telemetry regardless of result
    duration = System.monotonic_time(:microsecond) - start_time
    emit_query_telemetry(query, complexity, duration, result)
    
    result
  end
  
  @impl ElixirScope.Foundation.HealthCheckable
  def health_check() do
    {:ok, %{
      status: :healthy,
      details: %{
        active_queries: get_active_query_count(),
        rate_limited_count: get_rate_limited_count(),
        circuit_breaker_status: get_circuit_breaker_status()
      }
    }}
  end
  
  # Private functions
  defp execute_protected_complex_query(repo, query, client_id) do
    with :ok <- check_rate_limits(client_id),
         {:ok, result} <- execute_with_circuit_breaker(repo, query) do
      {:ok, result}
    else
      {:error, %Error{type: :rate_limited} = error} ->
        emit_rate_limited_telemetry(query, error)
        {:error, error}
      
      {:error, %Error{type: :circuit_breaker_open} = error} ->
        Logger.warn("Query circuit breaker open")
        {:error, error}
      
      error -> error
    end
  end
  
  defp check_rate_limits(client_id) do
    RateLimiter.check_rate(
      {:ast_complex_query, client_id}, 
      :ast_complex_queries_per_minute, 
      1
    )
  end
  
  defp execute_with_circuit_breaker(repo, query) do
    CircuitBreakerWrapper.execute(:ast_complex_queries, fn ->
      ElixirScope.AST.Querying.Executor.do_execute_query(repo, query)
    end, 30_000)
  end
  
  defp emit_query_telemetry(query, complexity, duration, result) do
    :ok = Telemetry.execute(
      [:elixir_scope, :ast, :query, :executed],
      %{duration_microseconds: duration},
      %{
        complexity: complexity,
        result: (if match?({:ok, _}, result), do: :success, else: :error),
        query_type: query.from
      }
    )
  end
  
  defp emit_rate_limited_telemetry(query, error) do
    :ok = Telemetry.execute(
      [:elixir_scope, :ast, :query, :rate_limited],
      %{retry_after_ms: error.context[:retry_after_ms] || 0},
      %{complexity: assess_query_complexity(query)}
    )
  end
end
```

## Migration Checklists

### Component Migration Checklist

- [ ] **Data Structures**
  - [ ] ModuleData migrated with Foundation integration
  - [ ] FunctionData migrated with Foundation integration
  - [ ] ComplexityMetrics enhanced with telemetry
  - [ ] All data structures return Foundation Error types

- [ ] **Repository System**
  - [ ] Core repository implements HealthCheckable
  - [ ] Core repository implements MemoryReporter
  - [ ] Enhanced repository migrated
  - [ ] Memory manager coordinates with Foundation

- [ ] **Query System**
  - [ ] Query executor implements health checks
  - [ ] Rate limiting integrated for complex queries
  - [ ] Circuit breaker protection implemented
  - [ ] Telemetry events emitted

- [ ] **Analysis Engine**
  - [ ] Pattern matcher implements health checks
  - [ ] Analysis telemetry integrated
  - [ ] Error handling uses Foundation types

### Foundation Contract Compliance Checklist

- [ ] **Health Check Interface**
  - [ ] All major components implement `HealthCheckable`
  - [ ] Health checks registered with `HealthAggregator`
  - [ ] Health status format complies with contract

- [ ] **Memory Reporting Interface**
  - [ ] Memory-intensive components implement `MemoryReporter`
  - [ ] Components registered with `MemoryManager`
  - [ ] Pressure signal handling implemented

- [ ] **Telemetry Compliance**
  - [ ] All required telemetry events implemented
  - [ ] Event naming follows exact specifications
  - [ ] Payload structures match contract requirements

- [ ] **Error Handling Compliance**
  - [ ] All functions return Foundation Error types
  - [ ] Error context includes actionable information
  - [ ] Graceful degradation implemented

## Testing Procedures

### Unit Test Validation

```bash
# Run migrated component tests
mix test test/ast_v2/ --verbose

# Run Foundation integration tests
mix test test/ast_v2/foundation_integration_test.exs

# Run contract compliance tests
mix test test/ast_v2/contract_compliance_test.exs
```

### Performance Validation

```bash
# Benchmark migration performance impact
mix run scripts/ast_migration_benchmark.exs

# Memory usage validation
mix run scripts/memory_usage_comparison.exs
```

### Integration Testing

```bash
# Full system integration test
mix test test/integration/ast_foundation_integration_test.exs

# End-to-end workflow validation
mix test test/integration/ast_e2e_test.exs
```

## Rollback Procedures

### Emergency Rollback

```bash
# Immediate rollback to backup
mv lib/elixir_scope/ast lib/elixir_scope/ast_migration_failed
mv lib/elixir_scope/ast_backup lib/elixir_scope/ast

# Revert configuration
git checkout -- config/

# Restart services
mix deps.compile --force
```

### Gradual Rollback

```bash
# Feature flag rollback
export AST_USE_FOUNDATION=false

# Component-by-component rollback
# 1. Disable new query executor
# 2. Disable Foundation memory coordination  
# 3. Disable Foundation health checks
# 4. Revert to original repository
```

---

**Implementation Team**: AST Migration Team  
**Review Cycle**: Daily progress review during active migration  
**Escalation**: Foundation Team for integration issues  
**Success Criteria**: All checklists completed, performance within targets 