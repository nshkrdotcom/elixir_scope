# ElixirScope Foundation Layer

The Foundation layer provides core infrastructure and utilities for the entire ElixirScope system. This is the bottom layer that all other components depend on.

## Features

- **Configuration Management**: Centralized, validated configuration with runtime updates
- **Event System**: Structured event creation, serialization, and management  
- **Utilities**: Time measurement, ID generation, data inspection, and system stats
- **Telemetry**: Standardized metrics collection and performance monitoring
- **Type System**: Complete type definitions for inter-layer contracts

## Architecture

The Foundation layer follows the "Stable Flexibility" pattern:

- **Stable Core**: Config, Events, Utils have comprehensive tests and type safety
- **Clear Contracts**: All public APIs use typespecs and behaviors
- **Progressive Formalization**: Components gain formal tests as they stabilize
- **Dependency Isolation**: No dependencies on other ElixirScope layers

## Quick Start

```elixir
# Initialize the Foundation layer
{:ok, _} = ElixirScope.Foundation.initialize()

# Use configuration
config = ElixirScope.Foundation.Config.get()
batch_size = ElixirScope.Foundation.Config.get([:capture, :processing, :batch_size])

# Create and work with events
event = ElixirScope.Foundation.Events.function_entry(MyModule, :my_function, 1, [:arg])
serialized = ElixirScope.Foundation.Events.serialize(event)

# Use utilities
id = ElixirScope.Foundation.Utils.generate_id()
{result, duration} = ElixirScope.Foundation.Utils.measure(fn -> expensive_operation() end)

# Collect telemetry
result = ElixirScope.Foundation.Telemetry.measure_event([:my_app, :operation], %{}, fn ->
  # Your operation here
end)
```

## Development

```bash
# Setup
make setup

# Run development workflow
make dev-workflow

# Quick development check
make dev-check

# Full CI validation
make ci-check

# Run smoke tests
make smoke

# Validate architecture
make validate
```

## Testing Strategy

The Foundation layer uses a tiered testing approach:

1. **Smoke Tests**: Fast workflow validation without implementation details
2. **Unit Tests**: Comprehensive coverage of stable APIs
3. **Contract Tests**: API contract validation for inter-layer communication
4. **Performance Tests**: Benchmarks for critical performance characteristics

## Configuration

Configuration is managed through the `Config` module with validation and runtime updates:

```elixir
# Get configuration
config = Config.get()
value = Config.get([:path, :to, :value])

# Update allowed configuration paths
:ok = Config.update([:ai, :planning, :sampling_rate], 0.8)

# Validation happens automatically
{:ok, config} = Config.validate(config)
```

## Events

The event system provides structured event creation and serialization:

```elixir
# Basic events
event = Events.new_event(:my_event_type, %{data: "value"})

# Function events
entry_event = Events.function_entry(Module, :function, 2, [arg1, arg2])
exit_event = Events.function_exit(Module, :function, 2, call_id, result, duration, :normal)

# State change events
change_event = Events.state_change(pid, :handle_call, old_state, new_state)

# Serialization
binary = Events.serialize(event)
restored_event = Events.deserialize(binary)
```

## Architecture Validation

The Foundation layer includes architectural validation:

```bash
# Validate that Foundation has no upward dependencies
mix validate_architecture
```

This ensures the Foundation layer remains the stable base for all other components.

## Performance

The Foundation layer is optimized for high-frequency operations:

- ID generation: ~1-5 μs per ID
- Event creation: ~10-50 μs per event  
- Serialization: ~50-200 μs per event
- Configuration access: ~10-50 μs per get

Run benchmarks with:

```bash
make benchmark
```

## Type Safety

All public APIs include comprehensive typespecs. Run Dialyzer for type checking:

```bash
make dialyzer
```

## Contributing

1. Follow the "Stable Flexibility" pattern
2. Add typespecs to all public functions
3. Include smoke tests for new workflows
4. Update architectural documentation
5. Validate with `make ci-check`