# AST Layer Foundation API Utilization Guide - Enhanced

**Document Version:** 2.0.0  
**Date:** June 4, 2025 (Enhanced May 2025)  
**Status:** Implementation Ready  
**Enhancement Source:** Foundation-AST Programmatic Contract v1.0

## Table of Contents

1. [Overview](#overview)
2. [Foundation API Integration Architecture](#foundation-api-integration-architecture)
3. [Standardized Error Handling Contracts](#standardized-error-handling-contracts)
4. [Health Reporting & Telemetry Contracts](#health-reporting--telemetry-contracts)
5. [Memory Management Coordination](#memory-management-coordination)
6. [Rate Limiting & Circuit Breaking](#rate-limiting--circuit-breaking)
7. [Configuration Management Schema](#configuration-management-schema)
8. [API Compliance & Validation](#api-compliance--validation)
9. [Contract Testing Patterns](#contract-testing-patterns)
10. [Implementation Phases](#implementation-phases)

## Overview

This enhanced document provides the definitive guide for AST Layer integration with the Foundation API, incorporating exact programmatic contracts, standardized interfaces, and compliance requirements derived from the Foundation-AST Programmatic Contract specification.

### Enhanced Integration Points

- **Standardized Error Contracts**: Exact error type handling for Foundation Infrastructure errors
- **Health Check Compliance**: Mandatory health check interface implementation
- **Memory Coordination Protocol**: Precise memory management coordination patterns
- **Telemetry Event Specifications**: Exact telemetry event naming and payload contracts
- **Configuration Schema Compliance**: Complete configuration path and structure requirements
- **API Contract Validation**: Comprehensive compliance testing and validation

## Foundation API Integration Architecture

### Required Behaviour Implementations

```elixir
# AST Components MUST implement these behaviours
defmodule TideScope.AST.{ComponentName} do
  use GenServer
  
  # Mandatory behaviours for Foundation integration
  @behaviour ElixirScope.Foundation.HealthCheckable
  @behaviour ElixirScope.Foundation.Infrastructure.MemoryReporter
  @behaviour ElixirScope.Foundation.TelemetrySource
  
  # Foundation API Integration (Enhanced)
  alias ElixirScope.Foundation.{Config, Events, Telemetry, Error}
  alias ElixirScope.Foundation.Infrastructure.{
    MemoryManager,
    HealthAggregator,
    PerformanceMonitor,
    CircuitBreakerWrapper,
    RateLimiter
  }
end
```

### Component Registration Requirements

```elixir
# All AST components MUST register with Foundation Infrastructure
def start_link(opts) do
  {:ok, pid} = GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  
  # Required registrations
  :ok = HealthAggregator.register_health_check_source(
    component_name(),
    {__MODULE__, :health_check, []},
    interval_ms: health_check_interval()
  )
  
  :ok = MemoryManager.register_memory_reporter(__MODULE__)
  
  {:ok, pid}
end
```

## Standardized Error Handling Contracts

### Foundation Infrastructure Error Types (MANDATORY)

AST Layer MUST handle these exact error types:

```elixir
defmodule TideScope.AST.ErrorHandler do
  alias ElixirScope.Foundation.Error
  
  def handle_foundation_error({:error, %Error{} = error}) do
    case error.type do
      :circuit_breaker_open ->
        handle_circuit_breaker_error(error)
      :rate_limited ->
        handle_rate_limit_error(error)
      :pool_checkout_timeout ->
        handle_pool_timeout_error(error)
      :service_unavailable ->
        handle_service_unavailable_error(error)
      _ ->
        handle_unknown_foundation_error(error)
    end
  end

  # Circuit Breaker Error Contract
  defp handle_circuit_breaker_error(%Error{
    type: :circuit_breaker_open,
    context: %{
      fuse_name: fuse_name,
      failure_count: count,
      next_retry_time: retry_time
    }
  } = error) do
    Logger.warn("Foundation circuit breaker open: #{fuse_name}, failures: #{count}")
    
    # AST-specific graceful degradation
    case fuse_name do
      :config_service -> use_cached_config()
      :event_store -> queue_events_locally()
      _ -> {:error, Error.new(:foundation_unavailable, 
            "Foundation service temporarily unavailable", 
            %{foundation_error: error, retry_after: retry_time})}
    end
  end

  # Rate Limit Error Contract  
  defp handle_rate_limit_error(%Error{
    type: :rate_limited,
    context: %{
      rule_name: rule,
      retry_after_ms: delay,
      current_count: count,
      limit: limit
    }
  } = error) do
    Logger.info("Foundation service rate limited: #{rule}, #{count}/#{limit}, retry in #{delay}ms")
    
    # Implement backoff strategy
    schedule_retry(delay)
    
    {:error, Error.new(:temporarily_unavailable,
      "Service temporarily rate limited",
      %{foundation_error: error, retry_after_ms: delay, should_retry: true})}
  end

  # Pool Timeout Error Contract
  defp handle_pool_timeout_error(%Error{
    type: :pool_checkout_timeout,
    context: %{
      pool_name: pool,
      timeout_ms: timeout,
      current_pool_size: size,
      checked_out: checked_out
    }
  } = error) do
    Logger.warn("Foundation pool timeout: #{pool}, #{checked_out}/#{size} workers busy")
    
    # Pool-specific handling
    {:error, Error.new(:resource_unavailable,
      "Foundation resource pool exhausted",
      %{foundation_error: error, pool_status: %{size: size, busy: checked_out}})}
  end
end
```

## Health Reporting & Telemetry Contracts

### Mandatory Health Check Interface

```elixir
defmodule TideScope.AST.Repository.Core do
  @behaviour ElixirScope.Foundation.HealthCheckable

  # EXACT interface compliance required
  @impl ElixirScope.Foundation.HealthCheckable
  def health_check() do
    case get_component_status() do
      {:ok, stats} when stats.error_count < 10 ->
        {:ok, %{
          status: :healthy,
          details: %{
            ets_tables: stats.table_count,
            memory_usage_mb: stats.memory_mb,
            active_operations: stats.active_ops,
            queue_depth: stats.queue_depth,
            error_count: stats.error_count,
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
            active_operations: stats.active_ops,
            queue_depth: stats.queue_depth,
            error_count: stats.error_count,
            last_error: stats.last_error,
            uptime_seconds: stats.uptime,
            degradation_reason: determine_degradation_reason(stats)
          }
        }}
      
      {:error, reason} ->
        {:error, %{
          status: :critical,
          reason: reason,
          timestamp: DateTime.utc_now(),
          component: component_name()
        }}
    end
  end
end
```

### Standardized Telemetry Event Contracts

```elixir
defmodule TideScope.AST.TelemetryReporter do
  alias ElixirScope.Foundation.Telemetry
  
  # EXACT telemetry event specifications (MANDATORY)
  
  # Parser Events
  def report_parse_complete(duration_us, file_size, result) do
    :ok = Telemetry.execute(
      [:elixir_scope, :ast, :parser, :parse_file_duration],
      %{
        duration_microseconds: duration_us,
        file_size_bytes: file_size,
        result: (if match?({:ok, _}, result), do: :success, else: :error)
      },
      %{
        parser_version: get_parser_version(),
        file_type: detect_file_type(file_size)
      }
    )
  end

  # Repository Events
  def report_module_stored(module_name, storage_duration, module_size) do
    :ok = Telemetry.execute(
      [:elixir_scope, :ast, :repository, :module_stored],
      %{
        storage_duration_microseconds: storage_duration,
        module_size_bytes: module_size
      },
      %{
        module_name: module_name,
        table_name: get_storage_table(module_name)
      }
    )
  end

  # Memory Events (coordinated with Foundation)
  def report_memory_pressure_change(old_level, new_level, trigger) do
    :ok = Telemetry.execute(
      [:elixir_scope, :ast, :memory, :pressure_level_changed],
      %{
        old_level: old_level,
        new_level: new_level,
        total_memory_bytes: get_total_memory_usage()
      },
      %{
        trigger: trigger, # :local | :global
        cleanup_triggered: new_level > old_level
      }
    )
  end

  # Query Events  
  def report_query_rate_limited(query_complexity, retry_after_ms) do
    :ok = Telemetry.execute(
      [:elixir_scope, :ast, :query, :rate_limited],
      %{retry_after_ms: retry_after_ms},
      %{
        query_complexity: query_complexity,
        client_pid: inspect(self())
      }
    )
  end
end
```

## Memory Management Coordination

### Enhanced Memory Reporter Implementation

```elixir
defmodule TideScope.AST.Repository.MemoryManager.Monitor do
  @behaviour ElixirScope.Foundation.Infrastructure.MemoryReporter

  # EXACT interface compliance
  @impl ElixirScope.Foundation.Infrastructure.MemoryReporter
  def report_memory_usage() do
    ets_usage = calculate_ets_memory_usage()
    cache_usage = calculate_cache_memory_usage()
    buffer_usage = calculate_buffer_memory_usage()
    
    {:ok, %{
      component: :ast_layer,
      total_bytes: ets_usage + cache_usage + buffer_usage,
      breakdown: %{
        ets_tables: ets_usage,
        pattern_caches: get_pattern_cache_size(),
        query_caches: get_query_cache_size(),
        correlation_index: get_correlation_memory(),
        file_buffers: buffer_usage,
        temporary_storage: get_temp_storage_size()
      },
      pressure_level: calculate_local_pressure_level(),
      last_cleanup: get_last_cleanup_timestamp(),
      cleanup_strategy: get_current_cleanup_strategy()
    }}
  end

  # Enhanced pressure signal handling
  @impl ElixirScope.Foundation.Infrastructure.MemoryReporter
  def handle_pressure_signal(pressure_level) when pressure_level in [:low, :medium, :high, :critical] do
    Logger.info("Received global memory pressure signal: #{pressure_level}")
    
    # Coordinate local and global pressure
    local_pressure = get_local_pressure_level()
    effective_pressure = max_pressure_level(local_pressure, pressure_level)
    
    case effective_pressure do
      :low -> 
        :ok
      :medium -> 
        spawn(fn -> trigger_gentle_cleanup() end)
      :high -> 
        spawn(fn -> trigger_aggressive_cleanup() end)
      :critical -> 
        # Immediate synchronous cleanup for critical pressure
        trigger_emergency_cleanup()
    end
    
    # Report pressure response
    TelemetryReporter.report_memory_pressure_change(local_pressure, effective_pressure, :global)
  end

  # Pressure coordination logic
  defp max_pressure_level(local, global) do
    levels = %{low: 1, medium: 2, high: 3, critical: 4}
    
    max_level = max(levels[local], levels[global])
    
    Enum.find(levels, fn {_level, value} -> value == max_level end)
    |> elem(0)
  end
end
```

## Rate Limiting & Circuit Breaking

### Enhanced Query Protection

```elixir
defmodule TideScope.AST.Querying.ProtectedExecutor do
  alias ElixirScope.Foundation.Infrastructure.{RateLimiter, CircuitBreakerWrapper}
  alias ElixirScope.Foundation.Error
  
  def execute_query(repo, query) do
    client_id = get_client_id()
    query_complexity = assess_query_complexity(query)
    
    # Apply rate limiting based on complexity
    with :ok <- check_rate_limits(client_id, query_complexity),
         {:ok, result} <- execute_with_circuit_protection(repo, query) do
      {:ok, result}
    else
      {:error, %Error{type: :rate_limited} = error} ->
        TelemetryReporter.report_query_rate_limited(query_complexity, 
          error.context[:retry_after_ms])
        {:error, error}
      
      {:error, %Error{type: :circuit_breaker_open} = error} ->
        Logger.warn("Query circuit breaker open")
        {:error, error}
      
      error ->
        error
    end
  end

  defp check_rate_limits(client_id, :high) do
    # High complexity queries have stricter limits
    RateLimiter.check_rate(
      {:ast_complex_query, client_id}, 
      :ast_complex_queries_per_minute, 
      1
    )
  end

  defp check_rate_limits(client_id, _complexity) do
    # Standard queries
    RateLimiter.check_rate(
      {:ast_query, client_id}, 
      :ast_queries_per_minute, 
      1
    )
  end

  defp execute_with_circuit_protection(repo, %{complexity: :high} = query) do
    # Protect complex queries with circuit breaker
    CircuitBreakerWrapper.execute(:ast_complex_queries, fn ->
      do_execute_query(repo, query)
    end, 30_000)
  end

  defp execute_with_circuit_protection(repo, query) do
    # Simple queries bypass circuit breaker
    do_execute_query(repo, query)
  end
end
```

## Configuration Management Schema

### Complete AST Configuration Contract

```elixir
defmodule TideScope.AST.ConfigSchema do
  # EXACT configuration schema (MANDATORY compliance)
  
  def required_config_schema() do
    %{
      ast: %{
        memory: %{
          pressure_thresholds: %{
            warning: {:float, 0.7, "Memory usage warning threshold"},
            critical: {:float, 0.85, "Memory usage critical threshold"},  
            emergency: {:float, 0.95, "Memory usage emergency threshold"}
          },
          cleanup_strategies: %{
            gentle: {:list, [:clear_query_cache], "Gentle cleanup actions"},
            aggressive: {:list, [:clear_query_cache, :compress_cold_data], "Aggressive cleanup"},
            emergency: {:list, [:clear_all_caches, :force_gc], "Emergency cleanup"}
          },
          coordination: %{
            report_interval_ms: {:integer, 30_000, "Memory usage reporting interval"},
            pressure_response_timeout_ms: {:integer, 1_000, "Max time to respond to pressure"}
          }
        },
        parser: %{
          timeout_ms: {:integer, 30_000, "Parser operation timeout"},
          max_file_size_bytes: {:integer, 10_485_760, "Maximum parseable file size"},
          instrumentation_enabled: {:boolean, true, "Enable instrumentation injection"},
          circuit_breaker: %{
            enabled: {:boolean, true, "Enable parser circuit breaker"},
            failure_threshold: {:integer, 5, "Failures before circuit opens"},
            reset_timeout_ms: {:integer, 60_000, "Circuit breaker reset timeout"}
          }
        },
        pattern_matcher: %{
          timeout_ms: {:integer, 5_000, "Pattern matching timeout"},
          confidence_threshold: {:float, 0.7, "Minimum confidence for pattern matches"},
          max_concurrent_analyses: {:integer, 10, "Maximum concurrent pattern analyses"},
          cache_enabled: {:boolean, true, "Enable pattern result caching"}
        },
        query: %{
          concurrent_limit: {:integer, 50, "Maximum concurrent queries"},
          complex_query_timeout_ms: {:integer, 30_000, "Complex query timeout"},
          cache_ttl_ms: {:integer, 300_000, "Query result cache TTL"},
          rate_limiting: %{
            enabled: {:boolean, true, "Enable query rate limiting"},
            queries_per_minute: {:integer, 100, "Standard queries per minute per client"},
            complex_queries_per_minute: {:integer, 10, "Complex queries per minute per client"}
          }
        },
        repository: %{
          ets_tables: %{
            read_concurrency: {:boolean, true, "Enable ETS read concurrency"},
            write_concurrency: {:boolean, true, "Enable ETS write concurrency"},
            compressed: {:boolean, false, "Enable ETS table compression"}
          },
          correlation_index_size_limit: {:integer, 1_000_000, "Max correlation index entries"},
          health_check_interval_ms: {:integer, 30_000, "Health check reporting interval"}
        },
        telemetry: %{
          enabled: {:boolean, true, "Enable telemetry reporting"},
          batch_size: {:integer, 100, "Telemetry event batch size"},
          flush_interval_ms: {:integer, 5_000, "Telemetry flush interval"}
        }
      }
    }
  end

  # Configuration validation
  def validate_config(config) do
    schema = required_config_schema()
    validate_against_schema(config, schema)
  end

  # Configuration update handler
  def handle_config_update(path, old_value, new_value) do
    case path do
      [:ast, :memory, :pressure_thresholds] ->
        update_memory_thresholds(new_value)
      
      [:ast, :query, :concurrent_limit] ->
        update_query_limits(new_value)
      
      [:ast, :parser, :circuit_breaker] ->
        reconfigure_parser_circuit_breaker(new_value)
      
      _ ->
        Logger.info("Configuration updated: #{inspect(path)}")
    end
  end
end
```

## API Compliance & Validation

### Compliance Checklist Implementation

```elixir
defmodule TideScope.AST.ComplianceValidator do
  @moduledoc """
  Validates AST Layer compliance with Foundation API contracts
  """

  def validate_full_compliance() do
    compliance_results = %{
      health_checks: validate_health_check_compliance(),
      memory_reporting: validate_memory_reporting_compliance(),
      error_handling: validate_error_handling_compliance(),
      telemetry: validate_telemetry_compliance(),
      configuration: validate_configuration_compliance()
    }
    
    overall_compliance = Enum.all?(compliance_results, fn {_area, result} -> 
      result == :compliant 
    end)
    
    {overall_compliance, compliance_results}
  end

  defp validate_health_check_compliance() do
    required_components = [
      TideScope.AST.Repository.Core,
      TideScope.AST.Querying.Executor,
      TideScope.AST.Analysis.PatternMatcher.Core,
      TideScope.AST.Repository.MemoryManager.Monitor,
      TideScope.AST.Repository.Synchronization.FileWatcher
    ]
    
    all_compliant = Enum.all?(required_components, fn component ->
      Code.ensure_loaded?(component) and
      function_exported?(component, :health_check, 0) and
      implements_health_checkable_behaviour?(component)
    end)
    
    if all_compliant, do: :compliant, else: :non_compliant
  end

  defp validate_error_handling_compliance() do
    # Test error handling for all Foundation Infrastructure error types
    required_error_types = [
      :circuit_breaker_open,
      :rate_limited, 
      :pool_checkout_timeout,
      :service_unavailable
    ]
    
    # Implementation would test actual error handling
    :compliant # Simplified for example
  end

  # Additional validation methods...
end
```

## Contract Testing Patterns

### Foundation Mock Interfaces

```elixir
defmodule TideScope.AST.Test.FoundationMocks do
  @moduledoc """
  Exact mock interfaces for Foundation services testing
  """

  defmodule MockMemoryManager do
    @behaviour ElixirScope.Foundation.Infrastructure.MemoryManager.Behaviour
    
    def subscribe_to_pressure_signals(), do: :ok
    def register_memory_reporter(_module), do: :ok
    
    def simulate_pressure_signal(level) when level in [:low, :medium, :high, :critical] do
      Process.send_after(self(), {:memory_pressure_signal, level, %{}}, 100)
    end
    
    def get_global_pressure_level(), do: :low
  end

  defmodule MockCircuitBreaker do
    def execute(fuse_name, operation, timeout \\ 5000) do
      case get_circuit_state(fuse_name) do
        :closed -> operation.()
        :open -> {:error, Error.new(:circuit_breaker_open, "Circuit breaker is open")}
        :half_open -> operation.() # Simplified
      end
    end
    
    defp get_circuit_state(_fuse_name), do: :closed # Configurable in tests
  end
end
```

### Integration Test Contracts

```elixir
defmodule TideScope.AST.IntegrationContractTest do
  use ExUnit.Case
  
  describe "Foundation API Contract Compliance" do
    test "health check interface compliance" do
      components = [
        TideScope.AST.Repository.Core,
        TideScope.AST.Querying.Executor
      ]
      
      for component <- components do
        health_result = component.health_check()
        
        # Validate exact contract compliance
        assert {:ok, %{status: status, details: details}} = health_result
        assert status in [:healthy, :degraded]
        assert is_map(details)
        assert Map.has_key?(details, :memory_usage_mb)
        assert Map.has_key?(details, :uptime_seconds)
      end
    end
    
    test "memory pressure response compliance" do
      component = TideScope.AST.Repository.MemoryManager.Monitor
      
      # Test all required pressure levels
      for level <- [:low, :medium, :high, :critical] do
        start_time = System.monotonic_time(:millisecond)
        
        :ok = component.handle_pressure_signal(level)
        
        response_time = System.monotonic_time(:millisecond) - start_time
        
        # Contract requires response within 1 second
        assert response_time < 1000, "Pressure response took #{response_time}ms (max: 1000ms)"
      end
    end
    
    test "error handling contract compliance" do
      # Test handling of all Foundation Infrastructure error types
      foundation_errors = [
        Error.new(:circuit_breaker_open, "Circuit breaker open", %{fuse_name: :test}),
        Error.new(:rate_limited, "Rate limited", %{retry_after_ms: 5000}),
        Error.new(:pool_checkout_timeout, "Pool timeout", %{pool_name: :test}),
        Error.new(:service_unavailable, "Service unavailable", %{service: :config})
      ]
      
      for error <- foundation_errors do
        result = TideScope.AST.ErrorHandler.handle_foundation_error({:error, error})
        
        # Verify graceful handling (no crashes, proper error propagation)
        assert {:error, %Error{}} = result
        refute result == {:error, error} # Should be transformed/wrapped
      end
    end
  end
end
```

## Implementation Phases

### Enhanced Phase 1: Contract Compliance (Weeks 1-2)
- **Health Check Interface**: Implement exact health check contract for all components
- **Error Handling**: Implement all Foundation Infrastructure error type handling
- **Memory Reporter**: Implement exact memory reporting interface
- **Basic Telemetry**: Implement core telemetry event specifications

### Enhanced Phase 2: Advanced Integration (Weeks 3-4)  
- **Memory Coordination**: Full integration with Foundation Infrastructure MemoryManager
- **Circuit Breaker Integration**: Selective circuit breaker usage for file operations
- **Rate Limiting**: Query protection with Foundation Infrastructure RateLimiter
- **Configuration Schema**: Complete configuration schema compliance

### Enhanced Phase 3: Validation & Optimization (Weeks 5-6)
- **Contract Testing**: Comprehensive Foundation API contract testing
- **Compliance Validation**: Automated compliance checking
- **Performance Optimization**: Minimize Foundation integration overhead
- **Documentation**: Complete contract documentation and examples

---

**Document Version:** 2.0.0 (Enhanced with Programmatic Contract Insights)  
**Contract Compliance:** Full Foundation-AST Programmatic Contract v1.0  
**Review Cycle:** Monthly with contract validation  
**Last Enhanced:** May 2025 