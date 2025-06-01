# ElixirScope Foundation Layer API Specification

**Version:** 1.0.0  
**Last Updated:** 2025-05-30
**Purpose:** Definitive API contract for Foundation layer - no Foundation code needed after this

## Overview

The Foundation layer provides core infrastructure services for all ElixirScope layers. This API specification defines the complete contract for configuration, events, utilities, telemetry, and error handling.

## Core Principles

- **Stability First**: Foundation APIs are stable contracts that higher layers depend on
- **Error Resilience**: All operations handle errors gracefully with structured error types
- **Type Safety**: Full typespec coverage with Dialyzer validation
- **Performance**: Sub-millisecond response times for core operations
- **Observability**: Comprehensive telemetry and logging

---

## 1. Foundation Module (`ElixirScope.Foundation`)

### 1.1 Application Lifecycle

```elixir
@spec initialize(keyword()) :: :ok | {:error, Error.t()}
```
**Purpose**: Initialize Foundation layer with optional configuration  
**Usage**: Called once during application startup  
**Opts**: `[config_overrides: keyword(), debug_mode: boolean()]`  
**Errors**: `:initialization_failed`, `:dependency_failed`

```elixir
@spec status() :: foundation_status()
@type foundation_status :: %{
  config: :ok | {:error, Error.t()},
  events: :ok | {:error, Error.t()},
  telemetry: :ok | {:error, Error.t()},
  uptime_ms: non_neg_integer()
}
```
**Purpose**: Get health status of all Foundation subsystems  
**Returns**: Health map with component status and uptime

---

## 2. Configuration (`ElixirScope.Foundation.Config`)

### 2.1 Core Configuration Operations

```elixir
@spec initialize(keyword()) :: :ok | {:error, Error.t()}
```
**Purpose**: Start configuration GenServer with initial values  
**Errors**: `:initialization_failed`, `:service_unavailable`

```elixir
@spec get() :: Config.t() | {:error, Error.t()}
@spec get(config_path()) :: config_value() | nil | {:error, Error.t()}
@type config_path :: [atom()]
```
**Purpose**: Retrieve complete configuration or value at path  
**Example**: `Config.get([:ai, :planning, :sampling_rate])`

```elixir
@spec update(config_path(), config_value()) :: :ok | {:error, Error.t()}
```
**Purpose**: Update configuration at runtime (only allowed paths)  
**Errors**: `:config_update_forbidden`, `:validation_failed`

```elixir
@spec validate(Config.t()) :: :ok | {:error, Error.t()}
```
**Purpose**: Validate configuration structure and values

### 2.2 Configuration Structure

```elixir
@type Config.t() :: %Config{
  ai: ai_config(),
  capture: capture_config(), 
  storage: storage_config(),
  interface: interface_config(),
  dev: dev_config()
}

@type ai_config :: %{
  provider: :mock | :openai | :anthropic | :gemini,
  api_key: String.t() | nil,
  model: String.t(),
  analysis: %{
    max_file_size: pos_integer(),
    timeout: pos_integer(),
    cache_ttl: pos_integer()
  },
  planning: %{
    default_strategy: :fast | :balanced | :thorough,
    performance_target: float(),
    sampling_rate: float()
  }
}

@type capture_config :: %{
  ring_buffer: %{
    size: pos_integer(),
    max_events: pos_integer(),
    overflow_strategy: :drop_oldest | :drop_newest | :block,
    num_buffers: pos_integer() | :schedulers
  },
  processing: %{
    batch_size: pos_integer(),
    flush_interval: pos_integer(),
    max_queue_size: pos_integer()
  },
  vm_tracing: %{
    enable_spawn_trace: boolean(),
    enable_exit_trace: boolean(),
    enable_message_trace: boolean(),
    trace_children: boolean()
  }
}

@type storage_config :: %{
  hot: %{
    max_events: pos_integer(),
    max_age_seconds: pos_integer(),
    prune_interval: pos_integer()
  },
  warm: %{
    enable: boolean(),
    path: String.t(),
    max_size_mb: pos_integer(),
    compression: :none | :gzip | :zstd
  },
  cold: %{enable: boolean()}
}

@type interface_config :: %{
  query_timeout: pos_integer(),
  max_results: pos_integer(),
  enable_streaming: boolean()
}

@type dev_config :: %{
  debug_mode: boolean(),
  verbose_logging: boolean(), 
  performance_monitoring: boolean()
}
```

### 2.3 Runtime Updatable Paths

```elixir
@updatable_paths [
  [:ai, :planning, :sampling_rate],
  [:ai, :planning, :performance_target],
  [:capture, :processing, :batch_size],
  [:capture, :processing, :flush_interval],
  [:interface, :query_timeout],
  [:interface, :max_results],
  [:dev, :debug_mode],
  [:dev, :verbose_logging],
  [:dev, :performance_monitoring]
]
```

---

## 3. Events (`ElixirScope.Foundation.Events`)

### 3.1 Event Creation

```elixir
@spec new_event(atom(), term(), keyword()) :: Events.t() | {:error, Error.t()}
```
**Purpose**: Create a new event with structured data  
**Opts**: `[correlation_id: String.t(), parent_id: event_id()]`

```elixir
@spec function_entry(module(), atom(), arity(), [term()], keyword()) :: 
  Events.t() | {:error, Error.t()}
```
**Purpose**: Create function entry event for tracing

```elixir
@spec function_exit(module(), atom(), arity(), event_id(), term(), 
  non_neg_integer(), atom()) :: Events.t() | {:error, Error.t()}
```
**Purpose**: Create function exit event with result and duration

```elixir
@spec state_change(pid(), atom(), term(), term(), keyword()) :: 
  Events.t() | {:error, Error.t()}
```
**Purpose**: Create GenServer state change event

### 3.2 Event Structure

```elixir
@type Events.t() :: %Events{
  event_id: event_id(),
  event_type: atom(),
  timestamp: timestamp(),
  wall_time: DateTime.t(),
  node: node(),
  pid: pid(),
  correlation_id: correlation_id() | nil,
  parent_id: event_id() | nil,
  data: term()
}

@type event_id :: pos_integer()
@type correlation_id :: String.t()
@type timestamp :: integer()
```

### 3.3 Event Serialization

```elixir
@spec serialize(Events.t()) :: binary() | {:error, Error.t()}
@spec deserialize(binary()) :: Events.t() | {:error, Error.t()}
@spec serialized_size(Events.t()) :: non_neg_integer()
```
**Purpose**: Convert events to/from binary for storage and transport

### 3.4 System Management

```elixir
@spec initialize() :: :ok
@spec status() :: :ok
```
**Purpose**: Initialize event system and check health

---

## 4. Utilities (`ElixirScope.Foundation.Utils`)

### 4.1 ID Generation

```elixir
@spec generate_id() :: event_id()
@spec generate_correlation_id() :: correlation_id()
@spec id_to_timestamp(event_id()) :: timestamp()
```
**Purpose**: Generate unique IDs for events and correlations

### 4.2 Time Utilities

```elixir
@spec monotonic_timestamp() :: timestamp()
@spec wall_timestamp() :: timestamp()
@spec format_timestamp(timestamp()) :: String.t()
```
**Purpose**: High-precision time measurement and formatting

### 4.3 Measurement

```elixir
@spec measure((-> t)) :: {t, non_neg_integer()} when t: var
@spec measure_memory((-> t)) :: {t, {non_neg_integer(), non_neg_integer(), integer()}} when t: var
```
**Purpose**: Measure execution time and memory usage  
**Returns**: `{result, duration_ns}` or `{result, {before, after, diff}}`

### 4.4 Data Processing

```elixir
@spec safe_inspect(term(), keyword()) :: String.t()
@spec truncate_if_large(term(), non_neg_integer()) :: term() | truncated_data()
@spec term_size(term()) :: non_neg_integer()

@type truncated_data :: {:truncated, non_neg_integer(), String.t()}
```
**Purpose**: Safe data inspection and size management

### 4.5 System Information

```elixir
@spec process_stats(pid()) :: process_stats()
@spec system_stats() :: system_stats()

@type process_stats :: %{
  memory: non_neg_integer(),
  reductions: non_neg_integer(),
  message_queue_len: non_neg_integer(),
  timestamp: timestamp()
}

@type system_stats :: %{
  timestamp: timestamp(),
  process_count: non_neg_integer(),
  total_memory: non_neg_integer(),
  scheduler_count: pos_integer(),
  otp_release: String.t()
}
```

### 4.6 Formatting

```elixir
@spec format_bytes(non_neg_integer()) :: String.t()
@spec format_duration(non_neg_integer()) :: String.t()
```
**Purpose**: Human-readable formatting for bytes and durations

### 4.7 Validation

```elixir
@spec valid_positive_integer?(term()) :: boolean()
@spec valid_percentage?(term()) :: boolean()
@spec valid_pid?(term()) :: boolean()
```
**Purpose**: Common validation predicates

---

## 5. Telemetry (`ElixirScope.Foundation.Telemetry`)

### 5.1 Measurement

```elixir
@spec measure_event([atom(), ...], map(), (-> t)) :: t when t: var
```
**Purpose**: Measure function execution with telemetry events  
**Example**: `measure_event([:elixir_scope, :cpg, :build], %{module: MyModule}, fn -> build_cpg() end)`

```elixir
@spec emit_counter([atom(), ...], map()) :: :ok
@spec emit_gauge([atom(), ...], number(), map()) :: :ok
```
**Purpose**: Emit counter and gauge metrics

### 5.2 Metrics Collection

```elixir
@spec get_metrics() :: metrics_data()
@type metrics_data :: %{
  foundation: %{
    uptime_ms: integer(),
    memory_usage: non_neg_integer(),
    process_count: non_neg_integer()
  },
  system: system_stats()
}
```

### 5.3 System Management

```elixir
@spec initialize() :: :ok
@spec status() :: :ok
```

### 5.4 Standard Telemetry Events

```elixir
# Configuration events
[:elixir_scope, :config, :get]
[:elixir_scope, :config, :update]
[:elixir_scope, :config, :validate]

# Event system events  
[:elixir_scope, :events, :create]
[:elixir_scope, :events, :serialize]
[:elixir_scope, :events, :deserialize]

# Performance events
[:elixir_scope, :performance, :measurement]
[:elixir_scope, :performance, :memory_usage]
```

---

## 6. Error Handling (`ElixirScope.Foundation.Error`)

### 6.1 Error Structure

```elixir
@type Error.t() :: %Error{
  code: error_code(),
  message: String.t(),
  context: map(),
  module: module() | nil,
  function: atom() | nil,
  line: non_neg_integer() | nil,
  stacktrace: [map()] | nil,
  timestamp: DateTime.t(),
  correlation_id: String.t() | nil
}

@type error_code :: 
  # Configuration Errors
  :invalid_config_structure | :invalid_config_value | :missing_required_config |
  :config_validation_failed | :config_not_found | :config_update_forbidden |
  
  # Validation Errors  
  :invalid_input | :validation_failed | :constraint_violation |
  :type_mismatch | :range_error | :format_error |
  
  # System Errors
  :initialization_failed | :service_unavailable | :timeout |
  :resource_exhausted | :dependency_failed | :internal_error |
  :external_error | :test_error |
  
  # Data Errors
  :data_corruption | :serialization_failed | :deserialization_failed |
  :data_not_found | :data_conflict
```

### 6.2 Error Construction

```elixir
@spec new(error_code(), String.t(), keyword()) :: Error.t()
@spec config_error(error_code(), String.t(), keyword()) :: Error.t()
@spec validation_error(error_code(), String.t(), keyword()) :: Error.t()
@spec system_error(error_code(), String.t(), keyword()) :: Error.t()
@spec data_error(error_code(), String.t(), keyword()) :: Error.t()
```

### 6.3 Error Result Helpers

```elixir
@spec error_result(Error.t()) :: {:error, Error.t()}
@spec error_result(error_code(), String.t(), keyword()) :: {:error, Error.t()}
```

### 6.4 Error Inspection

```elixir
@spec to_map(Error.t()) :: map()
@spec to_string(Error.t()) :: String.t()
@spec severity(Error.t()) :: :low | :medium | :high | :critical
```

---

## 7. Error Context (`ElixirScope.Foundation.ErrorContext`)

### 7.1 Context Management

```elixir
@spec new(module(), atom(), keyword()) :: context()
@type context :: %{
  module: module(),
  function: atom(),
  timestamp: DateTime.t(),
  metadata: map()
}
```

```elixir
@spec add_context(result(), context(), map()) :: result() when 
  result: :ok | {:ok, term()} | {:error, Error.t()} | {:error, term()}
```
**Purpose**: Add context information to operation results

```elixir
@spec with_context(context(), (-> term())) :: term()
```
**Purpose**: Wrap function execution with error context tracking

---

## 8. Types (`ElixirScope.Foundation.Types`)

### 8.1 Core Types

```elixir
# Time-related types
@type timestamp :: integer()
@type duration :: non_neg_integer()

# ID types
@type event_id :: pos_integer()
@type correlation_id :: String.t()
@type call_id :: pos_integer()

# Result types
@type result(success, error) :: {:ok, success} | {:error, error}
@type result(success) :: result(success, term())

# Location types
@type file_path :: String.t()
@type line_number :: pos_integer()
@type column_number :: pos_integer()
@type source_location :: %{
  file: file_path(),
  line: line_number(), 
  column: column_number() | nil
}

# Process types
@type process_info :: %{
  pid: pid(),
  registered_name: atom() | nil,
  status: atom(),
  memory: non_neg_integer(),
  reductions: non_neg_integer()
}

# Function types
@type module_name :: module()
@type function_name :: atom()
@type function_arity :: arity()
@type function_args :: [term()]
@type function_call :: {module_name(), function_name(), function_args()}

# Data types
@type byte_size :: non_neg_integer()
@type truncated_data :: {:truncated, byte_size(), String.t()}
@type maybe_truncated(t) :: t | truncated_data()
```

---

## 9. Test Support (`ElixirScope.Foundation.TestHelpers`)

### 9.1 Setup Helpers

```elixir
@spec ensure_config_available() :: :ok | {:error, Error.t()}
@spec create_test_event(keyword()) :: Events.t() | {:error, Error.t()}
@spec with_test_config(map(), (-> any())) :: any()
```

### 9.2 Validation Helpers

```elixir
@spec wait_for((-> boolean()), non_neg_integer()) :: :ok | :timeout
@spec test_error_context(module(), atom(), map()) :: context()
@spec assert_error_result({:error, Error.t()}, atom()) :: Error.t()
@spec assert_ok_result(term()) :: term()
```

---

## 10. Performance Characteristics

### 10.1 Latency Requirements

| Operation | Target Latency | Max Latency |
|-----------|----------------|-------------|
| Config.get() | < 1μs | < 10μs |
| Config.get(path) | < 5μs | < 50μs |
| Events.new_event() | < 10μs | < 100μs |
| Events.serialize() | < 50μs | < 500μs |
| Utils.generate_id() | < 1μs | < 10μs |
| Telemetry.emit_counter() | < 5μs | < 50μs |

### 10.2 Memory Usage

- **Config**: < 1MB total
- **Events**: < 1KB per event
- **Utils**: Stateless, no persistent memory
- **Telemetry**: < 100KB for metrics storage

### 10.3 Throughput

- **Event Creation**: > 100K events/second
- **ID Generation**: > 1M IDs/second  
- **Config Access**: > 1M gets/second
- **Telemetry**: > 10K measurements/second

---

## 11. Error Recovery

### 11.1 Failure Modes

| Component | Failure Mode | Recovery Strategy |
|-----------|--------------|------------------|
| Config GenServer | Crash | Restart with default config |
| Event Creation | Memory limit | Return error, continue operation |
| Telemetry | Handler crash | Log error, continue without telemetry |
| Utils | Exception | Catch and return error tuple |

### 11.2 Graceful Degradation

- **Config unavailable**: Return cached values or defaults
- **Events serialization failure**: Log error, continue with best effort
- **Telemetry failure**: Continue operation without metrics
- **Utils failure**: Return safe fallback values

---

## 12. Integration Points

### 12.1 Application Integration

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    # Foundation must start first
    {ElixirScope.Foundation, []},
    # Other children
  ]
  
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

### 12.2 Configuration Integration

```elixir
# In config.exs
config :elixir_scope,
  ai: [
    provider: :mock,
    planning: [
      default_strategy: :balanced,
      performance_target: 0.01,
      sampling_rate: 1.0
    ]
  ]
```

### 12.3 Higher Layer Usage

```elixir
# AST layer using Foundation
defmodule ElixirScope.AST.Parser do
  alias ElixirScope.Foundation.{Events, Utils, Telemetry}
  
  def parse(source) do
    correlation_id = Utils.generate_correlation_id()
    
    Telemetry.measure_event([:ast, :parse], %{size: byte_size(source)}, fn ->
      # Parse implementation
      event = Events.new_event(:ast_parsed, %{source: source}, 
                              correlation_id: correlation_id)
      # Continue processing
    end)
  end
end
```

---

## 13. Versioning & Compatibility

### 13.1 API Stability

- **STABLE**: Core APIs will not change in breaking ways
- **Config structure**: Backwards compatible additions only
- **Event format**: Versioned with migration support
- **Error codes**: New codes added, existing codes stable

### 13.2 Deprecation Policy

- **6 months notice** for any API changes
- **Migration guides** for breaking changes
- **Backwards compatibility** maintained for 2 major versions

---

## 14. Usage Examples

### 14.1 Basic Foundation Usage

```elixir
# Initialize Foundation
{:ok, _} = ElixirScope.Foundation.initialize()

# Create and serialize an event
event = ElixirScope.Foundation.Events.new_event(:user_action, %{user_id: 123})
{:ok, binary} = ElixirScope.Foundation.Events.serialize(event)

# Get configuration
config = ElixirScope.Foundation.Config.get()
sampling_rate = ElixirScope.Foundation.Config.get([:ai, :planning, :sampling_rate])

# Measure performance
{result, duration} = ElixirScope.Foundation.Utils.measure(fn ->
  expensive_operation()
end)

# Emit telemetry
ElixirScope.Foundation.Telemetry.emit_counter([:my_app, :operations])
```

### 14.2 Error Handling Pattern

```elixir
defmodule MyModule do
  alias ElixirScope.Foundation.{Error, ErrorContext}
  
  def my_operation(params) do
    context = ErrorContext.new(__MODULE__, :my_operation, 
                              metadata: %{params: params})
    
    ErrorContext.with_context(context, fn ->
      with {:ok, validated} <- validate_params(params),
           {:ok, result} <- process_data(validated) do
        {:ok, result}
      end
    end)
  end
end
```

### 14.3 Configuration Management

```elixir
# Development configuration override
ElixirScope.Foundation.Config.update([:dev, :debug_mode], true)

# Runtime performance tuning  
ElixirScope.Foundation.Config.update([:ai, :planning, :sampling_rate], 0.1)

# Conditional feature enablement
config = ElixirScope.Foundation.Config.get()
if config.dev.debug_mode do
  # Enable verbose logging
end
```

---

## 15. Contract Guarantees

### 15.1 API Contracts

1. **All functions return either success values or `{:error, Error.t()}`**
2. **All public functions have complete `@spec` annotations**
3. **Configuration changes only affect runtime behavior, not API**
4. **Events maintain backwards-compatible serialization format**
5. **Telemetry events follow consistent naming conventions**

### 15.2 Performance Contracts

1. **Foundation operations complete within specified latency bounds**
2. **Memory usage remains bounded and predictable**
3. **No unbounded queues or memory leaks**
4. **Graceful degradation under resource pressure**

### 15.3 Reliability Contracts

1. **Foundation components restart cleanly after crashes**
2. **Configuration maintains consistency across restarts**
3. **Events are never lost due to Foundation failures**
4. **Telemetry failures do not affect application operation**

---

This API specification serves as the definitive contract for the Foundation layer. Higher layers should only use the APIs documented here and should not depend on implementation details. The Foundation layer will maintain backward compatibility for all APIs marked as stable.

**Next Steps**: Use this specification to implement higher layers without needing to reference Foundation implementation code.