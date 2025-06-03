# ElixirScope Foundation Layer

**Status:** ✅ **PRODUCTION READY** - Core architecture 100% complete  
**Architecture:** OTP-compliant Registry-based service architecture with namespace isolation  
**Next Phase:** Infrastructure patterns implementation (Circuit Breaker, Memory Management, etc.)

The Foundation layer provides core infrastructure and utilities for the entire ElixirScope system. This is the bottom layer that all other components depend on, implementing a robust concurrent architecture using OTP principles.

## Features

### Core Services (✅ Complete)
- **Configuration Management**: Registry-based ConfigServer with runtime updates and validation
- **Event System**: Structured EventStore with querying and correlation capabilities  
- **Telemetry**: Comprehensive TelemetryService with metrics collection and monitoring
- **Process Management**: ProcessRegistry with namespace isolation for concurrent testing
- **Type System**: Complete type definitions for inter-layer contracts

### Infrastructure Patterns (🚧 Implementation Phase)
- **Circuit Breaker Framework**: Service protection and failure isolation
- **Memory Management**: Automatic monitoring, cleanup, and pressure relief
- **Enhanced Health Checks**: Deep service validation with dependency checking
- **Performance Monitoring**: Comprehensive metrics with alerting and trending
- **Rate Limiting**: Multi-algorithm protection for APIs
- **Connection Pooling**: Managed external service connections

## Architecture

The Foundation layer implements **OTP-compliant concurrent architecture**:

### Supervision Tree
```
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

### Design Principles
- **Registry-Based Discovery**: All services discoverable via `ServiceRegistry.via_tuple/2`
- **Namespace Isolation**: Complete test isolation enabling concurrent testing
- **"Let It Crash"**: OTP fault tolerance with automatic recovery
- **Type Safety**: Complete `@spec` coverage with Dialyzer validation

## Quick Start

```elixir
# Foundation layer starts automatically with application
# Services are available immediately in :production namespace

# Configuration Management
{:ok, config} = ElixirScope.Foundation.Config.get()
batch_size = ElixirScope.Foundation.Config.get([:capture, :processing, :batch_size])
:ok = ElixirScope.Foundation.Config.update([:ai, :planning, :sampling_rate], 0.8)

# Event Management  
{:ok, event_id} = ElixirScope.Foundation.Events.store(event)
{:ok, events} = ElixirScope.Foundation.Events.query(%{event_type: :function_entry})

# Telemetry
ElixirScope.Foundation.Telemetry.execute([:my_app, :operation], %{duration: 100}, %{})
ElixirScope.Foundation.Telemetry.emit_counter([:my_app, :requests], %{status: :success})

# Service Discovery (for other layers)
{:ok, pid} = ElixirScope.Foundation.ServiceRegistry.lookup(:production, :config_server)
```

## Development

```bash
# Setup
make setup

# Run development workflow  
make dev-workflow

# Quick development check
make dev-check

# Full CI validation (includes Dialyzer, all tests)
make ci-check

# Run concurrent tests (168 tests, all passing)
mix test

# Run property-based tests (marked with @moduletag :slow)
mix test --include slow

# Run integration tests
mix test --include integration

# Validate architecture compliance
make validate
```

## Testing Strategy

The Foundation layer uses **concurrent testing** with complete service isolation:

### Test Architecture
```elixir
defmodule MyTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  
  test "isolated operations", %{namespace: namespace, test_ref: test_ref} do
    # Automatic per-test service isolation
    assert {:ok, _} = ServiceRegistry.lookup(namespace, :config_server)
    assert {:ok, _} = ServiceRegistry.lookup(namespace, :event_store)
    assert {:ok, _} = ServiceRegistry.lookup(namespace, :telemetry_service)
    
    # All operations are isolated to this test
    :ok = Config.update(namespace, [:test_key], "test_value")
  end
end
```

### Test Results (Current)
- **168 Foundation tests**: ✅ All passing
- **0 Dialyzer errors**: ✅ Complete type safety
- **30 property-based tests**: ✅ Comprehensive edge case coverage
- **Concurrent execution**: ✅ Full async test isolation

### Test Categories
1. **Unit Tests**: Core functionality with mocking and isolation
2. **Integration Tests**: Service interaction and Registry behavior  
3. **Property Tests**: Edge cases and randomized input validation
4. **Concurrent Tests**: Namespace isolation and parallel execution
5. **Performance Tests**: Latency and throughput benchmarks

## Production Readiness

### Current Status ✅
- **Service Discovery**: Registry-based with health checks
- **Fault Tolerance**: Supervision tree with proper restart strategies
- **Concurrent Safety**: Complete namespace isolation for testing
- **Type Safety**: 100% `@spec` coverage, Dialyzer clean
- **Performance**: Optimized for high-frequency operations
- **Monitoring**: Telemetry integration throughout

### Performance Characteristics
- **ID generation**: ~1-5 μs per ID
- **Event creation**: ~10-50 μs per event  
- **Configuration access**: ~10-50 μs per get
- **Service lookup**: ~5-20 μs via Registry
- **Event storage**: ~50-200 μs per event
- **Service availability check**: <10ms

### Infrastructure Readiness
The Foundation is ready for production deployment and provides the base for upcoming **Infrastructure Patterns** (see `FOUNDATION_OTP_IMPLEMENT_NOW.md`):

- Circuit Breaker Framework
- Memory Management Framework  
- Enhanced Health Check System
- Performance Monitoring Infrastructure
- Rate Limiting Framework
- Connection Pooling Infrastructure

## Configuration

Configuration management with validation and runtime updates:

```elixir
# Get configuration (with namespace support)
config = Config.get()
config = Config.get(:production)  # explicit namespace
value = Config.get([:path, :to, :value])

# Update configuration (validates updatable paths)
:ok = Config.update([:ai, :planning, :sampling_rate], 0.8)

# Subscription to configuration changes
:ok = Config.subscribe(self())
# Receive: {:config_updated, [:ai, :planning, :sampling_rate], 0.8}

# Service status
{:ok, status} = Config.status()
# %{status: :running, updates_count: 5, start_time: 1640995200}
```

## Events

Structured event system with querying and correlation:

```elixir
# Event creation
event = Events.new_event(:my_event_type, %{data: "value"})
entry_event = Events.function_entry(Module, :function, 2, [arg1, arg2])

# Event storage and retrieval  
{:ok, event_id} = Events.store(event)
{:ok, stored_event} = Events.get(event_id)

# Advanced querying
{:ok, events} = Events.query(%{
  event_type: :function_entry,
  correlation_id: "trace-123",
  start_time: DateTime.utc_now() |> DateTime.add(-3600),
  limit: 100
})

# Batch operations
{:ok, event_ids} = Events.store_batch([event1, event2, event3])

# Correlation tracking
{:ok, related_events} = Events.get_by_correlation("trace-123")
```

## Telemetry

Comprehensive metrics collection and monitoring:

```elixir
# Execute telemetry events
Telemetry.execute([:foundation, :config_server, :get], 
                  %{duration: 150}, 
                  %{path: [:key], result: :success})

# Measure operations automatically
result = Telemetry.measure([:my_app, :operation], %{type: :critical}, fn ->
  expensive_operation()
end)

# Emit counters and gauges
Telemetry.emit_counter([:requests, :total], %{endpoint: "/api/v1"})
Telemetry.emit_gauge([:memory, :usage], memory_bytes, %{service: :config_server})

# Handler management
:ok = Telemetry.attach_handlers([[:foundation, :config_server]])
metrics = Telemetry.get_metrics()
```

## Service Discovery & Health

Registry-based service discovery with health monitoring:

```elixir
# Service lookup (automatic namespace handling)
{:ok, pid} = ServiceRegistry.lookup(:production, :config_server)
{:ok, pid} = ServiceRegistry.lookup({:test, test_ref}, :config_server)

# Health checks
{:ok, %{status: :healthy}} = ServiceRegistry.health_check(:production, :config_server)

# Service availability
true = Config.available?()
true = Events.available?()  
true = Telemetry.available?()

# Service information
info = ServiceRegistry.get_service_info(:production)
# %{namespace: :production, total_services: 3, service_names: [:config_server, :event_store, :telemetry_service]}
```

## Architecture Validation

Foundation maintains architectural purity as the bottom layer:

```bash
# Validate no upward dependencies
mix validate_architecture

# Check OTP compliance
mix check_supervision_tree

# Verify Registry patterns
mix validate_registry_usage

# Type safety validation
mix dialyzer
```

## Error Handling

Structured error handling with categorization:

```elixir
# Foundation Error structure
%ElixirScope.Foundation.Types.Error{
  code: 1001,
  error_type: :validation_failed,
  message: "Invalid configuration path",
  severity: :medium,
  category: :config,
  subcategory: :validation,
  timestamp: ~U[2025-01-01 00:00:00Z],
  metadata: %{path: [:invalid, :path]}
}

# Error categories: :system, :config, :events, :telemetry, :validation, :security
# Error types: :validation_failed, :service_unavailable, :operation_forbidden, etc.
```

## Integration Patterns

### Higher Layer Integration
```elixir
defmodule YourLayer.Service do
  # Use Foundation services with namespace support
  def your_operation(data) do
    with {:ok, config} <- Config.get([:your_layer, :settings]),
         :ok <- validate_data(data),
         {:ok, result} <- process_data(data, config),
         {:ok, _event_id} <- Events.store(create_event(result)) do
      
      Telemetry.emit_counter([:your_layer, :operations, :success])
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

### Test Integration
```elixir
defmodule YourLayerTest do
  use ElixirScope.Foundation.ConcurrentTestCase, async: true
  
  test "your functionality", %{namespace: namespace} do
    # Foundation services automatically available and isolated
    :ok = Config.update(namespace, [:test_setting], "test_value")
    {:ok, _} = Events.store(namespace, test_event)
    
    # Your test logic here with complete isolation
  end
end
```

## Contributing

1. Follow **OTP design principles** and Registry patterns
2. Add comprehensive `@spec` typespecs to all public functions
3. Use `ConcurrentTestCase` for all service interaction tests
4. Include property-based tests for complex logic
5. Update architectural documentation for new patterns
6. Validate with `make ci-check` before submission
7. Ensure Dialyzer compliance (0 errors required)

## Next Steps

The Foundation layer is **complete and production-ready**. Next development phase focuses on **Infrastructure Patterns** that will:

1. **Enhance production reliability** (Circuit Breaker, Memory Management)
2. **Provide deep observability** (Enhanced Health Checks, Performance Monitoring)  
3. **Prepare for AST layer** (Rate Limiting, Connection Pooling)

See `FOUNDATION_OTP_IMPLEMENT_NOW.md` for detailed implementation roadmap.

---

**Foundation Status**: ✅ Production Ready | **Next**: Infrastructure Patterns | **Timeline**: 3 weeks to AST readiness