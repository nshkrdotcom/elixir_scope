# Foundation Infrastructure Patterns - Implementation Roadmap

**Version:** 1.0  
**Date:** June 2025  
**Status:** Implementation Guide  
**Priority:** IMPLEMENT NOW - Before AST Layer Development

## Executive Summary

The Foundation layer is architecturally complete but requires critical infrastructure patterns to support production workloads and prepare for AST layer integration. This document provides comprehensive implementation guidance for 6 essential infrastructure patterns that deliver immediate value and establish frameworks for higher layers.

**Why Now?** The AST layer will add significant memory pressure, API request volume, and external service dependencies. These infrastructure patterns must be in place BEFORE AST development to ensure system stability and provide proven patterns for higher layers.

---

## Implementation Priorities

### Phase 1 (Week 1): Core Reliability 
1. **Circuit Breaker Framework** - Foundation service protection
2. **Memory Management Framework** - Critical before AST memory pressure

### Phase 2 (Week 2): Production Readiness
3. **Enhanced Health Check System** - Production deployment readiness  
4. **Performance Monitoring Infrastructure** - Baseline metrics establishment

### Phase 3 (Week 3): AST Preparation
5. **Rate Limiting Framework** - Essential for AST APIs
6. **Connection Pooling Infrastructure** - External service optimization

---

## 1. Circuit Breaker Framework

### Strategic Importance
- **Problem**: Foundation services can cascade failures across the system
- **Solution**: Automatic failure detection and recovery with graceful degradation
- **AST Benefit**: Establishes resilience patterns for AST parser/analyzer services

### Architecture Design

#### Core Circuit Breaker GenServer
```elixir
defmodule ElixirScope.Foundation.Infrastructure.CircuitBreaker do
  use GenServer
  
  @type state :: :closed | :open | :half_open
  @type circuit_config :: %{
    failure_threshold: pos_integer(),
    reset_timeout: pos_integer(),
    call_timeout: pos_integer(),
    monitor_window: pos_integer()
  }
  
  @type circuit_stats :: %{
    failure_count: non_neg_integer(),
    success_count: non_neg_integer(),
    last_failure_time: DateTime.t() | nil,
    state_changes: non_neg_integer()
  }
```

#### Service Integration Pattern
```elixir
defmodule ElixirScope.Foundation.Services.ProtectedConfigServer do
  use ElixirScope.Foundation.Infrastructure.CircuitBreaker.Protectable
  
  # Automatic circuit breaker wrapping for all public functions
  @circuit_config %{
    failure_threshold: 5,
    reset_timeout: 30_000,
    call_timeout: 5_000,
    monitor_window: 60_000
  }
  
  protected_function :get, fallback: &fallback_get/1
  protected_function :update, fallback: &fallback_update/2
  
  defp fallback_get(_path), do: {:error, :service_circuit_open}
  defp fallback_update(_path, _value), do: {:error, :service_circuit_open}
end
```

#### Registry Integration
```elixir
defmodule ElixirScope.Foundation.Infrastructure.CircuitBreakerRegistry do
  @spec register_circuit(namespace(), atom(), circuit_config()) :: :ok
  def register_circuit(namespace, service_name, config) do
    circuit_name = circuit_name(namespace, service_name)
    ProcessRegistry.register(namespace, circuit_name, self())
    CircuitBreaker.start_link([service: service_name, config: config, namespace: namespace])
  end
  
  @spec check_circuit(namespace(), atom()) :: :ok | {:error, :circuit_open}
  def check_circuit(namespace, service_name) do
    case ProcessRegistry.lookup(namespace, circuit_name(namespace, service_name)) do
      {:ok, pid} -> CircuitBreaker.check_state(pid)
      :error -> :ok  # No circuit breaker means allow
    end
  end
end
```

### Implementation Details

#### State Machine Implementation
```elixir
# Circuit Breaker State Transitions
def handle_call({:execute, operation}, _from, %{state: :closed} = circuit_state) do
  case safe_execute(operation, circuit_state.config.call_timeout) do
    {:ok, result} -> 
      new_state = record_success(circuit_state)
      {:reply, {:ok, result}, new_state}
    {:error, reason} ->
      new_state = record_failure(circuit_state)
      new_state = maybe_trip_circuit(new_state)
      {:reply, {:error, reason}, new_state}
  end
end

def handle_call({:execute, _operation}, _from, %{state: :open} = circuit_state) do
  if should_attempt_reset?(circuit_state) do
    {:reply, {:error, :circuit_open}, %{circuit_state | state: :half_open}}
  else
    {:reply, {:error, :circuit_open}, circuit_state}
  end
end
```

#### Telemetry Integration
```elixir
defp emit_circuit_telemetry(service, state_change, stats) do
  TelemetryService.execute(
    [:foundation, :circuit_breaker, state_change],
    %{
      failure_count: stats.failure_count,
      success_count: stats.success_count
    },
    %{service: service, namespace: stats.namespace}
  )
end
```

### Testing Strategy
```elixir
defmodule CircuitBreakerTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  
  test "circuit opens after failure threshold", %{namespace: namespace} do
    config = %{failure_threshold: 3, reset_timeout: 1000}
    {:ok, _} = CircuitBreaker.start_link([service: :test_service, config: config, namespace: namespace])
    
    # Trigger failures
    Enum.each(1..3, fn _ ->
      assert {:error, _} = CircuitBreaker.execute(namespace, :test_service, fn -> {:error, :test} end)
    end)
    
    # Circuit should be open
    assert {:error, :circuit_open} = CircuitBreaker.execute(namespace, :test_service, fn -> {:ok, :test} end)
  end
end
```

---

## 2. Memory Management Framework

### Strategic Importance
- **Problem**: Elixir processes can consume unbounded memory without proper management
- **Solution**: Automatic memory monitoring, cleanup, and pressure relief
- **AST Benefit**: Critical for AST parsing which creates large in-memory structures

### Architecture Design

#### Memory Monitor GenServer
```elixir
defmodule ElixirScope.Foundation.Infrastructure.MemoryManager do
  use GenServer
  
  @type memory_stats :: %{
    total_memory: non_neg_integer(),
    process_memory: non_neg_integer(),
    system_memory: non_neg_integer(),
    threshold_percentage: float(),
    pressure_level: :low | :medium | :high | :critical
  }
  
  @type memory_config :: %{
    check_interval: pos_integer(),
    warning_threshold: float(),
    critical_threshold: float(),
    cleanup_strategies: [cleanup_strategy()],
    pressure_relief_enabled: boolean()
  }
```

#### Process Memory Tracking
```elixir
defmodule ElixirScope.Foundation.Infrastructure.ProcessMemoryTracker do
  @spec track_process(pid(), atom()) :: :ok
  def track_process(pid, service_name) do
    :ets.insert(:process_memory_table, {pid, service_name, :erlang.process_info(pid, :memory)})
    Process.monitor(pid)
  end
  
  @spec get_memory_report(namespace()) :: memory_report()
  def get_memory_report(namespace) do
    processes = ServiceRegistry.list_services(namespace)
    
    Enum.map(processes, fn service ->
      {:ok, pid} = ServiceRegistry.lookup(namespace, service)
      {service, :erlang.process_info(pid, :memory)}
    end)
  end
end
```

#### Automatic Cleanup Strategies
```elixir
defmodule ElixirScope.Foundation.Infrastructure.MemoryCleanup do
  @callback cleanup(namespace(), service_name(), cleanup_options()) :: :ok | {:error, term()}
  
  defmodule EventStoreCleanup do
    @behaviour ElixirScope.Foundation.Infrastructure.MemoryCleanup
    
    def cleanup(namespace, :event_store, opts) do
      retention_hours = Keyword.get(opts, :retention_hours, 24)
      cutoff_time = DateTime.add(DateTime.utc_now(), -retention_hours * 3600, :second)
      
      EventStore.cleanup_events_before(namespace, cutoff_time)
    end
  end
  
  defmodule ConfigCacheCleanup do
    @behaviour ElixirScope.Foundation.Infrastructure.MemoryCleanup
    
    def cleanup(namespace, :config_server, _opts) do
      ConfigServer.clear_cache(namespace)
    end
  end
end
```

### Implementation Details

#### Memory Pressure Detection
```elixir
def handle_info(:check_memory, %{config: config} = state) do
  current_stats = collect_memory_stats()
  pressure_level = calculate_pressure_level(current_stats, config)
  
  new_state = %{state | 
    current_stats: current_stats,
    pressure_level: pressure_level,
    last_check: DateTime.utc_now()
  }
  
  case pressure_level do
    :critical -> trigger_emergency_cleanup(new_state)
    :high -> trigger_proactive_cleanup(new_state)
    :medium -> emit_warning_telemetry(new_state)
    :low -> emit_normal_telemetry(new_state)
  end
  
  schedule_next_check(config.check_interval)
  {:noreply, new_state}
end
```

#### Integration with Services
```elixir
defmodule ElixirScope.Foundation.Services.MemoryAwareEventStore do
  use GenServer
  
  def handle_call({:store, event}, _from, state) do
    case MemoryManager.check_pressure(state.namespace) do
      :critical -> 
        {:reply, {:error, :memory_pressure_critical}, state}
      pressure_level when pressure_level in [:high, :medium] ->
        # Store but trigger background cleanup
        result = store_event(event, state)
        MemoryManager.request_cleanup(state.namespace, :event_store, priority: pressure_level)
        {:reply, result, state}
      :low ->
        result = store_event(event, state)
        {:reply, result, state}
    end
  end
end
```

### Testing Strategy
```elixir
defmodule MemoryManagementTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  
  test "memory pressure triggers cleanup", %{namespace: namespace} do
    config = %{warning_threshold: 0.1, critical_threshold: 0.2}
    {:ok, _} = MemoryManager.start_link([namespace: namespace, config: config])
    
    # Simulate memory pressure
    MemoryManager.simulate_pressure(namespace, :high)
    
    # Verify cleanup was triggered
    assert_receive {:memory_cleanup_triggered, :event_store}, 1000
  end
end
```

---

## 3. Enhanced Health Check System

### Strategic Importance
- **Problem**: Current health checks are basic process-alive checks
- **Solution**: Deep health validation with dependency checking and recovery
- **AST Benefit**: Establishes comprehensive monitoring patterns for complex AST services

### Architecture Design

#### Health Check Framework
```elixir
defmodule ElixirScope.Foundation.Infrastructure.HealthCheck do
  @type health_status :: :healthy | :degraded | :unhealthy
  @type health_result :: %{
    status: health_status(),
    checks: [check_result()],
    overall_score: float(),
    timestamp: DateTime.t(),
    duration_ms: non_neg_integer()
  }
  
  @type check_result :: %{
    name: atom(),
    status: health_status(),
    message: binary(),
    metadata: map(),
    duration_ms: non_neg_integer()
  }
```

#### Service Health Check Behaviors
```elixir
defmodule ElixirScope.Foundation.Infrastructure.HealthCheckable do
  @callback deep_health_check() :: health_result()
  @callback dependency_health_check() :: [check_result()]
  @callback self_diagnostic() :: check_result()
  
  defmacro __using__(_opts) do
    quote do
      @behaviour ElixirScope.Foundation.Infrastructure.HealthCheckable
      
      def health_check() do
        start_time = System.monotonic_time(:millisecond)
        
        checks = [
          self_diagnostic(),
          dependency_health_check()
        ] |> List.flatten()
        
        duration = System.monotonic_time(:millisecond) - start_time
        
        %{
          status: calculate_overall_status(checks),
          checks: checks,
          overall_score: calculate_health_score(checks),
          timestamp: DateTime.utc_now(),
          duration_ms: duration
        }
      end
      
      defp calculate_overall_status(checks) do
        case Enum.group_by(checks, & &1.status) do
          %{unhealthy: _} -> :unhealthy
          %{degraded: _} -> :degraded
          _ -> :healthy
        end
      end
    end
  end
end
```

#### Service-Specific Implementations
```elixir
defmodule ElixirScope.Foundation.Services.ConfigServerHealthCheck do
  use ElixirScope.Foundation.Infrastructure.HealthCheckable
  
  def deep_health_check() do
    health_check()
  end
  
  def dependency_health_check() do
    [
      check_registry_connectivity(),
      check_configuration_validity(),
      check_subscriber_health()
    ]
  end
  
  def self_diagnostic() do
    %{
      name: :config_server_self_check,
      status: :healthy,
      message: "ConfigServer operational",
      metadata: %{
        updates_count: get_updates_count(),
        subscribers_count: get_subscribers_count(),
        uptime_ms: get_uptime_ms()
      },
      duration_ms: 1
    }
  end
  
  defp check_registry_connectivity() do
    case ProcessRegistry.stats() do
      %{total_services: count} when count > 0 ->
        %{name: :registry_connectivity, status: :healthy, message: "Registry accessible", metadata: %{services: count}, duration_ms: 2}
      _ ->
        %{name: :registry_connectivity, status: :unhealthy, message: "Registry unavailable", metadata: %{}, duration_ms: 2}
    end
  end
end
```

### Implementation Details

#### Health Check Aggregation Service
```elixir
defmodule ElixirScope.Foundation.Infrastructure.HealthAggregator do
  use GenServer
  
  def handle_call({:system_health, namespace}, _from, state) do
    services = ServiceRegistry.list_services(namespace)
    
    health_results = Enum.map(services, fn service ->
      case ServiceRegistry.lookup(namespace, service) do
        {:ok, pid} ->
          try do
            result = GenServer.call(pid, :deep_health_check, 10_000)
            {service, result}
          catch
            :exit, {:timeout, _} ->
              {service, %{status: :unhealthy, message: "Health check timeout"}}
          end
        {:error, _} ->
          {service, %{status: :unhealthy, message: "Service unavailable"}}
      end
    end)
    
    system_health = calculate_system_health(health_results)
    {:reply, system_health, state}
  end
  
  defp calculate_system_health(service_results) do
    total_services = length(service_results)
    healthy_services = Enum.count(service_results, fn {_, %{status: status}} -> status == :healthy end)
    
    overall_score = healthy_services / total_services
    
    %{
      status: determine_system_status(overall_score),
      services: service_results,
      overall_score: overall_score,
      healthy_services: healthy_services,
      total_services: total_services,
      timestamp: DateTime.utc_now()
    }
  end
end
```

#### HTTP Health Endpoint Integration
```elixir
defmodule ElixirScope.Foundation.Infrastructure.HealthEndpoint do
  @spec health_check_json(namespace()) :: map()
  def health_check_json(namespace \\ :production) do
    case HealthAggregator.system_health(namespace) do
      {:ok, health} ->
        %{
          status: health.status,
          timestamp: DateTime.to_iso8601(health.timestamp),
          services: format_service_health(health.services),
          overall_score: health.overall_score
        }
      {:error, reason} ->
        %{
          status: :error,
          message: "Health check failed: #{inspect(reason)}",
          timestamp: DateTime.to_iso8601(DateTime.utc_now())
        }
    end
  end
end
```

### Testing Strategy
```elixir
defmodule HealthCheckTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  
  test "deep health check detects service issues", %{namespace: namespace} do
    # Simulate service degradation
    ConfigServer.simulate_degradation(namespace, :subscriber_timeout)
    
    {:ok, health} = HealthAggregator.system_health(namespace)
    
    assert health.status in [:degraded, :unhealthy]
    assert Enum.any?(health.services, fn {service, result} ->
      service == :config_server and result.status != :healthy
    end)
  end
end
```

---

## 4. Performance Monitoring Infrastructure

### Strategic Importance
- **Problem**: No baseline performance metrics before AST layer adds complexity
- **Solution**: Comprehensive performance monitoring with alerting and trending
- **AST Benefit**: Establishes performance baselines and monitoring patterns

### Architecture Design

#### Performance Metrics Collection
```elixir
defmodule ElixirScope.Foundation.Infrastructure.PerformanceMonitor do
  @type metric_type :: :latency | :throughput | :error_rate | :resource_usage
  @type performance_metric :: %{
    type: metric_type(),
    name: binary(),
    value: number(),
    unit: atom(),
    tags: map(),
    timestamp: DateTime.t()
  }
  
  @type performance_summary :: %{
    service: atom(),
    metrics: [performance_metric()],
    period_start: DateTime.t(),
    period_end: DateTime.t(),
    aggregations: map()
  }
```

#### Automatic Service Instrumentation
```elixir
defmodule ElixirScope.Foundation.Infrastructure.ServiceInstrumentation do
  defmacro __using__(opts) do
    quote do
      import ElixirScope.Foundation.Infrastructure.ServiceInstrumentation
      
      @before_compile ElixirScope.Foundation.Infrastructure.ServiceInstrumentation
      @service_metrics Keyword.get(unquote(opts), :metrics, [:latency, :throughput, :errors])
    end
  end
  
  defmacro instrument_function(name, do: block) do
    quote do
      def unquote(name)(args) do
        start_time = System.monotonic_time(:microsecond)
        
        try do
          result = unquote(block)
          duration = System.monotonic_time(:microsecond) - start_time
          
          PerformanceMonitor.record_latency(
            [:foundation, __MODULE__, unquote(name)],
            duration,
            %{status: :success}
          )
          
          result
        rescue
          error ->
            duration = System.monotonic_time(:microsecond) - start_time
            
            PerformanceMonitor.record_latency(
              [:foundation, __MODULE__, unquote(name)],
              duration,
              %{status: :error, error_type: error.__struct__}
            )
            
            reraise error, __STACKTRACE__
        end
      end
    end
  end
end
```

#### Metric Aggregation and Storage
```elixir
defmodule ElixirScope.Foundation.Infrastructure.MetricsStore do
  use GenServer
  
  @type time_window :: :minute | :hour | :day
  @type aggregation_type :: :avg | :min | :max | :p50 | :p95 | :p99
  
  def handle_cast({:record_metric, metric}, state) do
    new_state = store_metric(metric, state)
    new_state = maybe_trigger_aggregation(new_state)
    new_state = maybe_trigger_alerting(metric, new_state)
    
    {:noreply, new_state}
  end
  
  defp store_metric(metric, %{metrics: metrics} = state) do
    time_bucket = time_bucket(metric.timestamp, :minute)
    bucket_metrics = Map.get(metrics, time_bucket, [])
    new_metrics = Map.put(metrics, time_bucket, [metric | bucket_metrics])
    
    %{state | metrics: new_metrics}
  end
  
  def handle_call({:get_metrics, service, time_window, aggregation}, _from, state) do
    metrics = aggregate_metrics(service, time_window, aggregation, state.metrics)
    {:reply, {:ok, metrics}, state}
  end
end
```

### Implementation Details

#### Service Performance Baselines
```elixir
defmodule ElixirScope.Foundation.Services.ConfigServerPerformance do
  use ElixirScope.Foundation.Infrastructure.ServiceInstrumentation,
    metrics: [:latency, :throughput, :cache_hit_rate]
  
  instrument_function :get do
    case get_from_cache(path) do
      {:hit, value} ->
        PerformanceMonitor.increment_counter([:foundation, :config_server, :cache_hits])
        {:ok, value}
      :miss ->
        PerformanceMonitor.increment_counter([:foundation, :config_server, :cache_misses])
        get_from_source(path)
    end
  end
  
  instrument_function :update do
    result = update_config(path, value)
    PerformanceMonitor.increment_counter([:foundation, :config_server, :updates])
    result
  end
end
```

#### Performance Alerting
```elixir
defmodule ElixirScope.Foundation.Infrastructure.PerformanceAlerting do
  @type alert_rule :: %{
    metric_pattern: [atom()],
    threshold: number(),
    comparison: :gt | :lt | :eq,
    window: pos_integer(),
    severity: :warning | :critical
  }
  
  def check_alert_rules(metric, rules) do
    Enum.filter(rules, fn rule ->
      matches_pattern?(metric, rule.metric_pattern) and
      violates_threshold?(metric, rule.threshold, rule.comparison)
    end)
  end
  
  defp trigger_alert(metric, rule) do
    alert = %{
      type: :performance_alert,
      severity: rule.severity,
      metric: metric,
      rule: rule,
      timestamp: DateTime.utc_now()
    }
    
    EventStore.store(alert)
    TelemetryService.execute([:foundation, :performance, :alert], %{severity: rule.severity}, %{rule: rule.name})
  end
end
```

### Testing Strategy
```elixir
defmodule PerformanceMonitoringTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  
  test "performance metrics are recorded and aggregated", %{namespace: namespace} do
    # Generate load
    Enum.each(1..100, fn _ ->
      ConfigServer.get(namespace, [:test_key])
    end)
    
    # Check metrics were recorded
    {:ok, metrics} = PerformanceMonitor.get_metrics(:config_server, :minute, :avg)
    
    assert length(metrics) > 0
    assert Enum.any?(metrics, fn m -> m.type == :latency end)
  end
end
```

---

## 5. Rate Limiting Framework

### Strategic Importance
- **Problem**: AST layer will expose APIs that need protection from abuse
- **Solution**: Flexible rate limiting with multiple algorithms and scopes
- **AST Benefit**: Ready-to-use rate limiting for AST parser APIs

### Architecture Design

#### Rate Limiter Interface
```elixir
defmodule ElixirScope.Foundation.Infrastructure.RateLimiter do
  @type rate_limit_result :: :ok | {:error, :rate_limited, retry_after_ms()}
  @type rate_limit_config :: %{
    algorithm: :token_bucket | :sliding_window | :fixed_window,
    limit: pos_integer(),
    window_ms: pos_integer(),
    burst_limit: pos_integer()
  }
  
  @callback check_rate_limit(key :: term(), config :: rate_limit_config()) :: rate_limit_result()
  @callback reset_rate_limit(key :: term()) :: :ok
  @callback get_rate_limit_status(key :: term()) :: rate_limit_status()
```

#### Token Bucket Implementation
```elixir
defmodule ElixirScope.Foundation.Infrastructure.TokenBucketLimiter do
  use GenServer
  @behaviour ElixirScope.Foundation.Infrastructure.RateLimiter
  
  @type bucket_state :: %{
    tokens: non_neg_integer(),
    last_refill: integer(),
    capacity: pos_integer(),
    refill_rate: pos_integer()
  }
  
  def check_rate_limit(key, config) do
    case GenServer.call(__MODULE__, {:check_tokens, key, config}) do
      :ok -> :ok
      {:error, retry_after} -> {:error, :rate_limited, retry_after}
    end
  end
  
  def handle_call({:check_tokens, key, config}, _from, state) do
    bucket = get_or_create_bucket(key, config, state)
    updated_bucket = refill_tokens(bucket, config)
    
    case updated_bucket.tokens >= 1 do
      true ->
        new_bucket = %{updated_bucket | tokens: updated_bucket.tokens - 1}
        new_state = update_bucket(key, new_bucket, state)
        {:reply, :ok, new_state}
      false ->
        retry_after = calculate_retry_after(updated_bucket, config)
        {:reply, {:error, retry_after}, state}
    end
  end
end
```

#### Service Integration Patterns
```elixir
defmodule ElixirScope.Foundation.Infrastructure.RateLimitedService do
  defmacro __using__(opts) do
    quote do
      import ElixirScope.Foundation.Infrastructure.RateLimitedService
      @rate_limit_config Keyword.get(unquote(opts), :rate_limit, %{})
    end
  end
  
  defmacro rate_limited(function_name, rate_config, do: block) do
    quote do
      def unquote(function_name)(args) do
        rate_key = generate_rate_key(unquote(function_name), args)
        
        case RateLimiter.check_rate_limit(rate_key, unquote(rate_config)) do
          :ok ->
            unquote(block)
          {:error, :rate_limited, retry_after} ->
            TelemetryService.emit_counter(
              [:foundation, :rate_limit, :rejected],
              %{function: unquote(function_name), retry_after: retry_after}
            )
            {:error, rate_limited_error(retry_after)}
        end
      end
    end
  end
end
```

### Implementation Details

#### Multi-Algorithm Support
```elixir
defmodule ElixirScope.Foundation.Infrastructure.SlidingWindowLimiter do
  @behaviour ElixirScope.Foundation.Infrastructure.RateLimiter
  
  def check_rate_limit(key, config) do
    now = System.system_time(:millisecond)
    window_start = now - config.window_ms
    
    # Clean old entries
    :ets.select_delete(:sliding_window_table, [
      {{key, :"$1", :_}, [{:<, :"$1", window_start}], [true]}
    ])
    
    # Count current window requests
    current_count = :ets.select_count(:sliding_window_table, [
      {{key, :"$1", :_}, [{:>=, :"$1", window_start}], [true]}
    ])
    
    case current_count < config.limit do
      true ->
        :ets.insert(:sliding_window_table, {key, now, true})
        :ok
      false ->
        retry_after = config.window_ms - (now - window_start)
        {:error, :rate_limited, retry_after}
    end
  end
end
```

#### Rate Limiting Middleware
```elixir
defmodule ElixirScope.Foundation.Infrastructure.RateLimitMiddleware do
  def call(request, opts) do
    rate_key = extract_rate_key(request, opts)
    rate_config = get_rate_config(request, opts)
    
    case RateLimiter.check_rate_limit(rate_key, rate_config) do
      :ok ->
        request
      {:error, :rate_limited, retry_after} ->
        raise RateLimitExceededError, retry_after: retry_after
    end
  end
  
  defp extract_rate_key(request, opts) do
    case Keyword.get(opts, :key_strategy) do
      :ip -> get_client_ip(request)
      :user -> get_user_id(request)
      :api_key -> get_api_key(request)
      custom_fun when is_function(custom_fun) -> custom_fun.(request)
    end
  end
end
```

### Testing Strategy
```elixir
defmodule RateLimitingTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  
  test "token bucket correctly limits requests", %{namespace: namespace} do
    config = %{algorithm: :token_bucket, limit: 5, window_ms: 1000, burst_limit: 10}
    
    # Should allow initial requests
    Enum.each(1..5, fn _ ->
      assert :ok = RateLimiter.check_rate_limit("test_key", config)
    end)
    
    # Should reject excess requests
    assert {:error, :rate_limited, _} = RateLimiter.check_rate_limit("test_key", config)
  end
end
```

---

## 6. Connection Pooling Infrastructure

### Strategic Importance
- **Problem**: Foundation services may need external connections (databases, APIs)
- **Solution**: Managed connection pools with monitoring and recovery
- **AST Benefit**: Establishes patterns for AST external tool integrations

### Architecture Design

#### Generic Connection Pool
```elixir
defmodule ElixirScope.Foundation.Infrastructure.ConnectionPool do
  @type pool_config :: %{
    min_size: non_neg_integer(),
    max_size: pos_integer(),
    checkout_timeout: pos_integer(),
    idle_timeout: pos_integer(),
    max_retries: non_neg_integer()
  }
  
  @type connection_spec :: %{
    module: module(),
    options: keyword(),
    health_check: (connection() -> boolean())
  }
  
  @callback create_connection(options :: keyword()) :: {:ok, connection()} | {:error, term()}
  @callback close_connection(connection()) :: :ok
  @callback ping_connection(connection()) :: :ok | {:error, term()}
```

#### Pool Manager Implementation
```elixir
defmodule ElixirScope.Foundation.Infrastructure.PoolManager do
  use GenServer
  
  @type pool_state :: %{
    connections: [connection_info()],
    available: :queue.queue(),
    checked_out: %{reference() => connection_info()},
    config: pool_config(),
    connection_spec: connection_spec()
  }
  
  def handle_call(:checkout, {from_pid, _}, state) do
    case :queue.out(state.available) do
      {{:value, conn_info}, remaining_queue} ->
        monitor_ref = Process.monitor(from_pid)
        new_checked_out = Map.put(state.checked_out, monitor_ref, conn_info)
        new_state = %{state | available: remaining_queue, checked_out: new_checked_out}
        {:reply, {:ok, conn_info.connection}, new_state}
      
      {:empty, _} when map_size(state.checked_out) < state.config.max_size ->
        case create_new_connection(state) do
          {:ok, conn_info} ->
            monitor_ref = Process.monitor(from_pid)
            new_checked_out = Map.put(state.checked_out, monitor_ref, conn_info)
            {:reply, {:ok, conn_info.connection}, %{state | checked_out: new_checked_out}}
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      
      {:empty, _} ->
        {:reply, {:error, :pool_exhausted}, state}
    end
  end
end
```

#### Database Connection Pool Example
```elixir
defmodule ElixirScope.Foundation.Infrastructure.DatabaseConnection do
  @behaviour ElixirScope.Foundation.Infrastructure.ConnectionPool
  
  def create_connection(opts) do
    database_url = Keyword.get(opts, :database_url)
    timeout = Keyword.get(opts, :timeout, 5000)
    
    case MyDatabase.connect(database_url, timeout: timeout) do
      {:ok, conn} -> {:ok, conn}
      {:error, reason} -> {:error, reason}
    end
  end
  
  def close_connection(conn) do
    MyDatabase.disconnect(conn)
  end
  
  def ping_connection(conn) do
    case MyDatabase.query(conn, "SELECT 1", [], timeout: 1000) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### Implementation Details

#### Connection Health Monitoring
```elixir
defmodule ElixirScope.Foundation.Infrastructure.ConnectionHealthMonitor do
  use GenServer
  
  def handle_info(:health_check, %{pools: pools} = state) do
    updated_pools = Enum.map(pools, fn {pool_name, pool_pid} ->
      case PoolManager.health_check(pool_pid) do
        :ok -> {pool_name, pool_pid}
        {:error, reason} ->
          Logger.warning("Pool #{pool_name} health check failed: #{inspect(reason)}")
          restart_pool(pool_name, pool_pid)
      end
    end)
    
    schedule_next_health_check()
    {:noreply, %{state | pools: updated_pools}}
  end
  
  defp restart_pool(pool_name, pool_pid) do
    DynamicSupervisor.terminate_child(ConnectionPoolSupervisor, pool_pid)
    
    case DynamicSupervisor.start_child(ConnectionPoolSupervisor, {PoolManager, [name: pool_name]}) do
      {:ok, new_pid} -> {pool_name, new_pid}
      {:error, reason} ->
        Logger.error("Failed to restart pool #{pool_name}: #{inspect(reason)}")
        {pool_name, nil}
    end
  end
end
```

#### Connection Pool Registry
```elixir
defmodule ElixirScope.Foundation.Infrastructure.ConnectionPoolRegistry do
  @spec register_pool(atom(), pool_config(), connection_spec()) :: {:ok, pid()} | {:error, term()}
  def register_pool(pool_name, config, connection_spec) do
    pool_opts = [
      name: pool_name,
      config: config,
      connection_spec: connection_spec
    ]
    
    case DynamicSupervisor.start_child(ConnectionPoolSupervisor, {PoolManager, pool_opts}) do
      {:ok, pid} ->
        ProcessRegistry.register(:production, {:connection_pool, pool_name}, pid)
        {:ok, pid}
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @spec get_connection(atom()) :: {:ok, connection()} | {:error, term()}
  def get_connection(pool_name) do
    case ProcessRegistry.lookup(:production, {:connection_pool, pool_name}) do
      {:ok, pool_pid} -> PoolManager.checkout(pool_pid)
      :error -> {:error, :pool_not_found}
    end
  end
end
```

### Testing Strategy
```elixir
defmodule ConnectionPoolTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  
  test "connection pool manages connections correctly", %{namespace: namespace} do
    config = %{min_size: 2, max_size: 5, checkout_timeout: 1000}
    connection_spec = %{module: MockConnection, options: [], health_check: &MockConnection.ping/1}
    
    {:ok, pool_pid} = PoolManager.start_link([config: config, connection_spec: connection_spec])
    
    # Should be able to checkout connections
    {:ok, conn1} = PoolManager.checkout(pool_pid)
    {:ok, conn2} = PoolManager.checkout(pool_pid)
    
    assert conn1 != conn2
    
    # Should return connections to pool
    :ok = PoolManager.checkin(pool_pid, conn1)
    {:ok, conn3} = PoolManager.checkout(pool_pid)
    assert conn3 == conn1  # Reused connection
  end
end
```

---

## Integration Strategy

### Foundation Service Integration

#### Retrofit Existing Services
```elixir
# Update existing ConfigServer with all infrastructure
defmodule ElixirScope.Foundation.Services.ConfigServer do
  use GenServer
  use ElixirScope.Foundation.Infrastructure.ServiceInstrumentation
  use ElixirScope.Foundation.Infrastructure.RateLimitedService
  use ElixirScope.Foundation.Infrastructure.HealthCheckable
  
  # Circuit breaker protection for external calls
  @circuit_breaker_config %{failure_threshold: 5, reset_timeout: 30_000}
  
  # Rate limiting for updates
  @rate_limit_config %{algorithm: :token_bucket, limit: 100, window_ms: 60_000}
  
  # Memory management participation
  @memory_cleanup_strategy ElixirScope.Foundation.Infrastructure.MemoryCleanup.ConfigCacheCleanup
end
```

#### Cross-Infrastructure Integration
```elixir
defmodule ElixirScope.Foundation.Infrastructure.IntegratedService do
  def enhanced_operation(args) do
    # Rate limiting check
    with :ok <- RateLimiter.check_rate_limit(rate_key(args), @rate_config),
         # Memory pressure check
         :ok <- MemoryManager.check_operation_allowed(),
         # Circuit breaker check
         :ok <- CircuitBreaker.check_state(:external_service),
         # Actual operation with performance monitoring
         {:ok, result} <- PerformanceMonitor.measure([:service, :operation], fn ->
           perform_operation(args)
         end) do
      {:ok, result}
    else
      {:error, :rate_limited, retry_after} -> 
        {:error, create_rate_limit_error(retry_after)}
      {:error, :memory_pressure} -> 
        {:error, create_memory_pressure_error()}
      {:error, :circuit_open} -> 
        {:error, create_circuit_breaker_error()}
      error -> error
    end
  end
end
```

### Testing Integration

#### Comprehensive Test Suite
```elixir
defmodule InfrastructureIntegrationTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  
  test "all infrastructure components work together", %{namespace: namespace} do
    # Start all infrastructure services
    :ok = start_infrastructure(namespace)
    
    # Test rate limiting with circuit breaker
    simulate_load_with_failures(namespace)
    
    # Verify circuit breaker tripped
    assert {:error, :circuit_open} = CircuitBreaker.check_state(namespace, :test_service)
    
    # Verify rate limiting engaged
    assert {:error, :rate_limited, _} = RateLimiter.check_rate_limit("test_key", @rate_config)
    
    # Verify memory management kicked in
    assert MemoryManager.get_pressure_level(namespace) in [:medium, :high]
    
    # Verify performance metrics collected
    {:ok, metrics} = PerformanceMonitor.get_metrics(:test_service, :minute, :avg)
    assert length(metrics) > 0
    
    # Verify health checks show degraded state
    {:ok, health} = HealthAggregator.system_health(namespace)
    assert health.status in [:degraded, :unhealthy]
  end
end
```

---

## Implementation Timeline

### Week 1: Core Reliability
- **Day 1-2**: Circuit Breaker Framework implementation
- **Day 3-4**: Memory Management Framework implementation  
- **Day 5**: Integration testing and documentation

### Week 2: Production Readiness
- **Day 1-2**: Enhanced Health Check System implementation
- **Day 3-4**: Performance Monitoring Infrastructure implementation
- **Day 5**: System-wide performance baseline establishment

### Week 3: AST Preparation
- **Day 1-2**: Rate Limiting Framework implementation
- **Day 3-4**: Connection Pooling Infrastructure implementation
- **Day 5**: Full integration testing and AST readiness validation

### Success Metrics
- **Circuit Breaker**: All Foundation services protected with < 10ms overhead
- **Memory Management**: Automatic cleanup prevents OOM conditions
- **Health Checks**: < 100ms end-to-end health validation
- **Performance**: Baseline metrics for all Foundation operations
- **Rate Limiting**: < 1ms rate check overhead, configurable limits
- **Connection Pooling**: Connection reuse > 90%, < 50ms checkout time

---

This infrastructure foundation will provide the reliability, observability, and performance patterns needed for AST layer development while delivering immediate production value for the Foundation layer. 