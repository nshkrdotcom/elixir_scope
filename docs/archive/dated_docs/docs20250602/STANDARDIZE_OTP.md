# ElixirScope OTP Architecture Specification

**Version:** 1.1  
**Date:** June 2025  
**Status:** Active  
**Scope:** Foundation Layer through Application Layer

## Executive Summary

This document establishes the formal OTP (Open Telecom Platform) architectural patterns, design principles, and implementation standards for all ElixirScope layers. These specifications ensure consistent, reliable, and maintainable concurrent systems across the entire platform.

**Implementation Status:** ✅ **Foundation Layer COMPLETE** - All patterns documented here have been implemented and validated in the Foundation layer, serving as the reference implementation for other layers.

## Table of Contents

1. [OTP Design Principles](#otp-design-principles)
2. [Supervision Strategies](#supervision-strategies)
3. [Process Management Patterns](#process-management-patterns)
4. [Registry Architecture](#registry-architecture)
5. [GenServer Patterns](#genserver-patterns)
6. [Error Handling & Recovery](#error-handling--recovery)
7. [Testing Patterns](#testing-patterns)
8. [Performance & Monitoring](#performance--monitoring)
9. [Layer Integration Standards](#layer-integration-standards)

---

## OTP Design Principles

### Core Philosophy

**"Let It Crash"** - Embrace failure as a natural part of concurrent systems:
- Isolate failures to prevent cascade effects
- Use supervision trees for automatic recovery
- Design for resilience, not error prevention
- Separate error handling from business logic

### Fault Tolerance Hierarchy

```
Application Layer (Tolerates individual request failures)
    ↓
Business Layer (Recovers from domain-specific errors)  
    ↓
Infrastructure Layer (Handles external system failures)
    ↓
Foundation Layer (Provides basic process reliability)
```

### Actor Model Implementation (ACTUAL IMPLEMENTATION)

- **Processes as Actors**: Each GenServer represents a single actor
- **Message Passing**: All communication via async/sync messages through Registry
- **Isolation**: No shared state between processes, namespace isolation
- **Location Transparency**: Processes addressable via `ServiceRegistry.via_tuple/2`

---

## Supervision Strategies

### Strategy Selection Guidelines

| Strategy | Use Case | Child Restart Policy |
|----------|----------|---------------------|
| `:one_for_one` | Independent services | Individual failure isolation |
| `:one_for_all` | Interdependent services | Coordinated restart required |
| `:rest_for_one` | Pipeline dependencies | Downstream restart cascade |
| `:simple_one_for_one` | Dynamic workers | Template-based spawning |

### Foundation Layer Pattern (ACTUAL IMPLEMENTATION)

```elixir
defmodule ElixirScope.Foundation.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Registry must start first for service discovery
      {ElixirScope.Foundation.ProcessRegistry, []},

      # Core foundation services with production namespace
      {ElixirScope.Foundation.Services.ConfigServer, [namespace: :production]},
      {ElixirScope.Foundation.Services.EventStore, [namespace: :production]},
      {ElixirScope.Foundation.Services.TelemetryService, [namespace: :production]},

      # TestSupervisor for dynamic test isolation
      {ElixirScope.Foundation.TestSupervisor, []},

      # Task supervisor for dynamic tasks
      {Task.Supervisor, name: ElixirScope.Foundation.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: ElixirScope.Foundation.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Supervision Tree Specification

```elixir
@spec supervision_tree_spec() :: %{
  strategy: :one_for_one | :one_for_all | :rest_for_one,
  children: [child_spec()],
  max_restarts: non_neg_integer(),
  max_seconds: pos_integer()
}

@type child_spec :: %{
  id: atom(),
  start: {module(), atom(), [term()]},
  restart: :permanent | :temporary | :transient,
  shutdown: :brutal_kill | :infinity | non_neg_integer(),
  type: :worker | :supervisor,
  modules: [module()]
}
```

---

## Process Management Patterns

### Registry-Based Process Discovery (ACTUAL IMPLEMENTATION)

All processes MUST be discoverable through the Registry pattern:

```elixir
# Registration Pattern (ACTUAL IMPLEMENTATION)
{:via, Registry, {ElixirScope.Foundation.ProcessRegistry, {namespace, service_name}}}

# Namespace Isolation (ACTUAL IMPLEMENTATION)  
:production                    # Global production namespace
{:test, reference()}          # Test-isolated namespace
```

### Process Lifecycle Management (ACTUAL IMPLEMENTATION)

#### Standard GenServer Template

```elixir
defmodule MyService do
  use GenServer
  require Logger

  # Public API
  def start_link(opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :production)
    name = ElixirScope.Foundation.ServiceRegistry.via_tuple(namespace, :my_service)
    GenServer.start_link(__MODULE__, Keyword.put(opts, :namespace, namespace), name: name)
  end

  def stop(namespace \\ :production) do
    case ElixirScope.Foundation.ServiceRegistry.lookup(namespace, :my_service) do
      {:ok, pid} -> GenServer.stop(pid)
      {:error, _} -> :ok
    end
  end

  # Health Check (Required)
  def health_check(namespace \\ :production) do
    try do
      case ElixirScope.Foundation.ServiceRegistry.lookup(namespace, :my_service) do
        {:ok, pid} -> GenServer.call(pid, :health_check, 5_000)
        {:error, _} -> {:error, :service_unavailable}
      end
    catch
      :exit, {:timeout, _} -> {:error, :service_timeout}
    end
  end

  # Available check (Required)
  def available?(namespace \\ :production) do
    case ElixirScope.Foundation.ServiceRegistry.lookup(namespace, :my_service) do
      {:ok, _pid} -> true
      {:error, _} -> false
    end
  end

  # GenServer Callbacks
  @impl true
  def init(opts) do
    namespace = Keyword.get(opts, :namespace, :production)
    
    case initialize_service(opts) do
      {:ok, state} ->
        Logger.info("#{__MODULE__} initialized in namespace #{inspect(namespace)}")
        {:ok, Map.put(state, :namespace, namespace)}
      {:error, reason} ->
        Logger.error("Failed to initialize #{__MODULE__}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:health_check, _from, state) do
    {:reply, {:ok, %{status: :healthy, service: __MODULE__, namespace: state.namespace}}, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("#{__MODULE__} terminating: #{inspect(reason)}")
    cleanup_resources(state)
    :ok
  end

  # Service-specific implementations
  defp initialize_service(_opts), do: {:ok, %{}}
  defp cleanup_resources(_state), do: :ok
end
```

### Child Specification Requirements (ACTUAL IMPLEMENTATION)

Every GenServer MUST implement proper child_spec:

```elixir
def child_spec(opts) do
  %{
    id: __MODULE__,
    start: {__MODULE__, :start_link, [opts]},
    restart: :permanent,
    shutdown: 5_000,
    type: :worker,
    modules: [__MODULE__]
  }
end
```

---

## Registry Architecture

### Namespace Design Patterns (ACTUAL IMPLEMENTATION)

#### Production Namespace
```elixir
# Global singleton services
{:via, Registry, {ElixirScope.Foundation.ProcessRegistry, {:production, :config_server}}}
{:via, Registry, {ElixirScope.Foundation.ProcessRegistry, {:production, :event_store}}}
{:via, Registry, {ElixirScope.Foundation.ProcessRegistry, {:production, :telemetry_service}}}
```

#### Test Isolation Namespace
```elixir
# Per-test isolated instances
test_ref = make_ref()
{:via, Registry, {ElixirScope.Foundation.ProcessRegistry, {{:test, test_ref}, :config_server}}}
```

### Registry Service Discovery (ACTUAL IMPLEMENTATION)

```elixir
defmodule ElixirScope.Foundation.ServiceRegistry do
  @spec lookup(namespace(), atom()) :: {:ok, pid()} | {:error, Error.t()}
  def lookup(namespace, service) do
    case ElixirScope.Foundation.ProcessRegistry.lookup(namespace, service) do
      {:ok, pid} -> {:ok, pid}
      :error -> {:error, create_service_not_found_error(namespace, service)}
    end
  end

  @spec via_tuple(namespace(), atom()) :: {:via, Registry, {atom(), {namespace(), atom()}}}
  def via_tuple(namespace, service) do
    ElixirScope.Foundation.ProcessRegistry.via_tuple(namespace, service)
  end

  @spec health_check(namespace(), atom(), keyword()) :: {:ok, pid()} | {:error, term()}
  def health_check(namespace, service, opts \\ []) do
    case lookup(namespace, service) do
      {:ok, pid} ->
        if Process.alive?(pid) do
          case Keyword.get(opts, :health_check) do
            nil -> {:ok, pid}
            health_check_fun -> health_check_fun.(pid)
          end
        else
          {:error, :process_dead}
        end
      error -> error
    end
  end
end
```

---

## GenServer Patterns

### State Management (ACTUAL IMPLEMENTATION)

#### Immutable State Pattern
```elixir
defmodule StatefulService do
  @type state :: %{
    data: map(),
    config: map(),
    metrics: map(),
    namespace: ProcessRegistry.namespace(),
    last_updated: DateTime.t()
  }

  def handle_call({:update_data, new_data}, _from, state) do
    new_state = %{state | 
      data: Map.merge(state.data, new_data),
      last_updated: DateTime.utc_now()
    }
    {:reply, :ok, new_state}
  end
end
```

#### Configuration Management Pattern (ACTUAL IMPLEMENTATION)
```elixir
def handle_call({:get_config_path, path}, _from, %{config: config} = state) do
  result = ConfigLogic.get_config_value(config, path)
  {:reply, result, state}
end

def handle_call({:update_config, path, value}, _from, %{config: config} = state) do
  case ConfigLogic.update_config(config, path, value) do
    {:ok, new_config} ->
      new_state = %{state | config: new_config}
      notify_subscribers(state.subscribers, {:config_updated, path, value})
      {:reply, :ok, new_state}
    {:error, _} = error ->
      {:reply, error, state}
  end
end
```

### Message Handling Patterns (ACTUAL IMPLEMENTATION)

#### Synchronous Operations (GenServer.call)
- Configuration reads/writes
- Health checks
- State queries
- Critical operations requiring confirmation

#### Asynchronous Operations (GenServer.cast)
- Event notifications
- Logging operations  
- Metric updates
- Fire-and-forget operations

#### Info Messages (handle_info)
- Timer events
- Monitor notifications
- External system messages

```elixir
# Timer-based operations (ACTUAL IMPLEMENTATION)
def handle_info(:cleanup_old_metrics, %{config: config} = state) do
  new_state = cleanup_old_metrics(state, config.metric_retention_ms)
  schedule_cleanup(config.cleanup_interval)
  {:noreply, new_state}
end

# Monitor notifications (ACTUAL IMPLEMENTATION)
def handle_info({:DOWN, ref, :process, pid, _reason}, %{subscribers: subscribers, monitors: monitors} = state) do
  new_subscribers = List.delete(subscribers, pid)
  new_monitors = Map.delete(monitors, ref)
  new_state = %{state | subscribers: new_subscribers, monitors: new_monitors}
  {:noreply, new_state}
end
```

---

## Error Handling & Recovery

### Error Classification (ACTUAL IMPLEMENTATION)

#### Recoverable Errors
- Network timeouts
- Temporary resource unavailability
- Malformed input data
- External service failures

**Strategy**: Retry with exponential backoff, graceful degradation

#### Non-Recoverable Errors
- Configuration errors
- Resource exhaustion
- System-level failures
- Critical business rule violations

**Strategy**: Let it crash, supervisor restart

### Error Handling Patterns (ACTUAL IMPLEMENTATION)

#### Foundation Error Structure
```elixir
%ElixirScope.Foundation.Types.Error{
  code: pos_integer(),
  error_type: :validation_failed | :service_unavailable | :operation_forbidden,
  message: binary(),
  severity: :low | :medium | :high | :critical,
  category: :system | :config | :events | :telemetry | :validation | :security,
  subcategory: :initialization | :operation | :authorization | :timeout | :resource,
  timestamp: DateTime.t(),
  metadata: map()
}
```

#### Graceful Degradation (ACTUAL IMPLEMENTATION)
```elixir
defmodule YourService do
  def operation_with_fallback(params) do
    case ConfigServer.available?() do
      true ->
        {:ok, config} = ConfigServer.get([:your_service])
        perform_operation(params, config)
      
      false ->
        Logger.warning("Config service unavailable, using defaults")
        perform_operation(params, default_config())
    end
  end
end
```

---

## Testing Patterns

### Test Isolation Architecture (ACTUAL IMPLEMENTATION)

#### ConcurrentTestCase Usage
```elixir
defmodule MyServiceTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true

  test "service operates correctly", %{test_ref: test_ref, namespace: namespace} do
    # Services automatically started in isolated namespace
    assert {:ok, _pid} = ServiceRegistry.lookup(namespace, :config_server)
    assert {:ok, _pid} = ServiceRegistry.lookup(namespace, :event_store)
    assert {:ok, _pid} = ServiceRegistry.lookup(namespace, :telemetry_service)
    
    # Test isolated operations
    :ok = ConfigServer.update(namespace, [:test_key], "test_value")
    {:ok, value} = ConfigServer.get(namespace, [:test_key])
    assert value == "test_value"
  end
end
```

#### Test Isolation Infrastructure (ACTUAL IMPLEMENTATION)
```elixir
defmodule ElixirScope.Foundation.TestSupervisor do
  @spec start_isolated_services(reference()) :: {:ok, [pid()]} | {:error, term()}
  def start_isolated_services(test_ref) when is_reference(test_ref) do
    namespace = {:test, test_ref}
    
    service_specs = [
      {ConfigServer, [namespace: namespace]},
      {EventStore, [namespace: namespace]}, 
      {TelemetryService, [namespace: namespace]}
    ]
    
    results = Enum.map(service_specs, fn {module, opts} ->
      DynamicSupervisor.start_child(__MODULE__, {module, opts})
    end)
    
    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {successes, []} ->
        pids = Enum.map(successes, fn {:ok, pid} -> pid end)
        {:ok, pids}
      {_successes, failures} ->
        cleanup_namespace(test_ref)
        List.first(failures)
    end
  end
  
  @spec cleanup_namespace(reference()) :: :ok
  def cleanup_namespace(test_ref) do
    namespace = {:test, test_ref}
    ServiceRegistry.cleanup_test_namespace(test_ref)
  end
end
```

### Property-Based Testing (ACTUAL IMPLEMENTATION)

#### Test Structure
```elixir
defmodule PropertyTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  use PropCheck

  @moduletag :slow

  property "config operations are consistent", %{namespace: namespace} do
    forall {path, value} <- {config_path(), config_value()} do
      :ok = ConfigServer.update(namespace, path, value)
      {:ok, retrieved_value} = ConfigServer.get(namespace, path)
      retrieved_value == value
    end
  end
end
```

---

## Performance & Monitoring

### Performance Metrics (ACTUAL IMPLEMENTATION)

#### Service-Level Metrics
- Request latency (via TelemetryService.measure/3)
- Throughput (via TelemetryService.emit_counter/2)
- Error rate (via event correlation)
- Availability (via health checks)

#### System-Level Metrics
- Process count and memory usage
- Message queue lengths
- Supervision tree restarts
- Registry lookup performance

### Monitoring Implementation (ACTUAL IMPLEMENTATION)

#### Telemetry Events
```elixir
# Actual Foundation implementation
TelemetryService.execute([:foundation, :config_server, :operation], 
                        %{duration: duration_ms}, 
                        %{operation: :get, path: path})

TelemetryService.emit_counter([:foundation, :event_store, :events_stored], 
                             %{event_type: event.event_type})

TelemetryService.emit_gauge([:foundation, :service, :memory_usage], 
                           process_memory_bytes, 
                           %{service: __MODULE__})
```

#### Health Check Aggregation (ACTUAL IMPLEMENTATION)
```elixir
defmodule ElixirScope.Foundation.HealthMonitor do
  def system_health(namespace \\ :production) do
    services = [:config_server, :event_store, :telemetry_service]
    
    health_results = Enum.map(services, fn service ->
      case ServiceRegistry.health_check(namespace, service) do
        {:ok, _pid} -> {service, :healthy}
        {:error, reason} -> {service, {:unhealthy, reason}}
      end
    end)
    
    case Enum.all?(health_results, fn {_service, status} -> status == :healthy end) do
      true -> {:ok, %{status: :healthy, services: health_results}}
      false -> {:error, %{status: :degraded, services: health_results}}
    end
  end
end
```

---

## Layer Integration Standards

### Foundation → Higher Layer Integration (TEMPLATE)

#### Service Registration Pattern
```elixir
defmodule YourLayer.SomeService do
  use GenServer
  
  def start_link(opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :production)
    name = ServiceRegistry.via_tuple(namespace, :your_service)
    GenServer.start_link(__MODULE__, Keyword.put(opts, :namespace, namespace), name: name)
  end
  
  # Use Foundation services
  def init(opts) do
    namespace = Keyword.get(opts, :namespace, :production)
    
    with {:ok, config} <- ConfigServer.get(namespace, [:your_layer, :settings]),
         :ok <- validate_config(config) do
      state = %{config: config, namespace: namespace}
      {:ok, state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end
end
```

### Cross-Layer Error Propagation (DESIGN)

```elixir
# Error flows upward through layers
Application Layer -> Business Layer -> Infrastructure Layer -> Foundation Layer
     ↓                    ↓                      ↓                    ↓
  HTTP Errors      Domain Errors       System Errors      Process Crashes
  (400, 500)       (validation)        (db timeout)       (let it crash)
```

---

## Compliance Checklist

### Process Design ✅
- [x] Uses GenServer for stateful processes
- [x] Implements proper child_spec/1
- [x] Registers via Registry pattern with ServiceRegistry.via_tuple/2
- [x] Supports namespace isolation with {:test, reference()} pattern
- [x] Implements health_check/1 and available?/0

### Supervision ✅
- [x] Included in supervision tree
- [x] Proper restart strategy (:one_for_one for Foundation)
- [x] Graceful shutdown handling via terminate/2
- [x] Resource cleanup in terminate/2

### Error Handling ✅
- [x] Follows "let it crash" philosophy
- [x] Uses structured Error types with categories/subcategories
- [x] Provides graceful degradation via available?/0 checks
- [x] Emits telemetry on errors and operations

### Testing ✅
- [x] Uses ConcurrentTestCase for service tests
- [x] Implements property-based tests with @moduletag :slow
- [x] Tests error scenarios and edge cases
- [x] Validates concurrent behavior with async: true

### Monitoring ✅
- [x] Emits telemetry events via TelemetryService
- [x] Implements health checks via ServiceRegistry
- [x] Monitors key metrics (operations, errors, performance)
- [x] Provides debug information via status/0 calls

---

**Document Revision History:**
- v1.1: Updated to reflect actual Foundation layer implementation details
- v1.0: Initial specification based on Foundation layer implementation
