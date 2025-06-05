# Foundation-AST Layer Programmatic Contract

**Version:** 2.0  
**Date:** June 4, 2025  
**Context:** Layer 1 (Foundation + Infrastructure) ↔ Layer 2 (AST)  
**Status:** Enhanced Contract Specification

## Overview

This document defines the exact programmatic contract between the Enhanced Foundation Layer (Layer 1, including Infrastructure sub-layer) and the AST Layer (Layer 2). It specifies all APIs, data structures, error contracts, and integration patterns required for proper layer interaction.

**Version 2.0 Enhancements:**
- Enhanced memory management coordination patterns
- Comprehensive circuit breaker and rate limiting integration
- Advanced telemetry and health reporting specifications
- Production-ready implementation examples
- Performance optimization contracts
- Graceful degradation and fallback mechanisms

## Table of Contents

1. [Foundation Services Consumed by AST](#foundation-services-consumed-by-ast)
2. [AST Services Provided to Foundation](#ast-services-provided-to-foundation)
3. [Foundation Infrastructure Integration](#foundation-infrastructure-integration)
4. [Error Handling Contracts](#error-handling-contracts)
5. [Telemetry Contracts](#telemetry-contracts)
6. [Health Check Contracts](#health-check-contracts)
7. [Memory Management Contracts](#memory-management-contracts)
8. [Configuration Contracts](#configuration-contracts)
9. [Event Coordination Contracts](#event-coordination-contracts)
10. [Testing Contracts](#testing-contracts)
11. [Performance Optimization Contracts](#performance-optimization-contracts)
12. [Fallback and Degradation Contracts](#fallback-and-degradation-contracts)
13. [Resource Management Contracts](#resource-management-contracts)
14. [Implementation Phase Contracts](#implementation-phase-contracts)

---

## 1. Foundation Services Consumed by AST

### 1.1 Configuration Management

**Enhanced AST Layer Usage:**
```elixir
# AST components use Foundation ConfigManager for dynamic runtime configuration
alias TideScope.Foundation.ConfigManager

# Memory pressure thresholds with dynamic updates
{:ok, thresholds} = ConfigManager.get_config(:ast_memory, %{
  warning: 0.7, 
  critical: 0.85, 
  emergency: 0.95
})

# Parser configuration with fallback defaults
{:ok, parser_config} = ConfigManager.get_config(:ast_parser, %{
  max_file_size: 10 * 1024 * 1024,  # 10MB default
  parse_timeout: 30_000,             # 30s default
  enable_caching: true,
  cache_ttl: 3600,                   # 1 hour
  parallel_parsing: true,
  max_parallel_jobs: 4
})

# Subscribe to configuration changes with handler registration
:ok = ConfigManager.subscribe()
:ok = ConfigManager.register_change_handler(:ast_parser, &handle_parser_config_change/3)

# Configuration change handler implementation
def handle_parser_config_change(:ast_parser, old_config, new_config) do
  # React to configuration changes atomically
  if old_config.max_parallel_jobs != new_config.max_parallel_jobs do
    :ok = resize_parser_pool(new_config.max_parallel_jobs)
  end
  
  if old_config.cache_ttl != new_config.cache_ttl do
    :ok = update_cache_ttl(new_config.cache_ttl)
  end
  
  Logger.info("AST parser configuration updated successfully")
end
```

**Enhanced Contract Requirements:**
- Foundation ConfigManager MUST provide atomic configuration updates
- Configuration updates MUST trigger registered change handlers within 100ms
- AST MUST handle `{:error, :service_unavailable}` with fallback to cached config
- Configuration validation MUST occur before propagation to handlers
- All AST configuration MUST support hot-reloading without service interruption

### 1.2 Memory Management Integration

**Enhanced Memory Allocation Contract:**
```elixir
alias TideScope.Foundation.MemoryManager

# Advanced memory allocation with operation context
def parse_large_file(file_path) do
  file_size = File.stat!(file_path).size
  estimated_ast_size = calculate_ast_memory_requirement(file_size)
  
  # Request memory allocation with detailed context
  case MemoryManager.request_allocation(
    requester: self(),
    operation: :ast_large_file_parsing,
    estimated_size: estimated_ast_size,
    priority: determine_priority(file_size),
    timeout: 30_000,
    context: %{
      file_path: file_path,
      file_size: file_size,
      parser_type: :elixir_code
    }
  ) do
    {:ok, allocation_ref} ->
      try do
        result = do_parse_with_monitoring(file_path, allocation_ref)
        MemoryManager.report_completion(allocation_ref, :success)
        {:ok, result}
      rescue
        error ->
          MemoryManager.report_completion(allocation_ref, {:error, error})
          {:error, {:parse_error, error}}
      end
    
    {:error, :insufficient_memory} ->
      # Implement fallback strategy
      handle_memory_pressure_fallback(file_path)
    
    {:error, :quota_exceeded} ->
      {:error, {:memory_quota_exceeded, "AST parsing quota exceeded"}}
  end
end

# Memory usage reporting during operation
defp do_parse_with_monitoring(file_path, allocation_ref) do
  start_memory = :erlang.memory(:total)
  
  # Report memory usage periodically during parsing
  monitoring_ref = start_memory_monitoring(allocation_ref)
  
  try do
    ast = Code.string_to_quoted!(File.read!(file_path))
    
    current_memory = :erlang.memory(:total)
    actual_usage = current_memory - start_memory
    
    MemoryManager.report_usage(
      allocation_ref: allocation_ref,
      current_usage: actual_usage,
      peak_usage: get_peak_usage(),
      operation_phase: :completion
    )
    
    ast
  after
    stop_memory_monitoring(monitoring_ref)
  end
end

# Memory cleanup integration
def terminate(reason, %{allocation_refs: refs} = state) do
  # Clean up all active allocations
  Enum.each(refs, &MemoryManager.release_allocation/1)
  cleanup_ast_caches(state.cache_refs)
  :ok
end
```

**Enhanced Memory Management Requirements:**
- MemoryManager MUST provide allocation quotas per operation type
- Memory monitoring MUST support real-time usage reporting
- AST MUST implement automatic cleanup on process termination
- Memory allocation MUST support priority-based scheduling
- Large file operations MUST coordinate with global memory pressure

### 1.3 Circuit Breaker Integration

**Enhanced Circuit Breaker Usage:**
```elixir
alias TideScope.Foundation.CircuitBreaker

# AST parsing with circuit breaker protection
def parse_with_circuit_breaker(source_code, options \\ []) do
  circuit_name = :ast_parser
  
  CircuitBreaker.call(circuit_name, fn ->
    case do_parse(source_code, options) do
      {:ok, ast} -> 
        {:ok, ast}
      {:error, reason} when reason in [:timeout, :memory_error, :oom] ->
        # These errors should trip the circuit breaker
        {:error, reason}
      {:error, :syntax_error} ->
        # Syntax errors are client errors, don't trip circuit
        {:ok, {:error, :syntax_error}}
    end
  end)
end

# Circuit breaker configuration with AST-specific parameters
def configure_ast_circuit_breakers() do
  CircuitBreaker.configure(:ast_parser, %{
    failure_threshold: 5,
    timeout: 30_000,
    recovery_timeout: 60_000,
    expected_errors: [:timeout, :memory_error, :oom],
    fallback: &parse_fallback/1,
    health_check: &parser_health_check/0
  })
  
  CircuitBreaker.configure(:ast_file_operations, %{
    failure_threshold: 3,
    timeout: 10_000,
    recovery_timeout: 30_000,
    expected_errors: [:file_not_found, :permission_denied, :disk_full],
    fallback: &file_operation_fallback/1
  })
end

# Fallback implementations for degraded service
defp parse_fallback(source_code) do
  Logger.warn("Using AST parsing fallback due to circuit breaker")
  {:ok, create_simplified_ast_stub(source_code)}
end

defp parser_health_check() do
  case get_parser_queue_depth() do
    depth when depth < 10 -> :healthy
    depth when depth < 50 -> :degraded
    _ -> :unhealthy
  end
end
```

**Circuit Breaker Contract Requirements:**
- AST MUST implement fallback strategies for all circuit-breaker-protected operations
- Circuit breakers MUST be configured with AST-specific error patterns
- Health check functions MUST reflect actual AST component health
- Fallback responses MUST be semantically meaningful (not just error responses)

### 1.4 Rate Limiting Integration

**Enhanced Rate Limiting Usage:**
```elixir
alias TideScope.Foundation.RateLimiter

# Multi-tier rate limiting for AST operations
def execute_ast_operation(operation_type, client_id, payload) do
  # Define rate limits based on operation complexity
  limits = case operation_type do
    :simple_parse ->
      [{:ast_parse_per_client, client_id, 100, :per_minute},
       {:ast_parse_global, :global, 1000, :per_minute}]
    
    :complex_analysis ->
      [{:ast_complex_per_client, client_id, 10, :per_minute},
       {:ast_complex_global, :global, 50, :per_minute},
       {:ast_memory_intensive, client_id, 5, :per_minute}]
    
    :pattern_matching ->
      [{:ast_pattern_per_client, client_id, 50, :per_minute},
       {:ast_pattern_global, :global, 200, :per_minute}]
  end
  
  case RateLimiter.check_limits(limits) do
    :allowed ->
      # Increment counters and proceed
      Enum.each(limits, fn {limit_type, key, _, _} ->
        RateLimiter.increment_counter(limit_type, key)
      end)
      
      execute_operation(operation_type, payload)
    
    {:rate_limited, limit_type, retry_after_ms} ->
      TelemetryCollector.increment_counter("ast.rate_limited", %{
        limit_type: limit_type,
        operation_type: operation_type
      })
      
      {:error, {:rate_limited, %{
        limit_type: limit_type,
        retry_after_ms: retry_after_ms,
        suggested_action: suggest_rate_limit_action(limit_type)
      }}}
  end
end

# Adaptive rate limiting based on system load
def get_dynamic_rate_limits(base_limits, system_load) do
  adjustment_factor = case system_load do
    load when load < 0.5 -> 1.0      # Normal limits
    load when load < 0.7 -> 0.8      # Reduce by 20%
    load when load < 0.9 -> 0.5      # Reduce by 50%
    _ -> 0.2                         # Emergency: reduce by 80%
  end
  
  Enum.map(base_limits, fn {type, key, limit, window} ->
    adjusted_limit = max(1, round(limit * adjustment_factor))
    {type, key, adjusted_limit, window}
  end)
end
```

**Rate Limiting Contract Requirements:**
- Rate limits MUST be configurable per operation type and client
- Dynamic rate limiting MUST respond to system load within 1 second
- Rate limit violations MUST include actionable retry information
- AST MUST implement graceful degradation when rate limited

---

## 2. AST Services Provided to Foundation

### 2.1 Health Check Interface

**AST Implementation Contract:**
```elixir
# All major AST GenServers MUST implement this interface
defmodule ElixirScope.AST.Repository.Core do
  @behaviour ElixirScope.Foundation.HealthCheckable

  @impl ElixirScope.Foundation.HealthCheckable
  def health_check() do
    case get_ets_table_stats() do
      {:ok, stats} when stats.error_count < 10 ->
        {:ok, %{
          status: :healthy,
          details: %{
            ets_tables: stats.table_count,
            memory_usage_mb: stats.memory_mb,
            last_error: nil,
            uptime_seconds: stats.uptime
          }
        }}
      {:ok, stats} when stats.error_count < 50 ->
        {:ok, %{
          status: :degraded,
          details: %{
            ets_tables: stats.table_count,
            memory_usage_mb: stats.memory_mb,
            last_error: stats.last_error,
            error_count: stats.error_count,
            uptime_seconds: stats.uptime
          }
        }}
      {:error, reason} ->
        {:error, %{
          status: :critical,
          reason: reason,
          timestamp: DateTime.utc_now()
        }}
    end
  end
end
```

**Health Check Registry:**
```elixir
# AST components register with Foundation HealthAggregator
defmodule ElixirScope.AST.Application do
  def start(_type, _args) do
    # Register health check providers
    :ok = ElixirScope.Foundation.Infrastructure.HealthAggregator.register_health_check_source(
      :ast_repository_core,
      {ElixirScope.AST.Repository.Core, :health_check, []},
      interval_ms: 30_000
    )
    
    :ok = ElixirScope.Foundation.Infrastructure.HealthAggregator.register_health_check_source(
      :ast_pattern_matcher,
      {ElixirScope.AST.Analysis.PatternMatcher.Core, :health_check, []},
      interval_ms: 60_000
    )
    
    # ... continue with supervision tree
  end
end
```

### 2.2 Memory Usage Reporting

**AST Implementation Contract:**
```elixir
defmodule ElixirScope.AST.Repository.MemoryManager.Monitor do
  @behaviour ElixirScope.Foundation.Infrastructure.MemoryReporter

  @impl ElixirScope.Foundation.Infrastructure.MemoryReporter
  def report_memory_usage() do
    ets_usage = calculate_ets_memory_usage()
    cache_usage = calculate_cache_memory_usage()
    
    {:ok, %{
      component: :ast_layer,
      total_bytes: ets_usage + cache_usage,
      breakdown: %{
        ets_tables: ets_usage,
        pattern_caches: cache_usage,
        query_caches: get_query_cache_size(),
        correlation_index: get_correlation_memory()
      },
      pressure_level: calculate_local_pressure_level(),
      last_cleanup: get_last_cleanup_timestamp()
    }}
  end

  @impl ElixirScope.Foundation.Infrastructure.MemoryReporter
  def handle_pressure_signal(pressure_level) when pressure_level in [:low, :medium, :high, :critical] do
    case pressure_level do
      :low -> 
        :ok
      :medium -> 
        trigger_gentle_cleanup()
      :high -> 
        trigger_aggressive_cleanup()
      :critical -> 
        trigger_emergency_cleanup()
    end
  end
end
```

### 2.3 Performance Metrics Contribution

**AST Implementation Contract:**
```elixir
# AST components emit structured performance telemetry
defmodule ElixirScope.AST.Parsing.Parser do
  alias ElixirScope.Foundation.Telemetry

  def parse_file(file_path) do
    start_time = System.monotonic_time(:microsecond)
    file_size = File.stat!(file_path).size
    
    result = do_parse_file(file_path)
    
    duration = System.monotonic_time(:microsecond) - start_time
    
    # Emit performance telemetry for Foundation Infrastructure
    :ok = Telemetry.execute(
      [:elixir_scope, :ast, :parser, :parse_file_duration],
      %{
        duration_microseconds: duration,
        file_size_bytes: file_size,
        result: (if match?({:ok, _}, result), do: :success, else: :error)
      },
      %{
        file_path: file_path,
        parser_version: @parser_version
      }
    )
    
    result
  end
end
```

---

## 3. Foundation Infrastructure Integration

### 3.1 Memory Manager Coordination

**AST Memory Manager Integration:**
```elixir
defmodule ElixirScope.AST.Repository.MemoryManager.PressureHandler do
  alias ElixirScope.Foundation.Infrastructure.MemoryManager

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Subscribe to global memory pressure signals
    :ok = MemoryManager.subscribe_to_pressure_signals()
    
    # Register as memory reporter
    :ok = MemoryManager.register_memory_reporter(__MODULE__)
    
    {:ok, %{local_pressure: :low, global_pressure: :low}}
  end

  def handle_info({:memory_pressure_signal, level}, state) do
    Logger.info("Received global memory pressure signal: #{level}")
    
    # Coordinate local cleanup with global pressure
    coordinate_cleanup_strategy(state.local_pressure, level)
    
    {:noreply, %{state | global_pressure: level}}
  end

  defp coordinate_cleanup_strategy(local_level, global_level) do
    effective_level = max_pressure_level(local_level, global_level)
    
    case effective_level do
      :critical -> 
        # Global critical overrides local assessment
        ElixirScope.AST.Repository.MemoryManager.Cleaner.emergency_cleanup()
      :high when global_level == :critical ->
        # Global critical, but local high - still do emergency cleanup
        ElixirScope.AST.Repository.MemoryManager.Cleaner.emergency_cleanup()
      level ->
        # Use normal escalation
        ElixirScope.AST.Repository.MemoryManager.Cleaner.cleanup(level)
    end
  end
end
```

### 3.2 Rate Limiting Integration (Selective)

**Query System Protection:**
```elixir
defmodule ElixirScope.AST.Querying.Executor do
  alias ElixirScope.Foundation.Infrastructure.RateLimiter
  
  def execute_query(repo, %{complexity: :high} = query) do
    # Protect complex queries with rate limiting
    case RateLimiter.check_rate(
      {:ast_complex_query, self()}, 
      :ast_complex_queries_per_minute, 
      1
    ) do
      :ok ->
        do_execute_query(repo, query)
      {:error, %Error{type: :rate_limited, context: %{retry_after_ms: delay}}} ->
        {:error, Error.new(:query_rate_limited, 
          "Complex query rate limited, retry in #{delay}ms", 
          %{retry_after_ms: delay})}
    end
  end
  
  def execute_query(repo, query) do
    # Simple queries bypass rate limiting
    do_execute_query(repo, query)
  end
end
```

### 3.3 Circuit Breaker Integration (Selective)

**File System Operations Protection:**
```elixir
defmodule ElixirScope.AST.Repository.Synchronization.FileWatcher do
  alias ElixirScope.Foundation.Infrastructure.CircuitBreakerWrapper
  
  def handle_file_change(file_path) do
    # Protect expensive file parsing operations
    operation = fn ->
      case File.read(file_path) do
        {:ok, content} -> 
          ElixirScope.AST.Parsing.Parser.parse_content(content, file_path)
        {:error, reason} -> 
          {:error, reason}
      end
    end
    
    case CircuitBreakerWrapper.execute(:ast_file_parsing_fuse, operation, 5000) do
      {:ok, result} -> 
        handle_successful_parse(file_path, result)
      {:error, %Error{type: :circuit_breaker_open}} ->
        Logger.warn("File parsing circuit breaker open for #{file_path}")
        queue_for_later_retry(file_path)
      {:error, %Error{type: :operation_timeout}} ->
        Logger.warn("File parsing timeout for #{file_path}")
        handle_parse_timeout(file_path)
    end
  end
end
```

---

## 4. Error Handling Contracts

## 4. Error Handling Contracts

### 4.1 Enhanced Foundation Infrastructure Error Types

**AST Layer MUST Handle:**
```elixir
# Circuit Breaker Errors with Recovery Context
%TideScope.Foundation.Error{
  type: :circuit_breaker_open,
  message: "Circuit breaker is open",
  context: %{
    circuit_name: :ast_parser,
    failure_count: 5,
    failure_threshold: 5,
    next_retry_time: ~U[2025-06-04 10:30:00Z],
    last_failure_reason: "timeout",
    recovery_timeout_ms: 60_000,
    health_check_available: true
  }
}

# Rate Limiting Errors with Adaptive Information
%TideScope.Foundation.Error{
  type: :rate_limited,
  message: "Rate limit exceeded",
  context: %{
    rule_name: :ast_complex_queries,
    current_count: 15,
    limit: 10,
    window_ms: 60_000,
    retry_after_ms: 45_000,
    dynamic_limit: true,
    suggested_backoff_strategy: :exponential,
    alternative_endpoints: ["/api/v1/simple-parse"]
  }
}

# Memory Allocation Errors
%TideScope.Foundation.Error{
  type: :memory_allocation_failed,
  message: "Memory allocation failed",
  context: %{
    requested_bytes: 10_485_760,
    available_bytes: 5_242_880,
    global_pressure_level: :high,
    suggested_retry_delay_ms: 5_000,
    fallback_allocation_size: 2_097_152,
    cleanup_in_progress: true
  }
}

# Connection Pool Errors with Pool State
%TideScope.Foundation.Error{
  type: :pool_checkout_timeout,
  message: "Pool checkout timeout",
  context: %{
    pool_name: :ast_http_client,
    timeout_ms: 5_000,
    current_pool_size: 10,
    checked_out: 10,
    queue_depth: 25,
    suggested_action: :retry_with_backoff,
    pool_health: :saturated
  }
}

# Service Unavailable with Fallback Options
%TideScope.Foundation.Error{
  type: :service_unavailable,
  message: "Foundation service unavailable",
  context: %{
    service: :config_manager,
    last_error: "GenServer call timeout",
    unavailable_since: ~U[2025-06-04 10:25:00Z],
    fallback_config_available: true,
    estimated_recovery_time_ms: 30_000,
    alternative_services: []
  }
}

# Configuration Validation Errors
%TideScope.Foundation.Error{
  type: :config_validation_failed,
  message: "Configuration validation failed",
  context: %{
    config_path: [:ast, :parser, :max_file_size],
    provided_value: -1,
    expected_type: :positive_integer,
    valid_range: {1, 100_000_000},
    current_fallback_value: 10_485_760
  }
}
```

### 4.2 Enhanced AST Error Propagation Contract

**Comprehensive Error Handling Implementation:**
```elixir
defmodule TideScope.AST.ErrorHandler do
  alias TideScope.Foundation.{Error, TelemetryCollector}
  require Logger

  def handle_foundation_error({:error, %Error{} = error}, operation_context \\ %{}) do
    # Record error telemetry
    TelemetryCollector.record_metrics([
      {:counter, "ast.foundation_errors.total", 1, %{
        error_type: error.type,
        service: Map.get(error.context, :service, :unknown),
        operation: Map.get(operation_context, :operation, :unknown)
      }}
    ])

    case error.type do
      :circuit_breaker_open ->
        handle_circuit_breaker_error(error, operation_context)
      :rate_limited ->
        handle_rate_limit_error(error, operation_context)
      :memory_allocation_failed ->
        handle_memory_error(error, operation_context)
      :pool_checkout_timeout ->
        handle_pool_error(error, operation_context)
      :service_unavailable ->
        handle_service_unavailable_error(error, operation_context)
      :config_validation_failed ->
        handle_config_error(error, operation_context)
      _ ->
        handle_unknown_error(error, operation_context)
    end
  end

  defp handle_circuit_breaker_error(%Error{context: context} = error, op_context) do
    Logger.warn("Foundation circuit breaker open: #{error.message}", 
      circuit_name: context.circuit_name,
      failure_count: context.failure_count
    )
    
    # Check if health check is available for recovery assessment
    recovery_strategy = if context[:health_check_available] do
      schedule_health_check_retry(context.circuit_name, context.next_retry_time)
      :health_check_scheduled
    else
      :time_based_retry
    end

    # AST-specific graceful degradation
    {:error, Error.new(:foundation_circuit_open, 
      "Foundation service circuit breaker open", 
      %{
        foundation_error: error,
        degraded_mode: true,
        retry_strategy: recovery_strategy,
        retry_after: context[:next_retry_time],
        fallback_available: has_fallback_strategy?(op_context.operation)
      })}
  end

  defp handle_rate_limit_error(%Error{context: context} = error, op_context) do
    retry_delay = context[:retry_after_ms] || 60_000
    
    Logger.info("Foundation service rate limited", 
      rule_name: context.rule_name,
      retry_after_ms: retry_delay
    )
    
    # Implement intelligent backoff strategy
    backoff_strategy = case context[:suggested_backoff_strategy] do
      :exponential -> calculate_exponential_backoff(retry_delay, op_context)
      :linear -> calculate_linear_backoff(retry_delay)
      _ -> retry_delay
    end

    # Check for alternative endpoints
    alternatives = context[:alternative_endpoints] || []
    
    {:error, Error.new(:temporarily_rate_limited,
      "Service temporarily rate limited",
      %{
        foundation_error: error,
        retry_after_ms: backoff_strategy,
        should_retry: true,
        alternatives_available: length(alternatives) > 0,
        alternative_endpoints: alternatives,
        backoff_strategy: context[:suggested_backoff_strategy]
      })}
  end

  defp handle_memory_error(%Error{context: context} = error, op_context) do
    Logger.warn("Memory allocation failed", 
      requested_bytes: context.requested_bytes,
      available_bytes: context.available_bytes,
      pressure_level: context.global_pressure_level
    )

    # Trigger local memory cleanup if not already in progress
    unless context[:cleanup_in_progress] do
      spawn(fn -> trigger_emergency_cleanup() end)
    end

    # Offer fallback allocation if available
    fallback_option = if context[:fallback_allocation_size] do
      {:fallback_allocation, context.fallback_allocation_size}
    else
      nil
    end

    {:error, Error.new(:memory_unavailable,
      "Insufficient memory for operation",
      %{
        foundation_error: error,
        retry_after_ms: context[:suggested_retry_delay_ms] || 5_000,
        fallback_option: fallback_option,
        cleanup_triggered: true,
        operation_can_be_simplified: can_simplify_operation?(op_context.operation)
      })}
  end

  defp handle_service_unavailable_error(%Error{context: context} = error, op_context) do
    service_name = context[:service] || :unknown_service
    
    Logger.error("Foundation service unavailable", 
      service: service_name,
      unavailable_since: context[:unavailable_since]
    )

    # Check for fallback configurations or cached data
    fallback_available = case service_name do
      :config_manager -> context[:fallback_config_available] || false
      :memory_manager -> has_local_memory_management?()
      :telemetry_collector -> has_local_telemetry_buffer?()
      _ -> false
    end

    degradation_level = determine_service_degradation_level(service_name, fallback_available)

    {:error, Error.new(:foundation_service_unavailable,
      "Foundation service temporarily unavailable",
      %{
        foundation_error: error,
        service: service_name,
        degradation_level: degradation_level,
        fallback_available: fallback_available,
        estimated_recovery_ms: context[:estimated_recovery_time_ms],
        local_alternatives: get_local_alternatives(service_name)
      })}
  end

  # Error recovery helpers
  defp calculate_exponential_backoff(base_delay, op_context) do
    attempt = Map.get(op_context, :retry_attempt, 0)
    jitter = :rand.uniform(1000)  # Add jitter to prevent thundering herd
    min(base_delay * :math.pow(2, attempt) + jitter, 300_000)  # Cap at 5 minutes
  end

  defp trigger_emergency_cleanup() do
    TideScope.AST.MemoryManager.emergency_cleanup()
  end

  defp can_simplify_operation?(:parse_large_file), do: true
  defp can_simplify_operation?(:complex_analysis), do: true
  defp can_simplify_operation?(_), do: false

  defp determine_service_degradation_level(:config_manager, true), do: :minimal
  defp determine_service_degradation_level(:config_manager, false), do: :severe
  defp determine_service_degradation_level(:memory_manager, _), do: :critical
  defp determine_service_degradation_level(_, _), do: :moderate
end
```

### 4.3 Error Recovery and Retry Patterns

**Automated Error Recovery Implementation:**
```elixir
defmodule TideScope.AST.RecoveryManager do
  alias TideScope.Foundation.{CircuitBreaker, MemoryManager, Error}
  
  @max_retries 3
  @base_backoff_ms 1_000

  def execute_with_recovery(operation_fn, context, options \\ []) do
    max_retries = Keyword.get(options, :max_retries, @max_retries)
    base_backoff = Keyword.get(options, :base_backoff_ms, @base_backoff_ms)
    
    execute_attempt(operation_fn, context, 0, max_retries, base_backoff)
  end

  defp execute_attempt(operation_fn, context, attempt, max_retries, base_backoff) 
       when attempt < max_retries do
    
    case operation_fn.(context) do
      {:ok, result} ->
        # Record successful recovery if this wasn't the first attempt
        if attempt > 0 do
          TelemetryCollector.record_metrics([
            {:counter, "ast.recovery.success", 1, %{attempts: attempt + 1}},
            {:histogram, "ast.recovery.attempts", attempt + 1, %{}}
          ])
        end
        {:ok, result}

      {:error, %Error{type: error_type} = error} ->
        recovery_strategy = determine_recovery_strategy(error_type, attempt)
        
        case recovery_strategy do
          :retry_immediately ->
            execute_attempt(operation_fn, context, attempt + 1, max_retries, base_backoff)
          
          {:retry_after, delay_ms} ->
            Logger.info("Retrying operation after #{delay_ms}ms", 
              attempt: attempt + 1, 
              error_type: error_type
            )
            Process.sleep(delay_ms)
            execute_attempt(operation_fn, context, attempt + 1, max_retries, base_backoff)
          
          {:retry_with_modified_context, new_context} ->
            execute_attempt(operation_fn, new_context, attempt + 1, max_retries, base_backoff)
          
          :abort ->
            TelemetryCollector.record_metrics([
              {:counter, "ast.recovery.aborted", 1, %{error_type: error_type, attempts: attempt + 1}}
            ])
            {:error, error}
        end

      error ->
        # Non-Foundation errors
        {:error, error}
    end
  end

  defp execute_attempt(_operation_fn, _context, max_retries, max_retries, _base_backoff) do
    TelemetryCollector.record_metrics([
      {:counter, "ast.recovery.max_retries_exceeded", 1, %{}}
    ])
    {:error, :max_retries_exceeded}
  end

  defp determine_recovery_strategy(:circuit_breaker_open, attempt) do
    # Wait for circuit breaker to potentially recover
    backoff = min(@base_backoff_ms * :math.pow(2, attempt), 60_000)
    {:retry_after, backoff}
  end

  defp determine_recovery_strategy(:rate_limited, attempt) do
    # Use exponential backoff for rate limiting
    backoff = @base_backoff_ms * :math.pow(1.5, attempt) + :rand.uniform(1000)
    {:retry_after, round(backoff)}
  end

  defp determine_recovery_strategy(:memory_allocation_failed, attempt) do
    if attempt < 2 do
      # Trigger cleanup and retry
      spawn(fn -> MemoryManager.trigger_cleanup(:aggressive) end)
      {:retry_after, 2000 + (attempt * 1000)}
    else
      :abort
    end
  end

  defp determine_recovery_strategy(:service_unavailable, attempt) do
    if attempt < 2 do
      # Give service time to recover
      {:retry_after, 5000 + (attempt * 2000)}
    else
      :abort
    end
  end

  defp determine_recovery_strategy(_, _), do: :abort
end
```
      :service_unavailable ->
        handle_service_unavailable_error(error)
      _ ->
        handle_unknown_error(error)
    end
  end

  defp handle_circuit_breaker_error(%Error{context: context} = error) do
    Logger.warn("Foundation circuit breaker open: #{error.message}")
    
    # AST-specific graceful degradation
    {:error, Error.new(:foundation_unavailable, 
      "Foundation service temporarily unavailable", 
      %{
        foundation_error: error,
        degraded_mode: true,
        retry_after: context[:next_retry_time]
      })}
  end

  defp handle_rate_limit_error(%Error{context: %{retry_after_ms: delay}} = error) do
    Logger.info("Foundation service rate limited, backing off #{delay}ms")
    
    # Implement exponential backoff or queue request
    {:error, Error.new(:temporarily_unavailable,
      "Service temporarily rate limited",
      %{
        foundation_error: error,
        retry_after_ms: delay,
        should_retry: true
      })}
  end
end
```

---

## 5. Telemetry Contracts

## 5. Telemetry Contracts

### 5.1 Enhanced AST Telemetry Implementation

**Comprehensive Telemetry Integration:**
```elixir
alias TideScope.Foundation.TelemetryCollector

# Enhanced parser metrics with correlation IDs
def report_parse_metrics(duration, file_size, ast_node_count, correlation_id) do
  TelemetryCollector.record_metrics([
    {:counter, "ast.parse.total", 1, %{component: "parser"}},
    {:histogram, "ast.parse.duration", duration, %{
      size_category: categorize_size(file_size),
      correlation_id: correlation_id
    }},
    {:gauge, "ast.parse.nodes_per_kb", ast_node_count / (file_size / 1024), %{}},
    {:gauge, "ast.active_parses", get_active_parse_count(), %{}},
    {:histogram, "ast.parse.complexity", calculate_complexity_score(ast_node_count), %{}}
  ])
end

# Cache performance metrics with hit/miss patterns
def report_cache_metrics(operation_type, hit_rate, cache_size, eviction_count) do
  TelemetryCollector.record_metrics([
    {:gauge, "ast.cache.hit_rate", hit_rate, %{
      cache_type: "ast_nodes", 
      operation_type: operation_type
    }},
    {:gauge, "ast.cache.size_bytes", cache_size, %{}},
    {:counter, "ast.cache.evictions", eviction_count, %{reason: "memory_pressure"}},
    {:histogram, "ast.cache.lookup_time", get_avg_lookup_time(), %{}},
    {:counter, "ast.cache.misses", get_cache_misses(), %{miss_reason: classify_miss_reason()}}
  ])
end

# Memory management telemetry with pressure levels
def report_memory_telemetry(pressure_level, cleanup_stats) do
  TelemetryCollector.record_metrics([
    {:gauge, "ast.memory.pressure_level", pressure_level, %{source: "local_monitor"}},
    {:counter, "ast.memory.cleanup.triggered", 1, %{
      trigger_reason: cleanup_stats.reason,
      cleanup_level: cleanup_stats.level
    }},
    {:histogram, "ast.memory.cleanup.freed_bytes", cleanup_stats.freed_bytes, %{}},
    {:histogram, "ast.memory.cleanup.duration", cleanup_stats.duration_ms, %{}},
    {:gauge, "ast.memory.total_usage", get_total_memory_usage(), %{}}
  ])
end

# Error tracking with categorization
def report_error_metrics(error_type, error_context, recovery_time \\ nil) do
  base_metrics = [
    {:counter, "ast.errors.total", 1, %{
      error_type: error_type,
      component: error_context.component,
      operation: error_context.operation
    }},
    {:counter, "ast.errors.by_severity", 1, %{
      severity: classify_error_severity(error_type)
    }}
  ]
  
  recovery_metrics = if recovery_time do
    [{:histogram, "ast.errors.recovery_time", recovery_time, %{error_type: error_type}}]
  else
    []
  end
  
  TelemetryCollector.record_metrics(base_metrics ++ recovery_metrics)
end
```

### 5.2 Required AST Telemetry Events

**Standardized Event Specifications:**
```elixir
# Enhanced Parser Events
[:tide_scope, :ast, :parser, :parse_duration]
# Measurements: %{duration_microseconds: integer(), file_size_bytes: integer(), node_count: integer()}
# Metadata: %{file_path: String.t(), result: :success | :error, correlation_id: String.t()}

[:tide_scope, :ast, :parser, :instrumentation_injection]
# Measurements: %{injected_points: integer(), duration_microseconds: integer()}
# Metadata: %{module_name: atom(), instrumentation_types: [atom()], correlation_id: String.t()}

# Enhanced Repository Events
[:tide_scope, :ast, :repository, :query_executed]
# Measurements: %{query_duration_microseconds: integer(), result_count: integer(), cache_hit: boolean()}
# Metadata: %{query_type: atom(), complexity: :low | :medium | :high, correlation_id: String.t()}

[:tide_scope, :ast, :repository, :storage_operation]
# Measurements: %{operation_duration_microseconds: integer(), data_size_bytes: integer()}
# Metadata: %{operation: :store | :retrieve | :delete, table_name: atom(), success: boolean()}

# Enhanced Memory Events
[:tide_scope, :ast, :memory, :pressure_change]
# Measurements: %{old_pressure: float(), new_pressure: float(), trigger_threshold: float()}
# Metadata: %{trigger_source: :local | :global, action_taken: atom(), correlation_id: String.t()}

[:tide_scope, :ast, :memory, :cleanup_executed]
# Measurements: %{freed_bytes: integer(), cleanup_duration_microseconds: integer(), tables_cleaned: integer()}
# Metadata: %{cleanup_level: :gentle | :aggressive | :emergency, trigger: atom()}

# Circuit Breaker Events
[:tide_scope, :ast, :circuit_breaker, :state_change]
# Measurements: %{failure_count: integer(), success_count: integer()}
# Metadata: %{circuit_name: atom(), old_state: atom(), new_state: atom(), correlation_id: String.t()}

# Rate Limiting Events
[:tide_scope, :ast, :rate_limiter, :limit_exceeded]
# Measurements: %{current_rate: integer(), limit: integer(), retry_after_ms: integer()}
# Metadata: %{limit_type: atom(), client_id: String.t(), operation_type: atom()}

# Performance Optimization Events
[:tide_scope, :ast, :optimization, :resource_adjustment]
# Measurements: %{old_allocation: integer(), new_allocation: integer(), efficiency_gain: float()}
# Metadata: %{resource_type: atom(), optimization_reason: String.t(), correlation_id: String.t()}
```

### 5.3 Foundation Infrastructure Telemetry Consumption

**Enhanced Performance Monitoring Contract:**
```elixir
# Foundation Infrastructure automatically aggregates AST telemetry
# Provides comprehensive performance analytics

TideScope.Foundation.Infrastructure.PerformanceMonitor.get_service_performance(:ast_layer, :detailed)
# Returns: {:ok, %{
#   parsing: %{
#     avg_duration_ms: 45.2, 
#     p50_duration_ms: 32.1,
#     p99_duration_ms: 150.0, 
#     error_rate: 0.02,
#     throughput_per_second: 25.3,
#     complexity_distribution: %{low: 0.6, medium: 0.3, high: 0.1}
#   },
#   memory: %{
#     avg_pressure: 0.45, 
#     peak_pressure: 0.87,
#     cleanup_frequency: 2.1,
#     efficiency_ratio: 0.82,
#     pressure_events_per_hour: 1.2
#   },
#   caching: %{
#     hit_rate: 0.73,
#     avg_lookup_time_ms: 0.8,
#     eviction_rate: 0.05,
#     size_efficiency: 0.89
#   },
#   resilience: %{
#     circuit_breaker_trips: 0,
#     rate_limit_hits: 3,
#     recovery_time_avg_ms: 1200,
#     fallback_usage_rate: 0.001
#   }
# }}

# Real-time telemetry streaming for monitoring dashboards
TideScope.Foundation.Infrastructure.TelemetryStreamer.subscribe_to_ast_metrics([
  "ast.parse.duration",
  "ast.memory.pressure_level", 
  "ast.errors.total",
  "ast.cache.hit_rate"
])
```

### 5.4 Telemetry Performance Requirements

**Performance Guarantees:**
- Telemetry emission overhead: < 1ms per event
- Batch telemetry processing: < 5ms for 100 events
- Memory overhead: < 1MB for telemetry buffers
- Network impact: < 1% of available bandwidth
- Storage efficiency: > 10:1 compression ratio for time-series data

**Reliability Requirements:**
- Telemetry data loss rate: < 0.01%
- Out-of-order event tolerance: 30 seconds
- Metric accuracy: ±0.1% for counters, ±1% for histograms
- Correlation ID propagation: 99.9% success rate

---

## 6. Health Check Contracts

### 6.1 AST Health Check Interface

**Required Health Check Implementation:**
```elixir
@type health_status :: :healthy | :degraded | :critical
@type health_details :: %{
  optional(:ets_tables) => non_neg_integer(),
  optional(:memory_usage_mb) => float(),
  optional(:error_count) => non_neg_integer(),
  optional(:last_error) => String.t() | nil,
  optional(:uptime_seconds) => non_neg_integer(),
  optional(atom()) => term()
}

@callback health_check() :: 
  {:ok, %{status: health_status(), details: health_details()}} | 
  {:error, %{status: :critical, reason: term(), timestamp: DateTime.t()}}
```

### 6.2 Health Check Registration

**AST Components MUST Register:**
```elixir
# In application startup
health_check_sources = [
  {:ast_repository_core, {ElixirScope.AST.Repository.Core, :health_check, []}, 30_000},
  {:ast_pattern_matcher, {ElixirScope.AST.Analysis.PatternMatcher.Core, :health_check, []}, 60_000},
  {:ast_query_executor, {ElixirScope.AST.Querying.Executor, :health_check, []}, 45_000},
  {:ast_file_watcher, {ElixirScope.AST.Repository.Synchronization.FileWatcher, :health_check, []}, 30_000},
  {:ast_memory_manager, {ElixirScope.AST.Repository.MemoryManager.Monitor, :health_check, []}, 15_000}
]

Enum.each(health_check_sources, fn {name, {mod, fun, args}, interval} ->
  :ok = ElixirScope.Foundation.Infrastructure.HealthAggregator.register_health_check_source(
    name, {mod, fun, args}, interval_ms: interval
  )
end)
```

---

## 7. Memory Management Contracts

## 7. Memory Management Contracts

### 7.1 Enhanced Memory Reporter Interface

**AST MUST Implement Advanced Memory Reporting:**
```elixir
defmodule TideScope.AST.MemoryManager.Monitor do
  @behaviour TideScope.Foundation.Infrastructure.MemoryReporter
  alias TideScope.Foundation.{MemoryManager, TelemetryCollector}

  @impl true
  def report_memory_usage() do
    memory_breakdown = calculate_detailed_memory_breakdown()
    pressure_level = calculate_local_pressure_level(memory_breakdown)
    
    {:ok, %{
      component: :ast_layer,
      timestamp: DateTime.utc_now(),
      total_bytes: memory_breakdown.total,
      breakdown: %{
        ets_tables: memory_breakdown.ets_tables,
        ast_caches: memory_breakdown.ast_caches,
        pattern_caches: memory_breakdown.pattern_caches,
        query_buffers: memory_breakdown.query_buffers,
        correlation_index: memory_breakdown.correlation_index,
        temporary_parses: memory_breakdown.temporary_parses
      },
      pressure_level: pressure_level,
      last_cleanup: get_last_cleanup_timestamp(),
      cleanup_effectiveness: calculate_cleanup_effectiveness(),
      growth_rate_per_hour: calculate_memory_growth_rate(),
      predictive_metrics: %{
        projected_usage_1h: project_memory_usage(3600),
        estimated_cleanup_threshold: calculate_cleanup_threshold(),
        fragmentation_level: calculate_memory_fragmentation()
      }
    }}
  end

  @impl true
  def handle_pressure_signal(level, context \\ %{}) when level in [:low, :medium, :high, :critical] do
    Logger.info("Received global memory pressure signal: #{level}", context: context)
    
    # Record pressure signal telemetry
    TelemetryCollector.record_metrics([
      {:counter, "ast.memory.pressure_signals", 1, %{level: level, source: :global}},
      {:gauge, "ast.memory.pressure_level", pressure_level_to_float(level), %{}}
    ])
    
    # Execute appropriate cleanup strategy
    cleanup_result = case level do
      :low -> 
        :ok  # No action needed
      :medium -> 
        trigger_gentle_cleanup(context)
      :high -> 
        trigger_aggressive_cleanup(context)
      :critical -> 
        trigger_emergency_cleanup(context)
    end
    
    # Report cleanup results back to Foundation
    if cleanup_result != :ok do
      MemoryManager.report_cleanup_completion(cleanup_result)
    end
    
    cleanup_result
  end

  # Advanced cleanup strategies
  defp trigger_gentle_cleanup(context) do
    start_time = System.monotonic_time(:millisecond)
    
    freed_bytes = 0
    |> cleanup_expired_cache_entries()
    |> cleanup_completed_parse_buffers()
    |> cleanup_old_correlation_entries()
    
    duration = System.monotonic_time(:millisecond) - start_time
    
    TelemetryCollector.record_metrics([
      {:histogram, "ast.memory.cleanup.duration", duration, %{level: :gentle}},
      {:histogram, "ast.memory.cleanup.freed_bytes", freed_bytes, %{level: :gentle}}
    ])
    
    {:ok, %{level: :gentle, freed_bytes: freed_bytes, duration_ms: duration}}
  end

  defp trigger_aggressive_cleanup(context) do
    start_time = System.monotonic_time(:millisecond)
    
    freed_bytes = 0
    |> cleanup_expired_cache_entries()
    |> cleanup_completed_parse_buffers()
    |> cleanup_old_correlation_entries()
    |> compress_cold_ast_data()
    |> evict_large_cache_entries()
    |> force_garbage_collection()
    
    duration = System.monotonic_time(:millisecond) - start_time
    
    TelemetryCollector.record_metrics([
      {:histogram, "ast.memory.cleanup.duration", duration, %{level: :aggressive}},
      {:histogram, "ast.memory.cleanup.freed_bytes", freed_bytes, %{level: :aggressive}}
    ])
    
    {:ok, %{level: :aggressive, freed_bytes: freed_bytes, duration_ms: duration}}
  end

  defp trigger_emergency_cleanup(context) do
    start_time = System.monotonic_time(:millisecond)
    Logger.warn("Executing emergency memory cleanup", context: context)
    
    freed_bytes = 0
    |> clear_all_caches()
    |> abort_non_critical_operations()
    |> compress_essential_data()
    |> force_aggressive_garbage_collection()
    |> release_unnecessary_ets_tables()
    
    duration = System.monotonic_time(:millisecond) - start_time
    
    TelemetryCollector.record_metrics([
      {:histogram, "ast.memory.cleanup.duration", duration, %{level: :emergency}},
      {:histogram, "ast.memory.cleanup.freed_bytes", freed_bytes, %{level: :emergency}},
      {:counter, "ast.memory.emergency_cleanups", 1, %{}}
    ])
    
    {:ok, %{level: :emergency, freed_bytes: freed_bytes, duration_ms: duration}}
  end
end
```

### 7.2 Advanced Memory Pressure Coordination

**Coordinated Memory Management:**
```elixir
defmodule TideScope.AST.MemoryManager.PressureCoordinator do
  use GenServer
  alias TideScope.Foundation.MemoryManager
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Subscribe to both global and local memory pressure signals
    :ok = MemoryManager.subscribe_to_pressure_signals()
    :ok = register_as_memory_reporter()
    
    # Start memory monitoring timer
    schedule_memory_check()
    
    {:ok, %{
      local_pressure: :low,
      global_pressure: :low,
      cleanup_history: :queue.new(),
      memory_trend: :stable,
      last_cleanup: nil
    }}
  end

  def handle_info({:memory_pressure_signal, level, context}, state) do
    Logger.info("Global memory pressure signal received", 
      level: level, 
      context: context,
      local_pressure: state.local_pressure
    )
    
    # Coordinate local and global pressure responses
    effective_pressure = determine_effective_pressure(state.local_pressure, level)
    response_strategy = determine_response_strategy(effective_pressure, state)
    
    # Execute coordinated response
    spawn(fn -> execute_coordinated_response(response_strategy, context) end)
    
    # Update state
    new_state = %{state | 
      global_pressure: level,
      last_response: {effective_pressure, response_strategy, DateTime.utc_now()}
    }
    
    {:noreply, new_state}
  end

  def handle_info(:memory_check, state) do
    # Perform local memory assessment
    local_pressure = assess_local_memory_pressure()
    
    # Update memory trend analysis
    new_trend = update_memory_trend(state.memory_trend, local_pressure)
    
    # Check if we need to proactively signal pressure
    if should_signal_pressure?(local_pressure, state.local_pressure) do
      MemoryManager.report_local_pressure(local_pressure, %{
        component: :ast_layer,
        trend: new_trend,
        proactive: true
      })
    end
    
    schedule_memory_check()
    
    {:noreply, %{state | 
      local_pressure: local_pressure,
      memory_trend: new_trend
    }}
  end

  defp determine_effective_pressure(local, global) do
    pressure_levels = %{low: 1, medium: 2, high: 3, critical: 4}
    
    local_value = Map.get(pressure_levels, local, 1)
    global_value = Map.get(pressure_levels, global, 1)
    
    # Use the higher pressure level, but weight global pressure more heavily
    effective_value = max(local_value, global_value + 0.5)
    
    cond do
      effective_value >= 4 -> :critical
      effective_value >= 3 -> :high
      effective_value >= 2 -> :medium
      true -> :low
    end
  end

  defp execute_coordinated_response(strategy, context) do
    case strategy do
      {:cleanup, level} ->
        TideScope.AST.MemoryManager.Monitor.handle_pressure_signal(level, context)
      
      {:throttle_operations, severity} ->
        TideScope.AST.OperationThrottler.apply_throttling(severity)
      
      {:emergency_mode, actions} ->
        TideScope.AST.EmergencyManager.activate_emergency_mode(actions)
      
      :no_action ->
        :ok
    end
  end
end
```

### 7.3 Memory Allocation Coordination

**Intelligent Memory Allocation:**
```elixir
defmodule TideScope.AST.MemoryManager.AllocationCoordinator do
  alias TideScope.Foundation.MemoryManager
  
  def request_coordinated_allocation(operation_type, size_estimate, options \\ []) do
    # Analyze allocation context
    allocation_context = build_allocation_context(operation_type, size_estimate, options)
    
    # Check if allocation should be deferred due to system state
    case should_defer_allocation?(allocation_context) do
      {:defer, reason, delay_ms} ->
        {:deferred, %{reason: reason, retry_after_ms: delay_ms}}
      
      :proceed ->
        # Request allocation with enhanced context
        request_with_coordination(allocation_context)
    end
  end

  defp request_with_coordination(context) do
    allocation_request = %{
      requester: self(),
      operation: context.operation_type,
      estimated_size: context.size_estimate,
      priority: context.priority,
      timeout: context.timeout,
      context: %{
        operation_complexity: context.complexity,
        expected_duration_ms: context.expected_duration,
        can_be_chunked: context.can_be_chunked,
        cleanup_callback: context.cleanup_callback
      }
    }
    
    case MemoryManager.request_allocation(allocation_request) do
      {:ok, allocation_ref} ->
        # Start monitoring this allocation
        start_allocation_monitoring(allocation_ref, context)
        {:ok, allocation_ref}
      
      {:error, reason} ->
        # Handle allocation failure with context-aware fallback
        handle_allocation_failure(reason, context)
    end
  end

  defp start_allocation_monitoring(allocation_ref, context) do
    monitor_pid = spawn(fn ->
      monitor_allocation_usage(allocation_ref, context)
    end)
    
    # Register monitoring process for cleanup
    :ets.insert(:ast_allocation_monitors, {allocation_ref, monitor_pid})
  end

  defp monitor_allocation_usage(allocation_ref, context) do
    start_memory = :erlang.memory(:total)
    
    # Periodic memory usage reporting
    Stream.repeatedly(fn ->
      Process.sleep(1000)  # Check every second
      current_memory = :erlang.memory(:total)
      usage = current_memory - start_memory
      
      MemoryManager.report_usage(
        allocation_ref: allocation_ref,
        current_usage: usage,
        operation_phase: get_current_operation_phase(context),
        efficiency_ratio: calculate_efficiency_ratio(usage, context.size_estimate)
      )
      
      # Check for allocation violations
      if usage > context.size_estimate * 1.5 do
        Logger.warn("Memory allocation exceeded estimate", 
          allocation_ref: allocation_ref,
          estimated: context.size_estimate,
          actual: usage
        )
      end
    end)
    |> Stream.take_while(fn _ -> 
      Process.alive?(context.requester_pid)
    end)
    |> Enum.each(fn _ -> :ok end)
  end
end
```

---

## 8. Configuration Contracts

### 8.1 AST Configuration Schema

**Required Configuration Paths:**
```elixir
# AST Layer configuration structure in Foundation Config
config = %{
  ast: %{
    memory: %{
      pressure_thresholds: %{
        warning: 0.7,
        critical: 0.85,  
        emergency: 0.95
      },
      cleanup_strategies: %{
        gentle: [:clear_query_cache],
        aggressive: [:clear_query_cache, :compress_cold_data],
        emergency: [:clear_all_caches, :force_gc]
      }
    },
    parser: %{
      timeout_ms: 30_000,
      max_file_size_bytes: 10_485_760, # 10MB
      instrumentation_enabled: true
    },
    pattern_matcher: %{
      timeout_ms: 5_000,
      confidence_threshold: 0.7,
      max_concurrent_analyses: 10
    },
    query: %{
      concurrent_limit: 50,
      complex_query_timeout_ms: 30_000,
      cache_ttl_ms: 300_000,
      rate_limiting: %{
        enabled: true,
        complex_queries_per_minute: 10
      }
    },
    file_watcher: %{
      debounce_ms: 500,
      max_batch_size: 100,
      circuit_breaker: %{
        enabled: true,
        failure_threshold: 5,
        reset_timeout_ms: 60_000
      }
    },
    repository: %{
      ets_tables: %{
        read_concurrency: true,
        write_concurrency: true,
        compressed: false
      },
      correlation_index_size_limit: 1_000_000
    }
  }
}
```

### 8.2 Configuration Update Handling

**AST MUST Handle Configuration Updates:**
```elixir
def handle_info({:config_updated, [:ast, :memory, :pressure_thresholds], old_value, new_value}, state) do
  Logger.info("Updating memory pressure thresholds: #{inspect(old_value)} -> #{inspect(new_value)}")
  
  # Update local thresholds
  :ok = ElixirScope.AST.Repository.MemoryManager.Monitor.update_thresholds(new_value)
  
  {:noreply, state}
end

def handle_info({:config_updated, [:ast, :query, :concurrent_limit], old_limit, new_limit}, state) do
  Logger.info("Updating query concurrent limit: #{old_limit} -> #{new_limit}")
  
  # Update query executor limits
  :ok = ElixirScope.AST.Querying.Executor.update_concurrent_limit(new_limit)
  
  {:noreply, state}
end
```

---

## 9. Event Coordination Contracts

### 9.1 AST Event Production

**AST MUST Produce Events:**
```elixir
# Analysis completion events
event = ElixirScope.Foundation.Events.new_event(:ast_analysis_complete, %{
  module_name: MyApp.Module,
  analysis_type: :full,
  duration_ms: 150,
  patterns_found: 3,
  complexity_score: 12,
  instrumentation_points: 15,
  correlation_id: "ast_analysis_#{UUID.uuid4()}"
})

# Memory pressure events
event = ElixirScope.Foundation.Events.new_event(:ast_memory_pressure, %{
  pressure_level: 0.85,
  trigger: :ets_table_size,
  cleanup_action: :aggressive,
  freed_bytes: 52_428_800
})

# Pattern detection events
event = ElixirScope.Foundation.Events.new_event(:ast_pattern_detected, %{
  pattern_type: :anti_pattern,
  confidence: 0.92,
  module_name: BadModule,
  function_name: :problematic_function,
  line_number: 45,
  description: "Potential N+1 query pattern detected"
})
```

### 9.2 Runtime Correlation Events

**Correlation Event Handling:**
```elixir
# AST MUST handle correlation queries from runtime events
def handle_call({:correlate_runtime_event, runtime_event}, _from, state) do
  case extract_correlation_id(runtime_event) do
    {:ok, correlation_id} ->
      case lookup_ast_node(correlation_id) do
        {:ok, ast_node} ->
          correlation = build_correlation(runtime_event, ast_node)
          {:reply, {:ok, correlation}, state}
        {:error, :not_found} ->
          {:reply, {:error, :no_ast_correlation}, state}
      end
    {:error, :no_correlation_id} ->
      {:reply, {:error, :no_correlation_possible}, state}
  end
end
```

---

## 10. Testing Contracts

### 10.1 Foundation Mock Interfaces

**AST Testing MUST Use Foundation Test Doubles:**
```elixir
defmodule ElixirScope.AST.Test.FoundationMocks do
  # Mock Foundation Config for AST tests
  defmodule MockConfig do
    @behaviour ElixirScope.Foundation.Config.Behaviour
    
    def get(path) do
      case path do
        [:ast, :memory, :pressure_thresholds] -> 
          {:ok, %{warning: 0.7, critical: 0.85, emergency: 0.95}}
        [:ast, :parser, :timeout_ms] -> 
          {:ok, 30_000}
        _ -> 
          {:error, :not_found}
      end
    end
    
    def subscribe(), do: :ok
    # ... other required callbacks
  end

  # Mock Memory Manager for pressure signal testing
  defmodule MockMemoryManager do
    def subscribe_to_pressure_signals(), do: :ok
    def register_memory_reporter(_module), do: :ok
    
    def simulate_pressure_signal(level) do
      send_to_subscribers({:memory_pressure_signal, level, %{}})
    end
  end
end
```

### 10.2 Integration Test Contracts

**Required Integration Tests:**
```elixir
defmodule ElixirScope.AST.Integration.FoundationTest do
  use ExUnit.Case
  
  test "handles Foundation config updates correctly" do
    # Test configuration change propagation
    assert :ok = Foundation.Config.update([:ast, :memory, :pressure_thresholds], new_thresholds)
    
    # Verify AST components receive and apply updates
    assert_receive {:config_updated, [:ast, :memory, :pressure_thresholds], _, ^new_thresholds}
  end
  
  test "responds to global memory pressure signals" do
    # Test memory pressure coordination
    Foundation.Infrastructure.MemoryManager.simulate_pressure(:critical)
    
    # Verify AST responds appropriately
    assert_eventually(fn -> 
      ast_memory_usage() < previous_memory_usage * 0.8
    end)
  end
  
  test "handles Foundation service circuit breaker" do
    # Simulate Foundation service circuit breaker open
    Foundation.Infrastructure.simulate_circuit_breaker_open(:config_service)
    
    # Verify AST graceful degradation
    assert {:error, %Error{type: :foundation_unavailable}} = AST.get_some_config()
  end
end
```

---

## Contract Validation

### Compliance Checklist

**AST Layer MUST:**
- [ ] Implement health check interface for all major components
- [ ] Register with Foundation Infrastructure HealthAggregator
- [ ] Report memory usage to Foundation Infrastructure MemoryManager
- [ ] Handle all Foundation Infrastructure error types gracefully
- [ ] Emit standardized telemetry events
---

## 11. Performance Optimization Contracts

### 11.1 Connection Pooling Integration

**AST HTTP Client Integration:**
```elixir
alias TideScope.Foundation.HTTPClient

# AST remote code fetching with managed connection pools
def fetch_remote_source(url, options \\ []) do
  pool_config = %{
    pool: :ast_remote_fetch,
    timeout: 30_000,
    headers: [{"User-Agent", "TideScope-AST/2.0"}],
    connect_timeout: 10_000,
    recv_timeout: 25_000
  }
  
  case HTTPClient.get(url, Map.merge(pool_config, Enum.into(options, %{}))) do
    {:ok, %{status: 200, body: body}} ->
      {:ok, body}
    {:ok, %{status: status}} when status in [404, 403] ->
      {:error, {:http_error, status}}
    {:error, %Error{type: :pool_checkout_timeout}} ->
      {:error, {:resource_unavailable, "HTTP pool exhausted"}}
    {:error, reason} ->
      {:error, {:network_error, reason}}
  end
end

# Configure HTTP pools for different AST operations
def configure_http_pools() do
  pools = [
    {:ast_remote_fetch, %{
      size: 5,
      max_size: 20,
      timeout: 30_000,
      connect_timeout: 10_000
    }},
    {:ast_package_metadata, %{
      size: 2,
      max_size: 8,
      timeout: 15_000,
      connect_timeout: 5_000
    }}
  ]
  
  Enum.each(pools, fn {pool_name, config} ->
    HTTPClient.configure_pool(pool_name, config)
  end)
end
```

### 11.2 Resource Pool Management

**AST Parser Worker Pools:**
```elixir
alias TideScope.Foundation.ResourcePool

# Managed parser worker pools for concurrent operations
def get_parser_worker(complexity \\ :normal) do
  pool_name = case complexity do
    :simple -> :ast_simple_parser_pool
    :normal -> :ast_parser_pool
    :complex -> :ast_complex_parser_pool
  end
  
  ResourcePool.checkout(
    pool_name: pool_name,
    timeout: 5000,
    max_wait_time: 30_000
  )
end

# Configure different pools for different workload types
def configure_parser_pools() do
  pools = [
    {:ast_simple_parser_pool, %{
      size: 20,
      max_size: 50,
      checkout_timeout: 1000,
      worker_module: TideScope.AST.SimpleParserWorker
    }},
    {:ast_parser_pool, %{
      size: 10,
      max_size: 25,
      checkout_timeout: 5000,
      worker_module: TideScope.AST.ParserWorker
    }},
    {:ast_complex_parser_pool, %{
      size: 5,
      max_size: 10,
      checkout_timeout: 10_000,
      worker_module: TideScope.AST.ComplexParserWorker
    }}
  ]
  
  Enum.each(pools, fn {pool_name, config} ->
    ResourcePool.configure(pool_name, config)
  end)
end
```

### 11.3 Caching Integration

**AST Cache with Foundation Memory Coordination:**
```elixir
alias TideScope.Foundation.{MemoryManager, TelemetryCollector}

# Cache with memory-aware eviction
def cache_ast(source_hash, ast, metadata \\ %{}) do
  ast_size = estimate_ast_size(ast)
  
  case MemoryManager.check_memory_availability(:ast_cache, ast_size) do
    :available ->
      cache_entry = {source_hash, ast, DateTime.utc_now(), metadata}
      :ets.insert(:ast_cache, cache_entry)
      
      TelemetryCollector.record_metrics([
        {:counter, "ast.cache.store", 1},
        {:histogram, "ast.cache.entry_size", ast_size}
      ])
      :ok
    
    :insufficient_memory ->
      # Trigger intelligent eviction
      freed_space = evict_cache_entries(:memory_pressure, ast_size)
      
      if freed_space >= ast_size do
        cache_ast(source_hash, ast, metadata)  # Retry once
      else
        {:error, :cache_full}
      end
  end
end

# Intelligent cache eviction strategy
defp evict_cache_entries(reason, required_space) do
  current_time = DateTime.utc_now()
  
  # Get all entries with access patterns
  entries = :ets.foldl(fn {hash, ast, timestamp, metadata}, acc ->
    age_seconds = DateTime.diff(current_time, timestamp)
    access_count = Map.get(metadata, :access_count, 0)
    size = estimate_ast_size(ast)
    
    # Calculate eviction priority (higher = evict first)
    priority = case reason do
      :memory_pressure -> age_seconds * 2 - access_count
      :ttl_expired -> age_seconds
      :manual -> 0
    end
    
    [{priority, hash, size} | acc]
  end, [], :ast_cache)
  
  # Sort by eviction priority and evict until we have enough space
  entries
  |> Enum.sort(fn {p1, _, _}, {p2, _, _} -> p1 >= p2 end)
  |> Enum.reduce_while(0, fn {_priority, hash, size}, freed_space ->
    if freed_space >= required_space do
      {:halt, freed_space}
    else
      :ets.delete(:ast_cache, hash)
      TelemetryCollector.increment_counter("ast.cache.eviction", %{reason: reason})
      {:cont, freed_space + size}
    end
  end)
end
```

---

## 12. Fallback and Degradation Contracts

### 12.1 Graceful Degradation Strategies

**AST Service Degradation Levels:**
```elixir
defmodule TideScope.AST.DegradationManager do
  @degradation_levels [:normal, :limited, :minimal, :emergency]
  
  def determine_degradation_level(system_health) do
    cond do
      system_health.memory_pressure > 0.9 -> :emergency
      system_health.error_rate > 0.1 -> :minimal
      system_health.response_time > 5000 -> :limited
      true -> :normal
    end
  end
  
  def apply_degradation_strategy(level, operation_type) do
    case {level, operation_type} do
      {:normal, _} ->
        :full_service
      
      {:limited, :parse} ->
        {:limited_service, %{cache_only: true, timeout: 15_000}}
      
      {:minimal, :parse} ->
        {:minimal_service, %{simplified_ast: true, no_instrumentation: true}}
      
      {:emergency, :parse} ->
        {:fallback_service, %{stub_response: true}}
      
      {:limited, :analysis} ->
        {:limited_service, %{basic_patterns_only: true}}
      
      {:minimal, :analysis} ->
        {:service_unavailable, "Analysis temporarily unavailable"}
      
      {:emergency, _} ->
        {:service_unavailable, "Service in emergency mode"}
    end
  end
end

# Fallback AST generation for emergency situations
def create_emergency_ast_stub(source_code) do
  # Generate minimal AST representation
  module_name = extract_module_name(source_code) || :UnknownModule
  
  {:defmodule, [line: 1], [
    {:__aliases__, [line: 1], [module_name]},
    [do: {:__block__, [], [
      {:def, [line: 2], [
        {:placeholder_function, [], []},
        [do: {:error, :emergency_mode}]
      ]}
    ]}]
  ]}
end
```

### 12.2 Error Recovery Patterns

**Automated Recovery Strategies:**
```elixir
defmodule TideScope.AST.RecoveryManager do
  alias TideScope.Foundation.{CircuitBreaker, MemoryManager}
  
  def attempt_operation_with_recovery(operation, context, max_retries \\ 3) do
    attempt_operation(operation, context, 0, max_retries)
  end
  
  defp attempt_operation(operation, context, attempt, max_retries) 
       when attempt < max_retries do
    
    case execute_operation(operation, context) do
      {:ok, result} ->
        # Reset any circuit breakers on success
        CircuitBreaker.record_success(context.circuit_name)
        {:ok, result}
      
      {:error, %Error{type: :memory_error}} ->
        # Trigger memory cleanup and retry
        Logger.warn("Memory error on attempt #{attempt + 1}, triggering cleanup")
        MemoryManager.trigger_cleanup(:aggressive)
        Process.sleep(1000 * (attempt + 1))  # Exponential backoff
        attempt_operation(operation, context, attempt + 1, max_retries)
      
      {:error, %Error{type: :timeout}} ->
        # Increase timeout and retry
        new_context = %{context | timeout: context.timeout * 2}
        Logger.warn("Timeout on attempt #{attempt + 1}, increasing timeout to #{new_context.timeout}")
        attempt_operation(operation, new_context, attempt + 1, max_retries)
      
      {:error, %Error{type: :circuit_breaker_open}} ->
        # Wait for circuit breaker recovery
        wait_time = CircuitBreaker.get_recovery_time(context.circuit_name)
        Logger.info("Circuit breaker open, waiting #{wait_time}ms for recovery")
        Process.sleep(wait_time)
        attempt_operation(operation, context, attempt + 1, max_retries)
      
      {:error, reason} ->
        # Non-recoverable error
        {:error, {:operation_failed, reason, attempt + 1}}
    end
  end
  
  defp attempt_operation(_operation, _context, max_retries, max_retries) do
    {:error, {:max_retries_exceeded, max_retries}}
  end
end
```

---

## 13. Resource Management Contracts

### 13.1 Dynamic Resource Allocation

**Adaptive Resource Management:**
```elixir
defmodule TideScope.AST.ResourceManager do
  alias TideScope.Foundation.{MemoryManager, ResourcePool}
  
  def allocate_resources_for_operation(operation_type, workload_size, priority) do
    base_allocation = get_base_allocation(operation_type)
    
    # Adjust allocation based on current system state
    system_load = get_current_system_load()
    adjusted_allocation = adjust_for_system_load(base_allocation, system_load)
    
    # Adjust for workload size
    workload_adjusted = adjust_for_workload(adjusted_allocation, workload_size)
    
    # Apply priority scaling
    final_allocation = apply_priority_scaling(workload_adjusted, priority)
    
    request_resources(final_allocation)
  end
  
  defp adjust_for_system_load(allocation, load) do
    scaling_factor = case load do
      l when l < 0.3 -> 1.2    # System underutilized, can allocate more
      l when l < 0.7 -> 1.0    # Normal allocation
      l when l < 0.9 -> 0.7    # High load, reduce allocation
      _ -> 0.4                 # Critical load, minimal allocation
    end
    
    %{allocation | 
      memory: round(allocation.memory * scaling_factor),
      workers: max(1, round(allocation.workers * scaling_factor)),
      timeout: round(allocation.timeout * (1 / scaling_factor))
    }
  end
  
  defp request_resources(%{memory: memory, workers: workers, timeout: timeout}) do
    with {:ok, memory_ref} <- MemoryManager.request_allocation(
           requester: self(),
           operation: :ast_dynamic_operation,
           estimated_size: memory,
           timeout: timeout
         ),
         {:ok, worker_pool} <- ResourcePool.checkout_multiple(
           :ast_dynamic_worker_pool,
           count: workers,
           timeout: timeout
         ) do
      
      {:ok, %{memory_ref: memory_ref, workers: worker_pool, timeout: timeout}}
    else
      error -> {:error, {:resource_allocation_failed, error}}
    end
  end
end
```

### 13.2 Resource Monitoring and Optimization

**Continuous Resource Optimization:**
```elixir
defmodule TideScope.AST.ResourceOptimizer do
  use GenServer
  alias TideScope.Foundation.TelemetryCollector
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Schedule periodic optimization
    schedule_optimization()
    
    {:ok, %{
      resource_usage_history: :queue.new(),
      optimization_metrics: %{},
      last_optimization: DateTime.utc_now()
    }}
  end
  
  def handle_info(:optimize_resources, state) do
    # Analyze recent resource usage patterns
    usage_patterns = analyze_usage_patterns(state.resource_usage_history)
    
    # Generate optimization recommendations
    recommendations = generate_recommendations(usage_patterns)
    
    # Apply optimizations
    optimization_results = apply_optimizations(recommendations)
    
    # Update metrics
    TelemetryCollector.record_metrics([
      {:gauge, "ast.resource_optimization.efficiency", optimization_results.efficiency},
      {:counter, "ast.resource_optimization.applied", length(recommendations)},
      {:histogram, "ast.resource_optimization.savings", optimization_results.savings}
    ])
    
    schedule_optimization()
    
    {:noreply, %{state | 
      optimization_metrics: optimization_results,
      last_optimization: DateTime.utc_now()
    }}
  end
  
  defp generate_recommendations(patterns) do
    recommendations = []
    
    # Pool size optimization
    recommendations = if patterns.avg_pool_utilization < 0.3 do
      [{:reduce_pool_size, :ast_parser_pool, patterns.optimal_pool_size} | recommendations]
    else
      recommendations
    end
    
    # Cache size optimization
    recommendations = if patterns.cache_hit_rate < 0.6 do
      [{:increase_cache_size, :ast_cache, patterns.optimal_cache_size} | recommendations]
    else
      recommendations
    end
    
    # Memory allocation optimization
    recommendations = if patterns.memory_waste > 0.2 do
      [{:optimize_memory_allocation, patterns.memory_recommendations} | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
end
```

---

## 14. Implementation Phase Contracts

### 14.1 Phase 1: Core Integration (Weeks 1-2)

**Foundation Services Integration:**
```elixir
# Phase 1 Deliverables Contract
defmodule TideScope.AST.Phase1Integration do
  @required_integrations [
    :memory_manager_basic,
    :health_reporting_basic,
    :error_handling_foundation,
    :configuration_basic,
    :telemetry_basic
  ]
  
  def verify_phase1_compliance() do
    results = Enum.map(@required_integrations, fn integration ->
      {integration, verify_integration(integration)}
    end)
    
    failures = Enum.filter(results, fn {_, result} -> result != :ok end)
    
    if Enum.empty?(failures) do
      {:ok, :phase1_complete}
    else
      {:error, {:integration_failures, failures}}
    end
  end
  
  defp verify_integration(:memory_manager_basic) do
    # Verify basic memory allocation/deallocation works
    case MemoryManager.request_allocation(
      requester: self(),
      operation: :test_allocation,
      estimated_size: 1024
    ) do
      {:ok, ref} ->
        case MemoryManager.release_allocation(ref) do
          :ok -> :ok
          error -> {:error, {:release_failed, error}}
        end
      error -> {:error, {:allocation_failed, error}}
    end
  end
  
  defp verify_integration(:health_reporting_basic) do
    # Verify health check registration and reporting
    try do
      health_status = TideScope.AST.Parser.health_check()
      case health_status do
        {:ok, %{status: _}} -> :ok
        error -> {:error, {:health_check_failed, error}}
      end
    rescue
      error -> {:error, {:health_check_exception, error}}
    end
  end
  
  # ... other verification functions
end
```

### 14.2 Phase 2: Advanced Features (Weeks 3-4)

**Advanced Integration Contract:**
```elixir
defmodule TideScope.AST.Phase2Integration do
  @advanced_features [
    :circuit_breaker_integration,
    :rate_limiting_complete,
    :telemetry_comprehensive,
    :connection_pooling,
    :resource_optimization
  ]
  
  def verify_phase2_compliance() do
    # Verify circuit breaker functionality
    verify_circuit_breaker_integration() &&
    verify_rate_limiting_complete() &&
    verify_telemetry_comprehensive() &&
    verify_connection_pooling() &&
    verify_resource_optimization()
  end
  
  defp verify_circuit_breaker_integration() do
    # Test circuit breaker configuration and fallback
    CircuitBreaker.configure(:test_ast_circuit, %{
      failure_threshold: 2,
      timeout: 1000
    })
    
    # Trigger failures to trip circuit breaker
    CircuitBreaker.call(:test_ast_circuit, fn -> {:error, :test_failure} end)
    CircuitBreaker.call(:test_ast_circuit, fn -> {:error, :test_failure} end)
    
    # Verify circuit is now open
    case CircuitBreaker.call(:test_ast_circuit, fn -> {:ok, :should_not_execute} end) do
      {:error, :circuit_open} -> true
      _ -> false
    end
  end
end
```

### 14.3 Phase 3: Optimization & Testing (Weeks 5-6)

**Production Readiness Contract:**
```elixir
defmodule TideScope.AST.ProductionReadiness do
  @performance_requirements %{
    parse_latency_p99: 500,      # milliseconds
    memory_efficiency: 0.85,     # utilization ratio
    error_rate_max: 0.01,       # 1% maximum error rate
    cache_hit_rate_min: 0.7,    # 70% minimum cache hit rate
    resource_cleanup_time: 1000  # milliseconds
  }
  
  def verify_production_readiness() do
    performance_check() &&
    resilience_check() &&
    monitoring_check() &&
    documentation_check()
  end
  
  defp performance_check() do
    # Run performance benchmarks
    parse_latencies = run_parse_performance_test()
    memory_usage = measure_memory_efficiency()
    
    parse_latencies.p99 <= @performance_requirements.parse_latency_p99 &&
    memory_usage >= @performance_requirements.memory_efficiency
  end
  
  defp resilience_check() do
    # Test failure scenarios
    memory_pressure_recovery() &&
    service_unavailable_handling() &&
    network_partition_tolerance()
  end
  
  defp monitoring_check() do
    # Verify all telemetry is working
    telemetry_events_emitted() &&
    health_checks_responsive() &&
    error_reporting_complete()
  end
end
```

---

## Contract Validation

### Enhanced Compliance Checklist

**AST Layer MUST:**
- [ ] Implement health check interface for all major components
- [ ] Register with Foundation Infrastructure HealthAggregator  
- [ ] Report memory usage to Foundation Infrastructure MemoryManager
- [ ] Handle all Foundation Infrastructure error types gracefully
- [ ] Emit standardized telemetry events with proper correlation IDs
- [ ] Respond to global memory pressure signals within 1 second
- [ ] Handle Foundation configuration updates without service interruption
- [ ] Use Foundation Error types for error propagation
- [ ] Implement graceful degradation for Foundation service failures
- [ ] Coordinate cleanup actions with global memory management
- [ ] **[NEW]** Implement circuit breaker fallback strategies for critical operations
- [ ] **[NEW]** Support multi-tier rate limiting with dynamic adjustment
- [ ] **[NEW]** Provide resource pool management for concurrent operations
- [ ] **[NEW]** Implement intelligent caching with memory-aware eviction
- [ ] **[NEW]** Support automated recovery strategies with exponential backoff
- [ ] **[NEW]** Provide comprehensive performance optimization hooks

**Foundation Layer MUST:**
- [ ] Provide reliable Configuration, Events, and Telemetry services
- [ ] Emit proper error types with actionable context
- [ ] Aggregate AST health checks correctly
- [ ] Collect and process AST telemetry events
- [ ] Coordinate global memory pressure signals
- [ ] Maintain API backward compatibility
- [ ] Support AST-specific configuration paths
- [ ] Provide circuit breaker and rate limiting services when needed
- [ ] **[NEW]** Support dynamic configuration updates with atomic propagation
- [ ] **[NEW]** Provide connection pooling and resource management APIs
- [ ] **[NEW]** Support memory allocation quotas and priority scheduling
- [ ] **[NEW]** Provide performance monitoring and optimization APIs
- [ ] **[NEW]** Support automated resource scaling based on system load

### Performance Requirements

**Response Time Guarantees:**
- Configuration updates: < 100ms propagation time
- Memory pressure response: < 1 second
- Health check execution: < 50ms per component
- Telemetry event emission: < 1ms overhead per event
- Circuit breaker state changes: < 10ms
- Rate limit checks: < 5ms per request

**Throughput Requirements:**
- Telemetry events: > 10,000 events/second
- Memory allocations: > 1,000 allocations/second  
- Configuration reads: > 5,000 reads/second
- Health checks: > 100 checks/second per component

**Resource Utilization Limits:**
- Foundation API overhead: < 5% of total CPU usage
- Memory management overhead: < 2% of total memory
- Network connection pools: < 1% of available connections

---

**Contract Version:** 2.0  
**Effective Date:** June 4, 2025  
**Review Cycle:** Monthly  
**Breaking Change Policy:** Major version bump required  
**Performance Validation Required:** Yes  
**Production Readiness Certification:** Required before deployment 