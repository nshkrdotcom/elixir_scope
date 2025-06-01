# ElixirScope Foundation Layer - Complete API Contract Specification

## Overview

This document serves as the **definitive API contract** for ElixirScope's Foundation layer. Based on comprehensive testing, implementation analysis, and real-world usage patterns, this contract specifies every public API, behavior pattern, and integration requirement for the Foundation layer.

**Purpose**: This is not just a standardization document, but the complete specification that any Foundation layer implementation must satisfy.

## Table of Contents

1. [Foundation Layer Architecture](#foundation-layer-architecture)
2. [Core Public APIs](#core-public-apis)
3. [Service APIs](#service-apis)
4. [Utility APIs](#utility-apis)
5. [Error Handling Contract](#error-handling-contract)
6. [Testing Infrastructure Contract](#testing-infrastructure-contract)
7. [Performance and Monitoring Contract](#performance-and-monitoring-contract)
8. [Implementation Requirements](#implementation-requirements)
9. [Contract Validation](#contract-validation)

## Foundation Layer Architecture

The Foundation layer implements a 6-tier architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│ Foundation Orchestration (ElixirScope.Foundation)           │ ← High-level coordination
├─────────────────────────────────────────────────────────────┤
│ Public APIs (Config, Events, Telemetry, Utils)            │ ← Clean interface layer
├─────────────────────────────────────────────────────────────┤
│ Services (ConfigServer, EventStore, TelemetryService)      │ ← Stateful GenServers
├─────────────────────────────────────────────────────────────┤
│ Logic (EventLogic, ConfigLogic, etc.)                      │ ← Pure business functions
├─────────────────────────────────────────────────────────────┤
│ Types & Contracts (Error, Event, Config, Behaviors)       │ ← Data structures & interfaces
├─────────────────────────────────────────────────────────────┤
│ Test Infrastructure (TestHelpers, Fixtures)               │ ← Testing support
└─────────────────────────────────────────────────────────────┘
```

## Core Public APIs

### 1. Foundation Orchestration API

**Module**: `ElixirScope.Foundation`

The top-level coordination module that manages the entire Foundation layer.

#### Required Functions

```elixir
@spec initialize(keyword()) :: :ok | {:error, Error.t()}
def initialize(opts \\ [])
```
- **Purpose**: Start all Foundation services in correct dependency order
- **Parameters**: `opts` - Configuration options for initialization
- **Returns**: `:ok` on success, `{:error, Error.t()}` on failure
- **Contract**: Must start ConfigServer, EventStore, TelemetryService in order

```elixir
@spec status() :: {:ok, map()} | {:error, Error.t()}
def status()
```
- **Purpose**: Get status of all Foundation services
- **Returns**: `{:ok, status_map}` with service statuses, or `{:error, Error.t()}`
- **Contract**: Status map must include `config`, `events`, `telemetry` keys

```elixir
@spec available?() :: boolean()
def available?()
```
- **Purpose**: Check if all critical Foundation services are running
- **Returns**: `true` if all services available, `false` otherwise
- **Contract**: Must check ConfigServer, EventStore, TelemetryService availability

```elixir
@spec shutdown() :: :ok
def shutdown()
```
- **Purpose**: Gracefully shutdown all Foundation services
- **Returns**: Always `:ok` (blocking until complete)
- **Contract**: Must stop services in reverse dependency order

```elixir
@spec health() :: {:ok, map()} | {:error, Error.t()}
def health()
```
- **Purpose**: Get comprehensive health metrics for monitoring
- **Returns**: Health data including service details and system metrics
- **Contract**: Must include overall status, timestamp, service details

```elixir
@spec version() :: String.t()
def version()
```
- **Purpose**: Get Foundation layer version
- **Returns**: Version string from application specification
- **Contract**: Must return semver-compatible version string

### 2. Configuration API

**Module**: `ElixirScope.Foundation.Config`

Manages application configuration with validation and change tracking.

#### Required Functions

```elixir
@spec initialize() :: :ok | {:error, Error.t()}
@spec initialize(keyword()) :: :ok | {:error, Error.t()}
def initialize(opts \\ [])
```

```elixir
@spec get() :: {:ok, Config.t()} | {:error, Error.t()}
def get()
```
- **Contract**: Must return complete configuration structure

```elixir
@spec get(config_path()) :: {:ok, config_value()} | {:error, Error.t()}
def get(path) when is_list(path)
```
- **Contract**: Path is list of atoms, returns nested value or error

```elixir
@spec update(config_path(), config_value()) :: :ok | {:error, Error.t()}
def update(path, value)
```
- **Contract**: Only updatable paths can be modified, triggers events

```elixir
@spec validate(Config.t()) :: :ok | {:error, Error.t()}
def validate(config)
```

```elixir
@spec updatable_paths() :: [config_path()]
def updatable_paths()
```
- **Contract**: Returns list of paths that can be updated at runtime

```elixir
@spec reset() :: :ok | {:error, Error.t()}
def reset()
```

```elixir
@spec available?() :: boolean()
def available?()
```

```elixir
@spec status() :: {:ok, map()} | {:error, Error.t()}
def status()
```

```elixir
@spec subscribe() :: :ok | {:error, Error.t()}
@spec unsubscribe() :: :ok
def subscribe()
def unsubscribe()
```
- **Contract**: Subscribe to config change notifications

```elixir
@spec get_with_default(config_path(), config_value()) :: config_value()
def get_with_default(path, default)
```
- **Contract**: Returns actual value or default, never fails

#### Type Definitions

```elixir
@type config_path :: [atom()]
@type config_value :: term()
```

### 3. Events API

**Module**: `ElixirScope.Foundation.Events`

Manages event creation, storage, and retrieval with correlation tracking.

#### Required Functions

```elixir
@spec initialize() :: :ok | {:error, Error.t()}
def initialize()
```

```elixir
@spec new_event(atom(), term()) :: {:ok, Event.t()} | {:error, Error.t()}
@spec new_event(atom(), term(), keyword()) :: {:ok, Event.t()} | {:error, Error.t()}
def new_event(event_type, data, opts \\ [])
```
- **Contract**: Creates event with unique ID, timestamp, correlation ID

```elixir
@spec store(Event.t()) :: {:ok, event_id()} | {:error, Error.t()}
def store(event)
```

```elixir
@spec store_batch([Event.t()]) :: {:ok, [event_id()]} | {:error, Error.t()}
def store_batch(events)
```
- **Contract**: Atomic storage of multiple events

```elixir
@spec get(event_id()) :: {:ok, Event.t()} | {:error, Error.t()}
def get(event_id) when is_integer(event_id) and event_id > 0
```

```elixir
@spec query(keyword()) :: {:ok, [Event.t()]} | {:error, Error.t()}
def query(query_options)
```
- **Contract**: Query events by type, correlation_id, time range, etc.

```elixir
@spec get_by_correlation(correlation_id()) :: {:ok, [Event.t()]} | {:error, Error.t()}
def get_by_correlation(correlation_id)
```

```elixir
@spec serialize(Event.t()) :: {:ok, binary()} | {:error, Error.t()}
@spec deserialize(binary()) :: {:ok, Event.t()} | {:error, Error.t()}
def serialize(event)
def deserialize(binary)
```

```elixir
@spec serialized_size(Event.t()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
def serialized_size(event)
```

#### Convenience Functions

```elixir
@spec function_entry(module(), atom(), arity(), [term()], keyword()) :: {:ok, Event.t()} | {:error, Error.t()}
def function_entry(module, function, arity, args, opts \\ [])

@spec function_exit(module(), atom(), arity(), pos_integer(), term(), non_neg_integer(), atom()) :: {:ok, Event.t()} | {:error, Error.t()}
def function_exit(module, function, arity, call_id, result, duration_ns, exit_reason)

@spec state_change(pid(), atom(), term(), term(), keyword()) :: {:ok, Event.t()} | {:error, Error.t()}
def state_change(server_pid, callback, old_state, new_state, opts \\ [])
```

#### Required Service Functions

```elixir
@spec available?() :: boolean()
@spec status() :: {:ok, map()} | {:error, Error.t()}
def available?()
def status()
```

#### Type Definitions

```elixir
@type event_id :: pos_integer()
@type correlation_id :: String.t()
@type event_query :: keyword()
```

### 4. Telemetry API

**Module**: `ElixirScope.Foundation.Telemetry`

Manages metrics collection, performance monitoring, and telemetry events.

#### Required Functions

```elixir
@spec initialize() :: :ok | {:error, Error.t()}
def initialize()
```

```elixir
@spec execute(event_name(), measurements(), metadata()) :: :ok
def execute(event_name, measurements, metadata)
```

```elixir
@spec measure(event_name(), metadata(), (() -> result)) :: result when result: var
def measure(event_name, metadata, fun)
```
- **Contract**: Executes function and emits timing telemetry

```elixir
@spec emit_counter(event_name(), metadata()) :: :ok
def emit_counter(event_name, metadata)
```

```elixir
@spec emit_gauge(event_name(), metric_value(), metadata()) :: :ok
def emit_gauge(event_name, value, metadata)
```

```elixir
@spec get_metrics() :: {:ok, map()} | {:error, Error.t()}
def get_metrics()
```
- **Contract**: Returns collected metrics data

```elixir
@spec reset_metrics() :: :ok
def reset_metrics()
```
- **Contract**: Clears all collected metrics

```elixir
@spec attach_handlers([event_name()]) :: :ok | {:error, Error.t()}
@spec detach_handlers([event_name()]) :: :ok
def attach_handlers(event_names)
def detach_handlers(event_names)
```

#### Convenience Functions

```elixir
@spec time_function(module(), atom(), (() -> result)) :: result when result: var
def time_function(module, function, fun)

@spec emit_performance(atom(), metric_value(), metadata()) :: :ok
def emit_performance(metric_name, value, metadata \\ %{})

@spec emit_system_event(atom(), metadata()) :: :ok
def emit_system_event(event_type, metadata \\ %{})
```

#### Required Service Functions

```elixir
@spec available?() :: boolean()
@spec status() :: {:ok, map()} | {:error, Error.t()}
def available?()
def status()
```

#### Type Definitions

```elixir
@type event_name :: [atom()]
@type measurements :: map()
@type metadata :: map()
@type metric_value :: number()
```

### 5. Utilities API

**Module**: `ElixirScope.Foundation.Utils`

Pure utility functions for ID generation, data manipulation, and common operations.

#### Required Functions

```elixir
@spec generate_id() :: pos_integer()
def generate_id()
```
- **Contract**: Must generate unique positive integers across all processes

```elixir
@spec generate_correlation_id() :: String.t()
def generate_correlation_id()
```
- **Contract**: Must generate 36-character UUID-format strings

```elixir
@spec monotonic_timestamp() :: integer()
def monotonic_timestamp()
```

```elixir
@spec deep_merge(map(), map()) :: map()
def deep_merge(left, right)
```
- **Contract**: Recursively merge maps, right-hand side wins conflicts

```elixir
@spec truncate_if_large(term()) :: term()
@spec truncate_if_large(term(), pos_integer()) :: term()
def truncate_if_large(data, max_size \\ 10_000)
```

```elixir
@spec deep_size(term()) :: non_neg_integer()
def deep_size(term)
```

```elixir
@spec safe_inspect(term()) :: String.t()
def safe_inspect(term)
```

```elixir
@spec get_nested(map(), [atom()], term()) :: term()
def get_nested(map, path, default \\ nil)
```

```elixir
@spec put_nested(map(), [atom()], term()) :: map()
def put_nested(map, path, value)
```

#### Performance Measurement Functions

```elixir
@spec measure((() -> result)) :: {result, non_neg_integer()} when result: any()
def measure(func)
```
- **Contract**: Returns {result, duration_in_microseconds}

```elixir
@spec measure_memory((() -> result)) :: {result, {non_neg_integer(), non_neg_integer(), integer()}} when result: any()
def measure_memory(func)
```
- **Contract**: Returns {result, {before_bytes, after_bytes, diff_bytes}}

#### System Information Functions

```elixir
@spec format_bytes(non_neg_integer()) :: String.t()
def format_bytes(bytes)
```
- **Contract**: Formats bytes as human-readable strings (B, KB, MB, GB)

```elixir
@spec process_stats() :: map()
def process_stats()
```
- **Contract**: Returns memory, message_queue_len, reductions, etc.

```elixir
@spec system_stats() :: map()
def system_stats()
```
- **Contract**: Returns process_count, memory, scheduler info, etc.

```elixir
@spec valid_positive_integer?(term()) :: boolean()
def valid_positive_integer?(value)
```

## Service APIs

The Foundation layer implements three core services that public APIs delegate to:

### 1. ConfigServer

**Module**: `ElixirScope.Foundation.Services.ConfigServer`

#### Required GenServer Functions

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
@spec initialize() :: :ok | {:error, Error.t()}
@spec initialize(keyword()) :: :ok | {:error, Error.t()}
```

#### Service-Level Functions

```elixir
@spec get() :: {:ok, Config.t()} | {:error, Error.t()}
@spec get(config_path()) :: {:ok, config_value()} | {:error, Error.t()}
@spec update(config_path(), config_value()) :: :ok | {:error, Error.t()}
@spec validate(Config.t()) :: :ok | {:error, Error.t()}
@spec available?() :: boolean()
@spec status() :: {:ok, map()} | {:error, Error.t()}
```

### 2. EventStore

**Module**: `ElixirScope.Foundation.Services.EventStore`

#### Required GenServer Functions

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
@spec initialize() :: :ok | {:error, Error.t()}
```

#### Service-Level Functions

```elixir
@spec store(Event.t()) :: {:ok, event_id()} | {:error, Error.t()}
@spec store_batch([Event.t()]) :: {:ok, [event_id()]} | {:error, Error.t()}
@spec get(event_id()) :: {:ok, Event.t()} | {:error, Error.t()}
@spec query(keyword()) :: {:ok, [Event.t()]} | {:error, Error.t()}
@spec get_by_correlation(correlation_id()) :: {:ok, [Event.t()]} | {:error, Error.t()}
@spec available?() :: boolean()
@spec status() :: {:ok, map()} | {:error, Error.t()}
```

### 3. TelemetryService

**Module**: `ElixirScope.Foundation.Services.TelemetryService`

#### Required GenServer Functions

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
@spec initialize() :: :ok | {:error, Error.t()}
```

#### Service-Level Functions

```elixir
@spec execute(event_name(), measurements(), metadata()) :: :ok
@spec measure(event_name(), metadata(), (() -> result)) :: result when result: var
@spec emit_counter(event_name(), metadata()) :: :ok
@spec emit_gauge(event_name(), metric_value(), metadata()) :: :ok
@spec get_metrics() :: {:ok, map()} | {:error, Error.t()}
@spec reset_metrics() :: :ok
@spec available?() :: boolean()
@spec status() :: {:ok, map()} | {:error, Error.t()}
```

## Error Handling Contract

### Error Structure

All errors must use `ElixirScope.Foundation.Types.Error`:

```elixir
%Error{
  error_type: atom(),          # For pattern matching
  message: String.t(),         # Human readable
  code: pos_integer(),         # Numeric code
  category: error_category(),  # :config | :system | :data | :external | :validation
  severity: error_severity(),  # :low | :medium | :high | :critical
  context: map(),              # Debug information
  correlation_id: String.t(),  # Request tracing
  timestamp: DateTime.t()      # When error occurred
}
```

### Return Value Patterns

**Rule 1: Operations that can fail AND return data**
- Must return `{:ok, result} | {:error, Error.t()}`
- Examples: `Config.get/1`, `Events.query/1`, `Telemetry.get_metrics/0`

**Rule 2: Operations that can fail but perform side-effects**
- Must return `:ok | {:error, Error.t()}`
- Examples: `Config.update/2`, `Events.store/1`, `Telemetry.emit_counter/2`

**Rule 3: Pure utility functions that cannot reasonably fail**
- Return result directly
- Examples: `Utils.generate_id/0`, `Utils.format_bytes/1`

**Rule 4: Service availability checks**
- Must return `boolean()`
- Examples: `Config.available?/0`, `Events.available?/0`

### Error Creation

```elixir
# Standard error creation
{:error, Error.new(:error_type, "Message", context: %{...})}

# Error propagation with enrichment
{:error, Error.enrich(existing_error, %{additional: "context"})}
```

## Testing Infrastructure Contract

### TestHelpers Module

**Module**: `ElixirScope.Foundation.TestHelpers`

#### Required Functions

```elixir
@spec wait_for_service_availability(module(), non_neg_integer()) :: :ok | :timeout
def wait_for_service_availability(service_module, timeout_ms \\ 5000)
```

```elixir
@spec wait_for_all_services_available(non_neg_integer()) :: :ok | :timeout
def wait_for_all_services_available(timeout_ms \\ 5000)
```

```elixir
@spec wait_for_service_restart(module(), non_neg_integer()) :: :ok | :timeout
def wait_for_service_restart(service_module, timeout_ms \\ 5000)
```

```elixir
@spec create_test_event(keyword()) :: {:ok, Event.t()} | {:error, Error.t()}
def create_test_event(overrides \\ [])
```

```elixir
@spec ensure_config_available() :: :ok | {:error, Error.t()}
def ensure_config_available()
```

```elixir
@spec wait_for((-> boolean()), non_neg_integer()) :: :ok | :timeout
def wait_for(condition, timeout_ms \\ 1000)
```

## Performance and Monitoring Contract

### Performance Requirements

1. **Service startup time**: < 100ms per service
2. **API response time**: < 10ms for simple operations
3. **Memory usage**: Stable under load (no leaks)
4. **Telemetry overhead**: < 200% of baseline operation cost

### Monitoring Requirements

1. **Service health checks**: All services must implement `available?/0`
2. **Status reporting**: All services must implement `status/0`
3. **Telemetry emission**: Key operations must emit telemetry events
4. **Error tracking**: All errors must include correlation IDs

### Event Names

Standard telemetry event naming:

```elixir
[:elixir_scope, :foundation, :service, :operation]
[:elixir_scope, :config, :update, :success]
[:elixir_scope, :events, :store, :batch]
[:elixir_scope, :telemetry, :metrics, :collection]
```

## Implementation Requirements

### 1. Supervision Tree

Foundation must implement a supervision tree:

```elixir
ElixirScope.Foundation.Application
├── ConfigServer (permanent restart)
├── EventStore (permanent restart)  
├── TelemetryService (permanent restart)
└── Registry (for dynamic processes)
```

### 2. Service Dependencies

**Startup Order**: ConfigServer → EventStore → TelemetryService
**Shutdown Order**: Reverse of startup

### 3. Correlation ID Format

Must generate 36-character UUID-format correlation IDs:
- Format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- Example: `550e8400-e29b-41d4-a716-446655440000`

### 4. Configuration Paths

Updatable configuration paths must include:
```elixir
[
  [:dev, :debug_mode],
  [:ai, :planning, :sampling_rate],
  [:capture, :buffer_size],
  [:telemetry, :enabled]
]
```

### 5. Event Structure

Events must include:
```elixir
%Event{
  event_id: pos_integer(),           # Unique ID
  event_type: atom(),                # Event type
  data: term(),                      # Event data
  correlation_id: String.t(),        # For tracing
  timestamp: DateTime.t(),           # When created
  metadata: map()                    # Additional context
}
```

## Contract Validation

### Automated Contract Tests

The Foundation layer must pass:

1. **Unit Tests**: 100% of core logic functions
2. **Integration Tests**: 95% of service interactions  
3. **Contract Tests**: 100% of behavior implementations
4. **Property Tests**: 75%+ of property-based scenarios

### Performance Benchmarks

Services must meet:

1. **Throughput**: 1000+ operations/second for simple operations
2. **Latency**: P99 < 50ms for complex operations
3. **Memory**: < 100MB total for all Foundation services
4. **Startup**: Complete initialization in < 500ms

### Error Handling Coverage

Must handle:

1. **Service unavailable**: All APIs gracefully handle service downtime
2. **Invalid input**: All functions validate input and return proper errors
3. **Resource exhaustion**: Graceful degradation under resource pressure
4. **Network failures**: Proper error propagation and retry logic

## Breaking Changes

Any changes to this contract that break existing functionality must:

1. **Version bump**: Increment major version number
2. **Migration guide**: Provide clear upgrade path
3. **Deprecation period**: 6 months minimum for public APIs
4. **Backward compatibility**: Where technically feasible

## Contract Compliance

This contract serves as the definitive specification for Foundation layer APIs. All implementations must:

1. **Implement all required functions** with exact specifications
2. **Pass all contract tests** without modification  
3. **Meet performance requirements** under specified conditions
4. **Follow error handling patterns** consistently
5. **Maintain type contracts** as specified

Any deviation from this contract constitutes a breaking change and must follow the breaking changes process.
