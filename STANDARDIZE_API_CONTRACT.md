# ElixirScope Foundation Layer - API Contract Specification

**Version:** 2.2  
**Date:** June 2025  
**Status:** Active - Fully Implemented  

## Executive Summary

The ElixirScope Foundation Layer provides a robust, OTP-compliant concurrent architecture serving as the bedrock for the entire ElixirScope platform. This document specifies the formal API contracts, behavior definitions, and integration patterns for all Foundation layer components.

**Implementation Status:** ✅ **100% COMPLETE** - All Foundation layer services have been successfully migrated to Registry-based process discovery with full namespace isolation, enabling safe concurrent testing and production operation.

## Table of Contents

1. [Core Architecture](#core-architecture)
2. [Process Registration & Discovery](#process-registration--discovery)
3. [Service Contracts](#service-contracts)
4. [Testing Infrastructure](#testing-infrastructure)
5. [Error Handling & Monitoring](#error-handling--monitoring)
6. [Integration Patterns](#integration-patterns)

---

## Core Architecture

### Supervision Tree Structure

```elixir
ElixirScope.Foundation.Supervisor (:one_for_one)
├── ElixirScope.Foundation.ProcessRegistry (Registry)
├── ElixirScope.Foundation.Services.ConfigServer (GenServer)
├── ElixirScope.Foundation.Services.EventStore (GenServer)
├── ElixirScope.Foundation.Services.TelemetryService (GenServer)
├── ElixirScope.Foundation.TestSupervisor (DynamicSupervisor)
└── Task.Supervisor (Task.Supervisor)
```

### Namespace Architecture

| Namespace | Purpose | Isolation Level |
|-----------|---------|-----------------|
| `:production` | Normal application operation | Global singleton services |
| `{:test, reference()}` | Test isolation | Per-test isolated instances |

---

## Process Registration & Discovery

### ProcessRegistry API Contract

```elixir
@type namespace :: :production | {:test, reference()}
@type service_name :: :config_server | :event_store | :telemetry_service | :test_supervisor
@type registry_key :: {namespace(), service_name()}

# Core Registration Functions
@spec register(namespace(), service_name(), pid()) :: :ok | {:error, {:already_registered, pid()}}
@spec lookup(namespace(), service_name()) :: {:ok, pid()} | :error
@spec unregister(namespace(), service_name()) :: :ok
@spec via_tuple(namespace(), service_name()) :: {:via, Registry, {atom(), registry_key()}}

# Discovery Functions
@spec list_services(namespace()) :: [service_name()]
@spec get_all_services(namespace()) :: %{service_name() => pid()}
@spec registered?(namespace(), service_name()) :: boolean()
@spec count_services(namespace()) :: non_neg_integer()
@spec stats() :: %{
  total_services: non_neg_integer(),
  partitions: non_neg_integer()
}

# Test Support Functions
@spec cleanup_test_namespace(reference()) :: :ok
```

### ServiceRegistry API Contract (High-level wrapper)

```elixir
@type lookup_result :: {:ok, pid()} | {:error, Error.t()}
@type registration_result :: :ok | {:error, {:already_registered, pid()}}
@type health_check_result :: {:ok, pid()} | {:error, term()}

# High-Level Service API  
@spec via_tuple(namespace(), service_name()) :: {:via, Registry, {atom(), registry_key()}}
@spec lookup(namespace(), service_name()) :: lookup_result()
@spec health_check(namespace(), service_name(), keyword()) :: health_check_result()
@spec wait_for_service(namespace(), service_name(), timeout()) :: {:ok, pid()} | {:error, :timeout}

# Service Management
@spec list_services(namespace()) :: [service_name()]
@spec get_service_info(namespace()) :: %{
  namespace: namespace(),
  total_services: non_neg_integer(),
  service_names: [service_name()]
}

# Test Support
@spec cleanup_test_namespace(reference()) :: :ok
```

---

## Service Contracts

### ConfigServer Contract (`Configurable` Behavior)

```elixir
@behaviour ElixirScope.Foundation.Contracts.Configurable

# Core Configuration API (ACTUAL IMPLEMENTATION)
@spec get() :: {:ok, Config.t()} | {:error, Error.t()}
@spec get([atom()]) :: {:ok, term()} | {:error, Error.t()}
@spec update([atom()], term()) :: :ok | {:error, Error.t()}
@spec reset() :: :ok | {:error, Error.t()}

# Service Management
@spec available?() :: boolean()
@spec updatable_paths() :: [[atom(), ...], ...]
@spec status() :: {:ok, map()} | {:error, Error.t()}

# Subscription Management
@spec subscribe(pid()) :: :ok | {:error, Error.t()}
@spec unsubscribe(pid()) :: :ok | {:error, Error.t()}

# GenServer Lifecycle
@spec start_link(keyword()) :: GenServer.on_start()
@spec stop() :: :ok
@spec initialize() :: :ok | {:error, Error.t()}
@spec initialize(keyword()) :: :ok | {:error, Error.t()}

# Testing Support (Test Mode Only)
@spec reset_state() :: :ok | {:error, Error.t()}

# Notification Messages
# Subscribers receive: {:config_updated, [atom()], term()}
# Subscribers receive: {:config_reset, Config.t()}
```

### EventStore Contract (`EventStore` Behavior)

```elixir
@behaviour ElixirScope.Foundation.Contracts.EventStore

# Core Event Operations
@spec store(Event.t()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
@spec store_batch([Event.t()]) :: {:ok, [non_neg_integer()]} | {:error, Error.t()}
@spec get(non_neg_integer()) :: {:ok, Event.t()} | {:error, Error.t()}
@spec query(map()) :: {:ok, [Event.t()]} | {:error, Error.t()}

# Advanced Querying
@spec get_by_correlation(binary()) :: {:ok, [Event.t()]} | {:error, Error.t()}
@spec get_by_type(atom()) :: {:ok, [Event.t()]} | {:error, Error.t()}
@spec get_by_source(binary()) :: {:ok, [Event.t()]} | {:error, Error.t()}

# Service Management
@spec available?() :: boolean()
@spec get_stats() :: {:ok, map()} | {:error, Error.t()}
@spec status() :: {:ok, map()} | {:error, Error.t()}

# GenServer Lifecycle
@spec start_link(keyword()) :: GenServer.on_start()
@spec stop() :: :ok
@spec initialize() :: :ok | {:error, Error.t()}

# Testing Support (Test Mode Only)
@spec reset_state() :: :ok | {:error, Error.t()}

# Query Structure
@type query_options :: %{
  optional(:event_type) => atom(),
  optional(:source) => binary(),
  optional(:correlation_id) => binary(),
  optional(:start_time) => DateTime.t(),
  optional(:end_time) => DateTime.t(),
  optional(:limit) => pos_integer(),
  optional(:offset) => non_neg_integer()
}
```

### TelemetryService Contract (`Telemetry` Behavior)

```elixir
@behaviour ElixirScope.Foundation.Contracts.Telemetry

# Core Telemetry Operations (ACTUAL IMPLEMENTATION)
@spec execute([atom()], map(), map()) :: :ok
@spec measure([atom()], map(), (() -> term())) :: term()
@spec emit_counter([atom()], map()) :: :ok
@spec emit_counter([atom()], number(), map()) :: :ok  # Overloaded version for tests
@spec emit_gauge([atom()], number(), map()) :: :ok

# Service Management  
@spec get_metrics() :: {:ok, map()} | {:error, Error.t()}
@spec attach_handlers([[atom()]]) :: :ok | {:error, Error.t()}
@spec detach_handlers([[atom()]]) :: :ok
@spec available?() :: boolean()
@spec status() :: {:ok, map()} | {:error, Error.t()}

# GenServer Lifecycle
@spec start_link(keyword()) :: GenServer.on_start()
@spec stop() :: :ok
@spec initialize() :: :ok | {:error, Error.t()}

# Testing Support (Test Mode Only)
@spec reset_metrics() :: :ok | {:error, Error.t()}
@spec reset_state() :: :ok | {:error, Error.t()}

# Metric Types
@type metric_type :: :counter | :gauge | :histogram | :summary
@type measurement :: number() | %{atom() => number()}
@type metadata :: %{atom() => term()}
```

---

## Testing Infrastructure

### TestSupervisor Contract (ACTUAL IMPLEMENTATION)

```elixir
@type test_ref :: reference()
@type namespace :: {:test, test_ref()}

# Test Isolation Management
@spec start_isolated_services(test_ref()) :: {:ok, [pid()]} | {:error, term()}
@spec cleanup_namespace(test_ref()) :: :ok
@spec list_isolated_services(test_ref()) :: [{service_name(), pid()}]
@spec stop_isolated_services(test_ref()) :: :ok

# Health Monitoring
@spec namespace_healthy?(test_ref()) :: boolean()
@spec wait_for_services_ready(test_ref(), timeout()) :: :ok | {:error, :timeout}

# Resource Management  
@spec count_test_namespaces() :: non_neg_integer()
@spec cleanup_all_test_namespaces() :: :ok

# GenServer Lifecycle
@spec start_link(keyword()) :: GenServer.on_start()
```

### ConcurrentTestCase API (ACTUAL IMPLEMENTATION)

```elixir
defmodule MyTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  
  # Automatic setup provides:
  # %{test_ref: reference(), namespace: {:test, reference()}, service_pids: [pid()]}
  
  test "isolated test operations", %{namespace: namespace} do
    # Test code with isolated services
    assert ServiceRegistry.lookup(namespace, :config_server) |> elem(0) == :ok
  end
end

# Helper Functions Available in Tests (ACTUAL IMPLEMENTATION)
@spec with_isolated_services(test_ref(), (namespace() -> term())) :: term()
@spec wait_for_service_health(namespace(), service_name(), timeout()) :: :ok | {:error, :timeout}
@spec assert_services_isolated(namespace()) :: :ok
@spec simulate_service_restart(namespace(), service_name()) :: :ok
```

---

## Error Handling & Monitoring

### Standard Error Types (ACTUAL IMPLEMENTATION)

```elixir
@type error_category :: :system | :config | :events | :telemetry | :validation | :security
@type error_subcategory :: :initialization | :operation | :authorization | :timeout | :resource
@type error_severity :: :low | :medium | :high | :critical
@type error_type :: :validation_failed | :service_unavailable | :operation_forbidden | 
                   :resource_not_found | :timeout | :internal_error | :service_initialization_failed

# Error Structure (ACTUAL IMPLEMENTATION)
%Error{
  code: pos_integer(),
  error_type: error_type(),
  message: binary(),
  severity: error_severity(),
  category: error_category(),
  subcategory: error_subcategory(),
  timestamp: DateTime.t(),
  metadata: map()
}
```

### Health Check Response Format (ACTUAL IMPLEMENTATION)

```elixir
# Service Health Check Response
%{
  status: :healthy | :unhealthy,
  service: module_name(),
  namespace: namespace()
}

# Service Status Response  
%{
  status: :running,
  metrics_count: non_neg_integer(),     # TelemetryService
  handlers_count: non_neg_integer(),    # TelemetryService
  events_stored: non_neg_integer(),     # EventStore
  config: map(),                        # Service configuration
  start_time: integer(),               # ConfigServer
  updates_count: non_neg_integer(),    # ConfigServer
  last_update: integer() | nil         # ConfigServer
}
```

---

## Integration Patterns

### Service Registration Pattern (ACTUAL IMPLEMENTATION)

```elixir
defmodule YourService do
  use GenServer
  
  def start_link(opts \\ []) do
    namespace = Keyword.get(opts, :namespace, :production)
    name = ElixirScope.Foundation.ServiceRegistry.via_tuple(namespace, :your_service)
    GenServer.start_link(__MODULE__, Keyword.put(opts, :namespace, namespace), name: name)
  end
  
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end
end
```

### Higher Layer Integration Pattern (ACTUAL IMPLEMENTATION)

```elixir
defmodule YourHigherLayer do
  alias ElixirScope.Foundation.{Config, Events, Telemetry}
  
  def your_operation(data) do
    with {:ok, config} <- Config.get([:your_layer, :settings]),
         :ok <- validate_data(data),
         {:ok, result} <- process_data(data, config),
         {:ok, _event_id} <- Events.store(create_event(result)) do
      
      Telemetry.emit_counter([:your_layer, :operations, :success], %{})
      {:ok, result}
    else
      {:error, reason} = error ->
        Telemetry.emit_counter([:your_layer, :operations, :error], %{reason: reason})
        Events.store(create_error_event(reason))
        error
    end
  end
end
```

### Graceful Degradation Pattern (ACTUAL IMPLEMENTATION)

```elixir
defmodule YourService do
  def operation_with_fallback(params) do
    case Config.available?() do
      true ->
        {:ok, config} = Config.get([:your_service])
        perform_operation(params, config)
      
      false ->
        # Graceful degradation with defaults
        Logger.warning("Config service unavailable, using defaults")
        perform_operation(params, default_config())
    end
  end
end
```

---

## API Stability Guarantees

### Stable APIs (Backward Compatible)
- All public functions in `Config`, `Events`, `Telemetry` modules
- Service behavior callback definitions
- Error structure format
- Health check response format
- ProcessRegistry and ServiceRegistry APIs
- TestSupervisor isolation patterns

### Evolving APIs (May Change)
- Internal GenServer message formats
- Registry key structures
- Test helper implementation details
- Performance monitoring metrics

### Deprecated APIs
- Manual service lifecycle management (use supervision tree)
- Direct GenServer calls to services (use public API modules)
- Global process naming (use namespace isolation)

---

## Compliance Requirements

### OTP Compliance
- All services implement proper `child_spec/1`
- Services support graceful shutdown via `terminate/2`
- Proper supervision tree integration
- "Let it crash" error handling philosophy

### Concurrent Testing Requirements
- All tests must use `ConcurrentTestCase` for service interaction
- No manual service lifecycle management in tests
- Proper test isolation through namespace separation
- Resource cleanup through supervision, not manual intervention

### Performance Requirements
- Service availability check: < 10ms
- Configuration read operations: < 5ms
- Event storage operations: < 20ms
- Test isolation setup: < 100ms

---

**Document Revision History:**
- v2.2: Aligned with actual Foundation implementation details
- v2.1: Updated to reflect 100% implementation completion of Registry-based architecture
- v2.0: Complete rewrite reflecting OTP-compliant Registry-based architecture  
- v1.x: Legacy API specifications (deprecated)
