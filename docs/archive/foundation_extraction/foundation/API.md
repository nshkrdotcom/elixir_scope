# ElixirScope Foundation Layer - Public API Documentation

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Configuration API](#configuration-api)
4. [Events API](#events-api)
5. [Telemetry API](#telemetry-api)
6. [Foundation API](#foundation-api)
7. [Error Handling](#error-handling)
8. [Performance Considerations](#performance-considerations)
9. [Best Practices](#best-practices)
10. [Examples](#examples)
11. [Migration Guide](#migration-guide)

## Overview

The ElixirScope Foundation Layer provides core utilities, configuration management, event handling, and telemetry for the ElixirScope platform. It offers a clean, well-documented API designed for both ease of use and enterprise-grade performance.

### Key Features

- **🔧 Configuration Management** - Runtime configuration with validation and hot-reloading
- **📊 Event System** - Structured event creation, storage, and querying
- **📈 Telemetry Integration** - Comprehensive metrics collection and monitoring
- **🛡️ Error Handling** - Hierarchical error management with context propagation
- **⚡ High Performance** - Optimized for low latency and high throughput
- **🧪 Test-Friendly** - Built-in support for isolated testing

### System Requirements

- Elixir 1.15+ and OTP 26+
- Memory: ~10MB base + ~100 bytes per registered service
- CPU: Optimized for multi-core systems with automatic partitioning

---

## Getting Started

### Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:elixir_scope, "~> 0.2.0"}
  ]
end
```

### Basic Setup

```elixir
# Start the Foundation layer
{:ok, _} = ElixirScope.Foundation.initialize()

# Check if services are available
true = ElixirScope.Foundation.available?()

# Get system status
{:ok, status} = ElixirScope.Foundation.status()
```

### Quick Example

```elixir
# Configure the system
:ok = ElixirScope.Foundation.Config.update([:dev, :debug_mode], true)

# Create and store an event
{:ok, event} = ElixirScope.Foundation.Events.new_event(:user_action, %{action: "login"})
{:ok, event_id} = ElixirScope.Foundation.Events.store(event)

# Emit telemetry
:ok = ElixirScope.Foundation.Telemetry.emit_counter([:app, :user, :login], %{user_id: 123})
```

---

## Configuration API

The Configuration API provides centralized configuration management with runtime updates, validation, and subscriber notifications.

### ElixirScope.Foundation.Config

#### initialize/0, initialize/1

Initialize the configuration service.

```elixir
@spec initialize() :: :ok | {:error, Error.t()}
@spec initialize(keyword()) :: :ok | {:error, Error.t()}
```

**Parameters:**
- `opts` (optional) - Configuration options

**Returns:**
- `:ok` on success
- `{:error, Error.t()}` on failure

**Example:**
```elixir
# Initialize with defaults
:ok = ElixirScope.Foundation.Config.initialize()

# Initialize with custom options
:ok = ElixirScope.Foundation.Config.initialize(cache_size: 1000)
```

#### get/0, get/1

Retrieve configuration values.

```elixir
@spec get() :: {:ok, Config.t()} | {:error, Error.t()}
@spec get([atom()]) :: {:ok, term()} | {:error, Error.t()}
```

**Parameters:**
- `path` (optional) - Configuration path as list of atoms

**Returns:**
- `{:ok, value}` - Configuration value
- `{:error, Error.t()}` - Error if path not found or service unavailable

**Examples:**
```elixir
# Get complete configuration
{:ok, config} = ElixirScope.Foundation.Config.get()

# Get specific value
{:ok, provider} = ElixirScope.Foundation.Config.get([:ai, :provider])
# Returns: {:ok, :mock}

# Get nested value
{:ok, timeout} = ElixirScope.Foundation.Config.get([:interface, :query_timeout])
# Returns: {:ok, 10000}

# Handle missing path
{:error, error} = ElixirScope.Foundation.Config.get([:nonexistent, :path])
# Returns: {:error, %Error{error_type: :config_path_not_found}}
```

#### update/2

Update configuration values at runtime.

```elixir
@spec update([atom()], term()) :: :ok | {:error, Error.t()}
```

**Parameters:**
- `path` - Configuration path (must be in updatable paths)
- `value` - New value

**Returns:**
- `:ok` on successful update
- `{:error, Error.t()}` on validation failure or forbidden path

**Examples:**
```elixir
# Update sampling rate
:ok = ElixirScope.Foundation.Config.update([:ai, :planning, :sampling_rate], 0.8)

# Update debug mode
:ok = ElixirScope.Foundation.Config.update([:dev, :debug_mode], true)

# Try to update forbidden path
{:error, error} = ElixirScope.Foundation.Config.update([:ai, :api_key], "secret")
# Returns: {:error, %Error{error_type: :config_update_forbidden}}
```

#### updatable_paths/0

Get list of configuration paths that can be updated at runtime.

```elixir
@spec updatable_paths() :: [[atom(), ...], ...]
```

**Returns:**
- List of updatable configuration paths

**Example:**
```elixir
paths = ElixirScope.Foundation.Config.updatable_paths()
# Returns: [
#   [:ai, :planning, :sampling_rate],
#   [:ai, :planning, :performance_target],
#   [:capture, :processing, :batch_size],
#   [:dev, :debug_mode],
#   ...
# ]
```

#### subscribe/0, unsubscribe/0

Subscribe to configuration change notifications.

```elixir
@spec subscribe() :: :ok | {:error, Error.t()}
@spec unsubscribe() :: :ok | {:error, Error.t()}
```

**Returns:**
- `:ok` on success
- `{:error, Error.t()}` on failure

**Example:**
```elixir
# Subscribe to config changes
:ok = ElixirScope.Foundation.Config.subscribe()

# You'll receive messages like:
# {:config_notification, {:config_updated, [:dev, :debug_mode], true}}

# Unsubscribe
:ok = ElixirScope.Foundation.Config.unsubscribe()
```

#### available?/0, status/0

Check service availability and get status information.

```elixir
@spec available?() :: boolean()
@spec status() :: {:ok, map()} | {:error, Error.t()}
```

**Examples:**
```elixir
# Check if service is available
true = ElixirScope.Foundation.Config.available?()

# Get detailed status
{:ok, status} = ElixirScope.Foundation.Config.status()
# Returns: {:ok, %{
#   status: :running,
#   uptime_ms: 3600000,
#   updates_count: 15,
#   subscribers_count: 3
# }}
```

#### Helper Functions

```elixir
# Get configuration with default fallback
@spec get_with_default([atom()], term()) :: term()
sampling_rate = ElixirScope.Foundation.Config.get_with_default([:ai, :sampling_rate], 1.0)

# Safe update (checks if path is updatable)
@spec safe_update([atom()], term()) :: :ok | {:error, Error.t()}
:ok = ElixirScope.Foundation.Config.safe_update([:dev, :debug_mode], true)
```

---

## Events API

The Events API provides structured event creation, storage, querying, and serialization capabilities.

### ElixirScope.Foundation.Events

#### initialize/0, status/0

Initialize the event system and get status information.

```elixir
@spec initialize() :: :ok | {:error, Error.t()}
@spec status() :: {:ok, map()} | {:error, Error.t()}
```

**Examples:**
```elixir
# Initialize events system
:ok = ElixirScope.Foundation.Events.initialize()

# Get status
{:ok, status} = ElixirScope.Foundation.Events.status()
# Returns: {:ok, %{status: :running, event_count: 1500, next_id: 1501}}
```

#### new_event/2, new_event/3

Create new structured events.

```elixir
@spec new_event(atom(), term()) :: {:ok, Event.t()} | {:error, Error.t()}
@spec new_event(atom(), term(), keyword()) :: {:ok, Event.t()} | {:error, Error.t()}
```

**Parameters:**
- `event_type` - Event type atom
- `data` - Event data (any term)
- `opts` - Optional parameters (correlation_id, parent_id, etc.)

**Returns:**
- `{:ok, Event.t()}` - Created event
- `{:error, Error.t()}` - Validation error

**Examples:**
```elixir
# Simple event
{:ok, event} = ElixirScope.Foundation.Events.new_event(:user_login, %{user_id: 123})

# Event with correlation ID
{:ok, event} = ElixirScope.Foundation.Events.new_event(
  :payment_processed,
  %{amount: 100, currency: "USD"},
  correlation_id: "req-abc-123"
)

# Event with parent relationship
{:ok, event} = ElixirScope.Foundation.Events.new_event(
  :validation_step,
  %{field: "email", valid: true},
  parent_id: parent_event.event_id,
  correlation_id: "req-abc-123"
)
```

#### store/1, store_batch/1

Store events in the event store.

```elixir
@spec store(Event.t()) :: {:ok, event_id()} | {:error, Error.t()}
@spec store_batch([Event.t()]) :: {:ok, [event_id()]} | {:error, Error.t()}
```

**Parameters:**
- `event` - Event to store
- `events` - List of events for batch storage

**Returns:**
- `{:ok, event_id}` or `{:ok, [event_ids]}` - Assigned event IDs
- `{:error, Error.t()}` - Storage error

**Examples:**
```elixir
# Store single event
{:ok, event} = ElixirScope.Foundation.Events.new_event(:user_action, %{action: "click"})
{:ok, event_id} = ElixirScope.Foundation.Events.store(event)

# Store multiple events atomically
{:ok, events} = create_multiple_events()
{:ok, event_ids} = ElixirScope.Foundation.Events.store_batch(events)
```

#### get/1, query/1

Retrieve and query stored events.

```elixir
@spec get(event_id()) :: {:ok, Event.t()} | {:error, Error.t()}
@spec query(map() | keyword()) :: {:ok, [Event.t()]} | {:error, Error.t()}
```

**Parameters:**
- `event_id` - Event ID to retrieve
- `query` - Query parameters map or keyword list

**Query Parameters:**
- `:event_type` - Filter by event type
- `:time_range` - `{start_time, end_time}` tuple
- `:limit` - Maximum number of results
- `:offset` - Number of results to skip
- `:order_by` - `:event_id` or `:timestamp`

**Examples:**
```elixir
# Get specific event
{:ok, event} = ElixirScope.Foundation.Events.get(12345)

# Query by event type
{:ok, events} = ElixirScope.Foundation.Events.query(%{
  event_type: :user_login,
  limit: 100
})

# Query with time range
start_time = System.monotonic_time() - 3600_000  # 1 hour ago
end_time = System.monotonic_time()
{:ok, events} = ElixirScope.Foundation.Events.query(%{
  time_range: {start_time, end_time},
  order_by: :timestamp,
  limit: 500
})

# Query recent events
{:ok, recent_events} = ElixirScope.Foundation.Events.get_recent(50)
```

#### get_by_correlation/1

Retrieve all events with the same correlation ID.

```elixir
@spec get_by_correlation(String.t()) :: {:ok, [Event.t()]} | {:error, Error.t()}
```

**Example:**
```elixir
{:ok, related_events} = ElixirScope.Foundation.Events.get_by_correlation("req-abc-123")
# Returns all events that share the correlation ID, sorted by timestamp
```

#### Convenience Functions

```elixir
# Create function entry event
{:ok, entry_event} = ElixirScope.Foundation.Events.function_entry(
  MyModule, :my_function, 2, [arg1, arg2]
)

# Create function exit event
{:ok, exit_event} = ElixirScope.Foundation.Events.function_exit(
  MyModule, :my_function, 2, call_id, result, duration_ns, :normal
)

# Create state change event
{:ok, state_event} = ElixirScope.Foundation.Events.state_change(
  server_pid, :handle_call, old_state, new_state
)

# Get correlation chain
{:ok, chain} = ElixirScope.Foundation.Events.get_correlation_chain("req-abc-123")

# Get events in time range
{:ok, events} = ElixirScope.Foundation.Events.get_time_range(start_time, end_time)
```

#### Serialization

```elixir
# Serialize event to binary
{:ok, event} = ElixirScope.Foundation.Events.new_event(:test, %{data: "example"})
{:ok, binary} = ElixirScope.Foundation.Events.serialize(event)

# Deserialize binary to event
{:ok, restored_event} = ElixirScope.Foundation.Events.deserialize(binary)

# Calculate serialized size
{:ok, size_bytes} = ElixirScope.Foundation.Events.serialized_size(event)
```

#### Storage Management

```elixir
# Get storage statistics
{:ok, stats} = ElixirScope.Foundation.Events.stats()
# Returns: {:ok, %{
#   current_event_count: 15000,
#   events_stored: 50000,
#   events_pruned: 1000,
#   memory_usage_estimate: 15728640,
#   uptime_ms: 3600000
# }}

# Prune old events
cutoff_time = System.monotonic_time() - 86400_000  # 24 hours ago
{:ok, pruned_count} = ElixirScope.Foundation.Events.prune_before(cutoff_time)
```

---

## Telemetry API

The Telemetry API provides comprehensive metrics collection, event measurement, and monitoring capabilities.

### ElixirScope.Foundation.Telemetry

#### initialize/0, status/0

Initialize telemetry service and get status information.

```elixir
@spec initialize() :: :ok | {:error, Error.t()}
@spec status() :: {:ok, map()} | {:error, Error.t()}
```

**Examples:**
```elixir
# Initialize telemetry
:ok = ElixirScope.Foundation.Telemetry.initialize()

# Get status
{:ok, status} = ElixirScope.Foundation.Telemetry.status()
# Returns: {:ok, %{
#   status: :running,
#   metrics_count: 50,
#   handlers_count: 5
# }}
```

#### execute/3

Execute telemetry events with measurements and metadata.

```elixir
@spec execute([atom()], map(), map()) :: :ok
```

**Parameters:**
- `event_name` - Event name as list of atoms
- `measurements` - Map of numeric measurements
- `metadata` - Map of additional context

**Example:**
```elixir
ElixirScope.Foundation.Telemetry.execute(
  [:elixir_scope, :query, :execution],
  %{duration: 1500, memory_used: 1024},
  %{query_type: :complex, user_id: 123}
)
```

#### measure/3

Measure execution time of a function.

```elixir
@spec measure([atom()], map(), (-> result)) :: result when result: var
```

**Parameters:**
- `event_name` - Event name for the measurement
- `metadata` - Additional context
- `fun` - Zero-arity function to measure

**Example:**
```elixir
result = ElixirScope.Foundation.Telemetry.measure(
  [:elixir_scope, :database, :query],
  %{table: "users", operation: "select"},
  fn ->
    # Expensive database operation
    Repo.all(User)
  end
)
# Automatically emits duration telemetry
```

#### emit_counter/2, emit_gauge/3

Emit specific metric types.

```elixir
@spec emit_counter([atom()], map()) :: :ok
@spec emit_gauge([atom()], number(), map()) :: :ok
```

**Examples:**
```elixir
# Emit counter
ElixirScope.Foundation.Telemetry.emit_counter(
  [:elixir_scope, :user, :login],
  %{user_type: "premium", source: "web"}
)

# Emit gauge
ElixirScope.Foundation.Telemetry.emit_gauge(
  [:elixir_scope, :memory, :usage],
  :erlang.memory(:total),
  %{node: Node.self()}
)
```

#### get_metrics/0

Retrieve collected metrics.

```elixir
@spec get_metrics() :: {:ok, map()} | {:error, Error.t()}
```

**Example:**
```elixir
{:ok, metrics} = ElixirScope.Foundation.Telemetry.get_metrics()
# Returns: {:ok, %{
#   [:elixir_scope, :user, :login] => %{
#     timestamp: 1634567890,
#     measurements: %{counter: 150},
#     count: 150
#   },
#   ...
# }}
```

#### Convenience Functions

```elixir
# Time a function with automatic event naming
result = ElixirScope.Foundation.Telemetry.time_function(
  MyModule, :expensive_function,
  fn -> MyModule.expensive_function(arg1, arg2) end
)

# Emit performance metrics
ElixirScope.Foundation.Telemetry.emit_performance(
  :query_duration, 1500, %{complexity: :high}
)

# Emit system events
ElixirScope.Foundation.Telemetry.emit_system_event(
  :error, %{error_type: :validation, module: MyModule}
)

# Get metrics for specific pattern
{:ok, function_metrics} = ElixirScope.Foundation.Telemetry.get_metrics_for(
  [:elixir_scope, :function]
)
```

---

## Foundation API

The Foundation API provides system-level operations and health monitoring.

### ElixirScope.Foundation

#### initialize/1

Initialize the entire Foundation layer.

```elixir
@spec initialize(keyword()) :: :ok | {:error, Error.t()}
```

**Parameters:**
- `opts` - Initialization options for each service

**Example:**
```elixir
:ok = ElixirScope.Foundation.initialize(
  config: [debug_mode: true],
  telemetry: [enable_vm_metrics: true]
)
```

#### status/0

Get comprehensive status of all Foundation services.

```elixir
@spec status() :: {:ok, map()} | {:error, Error.t()}
```

**Example:**
```elixir
{:ok, status} = ElixirScope.Foundation.status()
# Returns: {:ok, %{
#   config: %{status: :running, uptime_ms: 3600000},
#   events: %{status: :running, event_count: 15000},
#   telemetry: %{status: :running, metrics_count: 50}
# }}
```

#### available?/0

Check if all Foundation services are available.

```elixir
@spec available?() :: boolean()
```

**Example:**
```elixir
if ElixirScope.Foundation.available?() do
  # All services are ready
  proceed_with_operations()
else
  # Some services are unavailable
  handle_degraded_mode()
end
```

#### health/0

Get detailed health information for monitoring.

```elixir
@spec health() :: {:ok, map()} | {:error, Error.t()}
```

**Example:**
```elixir
{:ok, health} = ElixirScope.Foundation.health()
# Returns: {:ok, %{
#   status: :healthy,  # :healthy, :degraded, or :unhealthy
#   timestamp: 1634567890123,
#   services: %{...},
#   foundation_available: true,
#   elixir_version: "1.15.0",
#   otp_release: "26"
# }}
```

#### version/0, shutdown/0

Get version information and shutdown services.

```elixir
@spec version() :: String.t()
@spec shutdown() :: :ok
```

**Examples:**
```elixir
# Get version
version = ElixirScope.Foundation.version()
# Returns: "0.2.0"

# Graceful shutdown
:ok = ElixirScope.Foundation.shutdown()
```

---

## Error Handling

The Foundation layer provides comprehensive error handling with structured error types, context propagation, and recovery mechanisms.

### Error Types

All APIs return structured errors conforming to the `ElixirScope.Foundation.Types.Error` specification.

#### Error Structure

```elixir
%ElixirScope.Foundation.Types.Error{
  code: 1001,                           # Hierarchical error code
  error_type: :config_path_not_found,   # Specific error identifier
  message: "Configuration path not found: [:nonexistent]",
  severity: :medium,                    # :low, :medium, :high, :critical
  context: %{path: [:nonexistent]},     # Additional error context
  correlation_id: "req-abc-123",        # Request correlation
  timestamp: ~U[2023-10-01 12:00:00Z],  # When error occurred
  category: :config,                    # High-level category
  subcategory: :access,                 # Specific subcategory
  retry_strategy: :no_retry,            # Retry recommendation
  recovery_actions: ["Check path", "Review docs"]  # Suggested actions
}
```

#### Error Categories

| Category | Code Range | Description |
|----------|------------|-------------|
| Config   | 1000-1999  | Configuration-related errors |
| System   | 2000-2999  | System and service errors |
| Data     | 3000-3999  | Data validation and processing errors |
| External | 4000-4999  | External service and network errors |

#### Common Error Types

```elixir
# Configuration errors
{:error, %Error{error_type: :config_path_not_found}}
{:error, %Error{error_type: :config_update_forbidden}}
{:error, %Error{error_type: :invalid_config_value}}

# Service errors
{:error, %Error{error_type: :service_unavailable}}
{:error, %Error{error_type: :service_not_found}}

# Data errors
{:error, %Error{error_type: :validation_failed}}
{:error, %Error{error_type: :serialization_failed}}
{:error, %Error{error_type: :data_too_large}}
```

### Error Handling Patterns

#### Basic Error Handling

```elixir
case ElixirScope.Foundation.Config.get([:nonexistent, :path]) do
  {:ok, value} ->
    # Success path
    process_value(value)
    
  {:error, %Error{error_type: :config_path_not_found} = error} ->
    # Handle specific error type
    Logger.warning("Config path not found: #{error.message}")
    use_default_value()
    
  {:error, %Error{error_type: :service_unavailable}} ->
    # Handle service unavailability
    :timer.sleep(1000)
    retry_operation()
    
  {:error, error} ->
    # Handle other errors
    Logger.error("Unexpected error: #{Error.to_string(error)}")
    {:error, :operation_failed}
end
```

#### Pattern Matching on Error Categories

```elixir
case ElixirScope.Foundation.Events.store(event) do
  {:ok, event_id} ->
    {:ok, event_id}
    
  {:error, %Error{category: :data, error_type: :validation_failed} = error} ->
    # Data validation error - fix the event
    Logger.warning("Event validation failed: #{error.message}")
    fix_and_retry_event(event, error.context)
    
  {:error, %Error{category: :system, severity: :high}} ->
    # High-severity system error - escalate
    escalate_to_ops_team(error)
    
  {:error, %Error{retry_strategy: strategy} = error} when strategy != :no_retry ->
    # Retryable error - implement retry logic
    retry_with_backoff(fn -> ElixirScope.Foundation.Events.store(event) end, error)
    
  {:error, error} ->
    # Non-retryable error
    Logger.error("Event storage failed: #{Error.to_string(error)}")
    {:error, :storage_failed}
end
```

#### Error Context and Recovery

```elixir
# Errors include recovery suggestions
{:error, %Error{recovery_actions: actions} = error} = 
  ElixirScope.Foundation.Config.update([:invalid, :path], value)

Logger.error("Config update failed: #{error.message}")
Logger.info("Suggested recovery actions:")
Enum.each(actions, &Logger.info("  - #{&1}"))

# Errors include context for debugging
{:error, %Error{context: context}} = 
  ElixirScope.Foundation.Events.new_event(:invalid_type, data)

Logger.debug("Error context: #{inspect(context)}")
```

---

## Performance Considerations

The Foundation layer is optimized for high performance and low latency operations.

### Performance Characteristics

| Operation | Time Complexity | Typical Latency | Memory Usage |
|-----------|----------------|-----------------|--------------|
| Config Get | O(1) | < 1μs | Minimal |
| Config Update | O(1) + validation | < 100μs | Minimal |
| Event Creation | O(1) | < 10μs | ~200 bytes |
| Event Storage | O(1) | < 50μs | ~500 bytes |
| Event Query | O(log n) to O(n) | < 1ms | Variable |
| Service Lookup | O(1) | < 1μs | Minimal |
| Telemetry Emit | O(1) | < 5μs | ~100 bytes |

### Registry Performance

The ProcessRegistry is optimized for high concurrency:

- **Partitioned Storage**: CPU-core optimized partitions
- **Lock-Free Reads**: Concurrent read operations
- **Automatic Cleanup**: Dead process monitoring
- **Memory Efficiency**: ~100 bytes per registered process

### Optimization Tips

#### Configuration

```elixir
# Cache frequently accessed config values
defmodule MyApp.Config do
  @sampling_rate ElixirScope.Foundation.Config.get_with_default(
    [:ai, :planning, :sampling_rate], 1.0
  )
  
  def sampling_rate, do: @sampling_rate
end

# Subscribe to config changes for cache invalidation
ElixirScope.Foundation.Config.subscribe()
```

#### Event Processing

```elixir
# Use batch operations for multiple events
events = create_multiple_events(data_list)
{:ok, event_ids} = ElixirScope.Foundation.Events.store_batch(events)

# Prefer specific queries over broad searches
{:ok, events} = ElixirScope.Foundation.Events.query(%{
  event_type: :user_action,
  time_range: {recent_time, now},
  limit: 100
})
```

#### Telemetry

```elixir
# Use measure/3 for automatic timing
result = ElixirScope.Foundation.Telemetry.measure(
  [:app, :operation],
  %{type: :important},
  fn -> expensive_operation() end
)

# Batch telemetry emissions when possible
Enum.each(user_actions, fn action ->
  ElixirScope.Foundation.Telemetry.emit_counter(
    [:app, :user, :action], 
    %{action_type: action.type}
  )
end)
```

---

## Best Practices

### Configuration Management

1. **Use Hierarchical Paths**: Organize configuration logically
   ```elixir
   # Good
   [:ai, :planning, :sampling_rate]
   [:capture, :processing, :batch_size]
   
   # Avoid
   [:ai_planning_sampling_rate]
   ```

2. **Validate Before Update**: Check if paths are updatable
   ```elixir
   # Check updatable paths first
   if path in ElixirScope.Foundation.Config.updatable_paths() do
     ElixirScope.Foundation.Config.update(path, value)
   end
   ```

3. **Subscribe to Changes**: React to configuration updates
   ```elixir
   ElixirScope.Foundation.Config.subscribe()
   
   def handle_info({:config_notification, {:config_updated, path, value}}, state) do
     # Update internal state based on config change
     {:noreply, update_state_for_config(state, path, value)}
   end
   ```

### Event Management

1. **Use Correlation IDs**: Track related events
   ```elixir
   correlation_id = ElixirScope.Foundation.Utils.generate_correlation_id()
   
   {:ok, start_event} = ElixirScope.Foundation.Events.new_event(
     :operation_start, data, correlation_id: correlation_id
   )
   
   {:ok, end_event} = ElixirScope.Foundation.Events.new_event(
     :operation_end, result, 
     correlation_id: correlation_id,
     parent_id: start_event.event_id
   )
   ```

2. **Structure Event Data**: Use consistent data formats
   ```elixir
   # Good: Structured data
   {:ok, event} = ElixirScope.Foundation.Events.new_event(:user_action, %{
     user_id: 123,
     action: "login",
     source: "web",
     timestamp: DateTime.utc_now(),
     metadata: %{ip: "192.168.1.1", user_agent: "..."}
   })
   
   # Avoid: Unstructured data
   {:ok, event} = ElixirScope.Foundation.Events.new_event(:user_action, 
     "user 123 logged in from web"
   )
   ```

3. **Query Efficiently**: Use specific filters
   ```elixir
   # Good: Specific query
   {:ok, events} = ElixirScope.Foundation.Events.query(%{
     event_type: :user_login,
     time_range: {start_time, end_time},
     limit: 100
   })
   
   # Avoid: Broad query
   {:ok, all_events} = ElixirScope.Foundation.Events.query(%{})
   filtered_events = Enum.filter(all_events, &(&1.event_type == :user_login))
   ```

### Telemetry Integration

1. **Use Meaningful Event Names**: Follow hierarchical naming
   ```elixir
   # Good: Hierarchical and descriptive
   ElixirScope.Foundation.Telemetry.execute(
     [:myapp, :user, :authentication, :success],
     %{duration: 150},
     %{provider: "oauth", user_type: "premium"}
   )
   
   # Avoid: Flat or unclear names
   ElixirScope.Foundation.Telemetry.execute(
     [:auth_success],
     %{duration: 150},
     %{}
   )
   ```

2. **Include Rich Metadata**: Provide context for analysis
   ```elixir
   ElixirScope.Foundation.Telemetry.emit_counter(
     [:myapp, :api, :request],
     %{
       endpoint: "/api/v1/users",
       method: "GET",
       status_code: 200,
       user_type: "authenticated",
       region: "us-east-1"
     }
   )
   ```

3. **Measure What Matters**: Focus on business-critical metrics
   ```elixir
   # Business metrics
   ElixirScope.Foundation.Telemetry.measure(
     [:myapp, :order, :processing],
     %{order_value: order.total, customer_tier: customer.tier},
     fn -> process_order(order) end
   )
   
   # Performance metrics
   ElixirScope.Foundation.Telemetry.emit_gauge(
     [:myapp, :database, :connection_pool],
     connection_pool_size(),
     %{database: "primary"}
   )
   ```

### Error Handling

1. **Handle Errors Appropriately**: Match on error types
   ```elixir
   case ElixirScope.Foundation.Events.store(event) do
     {:ok, event_id} -> 
       {:ok, event_id}
       
     {:error, %Error{error_type: :validation_failed} = error} ->
       # Fix and retry
       fixed_event = fix_event(event, error.context)
       ElixirScope.Foundation.Events.store(fixed_event)
       
     {:error, %Error{error_type: :service_unavailable}} ->
       # Graceful degradation
       store_in_fallback_buffer(event)
       
     {:error, error} ->
       # Log and propagate
       Logger.error("Event storage failed: #{Error.to_string(error)}")
       {:error, :storage_failed}
   end
   ```

2. **Use Error Context**: Leverage provided information
   ```elixir
   {:error, %Error{recovery_actions: actions, context: context} = error} = 
     problematic_operation()
   
   Logger.error("Operation failed: #{error.message}")
   Logger.debug("Error context: #{inspect(context)}")
   
   if error.retry_strategy != :no_retry do
     schedule_retry(operation, error.retry_strategy)
   else
     Enum.each(actions, &Logger.info("Suggested action: #{&1}"))
   end
   ```

### Testing

1. **Use Test Namespaces**: Isolate test processes
   ```elixir
   defmodule MyTest do
     use ExUnit.Case
     
     setup do
       test_ref = make_ref()
       namespace = {:test, test_ref}
       
       # Services automatically use test namespace
       :ok = ElixirScope.Foundation.initialize()
       
       on_exit(fn ->
         ElixirScope.Foundation.ServiceRegistry.cleanup_test_namespace(test_ref)
       end)
       
       {:ok, namespace: namespace}
     end
   end
   ```

2. **Reset State Between Tests**: Ensure test isolation
   ```elixir
   setup do
     # Reset all Foundation services
     :ok = ElixirScope.Foundation.Services.ConfigServer.reset_state()
     :ok = ElixirScope.Foundation.Services.EventStore.reset_state()
     :ok = ElixirScope.Foundation.Services.TelemetryService.reset_state()
     
     :ok
   end
   ```

---

## Examples

### Complete Application Setup

```elixir
defmodule MyApp.Application do
  use Application
  
  def start(_type, _args) do
    # Initialize Foundation layer first
    :ok = ElixirScope.Foundation.initialize()
    
    # Configure the application
    configure_application()
    
    # Start your application's supervision tree
    children = [
      MyApp.Supervisor,
      # ... other children
    ]
    
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  defp configure_application do
    # Set up configuration
    :ok = ElixirScope.Foundation.Config.update([:dev, :debug_mode], 
      Application.get_env(:myapp, :debug_mode, false))
    
    # Subscribe to config changes
    :ok = ElixirScope.Foundation.Config.subscribe()
    
    # Set up telemetry
    :ok = ElixirScope.Foundation.Telemetry.attach_handlers([
      [:myapp, :request],
      [:myapp, :database],
      [:myapp, :cache]
    ])
  end
end
```

### Request Tracking Example

```elixir
defmodule MyApp.RequestTracker do
  @moduledoc "Track HTTP requests using Foundation layer"
  
  def track_request(conn, operation) do
    correlation_id = get_or_generate_correlation_id(conn)
    
    # Create request start event
    {:ok, start_event} = ElixirScope.Foundation.Events.new_event(
      :request_start,
      %{
        method: conn.method,
        path: conn.request_path,
        user_id: get_user_id(conn),
        ip_address: get_client_ip(conn)
      },
      correlation_id: correlation_id
    )
    
    {:ok, _} = ElixirScope.Foundation.Events.store(start_event)
    
    # Measure request processing
    {result, processing_time} = ElixirScope.Foundation.Telemetry.measure(
      [:myapp, :request, :processing],
      %{
        method: conn.method,
        path: conn.request_path,
        user_type: get_user_type(conn)
      },
      fn -> operation.() end
    )
    
    # Create request end event
    {:ok, end_event} = ElixirScope.Foundation.Events.new_event(
      :request_end,
      %{
        status_code: get_status_code(result),
        processing_time_us: processing_time,
        response_size: get_response_size(result)
      },
      correlation_id: correlation_id,
      parent_id: start_event.event_id
    )
    
    {:ok, _} = ElixirScope.Foundation.Events.store(end_event)
    
    # Emit telemetry
    ElixirScope.Foundation.Telemetry.emit_counter(
      [:myapp, :request, :completed],
      %{
        method: conn.method,
        status_code: get_status_code(result),
        user_type: get_user_type(conn)
      }
    )
    
    result
  end
  
  defp get_or_generate_correlation_id(conn) do
    case Plug.Conn.get_req_header(conn, "x-correlation-id") do
      [correlation_id] -> correlation_id
      [] -> ElixirScope.Foundation.Utils.generate_correlation_id()
    end
  end
  
  # ... other helper functions
end
```

### Configuration-Driven Feature Flags

```elixir
defmodule MyApp.FeatureFlags do
  @moduledoc "Feature flags using Foundation configuration"
  
  def enabled?(feature_name) do
    path = [:features, feature_name, :enabled]
    
    case ElixirScope.Foundation.Config.get(path) do
      {:ok, enabled} when is_boolean(enabled) -> enabled
      {:ok, _} -> false  # Invalid value, default to disabled
      {:error, _} -> false  # Feature not configured, default to disabled
    end
  end
  
  def enable_feature(feature_name) do
    path = [:features, feature_name, :enabled]
    ElixirScope.Foundation.Config.update(path, true)
  end
  
  def disable_feature(feature_name) do
    path = [:features, feature_name, :enabled]
    ElixirScope.Foundation.Config.update(path, false)
  end
  
  def track_feature_usage(feature_name, user_id) do
    if enabled?(feature_name) do
      # Track feature usage
      ElixirScope.Foundation.Telemetry.emit_counter(
        [:myapp, :feature, :usage],
        %{feature: feature_name, user_id: user_id}
      )
      
      # Store feature usage event
      {:ok, event} = ElixirScope.Foundation.Events.new_event(
        :feature_used,
        %{feature: feature_name, user_id: user_id, timestamp: DateTime.utc_now()}
      )
      
      ElixirScope.Foundation.Events.store(event)
      
      true
    else
      false
    end
  end
end

# Usage
if MyApp.FeatureFlags.track_feature_usage(:new_dashboard, user.id) do
  render_new_dashboard(conn, user)
else
  render_old_dashboard(conn, user)
end
```

### Event-Driven Architecture Example

```elixir
defmodule MyApp.OrderProcessor do
  @moduledoc "Order processing with comprehensive event tracking"
  
  def process_order(order_data) do
    correlation_id = ElixirScope.Foundation.Utils.generate_correlation_id()
    
    # Start order processing
    {:ok, start_event} = create_and_store_event(
      :order_processing_started,
      %{order_id: order_data.id, customer_id: order_data.customer_id},
      correlation_id: correlation_id
    )
    
    try do
      # Validate order
      {:ok, validated_order} = validate_order(order_data, correlation_id, start_event.event_id)
      
      # Process payment
      {:ok, payment_result} = process_payment(validated_order, correlation_id, start_event.event_id)
      
      # Update inventory
      {:ok, inventory_result} = update_inventory(validated_order, correlation_id, start_event.event_id)
      
      # Complete order
      {:ok, completed_order} = complete_order(validated_order, correlation_id, start_event.event_id)
      
      # Success event
      create_and_store_event(
        :order_processing_completed,
        %{
          order_id: completed_order.id,
          processing_time_ms: calculate_processing_time(start_event),
          total_amount: completed_order.total
        },
        correlation_id: correlation_id,
        parent_id: start_event.event_id
      )
      
      {:ok, completed_order}
      
    rescue
      error ->
        # Error event
        create_and_store_event(
          :order_processing_failed,
          %{
            order_id: order_data.id,
            error_type: error.__struct__,
            error_message: Exception.message(error),
            processing_time_ms: calculate_processing_time(start_event)
          },
          correlation_id: correlation_id,
          parent_id: start_event.event_id
        )
        
        {:error, error}
    end
  end
  
  defp validate_order(order_data, correlation_id, parent_id) do
    ElixirScope.Foundation.Telemetry.measure(
      [:myapp, :order, :validation],
      %{order_type: order_data.type},
      fn ->
        # Validation logic here
        result = perform_validation(order_data)
        
        # Track validation result
        create_and_store_event(
          :order_validated,
          %{order_id: order_data.id, validation_result: result},
          correlation_id: correlation_id,
          parent_id: parent_id
        )
        
        result
      end
    )
  end
  
  defp create_and_store_event(event_type, data, opts \\ []) do
    {:ok, event} = ElixirScope.Foundation.Events.new_event(event_type, data, opts)
    {:ok, _event_id} = ElixirScope.Foundation.Events.store(event)
    {:ok, event}
  end
  
  # ... other helper functions
end
```

### Health Check Implementation

```elixir
defmodule MyApp.HealthCheck do
  @moduledoc "Application health check using Foundation layer"
  
  def health_status do
    checks = [
      {"foundation", check_foundation()},
      {"database", check_database()},
      {"external_api", check_external_api()}
    ]
    
    overall_status = determine_overall_status(checks)
    
    %{
      status: overall_status,
      timestamp: DateTime.utc_now(),
      checks: Map.new(checks),
      foundation_info: get_foundation_info()
    }
  end
  
  defp check_foundation do
    if ElixirScope.Foundation.available?() do
      case ElixirScope.Foundation.health() do
        {:ok, %{status: :healthy}} -> :healthy
        {:ok, %{status: :degraded}} -> :degraded
        {:ok, %{status: status}} -> status
        {:error, _} -> :unhealthy
      end
    else
      :unhealthy
    end
  end
  
  defp get_foundation_info do
    case ElixirScope.Foundation.status() do
      {:ok, status} -> status
      {:error, _} -> %{error: "Foundation not available"}
    end
  end
  
  defp determine_overall_status(checks) do
    statuses = Enum.map(checks, fn {_name, status} -> status end)
    
    cond do
      Enum.all?(statuses, &(&1 == :healthy)) -> :healthy
      Enum.any?(statuses, &(&1 == :unhealthy)) -> :unhealthy
      true -> :degraded
    end
  end
  
  # Track health check results
  def track_health_check do
    status = health_status()
    
    # Store health check event
    {:ok, _} = ElixirScope.Foundation.Events.new_event(
      :health_check_performed,
      %{
        overall_status: status.status,
        checks: status.checks,
        foundation_available: ElixirScope.Foundation.available?()
      }
    )
    |> case do
      {:ok, event} -> ElixirScope.Foundation.Events.store(event)
      error -> error
    end
    
    # Emit telemetry
    ElixirScope.Foundation.Telemetry.emit_gauge(
      [:myapp, :health, :status],
      health_status_to_number(status.status),
      %{timestamp: DateTime.to_unix(status.timestamp)}
    )
    
    status
  end
  
  defp health_status_to_number(:healthy), do: 1
  defp health_status_to_number(:degraded), do: 0.5
  defp health_status_to_number(:unhealthy), do: 0
end
```

---

## Migration Guide

### Upgrading from Previous Versions

#### From 0.1.x to 0.2.x

**Breaking Changes:**
- Event creation now returns `{:ok, Event.t()}` instead of `Event.t()`
- Configuration paths are now validated at runtime
- Service registry requires explicit namespaces

**Migration Steps:**

1. **Update Event Creation Code:**
   ```elixir
   # Old (0.1.x)
   event = ElixirScope.Foundation.Events.new_event(:user_action, data)
   
   # New (0.2.x)
   {:ok, event} = ElixirScope.Foundation.Events.new_event(:user_action, data)
   ```

2. **Handle Configuration Errors:**
   ```elixir
   # Old (0.1.x)
   value = ElixirScope.Foundation.Config.get([:some, :path])
   
   # New (0.2.x)
   case ElixirScope.Foundation.Config.get([:some, :path]) do
     {:ok, value} -> value
     {:error, _} -> default_value
   end
   ```

3. **Update Service Registration:**
   ```elixir
   # Old (0.1.x)
   ElixirScope.Foundation.ProcessRegistry.register(:my_service, self())
   
   # New (0.2.x)
   ElixirScope.Foundation.ServiceRegistry.register(:production, :my_service, self())
   ```

### Integration with Existing Applications

#### Adding Foundation Layer to Existing App

1. **Add to Supervision Tree:**
   ```elixir
   def start(_type, _args) do
     children = [
       # Add Foundation layer first
       {ElixirScope.Foundation, []},
       # Your existing children
       MyApp.Repo,
       MyApp.Endpoint
     ]
     
     Supervisor.start_link(children, opts)
   end
   ```

2. **Migrate Configuration:**
   ```elixir
   # Move from Application config to Foundation config
   # config.exs
   config :myapp,
     feature_flags: %{new_ui: true}
   
   # Runtime
   :ok = ElixirScope.Foundation.Config.update([:features, :new_ui, :enabled], true)
   ```

3. **Add Event Tracking:**
   ```elixir
   # Wrap existing functions with event tracking
   def create_user(params) do
     correlation_id = ElixirScope.Foundation.Utils.generate_correlation_id()
     
     {:ok, _} = ElixirScope.Foundation.Events.new_event(
       :user_creation_started,
       %{params: sanitize_params(params)},
       correlation_id: correlation_id
     )
     |> case do
       {:ok, event} -> ElixirScope.Foundation.Events.store(event)
       error -> error
     end
     
     # Your existing logic
     result = do_create_user(params)
     
     # Track result
     event_type = case result do
       {:ok, _} -> :user_creation_succeeded
       {:error, _} -> :user_creation_failed
     end
     
     {:ok, _} = ElixirScope.Foundation.Events.new_event(
       event_type,
       %{result: inspect(result)},
       correlation_id: correlation_id
     )
     |> case do
       {:ok, event} -> ElixirScope.Foundation.Events.store(event)
       error -> error
     end
     
     result
   end
   ```

#### Gradual Migration Strategy

1. **Phase 1: Foundation Setup**
   - Add Foundation layer to supervision tree
   - Verify all services start correctly
   - Run existing tests to ensure no regressions

2. **Phase 2: Configuration Migration**
   - Identify configuration that should be runtime-updatable
   - Migrate critical configuration paths
   - Set up configuration change subscribers

3. **Phase 3: Event Integration**
   - Start with high-level business events
   - Add correlation IDs to request flows
   - Implement event-driven monitoring

4. **Phase 4: Telemetry Enhancement**
   - Replace existing metrics with Foundation telemetry
   - Add performance monitoring
   - Set up alerting based on telemetry data

---

## Support and Resources

### Documentation
- **API Reference**: [hexdocs.pm/elixir_scope](https://hexdocs.pm/elixir_scope)
- **Architecture Guide**: See Foundation layer architecture documentation
- **Performance Guide**: Registry performance and optimization guide

### Community
- **GitHub Issues**: [Report bugs and request features](https://github.com/nshkrdotcom/ElixirScope/issues)
- **Discussions**: [Community discussions and Q&A](https://github.com/nshkrdotcom/ElixirScope/discussions)
- **Examples**: Check the `examples/` directory in the repository

### Getting Help

For technical support:

1. **Check Documentation**: Start with the API reference and guides
2. **Search Issues**: Look for similar problems in GitHub issues
3. **Create Issue**: Report bugs with minimal reproduction cases
4. **Start Discussion**: Ask questions in GitHub Discussions

### Contributing

We welcome contributions! See our [Contributing Guide](CONTRIBUTING.md) for:
- Code style guidelines
- Testing requirements
- Pull request process
- Development setup

---

**Built with ❤️ by the ElixirScope team**

*ElixirScope Foundation - The solid foundation for intelligent Elixir applications*
