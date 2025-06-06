# ElixirScope Foundation Layer - Public API Documentation

## Table of Contents

1.  [Overview](#overview)
2.  [Getting Started](#getting-started)
3.  [Core Foundation API (`ElixirScope.Foundation`)](#core-foundation-api)
4.  [Configuration API (`ElixirScope.Foundation.Config`)](#configuration-api)
5.  [Events API (`ElixirScope.Foundation.Events`)](#events-api)
6.  [Telemetry API (`ElixirScope.Foundation.Telemetry`)](#telemetry-api)
7.  [Utilities API (`ElixirScope.Foundation.Utils`)](#utilities-api)
8.  [Service Registry API (`ElixirScope.Foundation.ServiceRegistry`)](#service-registry-api)
9.  [Process Registry API (`ElixirScope.Foundation.ProcessRegistry`)](#process-registry-api)
10. [Infrastructure Protection API (`ElixirScope.Foundation.Infrastructure`)](#infrastructure-protection-api)
11. [Error Context API (`ElixirScope.Foundation.ErrorContext`)](#error-context-api)
12. [Error Handling & Types (`ElixirScope.Foundation.Error`, `ElixirScope.Foundation.Types.Error`)](#error-handling--types)
13. [Performance Considerations](#performance-considerations)
14. [Best Practices](#best-practices)
15. [Examples](#examples)
16. [Migration Guide](#migration-guide)

## Overview

The ElixirScope Foundation Layer provides core utilities, configuration management, event handling, telemetry, service registration, infrastructure protection patterns, and robust error handling for the ElixirScope platform. It offers a clean, well-documented API designed for both ease of use and enterprise-grade performance.

### Key Features

- **🔧 Configuration Management** - Runtime configuration with validation and hot-reloading
- **📦 Event System** - Structured event creation, storage, and querying
- **📊 Telemetry Integration** - Comprehensive metrics collection and monitoring
- **🔗 Service & Process Registry** - Namespaced service discovery and management
- **🛡️ Infrastructure Protection** - Circuit breakers, rate limiters, connection pooling
- **✨ Error Context** - Enhanced error reporting with operational context
- **🛠️ Core Utilities** - Essential helper functions for common tasks
- **⚡ High Performance** - Optimized for low latency and high throughput
- **🧪 Test-Friendly** - Built-in support for isolated testing and namespacing

### System Requirements

- Elixir 1.15+ and OTP 26+
- Memory: Variable, base usage ~10MB + resources per service/event
- CPU: Optimized for multi-core systems

---

## Getting Started

### Installation

Add ElixirScope to your `mix.exs`:

```elixir
def deps do
  [
    {:elixir_scope, "~> 0.2.0"} # Or the latest version
  ]
end
```

### Basic Setup (in your Application's `start/2` callback)

```elixir
def start(_type, _args) do
  # Start ElixirScope's core supervisor, which includes the Foundation layer
  children = [
    ElixirScope.Application # Or just ElixirScope if it provides a child_spec
  ]

  # Alternatively, if you need to initialize Foundation manually (less common for library users):
  # {:ok, _} = ElixirScope.Foundation.initialize()

  # ... your application's children
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### Quick Example

```elixir
# Ensure Foundation is initialized (typically done by ElixirScope.Application)
# ElixirScope.Foundation.initialize()

# Configure a setting
:ok = ElixirScope.Foundation.Config.update([:dev, :debug_mode], true)

# Create and store an event
correlation_id = ElixirScope.Foundation.Utils.generate_correlation_id()
{:ok, event} = ElixirScope.Foundation.Events.new_event(:user_action, %{action: "login"}, correlation_id: correlation_id)
{:ok, event_id} = ElixirScope.Foundation.Events.store(event)

# Emit telemetry
:ok = ElixirScope.Foundation.Telemetry.emit_counter([:myapp, :user, :login_attempts], %{user_id: 123})

# Use a utility
unique_op_id = ElixirScope.Foundation.Utils.generate_id()
```

---

## Core Foundation API (`ElixirScope.Foundation`)

The `ElixirScope.Foundation` module is the main entry point for managing the Foundation layer itself.

### initialize/1

Initialize the entire Foundation layer. This typically ensures `Config`, `Events`, and `Telemetry` services are started. Often called by `ElixirScope.Application`.

```elixir
@spec initialize(opts :: keyword()) :: :ok | {:error, Error.t()}
```
**Parameters:**
- `opts` (optional) - Initialization options for each service (e.g., `config: [debug_mode: true]`).

**Example:**
```elixir
:ok = ElixirScope.Foundation.initialize(config: [debug_mode: true])
# To initialize with defaults:
:ok = ElixirScope.Foundation.initialize()
```

### status/0

Get comprehensive status of all core Foundation services (`Config`, `Events`, `Telemetry`).

```elixir
@spec status() :: {:ok, map()} | {:error, Error.t()}
```
**Returns:**
- `{:ok, status_map}` where `status_map` contains individual statuses.
**Example:**
```elixir
{:ok, status} = ElixirScope.Foundation.status()
# status might be:
# %{
#   config: %{status: :running, uptime_ms: 3600000},
#   events: %{status: :running, event_count: 15000},
#   telemetry: %{status: :running, metrics_count: 50}
# }
```

### available?/0

Check if all core Foundation services (`Config`, `Events`, `Telemetry`) are available.

```elixir
@spec available?() :: boolean()
```
**Example:**
```elixir
if ElixirScope.Foundation.available?() do
  IO.puts("Foundation layer is ready.")
end
```

### health/0

Get detailed health information for monitoring, including service status, Elixir/OTP versions.

```elixir
@spec health() :: {:ok, map()} | {:error, Error.t()}
```
**Returns:**
- `{:ok, health_map}` with keys like `:status` (`:healthy`, `:degraded`), `:timestamp`, `:services`, etc.
**Example:**
```elixir
{:ok, health_info} = ElixirScope.Foundation.health()
IO.inspect(health_info.status) # :healthy
```

### version/0

Get the version string of the ElixirScope application.

```elixir
@spec version() :: String.t()
```
**Example:**
```elixir
version_string = ElixirScope.Foundation.version()
# "0.2.0"
```

### shutdown/0

Gracefully shut down the Foundation layer and its services. This is typically managed by the application's supervision tree.

```elixir
@spec shutdown() :: :ok
```

---

## Configuration API (`ElixirScope.Foundation.Config`)

Manages application configuration with runtime updates and validation.

### initialize/0, initialize/1
Initialize the configuration service. Usually called by `ElixirScope.Foundation.initialize/1`.
```elixir
@spec initialize() :: :ok | {:error, Error.t()}
@spec initialize(opts :: keyword()) :: :ok | {:error, Error.t()}
```

### status/0
Get the status of the configuration service.
```elixir
@spec status() :: {:ok, map()} | {:error, Error.t()}
```

### get/0, get/1
Retrieve the entire configuration or a specific value by path.
```elixir
@spec get() :: {:ok, ElixirScope.Foundation.Types.Config.t()} | {:error, Error.t()}
@spec get(path :: [atom()]) :: {:ok, term()} | {:error, Error.t()}
```
**Example:**
```elixir
{:ok, all_config} = ElixirScope.Foundation.Config.get()
{:ok, provider} = ElixirScope.Foundation.Config.get([:ai, :provider])
```

### get_with_default/2
Retrieve a configuration value, returning a default if the path is not found.
```elixir
@spec get_with_default(path :: [atom()], default :: term()) :: term()
```
**Example:**
```elixir
timeout = ElixirScope.Foundation.Config.get_with_default([:my_feature, :timeout_ms], 5000)
```

### update/2
Update a configuration value at runtime. Only affects paths listed by `updatable_paths/0`.
```elixir
@spec update(path :: [atom()], value :: term()) :: :ok | {:error, Error.t()}
```
**Example:**
```elixir
:ok = ElixirScope.Foundation.Config.update([:dev, :debug_mode], true)
```

### safe_update/2
Update configuration if the path is updatable and not forbidden, otherwise return an error.
```elixir
@spec safe_update(path :: [atom()], value :: term()) :: :ok | {:error, Error.t()}
```

### updatable_paths/0
Get a list of configuration paths that can be updated at runtime.
```elixir
@spec updatable_paths() :: [[atom(), ...], ...]
```

### subscribe/0, unsubscribe/0
Subscribe/unsubscribe the calling process to/from configuration change notifications.
Messages are received as `{:config_notification, {:config_updated, path, new_value}}`.
```elixir
@spec subscribe() :: :ok | {:error, Error.t()}
@spec unsubscribe() :: :ok | {:error, Error.t()} # In implementation, Error.t() is not specified.
```

### available?/0
Check if the configuration service is available.
```elixir
@spec available?() :: boolean()
```

### reset/0
Reset configuration to its default values.
```elixir
@spec reset() :: :ok | {:error, Error.t()}
```

---

## Events API (`ElixirScope.Foundation.Events`)

Manages structured event creation, storage, querying, and serialization.

### initialize/0, status/0
Initialize/get status of the event store service.
```elixir
@spec initialize() :: :ok | {:error, Error.t()}
@spec status() :: {:ok, map()} | {:error, Error.t()}
```

### new_event/2, new_event/3
Create a new structured event. The 2-arity version uses default options. The 3-arity version accepts `opts` like `:correlation_id`, `:parent_id`.
The implementation `new_event(event_type, data, opts \\ [])` covers both.
```elixir
@spec new_event(event_type :: atom(), data :: term()) :: {:ok, Event.t()} | {:error, Error.t()}
@spec new_event(event_type :: atom(), data :: term(), opts :: keyword()) :: {:ok, Event.t()} | {:error, Error.t()}
```
**Example:**
```elixir
{:ok, event} = ElixirScope.Foundation.Events.new_event(:user_login, %{user_id: 123})
```

### store/1, store_batch/1
Store one or more events.
```elixir
@spec store(event :: Event.t()) :: {:ok, event_id :: Event.event_id()} | {:error, Error.t()}
@spec store_batch(events :: [Event.t()]) :: {:ok, [event_id :: Event.event_id()]} | {:error, Error.t()}
```

### get/1
Retrieve a stored event by its ID.
```elixir
@spec get(event_id :: Event.event_id()) :: {:ok, Event.t()} | {:error, Error.t()}
```

### query/1
Query stored events.
```elixir
@spec query(query_params :: map() | keyword()) :: {:ok, [Event.t()]} | {:error, Error.t()}
```
**Query Parameters (as map keys or keyword list):**
- `:event_type`: Atom
- `:time_range`: `{start_time_monotonic_ns, end_time_monotonic_ns}`
- `:limit`: Integer
- `:offset`: Integer
- `:order_by`: `:event_id` or `:timestamp`

### get_by_correlation/1
Retrieve all events matching a correlation ID, sorted by timestamp.
```elixir
@spec get_by_correlation(correlation_id :: String.t()) :: {:ok, [Event.t()]} | {:error, Error.t()}
```

### Convenience Event Creators
- **`function_entry(module, function, arity, args, opts \\ [])`**: Creates a `:function_entry` event.
  ```elixir
  @spec function_entry(module :: module(), function :: atom(), arity :: arity(), args :: [term()], opts :: keyword()) :: {:ok, Event.t()} | {:error, Error.t()}
  ```
- **`function_exit(module, function, arity, call_id, result, duration_ns, exit_reason)`**: Creates a `:function_exit` event.
  ```elixir
  @spec function_exit(module :: module(), function :: atom(), arity :: arity(), call_id :: Event.event_id(), result :: term(), duration_ns :: non_neg_integer(), exit_reason :: atom()) :: {:ok, Event.t()} | {:error, Error.t()}
  ```
- **`state_change(server_pid, callback, old_state, new_state, opts \\ [])`**: Creates a `:state_change` event.
  ```elixir
  @spec state_change(server_pid :: pid(), callback :: atom(), old_state :: term(), new_state :: term(), opts :: keyword()) :: {:ok, Event.t()} | {:error, Error.t()}
  ```

### Other Convenience Queries
- **`get_correlation_chain(correlation_id)`**: Retrieves events for a correlation ID, sorted.
  ```elixir
  @spec get_correlation_chain(correlation_id :: String.t()) :: {:ok, [Event.t()]} | {:error, Error.t()}
  ```
- **`get_time_range(start_time, end_time)`**: Retrieves events in a monotonic time range.
  ```elixir
  @spec get_time_range(start_time :: integer(), end_time :: integer()) :: {:ok, [Event.t()]} | {:error, Error.t()}
  ```
- **`get_recent(limit \\ 100)`**: Retrieves the most recent N events.
  ```elixir
  @spec get_recent(limit :: non_neg_integer()) :: {:ok, [Event.t()]} | {:error, Error.t()}
  ```

### Serialization
- **`serialize(event)`**: Serializes an event to binary.
  ```elixir
  @spec serialize(event :: Event.t()) :: {:ok, binary()} | {:error, Error.t()}
  ```
- **`deserialize(binary)`**: Deserializes binary to an event.
  ```elixir
  @spec deserialize(binary :: binary()) :: {:ok, Event.t()} | {:error, Error.t()}
  ```
- **`serialized_size(event)`**: Calculates the size of a serialized event.
  ```elixir
  @spec serialized_size(event :: Event.t()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  ```

### Storage Management
- **`stats/0`**: Get storage statistics.
  ```elixir
  @spec stats() :: {:ok, map()} | {:error, Error.t()}
  ```
- **`prune_before(cutoff_timestamp)`**: Prune events older than a monotonic timestamp.
  ```elixir
  @spec prune_before(cutoff_timestamp :: integer()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  ```

### available?/0
Check if the event store service is available.
```elixir
@spec available?() :: boolean()
```

---

## Telemetry API (`ElixirScope.Foundation.Telemetry`)

Provides metrics collection, event measurement, and monitoring.

### initialize/0, status/0
Initialize/get status of the telemetry service.
```elixir
@spec initialize() :: :ok | {:error, Error.t()}
@spec status() :: {:ok, map()} | {:error, Error.t()}
```

### execute/3
Execute a telemetry event with measurements and metadata. This is the core emission function.
```elixir
@spec execute(event_name :: [atom()], measurements :: map(), metadata :: map()) :: :ok
```
**Example:**
```elixir
ElixirScope.Foundation.Telemetry.execute(
  [:myapp, :request, :duration],
  %{value: 120, unit: :milliseconds},
  %{path: "/users", method: "GET"}
)
```

### measure/3
Measure the execution time of a function and emit a telemetry event.
```elixir
@spec measure(event_name :: [atom()], metadata :: map(), fun :: (-> result)) :: result when result: var
```
**Example:**
```elixir
result = ElixirScope.Foundation.Telemetry.measure(
  [:myapp, :db_query],
  %{table: "users"},
  fn -> Repo.all(User) end
)
```

### emit_counter/2
Emit a counter metric (increments by 1).
```elixir
@spec emit_counter(event_name :: [atom()], metadata :: map()) :: :ok
```

### emit_gauge/3
Emit a gauge metric (absolute value).
```elixir
@spec emit_gauge(event_name :: [atom()], value :: number(), metadata :: map()) :: :ok
```

### get_metrics/0
Retrieve all collected metrics.
```elixir
@spec get_metrics() :: {:ok, map()} | {:error, Error.t()}
```

### attach_handlers/1, detach_handlers/1
Attach/detach custom handlers for specific telemetry event names. Primarily for internal use or advanced scenarios.
```elixir
@spec attach_handlers(event_names :: [[atom()]]) :: :ok | {:error, Error.t()}
@spec detach_handlers(event_names :: [[atom()]]) :: :ok
```

### available?/0
Check if the telemetry service is available.
```elixir
@spec available?() :: boolean()
```

### Convenience Telemetry Emitters
- **`time_function(module, function, fun)`**: Measures execution of `fun`, names event based on `module`/`function`.
  ```elixir
  @spec time_function(module :: module(), function :: atom(), fun :: (-> result)) :: result when result: var
  ```
- **`emit_performance(metric_name, value, metadata \\ %{})`**: Emits a gauge under `[:elixir_scope, :performance, metric_name]`.
  ```elixir
  @spec emit_performance(metric_name :: atom(), value :: number(), metadata :: map()) :: :ok
  ```
- **`emit_system_event(event_type, metadata \\ %{})`**: Emits a counter under `[:elixir_scope, :system, event_type]`.
  ```elixir
  @spec emit_system_event(event_type :: atom(), metadata :: map()) :: :ok
  ```
- **`get_metrics_for(event_pattern)`**: Retrieves metrics matching a specific prefix pattern.
  ```elixir
  @spec get_metrics_for(event_pattern :: [atom()]) :: {:ok, map()} | {:error, Error.t()}
  ```

---

## Utilities API (`ElixirScope.Foundation.Utils`)

Provides general-purpose helper functions used within the Foundation layer and potentially useful for applications integrating with ElixirScope.

### generate_id/0
Generates a unique positive integer ID, typically for events or operations.
```elixir
@spec generate_id() :: pos_integer()
```

### monotonic_timestamp/0
Returns the current monotonic time in nanoseconds. Suitable for duration calculations.
```elixir
@spec monotonic_timestamp() :: integer()
```

### wall_timestamp/0
Returns the current system (wall clock) time in nanoseconds.
```elixir
@spec wall_timestamp() :: integer()
```

### generate_correlation_id/0
Generates a UUID v4 string, suitable for correlating events across operations or systems.
```elixir
@spec generate_correlation_id() :: String.t()
```

### truncate_if_large/1, truncate_if_large/2
Truncates a term if its serialized size exceeds a limit (default 10KB). Returns a map with truncation info if truncated.
```elixir
@spec truncate_if_large(term :: term()) :: term()
@spec truncate_if_large(term :: term(), max_size :: pos_integer()) :: term()
```

### safe_inspect/1
Inspects a term, limiting recursion and printable length to prevent overly long strings. Returns `<uninspectable>` on error.
```elixir
@spec safe_inspect(term :: term()) :: String.t()
```

### deep_merge/2
Recursively merges two maps.
```elixir
@spec deep_merge(left :: map(), right :: map()) :: map()
```

### format_duration/1
Formats a duration (in nanoseconds) into a human-readable string (e.g., "1.5s", "2.5ms").
```elixir
@spec format_duration(nanoseconds :: non_neg_integer()) :: String.t()
```

### format_bytes/1
Formats a byte size into a human-readable string (e.g., "1.0 KB", "1.5 MB").
```elixir
@spec format_bytes(bytes :: non_neg_integer()) :: String.t()
```

### measure/1
Measures the execution time of a function.
```elixir
@spec measure(func :: (-> result)) :: {result, duration_microseconds :: non_neg_integer()} when result: any()
```

### measure_memory/1
Measures memory consumption change due to a function's execution.
```elixir
@spec measure_memory(func :: (-> result)) :: {result, {before_bytes :: non_neg_integer(), after_bytes :: non_neg_integer(), diff_bytes :: integer()}} when result: any()
```

### system_stats/0
Returns a map of current system statistics (process count, memory, schedulers).
```elixir
@spec system_stats() :: map()
```

---

## Service Registry API (`ElixirScope.Foundation.ServiceRegistry`)

High-level API for service registration and discovery, built upon `ProcessRegistry`.

### register/3
Registers a service PID under a specific name within a namespace.
```elixir
@spec register(namespace :: namespace(), service_name :: service_name(), pid :: pid()) :: :ok | {:error, {:already_registered, pid()}}
```
**`namespace`**: `:production` or `{:test, reference()}`
**`service_name`**: An atom like `:config_server`, `:event_store`.

### lookup/2
Looks up a registered service PID.
```elixir
@spec lookup(namespace :: namespace(), service_name :: service_name()) :: {:ok, pid()} | {:error, Error.t()}
```

### unregister/2
Unregisters a service.
```elixir
@spec unregister(namespace :: namespace(), service_name :: service_name()) :: :ok
```

### list_services/1
Lists all service names registered in a namespace.
```elixir
@spec list_services(namespace :: namespace()) :: [service_name()]
```

### health_check/3
Checks if a service is registered, alive, and optionally passes a custom health check function.
```elixir
@spec health_check(namespace :: namespace(), service_name :: service_name(), opts :: keyword()) :: {:ok, pid()} | {:error, term()}
```
**Options:** `:health_check` (function), `:timeout` (ms).

### wait_for_service/3
Waits for a service to become available, up to a timeout.
```elixir
@spec wait_for_service(namespace :: namespace(), service_name :: service_name(), timeout_ms :: pos_integer()) :: {:ok, pid()} | {:error, :timeout}
```

### via_tuple/2
Generates a `{:via, Registry, ...}` tuple for Genserver registration with the underlying ProcessRegistry.
```elixir
@spec via_tuple(namespace :: namespace(), service_name :: service_name()) :: {:via, Registry, {module(), {namespace(), service_name()}}}
```

### get_service_info/1
Get detailed information about all services in a namespace, including PIDs and alive status.
```elixir
@spec get_service_info(namespace :: namespace()) :: map()
```

### cleanup_test_namespace/1
Specifically for testing: terminates and unregisters all services within a `{:test, ref}` namespace.
```elixir
@spec cleanup_test_namespace(test_ref :: reference()) :: :ok
```

---

## Process Registry API (`ElixirScope.Foundation.ProcessRegistry`)

Lower-level, ETS-based process registry providing namespaced registration. Generally, `ServiceRegistry` is preferred for direct use.

### register/3
Registers a PID with a name in a namespace directly in the registry.
```elixir
@spec register(namespace :: namespace(), service_name :: service_name(), pid :: pid()) :: :ok | {:error, {:already_registered, pid()}}
```

### lookup/2
Looks up a PID directly from the registry.
```elixir
@spec lookup(namespace :: namespace(), service_name :: service_name()) :: {:ok, pid()} | :error
```

### via_tuple/2
Generates a `{:via, Registry, ...}` tuple for `GenServer.start_link` using this registry.
```elixir
@spec via_tuple(namespace :: namespace(), service_name :: service_name()) :: {:via, Registry, {module(), {namespace(), service_name()}}}
```
*(Other functions like `unregister/2`, `list_services/1`, `cleanup_test_namespace/1`, `stats/0` also exist but are often accessed via `ServiceRegistry`)*.

---

## Infrastructure Protection API (`ElixirScope.Foundation.Infrastructure`)

Unified facade for applying protection patterns like circuit breakers, rate limiting, and connection pooling.

### initialize_all_infra_components/0
Initializes all underlying infrastructure components (Fuse for circuit breakers, Hammer for rate limiting). Typically called during application startup.
```elixir
@spec initialize_all_infra_components() :: {:ok, []} | {:error, term()}
```

### execute_protected/3
Executes a function with specified protection layers.
```elixir
@spec execute_protected(protection_key :: atom(), options :: keyword(), fun :: (-> term())) :: {:ok, term()} | {:error, term()}
```
**Options (examples):**
- `circuit_breaker: :my_api_breaker`
- `rate_limiter: {:api_calls_per_user, "user_id_123"}`
- `connection_pool: :http_client_pool` (if ConnectionManager is used for this)

**Example:**
```elixir
ElixirScope.Foundation.Infrastructure.execute_protected(
  :external_api_call,
  [circuit_breaker: :api_fuse, rate_limiter: {:api_user_rate, current_user.id}],
  fn -> HTTPoison.get("https://api.example.com/data") end
)
```

### configure_protection/2
Configures protection rules for a given key (e.g., circuit breaker thresholds, rate limits).
```elixir
@spec configure_protection(protection_key :: atom(), config :: map()) :: :ok | {:error, term()}
```
**Config Example:**
```elixir
%{
  circuit_breaker: %{failure_threshold: 3, recovery_time: 15_000}, # For CircuitBreaker
  rate_limiter: %{scale: 60_000, limit: 50} # For RateLimiter
}
```

### get_protection_config/1
Retrieves the current protection configuration for a key.
```elixir
@spec get_protection_config(protection_key :: atom()) :: {:ok, map()} | {:error, :not_found | term()}
```
*(Note: The individual components `CircuitBreaker`, `RateLimiter`, `ConnectionManager` also have their own APIs, but `Infrastructure` provides a unified entry point.)*

---

## Error Context API (`ElixirScope.Foundation.ErrorContext`)

Provides a way to build up contextual information for operations, which can then be used to enrich errors.

### new/3
Creates a new error context for an operation.
```elixir
@spec new(module :: module(), function :: atom(), opts :: keyword()) :: ErrorContext.t()
```
**Options:** `:correlation_id`, `:metadata`, `:parent_context`.

### child_context/4
Creates a new error context that inherits from a parent context.
```elixir
@spec child_context(parent_context :: ErrorContext.t(), module :: module(), function :: atom(), metadata :: map()) :: ErrorContext.t()
```

### add_breadcrumb/4
Adds a breadcrumb (a step in an operation) to the context.
```elixir
@spec add_breadcrumb(context :: ErrorContext.t(), module :: module(), function :: atom(), metadata :: map()) :: ErrorContext.t()
```

### add_metadata/2
Adds or merges metadata into an existing context.
```elixir
@spec add_metadata(context :: ErrorContext.t(), new_metadata :: map()) :: ErrorContext.t()
```

### with_context/2
Executes a function, automatically capturing exceptions and enhancing them with the provided error context.
```elixir
@spec with_context(context :: ErrorContext.t(), fun :: (-> term())) :: term() | {:error, Error.t()}
```
**Example:**
```elixir
context = ElixirScope.Foundation.ErrorContext.new(MyModule, :complex_op)
result = ElixirScope.Foundation.ErrorContext.with_context(context, fn ->
  # ... operations ...
  if some_condition_fails, do: raise("Specific failure")
  :ok
end)

case result do
  {:error, %Error{context: err_ctx}} -> IO.inspect(err_ctx.operation_context) # Will include breadcrumbs, etc.
  _ -> # success
end
```

### enhance_error/2
Adds the operational context from `ErrorContext.t()` to an existing `Error.t()`.
```elixir
@spec enhance_error(error :: Error.t(), context :: ErrorContext.t()) :: Error.t()
@spec enhance_error({:error, Error.t()}, context :: ErrorContext.t()) :: {:error, Error.t()}
@spec enhance_error({:error, term()}, context :: ErrorContext.t()) :: {:error, Error.t()} # Converts raw error to Error.t()
```

---

## Error Handling & Types (`ElixirScope.Foundation.Error`, `ElixirScope.Foundation.Types.Error`)

The Foundation layer uses a structured error system.

### `ElixirScope.Foundation.Types.Error` (Struct)
This is the data structure for all errors.
```elixir
%ElixirScope.Foundation.Types.Error{
  code: pos_integer(),                # Hierarchical error code
  error_type: atom(),                 # Specific error identifier (e.g., :config_path_not_found)
  message: String.t(),
  severity: :low | :medium | :high | :critical,
  context: map() | nil,               # Additional error context
  correlation_id: String.t() | nil,
  timestamp: DateTime.t() | nil,
  stacktrace: list() | nil,           # Formatted stacktrace
  category: atom() | nil,             # E.g., :config, :system, :data
  subcategory: atom() | nil,          # E.g., :validation, :access
  retry_strategy: atom() | nil,       # E.g., :no_retry, :fixed_delay
  recovery_actions: [String.t()] | nil # Suggested actions
}
```

### `ElixirScope.Foundation.Error` (Module)

Provides functions for working with `Types.Error` structs.

#### new/3
Creates a new `Error.t()` struct based on a predefined error type or a custom definition.
```elixir
@spec new(error_type :: atom(), message :: String.t() | nil, opts :: keyword()) :: Error.t()
```
**Options:** `:context`, `:correlation_id`, `:stacktrace`, etc. (to populate `Types.Error` fields).

#### error_result/3
Convenience function to create an `{:error, Error.t()}` tuple.
```elixir
@spec error_result(error_type :: atom(), message :: String.t() | nil, opts :: keyword()) :: {:error, Error.t()}
```

#### wrap_error/4
Wraps an existing error result (either `{:error, Error.t()}` or `{:error, reason}`) with a new `Error.t()`, preserving context.
```elixir
@spec wrap_error(result :: term(), error_type :: atom(), message :: String.t() | nil, opts :: keyword()) :: term()
```

#### to_string/1
Converts an `Error.t()` struct to a human-readable string.
```elixir
@spec to_string(error :: Error.t()) :: String.t()
```

#### is_retryable?/1
Checks if an error suggests a retry strategy.
```elixir
@spec is_retryable?(error :: Error.t()) :: boolean()
```

#### collect_error_metrics/1
Emits telemetry for an error. This is often called internally by error-aware functions.
```elixir
@spec collect_error_metrics(error :: Error.t()) :: :ok
```

---

## Performance Considerations

- **Service Registry:** Uses Elixir's native `Registry` with ETS-based partitioned tables for O(1) lookups.
- **Event Storage (`EventStore`):** In-memory by default (for `repomix-output.xml` version); performance depends on the number of events and query complexity. Batch operations (`store_batch/1`) are more performant for high volumes.
- **Configuration (`ConfigServer`):** In-memory access, very fast. Updates involve notifications which have minimal overhead.
- **Telemetry (`TelemetryService`):** Asynchronous event emission (`GenServer.cast`) to minimize impact on calling processes.
- **Utilities (`Utils`):** Pure functions, performance varies by function (e.g., `deep_merge` can be costly for large, deep maps).

---

## Best Practices

- **Initialization:** Ensure `ElixirScope.Foundation.initialize/1` (or the main `ElixirScope.Application` start) is called early in your application's lifecycle.
- **Configuration:** Use `Config.get_with_default/2` for safe access. Subscribe to changes only when necessary to react to runtime updates.
- **Events:**
    - Use `Events.new_event/3` with `correlation_id` to group related events.
    - Leverage convenience functions like `Events.function_entry/5` for common patterns.
    - Query efficiently using specific filters and limits.
- **Telemetry:**
    - Use `Telemetry.measure/3` for timing critical operations.
    - Employ hierarchical event names (e.g., `[:myapp, :component, :action]`).
    - Include rich, structured metadata.
- **Error Handling:**
    - Pattern match on `{:error, %ElixirScope.Foundation.Types.Error{error_type: type} = err}` to handle specific errors.
    - Use `ElixirScope.Foundation.ErrorContext.with_context/2` for operations to automatically enrich exceptions.
- **Service Registry:** Use `ServiceRegistry.via_tuple/2` for robust GenServer registration. Clean up test namespaces using `ServiceRegistry.cleanup_test_namespace/1`.
- **Infrastructure:** Utilize `Infrastructure.execute_protected/3` for calls to external or potentially unreliable services.

---

## Examples

*(These are conceptual and might be slightly different from the API.md you provided initially, expanded to show more Foundation features.)*

### Complete Application Setup (Conceptual)

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # ElixirScope application itself should start its foundation services
    children = [
      ElixirScope.Application, # This should handle ElixirScope's internal supervision
      # ... Your application's children ...
      {MyApp.MyConfigSubscriber, []} # Example process to react to config changes
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end

defmodule MyApp.MyConfigSubscriber do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to config changes
    :ok = ElixirScope.Foundation.Config.subscribe()
    {:ok, %{debug: false}}
  end

  @impl true
  def handle_info({:config_notification, {:config_updated, [:dev, :debug_mode], new_val}}, state) do
    IO.puts("Debug mode changed to: #{new_val}")
    {:noreply, %{state | debug: new_val}}
  end
  def handle_info(_msg, state), do: {:noreply, state}
end
```

### Request Tracking with Events and Telemetry

```elixir
defmodule MyApp.RequestTracker do
  alias ElixirScope.Foundation.{Events, Telemetry, Utils, ErrorContext}

  def track_request(conn, operation_function) do
    correlation_id = Utils.generate_correlation_id()
    request_context = ErrorContext.new(
      __MODULE__,
      :track_request,
      correlation_id: correlation_id,
      metadata: %{path: conn.request_path, method: conn.method}
    )

    ErrorContext.with_context(request_context, fn ->
      {:ok, start_event} = Events.new_event(
        :request_start,
        %{method: conn.method, path: conn.request_path},
        correlation_id: correlation_id
      )
      Events.store(start_event)

      # Measure the core operation
      {result, duration_ns} = Telemetry.measure(
        [:myapp, :request, :processing_time],
        %{path: conn.request_path, user_id: conn.assigns.current_user_id},
        operation_function
      )

      Events.new_event(
        :request_end,
        %{status: conn.status, duration_ns: duration_ns},
        correlation_id: correlation_id, parent_id: start_event.event_id
      )
      |> Events.store()

      Telemetry.emit_counter([:myapp, :requests_completed], %{status_code: conn.status})
      result # Return result of operation_function
    end)
  end
end
```

## Support and Resources

- **Main Documentation**: [ElixirScope HexDocs Link - Fictional]
- **GitHub Issues**: [ElixirScope GitHub Issues Link - Fictional]
- **Discussions**: [ElixirScope GitHub Discussions Link - Fictional]

---

**Built with ❤️ by the ElixirScope team**

*ElixirScope Foundation - The solid foundation for intelligent Elixir applications*
