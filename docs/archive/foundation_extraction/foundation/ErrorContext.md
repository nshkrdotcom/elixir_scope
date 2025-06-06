# ElixirScope ErrorContext - Technical Architecture and Usage Guide

## Table of Contents

1. [ErrorContext Internals](#errorcontext-internals)
2. [ErrorContext Usage Guide](#errorcontext-usage-guide)
3. [Architecture Integration](#architecture-integration)
4. [Performance Considerations](#performance-considerations)
5. [Best Practices](#best-practices)
6. [Examples](#examples)

---

# ErrorContext Internals

## Overview

`ErrorContext` is a sophisticated error tracking and correlation system designed for complex, multi-step operations in ElixirScope. It provides operation tracing, breadcrumb collection, correlation tracking, and emergency recovery mechanisms.

## Core Architecture

### Data Structure

```elixir
@type t :: %__MODULE__{
  operation_id: pos_integer(),        # Unique operation identifier
  module: module(),                   # Starting module
  function: atom(),                   # Starting function
  correlation_id: String.t(),         # Cross-system correlation
  start_time: integer(),              # Operation start timestamp
  metadata: map(),                    # Additional context data
  breadcrumbs: [breadcrumb()],        # Operation trail
  parent_context: t() | nil           # Nested context support
}

@type breadcrumb :: %{
  module: module(),                   # Module where breadcrumb added
  function: atom(),                   # Function where breadcrumb added
  timestamp: integer(),               # When breadcrumb was created
  metadata: map()                     # Step-specific context
}
```

### Key Components

#### 1. Operation Tracking
- **Unique Operation ID**: Generated using `Utils.generate_id()` for absolute uniqueness
- **Correlation ID**: UUID v4 format for cross-system tracking
- **Timing Information**: Monotonic timestamps for precise duration measurement

#### 2. Breadcrumb System
```elixir
# Breadcrumbs track operation flow
breadcrumb = %{
  module: MyModule,
  function: :complex_operation,
  timestamp: Utils.monotonic_timestamp(),
  metadata: %{step: "validation", input_size: 1024}
}
```

#### 3. Context Hierarchy
- **Parent-Child Relationships**: Nested contexts for complex operations
- **Context Inheritance**: Child contexts inherit correlation IDs and metadata
- **Hierarchical Tracking**: Full operation tree reconstruction

#### 4. Emergency Recovery
- **Process Dictionary Storage**: Contexts stored in process dictionary for crash analysis
- **Automatic Cleanup**: Contexts removed on successful completion
- **Exception Enhancement**: Automatic context injection into exceptions

## Internal Implementation Details

### Context Creation

```elixir
def new(module, function, opts \\ []) do
  %__MODULE__{
    operation_id: Utils.generate_id(),
    module: module,
    function: function,
    correlation_id: Keyword.get(opts, :correlation_id, Utils.generate_correlation_id()),
    start_time: Utils.monotonic_timestamp(),
    metadata: Keyword.get(opts, :metadata, %{}),
    breadcrumbs: [create_initial_breadcrumb(module, function)],
    parent_context: Keyword.get(opts, :parent_context)
  }
end
```

### Context Execution

The `with_context/2` function implements sophisticated error handling:

```elixir
def with_context(%__MODULE__{} = context, fun) when is_function(fun, 0) do
  # Store context for emergency access
  Process.put(:error_context, context)
  
  try do
    result = fun.()
    
    # Clean up and enhance results
    Process.delete(:error_context)
    enhance_result_with_context(result, context)
  rescue
    exception ->
      # Capture and enhance exception
      enhanced_error = create_exception_error(exception, context, __STACKTRACE__)
      
      # Clean up
      Process.delete(:error_context)
      
      # Emit error telemetry
      Error.collect_error_metrics(enhanced_error)
      
      {:error, enhanced_error}
  end
end
```

### Breadcrumb Management

```elixir
def add_breadcrumb(%__MODULE__{} = context, module, function, metadata \\ %{}) do
  breadcrumb = %{
    module: module,
    function: function,
    timestamp: Utils.monotonic_timestamp(),
    metadata: metadata
  }
  
  %{context | breadcrumbs: context.breadcrumbs ++ [breadcrumb]}
end
```

### Context Enhancement

ErrorContext provides multiple enhancement mechanisms:

#### 1. Result Enhancement
```elixir
defp enhance_result_with_context(result, context) do
  # Emit successful operation telemetry
  duration = get_operation_duration(context)
  
  ElixirScope.Foundation.Telemetry.emit_gauge(
    [:foundation, :operations, :duration],
    duration,
    %{
      module: context.module,
      function: context.function,
      correlation_id: context.correlation_id
    }
  )
  
  result
end
```

#### 2. Error Enhancement
```elixir
def enhance_error(%Error{} = error, %__MODULE__{} = context) do
  enhanced_context = Map.merge(error.context, %{
    operation_context: %{
      operation_id: context.operation_id,
      correlation_id: context.correlation_id,
      breadcrumbs: context.breadcrumbs,
      duration_ns: Utils.monotonic_timestamp() - context.start_time,
      metadata: context.metadata
    }
  })
  
  %{
    error
    | context: enhanced_context,
      correlation_id: error.correlation_id || context.correlation_id
  }
end
```

### Child Context Creation

```elixir
def child_context(%__MODULE__{} = parent, module, function, metadata \\ %{}) do
  %__MODULE__{
    operation_id: Utils.generate_id(),
    module: module,
    function: function,
    correlation_id: parent.correlation_id,  # Inherit correlation
    start_time: Utils.monotonic_timestamp(),
    metadata: Map.merge(parent.metadata, metadata),  # Merge metadata
    breadcrumbs: parent.breadcrumbs ++ [create_breadcrumb(module, function, metadata)],
    parent_context: parent  # Maintain hierarchy
  }
end
```

## Emergency Recovery Mechanisms

### Process Dictionary Storage
```elixir
# Emergency context retrieval
def get_current_context() do
  Process.get(:error_context)
end
```

### Exception Enhancement
```elixir
defp create_exception_error(exception, context, stacktrace) do
  Error.new(:internal_error, "Exception in operation: #{Exception.message(exception)}",
    context: %{
      exception_type: exception.__struct__,
      exception_message: Exception.message(exception),
      operation_context: %{
        operation_id: context.operation_id,
        correlation_id: context.correlation_id,
        breadcrumbs: context.breadcrumbs,
        duration_ns: get_operation_duration(context),
        metadata: context.metadata
      }
    },
    correlation_id: context.correlation_id,
    stacktrace: format_stacktrace(stacktrace)
  )
end
```

## Performance Characteristics

### Memory Usage
- **Base Context**: ~200 bytes per context
- **Breadcrumbs**: ~50 bytes per breadcrumb
- **Metadata**: Variable based on content
- **Process Dictionary**: Minimal overhead

### Time Complexity
- **Context Creation**: O(1)
- **Breadcrumb Addition**: O(1) amortized
- **Context Enhancement**: O(1)
- **Emergency Recovery**: O(1)

### Timing Precision
- **Monotonic Timestamps**: Nanosecond precision
- **Duration Calculation**: Immune to clock adjustments
- **Telemetry Integration**: Sub-microsecond overhead

---

# ErrorContext Usage Guide

## When to Use ErrorContext

### Use ErrorContext For:

1. **Multi-Step Operations**
   ```elixir
   # Complex initialization sequences
   def initialize_application(opts) do
     context = ErrorContext.new(__MODULE__, :initialize_application, metadata: %{opts: opts})
     
     ErrorContext.with_context(context, fn ->
       :ok = initialize_config(opts)
       :ok = initialize_services()
       :ok = verify_system_health()
       {:ok, :initialized}
     end)
   end
   ```

2. **Cross-Service Coordination**
   ```elixir
   # Operations spanning multiple Foundation services
   def migrate_data(source, target) do
     context = ErrorContext.new(__MODULE__, :migrate_data, 
       metadata: %{source: source, target: target})
     
     ErrorContext.with_context(context, fn ->
       {:ok, data} = fetch_from_source(source)
       {:ok, transformed} = transform_data(data)
       {:ok, _} = store_in_target(target, transformed)
       :ok
     end)
   end
   ```

3. **User-Facing Operations**
   ```elixir
   # High-level API operations
   def start_debug_session(module, function, args) do
     correlation_id = Utils.generate_correlation_id()
     context = ErrorContext.new(__MODULE__, :start_debug_session, 
       correlation_id: correlation_id,
       metadata: %{module: module, function: function})
     
     ErrorContext.with_context(context, fn ->
       {:ok, session} = create_session(module, function, args)
       :ok = setup_instrumentation(session)
       :ok = start_capture(session)
       {:ok, session.id}
     end)
   end
   ```

### Don't Use ErrorContext For:

1. **Simple Foundation Operations**
   ```elixir
   # Too much overhead for simple operations
   def get_config(path) do
     # Use simple Error instead
     case ConfigLogic.get_config_value(config, path) do
       {:ok, value} -> {:ok, value}
       {:error, _} = error -> error
     end
   end
   ```

2. **Hot Path Operations**
   ```elixir
   # Performance-critical code
   def emit_telemetry(event_name, measurements) do
     # Direct telemetry emission without context overhead
     :telemetry.execute(event_name, measurements, %{})
   end
   ```

## Architecture Integration

### Layer-by-Layer Usage

#### 1. Foundation Layer (Minimal Usage)
- **Only at layer boundaries** - initialization, shutdown
- **Service coordination** - when multiple services interact
- **Error-prone operations** - complex validation sequences

#### 2. Core Layers (Regular Usage)
- **AST Processing** - Multi-file parsing operations
- **Graph Construction** - Complex graph building algorithms
- **Analysis Workflows** - Multi-stage analysis pipelines

#### 3. Intelligence Layer (Heavy Usage)
- **AI Operations** - LLM interactions with retry logic
- **Learning Workflows** - Model training and evaluation
- **Cross-Layer Correlation** - Connecting runtime data with static analysis

#### 4. Application Layer (Always Use)
- **User API Endpoints** - All public API operations
- **Session Management** - Debug session lifecycle
- **System Operations** - Startup, shutdown, health checks

### Context Hierarchy Patterns

#### Parent-Child Contexts
```elixir
def complex_analysis(codebase) do
  parent_context = ErrorContext.new(__MODULE__, :complex_analysis,
    metadata: %{codebase_size: count_files(codebase)})
    
  ErrorContext.with_context(parent_context, fn ->
    # Child operation 1
    {:ok, ast_data} = parse_codebase_with_context(codebase, parent_context)
    
    # Child operation 2
    {:ok, graph_data} = build_graph_with_context(ast_data, parent_context)
    
    # Child operation 3
    {:ok, analysis} = analyze_graph_with_context(graph_data, parent_context)
    
    {:ok, analysis}
  end)
end

defp parse_codebase_with_context(codebase, parent_context) do
  child_context = ErrorContext.child_context(parent_context, __MODULE__, :parse_codebase,
    %{files: length(codebase.files)})
    
  ErrorContext.with_context(child_context, fn ->
    # Parsing logic here
    parse_all_files(codebase)
  end)
end
```

#### Correlation Tracking
```elixir
def handle_user_request(request) do
  # Extract or generate correlation ID
  correlation_id = get_correlation_id(request)
  
  context = ErrorContext.new(__MODULE__, :handle_user_request,
    correlation_id: correlation_id,
    metadata: %{
      user_id: request.user_id,
      request_type: request.type,
      timestamp: DateTime.utc_now()
    })
    
  ErrorContext.with_context(context, fn ->
    # All nested operations will share the correlation ID
    result = process_request(request)
    log_request_completion(request, result, correlation_id)
    result
  end)
end
```

## Error Handling Patterns

### Basic Pattern
```elixir
def my_operation(params) do
  context = ErrorContext.new(__MODULE__, :my_operation, metadata: %{params: params})
  
  ErrorContext.with_context(context, fn ->
    # Operation code here
    case do_something(params) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> 
        # Error will be automatically enhanced with context
        {:error, reason}
    end
  end)
end
```

### Enhanced Error Handling
```elixir
def enhanced_operation(params) do
  context = ErrorContext.new(__MODULE__, :enhanced_operation, metadata: %{params: params})
  
  case ErrorContext.with_context(context, fn ->
    # Add breadcrumbs for tracing
    context = ErrorContext.add_breadcrumb(context, __MODULE__, :validation, 
      %{step: "input_validation"})
    
    {:ok, validated} = validate_params(params)
    
    context = ErrorContext.add_breadcrumb(context, __MODULE__, :processing,
      %{step: "main_processing", validated_params: validated})
    
    {:ok, result} = process_validated_params(validated)
    
    {:ok, result}
  end) do
    {:ok, result} -> 
      {:ok, result}
      
    {:error, %Error{} = error} ->
      # Error already enhanced with context
      Logger.error("Operation failed: #{Error.to_string(error)}")
      {:error, error}
  end
end
```

### Nested Context Pattern
```elixir
def orchestrator_operation(workflow) do
  parent_context = ErrorContext.new(__MODULE__, :orchestrator_operation,
    metadata: %{workflow_id: workflow.id})
    
  ErrorContext.with_context(parent_context, fn ->
    # Step 1
    {:ok, prepared} = prepare_workflow(workflow, parent_context)
    
    # Step 2
    {:ok, executed} = execute_workflow(prepared, parent_context)
    
    # Step 3
    {:ok, finalized} = finalize_workflow(executed, parent_context)
    
    {:ok, finalized}
  end)
end

defp prepare_workflow(workflow, parent_context) do
  child_context = ErrorContext.child_context(parent_context, __MODULE__, :prepare_workflow,
    %{workflow_type: workflow.type})
    
  ErrorContext.with_context(child_context, fn ->
    # Preparation logic
    {:ok, prepared_workflow}
  end)
end
```

## Integration with Foundation Services

### Configuration Operations
```elixir
def reconfigure_system(new_config) do
  context = ErrorContext.new(__MODULE__, :reconfigure_system,
    metadata: %{config_keys: Map.keys(new_config)})
    
  ErrorContext.with_context(context, fn ->
    # Validate configuration
    case Config.validate(new_config) do
      :ok -> :ok
      {:error, error} -> {:error, ErrorContext.enhance_error(error, context)}
    end
    
    # Apply configuration updates
    Enum.each(new_config, fn {path, value} ->
      case Config.update(path, value) do
        :ok -> :ok
        {:error, error} -> 
          enhanced_error = ErrorContext.enhance_error(error, context)
          throw({:config_error, enhanced_error})
      end
    end)
    
    :ok
  end)
catch
  {:config_error, error} -> {:error, error}
end
```

### Event Correlation
```elixir
def correlated_event_processing(events) do
  correlation_id = Utils.generate_correlation_id()
  context = ErrorContext.new(__MODULE__, :correlated_event_processing,
    correlation_id: correlation_id,
    metadata: %{event_count: length(events)})
    
  ErrorContext.with_context(context, fn ->
    # All events will share the correlation ID
    processed_events = Enum.map(events, fn event ->
      {:ok, enhanced_event} = Events.new_event(event.type, event.data,
        correlation_id: correlation_id,
        metadata: %{processing_context: context.operation_id})
        
      {:ok, _event_id} = Events.store(enhanced_event)
      enhanced_event
    end)
    
    {:ok, processed_events}
  end)
end
```

### Telemetry Integration
```elixir
def measured_operation(data) do
  context = ErrorContext.new(__MODULE__, :measured_operation,
    metadata: %{data_size: byte_size(data)})
    
  ErrorContext.with_context(context, fn ->
    # Operation will automatically emit duration telemetry
    result = Telemetry.measure(
      [:myapp, :operation, :execution],
      %{
        operation_id: context.operation_id,
        correlation_id: context.correlation_id
      },
      fn ->
        process_data(data)
      end
    )
    
    result
  end)
end
```

## Debugging and Observability

### Context Inspection
```elixir
# Get current operation context for debugging
def debug_current_operation() do
  case ErrorContext.get_current_context() do
    nil -> 
      IO.puts("No active operation context")
      
    context ->
      IO.puts("Current Operation:")
      IO.puts("  ID: #{context.operation_id}")
      IO.puts("  Correlation: #{context.correlation_id}")
      IO.puts("  Duration: #{ErrorContext.get_operation_duration(context)}ns")
      IO.puts("  Breadcrumbs:")
      
      Enum.each(context.breadcrumbs, fn breadcrumb ->
        IO.puts("    #{breadcrumb.module}.#{breadcrumb.function} - #{breadcrumb.metadata}")
      end)
  end
end
```

### Breadcrumb Formatting
```elixir
def format_operation_trace(context) do
  breadcrumbs_str = ErrorContext.format_breadcrumbs(context)
  duration = ErrorContext.get_operation_duration(context)
  
  """
  Operation Trace:
    ID: #{context.operation_id}
    Correlation: #{context.correlation_id}
    Duration: #{Utils.format_duration(duration)}
    Path: #{breadcrumbs_str}
    Metadata: #{inspect(context.metadata)}
  """
end
```

### Error Analysis
```elixir
def analyze_error_context(%Error{context: %{operation_context: op_ctx}} = error) do
  %{
    error_summary: %{
      type: error.error_type,
      message: error.message,
      severity: error.severity
    },
    operation_summary: %{
      operation_id: op_ctx.operation_id,
      correlation_id: op_ctx.correlation_id,
      duration_ms: div(op_ctx.duration_ns, 1_000_000),
      breadcrumb_count: length(op_ctx.breadcrumbs)
    },
    operation_path: format_breadcrumb_path(op_ctx.breadcrumbs),
    recovery_suggestions: error.recovery_actions || []
  }
end
```

## Performance Optimization

### Context Reuse
```elixir
# Reuse context for related operations
def batch_operation(items, base_context) do
  Enum.map(items, fn item ->
    # Create child context for each item
    item_context = ErrorContext.child_context(base_context, __MODULE__, :process_item,
      %{item_id: item.id})
      
    ErrorContext.with_context(item_context, fn ->
      process_single_item(item)
    end)
  end)
end
```

### Conditional Context
```elixir
# Only use context for complex operations
def smart_operation(data, opts \\ []) do
  use_context = Keyword.get(opts, :use_context, byte_size(data) > 1000)
  
  if use_context do
    context = ErrorContext.new(__MODULE__, :smart_operation,
      metadata: %{data_size: byte_size(data)})
      
    ErrorContext.with_context(context, fn ->
      complex_processing(data)
    end)
  else
    # Direct processing for small data
    simple_processing(data)
  end
end
```

### Metadata Optimization
```elixir
# Optimize metadata size
def create_context_with_optimized_metadata(operation, data) do
  # Only include essential metadata
  essential_metadata = %{
    data_size: byte_size(data),
    operation_type: classify_operation(data),
    # Don't include the actual data
    timestamp: DateTime.utc_now()
  }
  
  ErrorContext.new(__MODULE__, operation, metadata: essential_metadata)
end
```

## Best Practices

### 1. Context Naming
```elixir
# Good: Descriptive operation names
context = ErrorContext.new(__MODULE__, :initialize_ai_analysis_pipeline, ...)

# Avoid: Generic names  
context = ErrorContext.new(__MODULE__, :process, ...)
```

### 2. Metadata Management
```elixir
# Good: Structured, relevant metadata
metadata = %{
  user_id: user.id,
  operation_type: :full_analysis,
  estimated_duration_ms: 5000,
  resource_requirements: %{memory_mb: 100, cpu_cores: 2}
}

# Avoid: Large or sensitive data
metadata = %{
  user_object: user,  # Too large
  api_key: "secret",  # Sensitive
  raw_data: binary    # Too large
}
```

### 3. Error Enhancement
```elixir
# Good: Enhance errors with context
case Foundation.operation() do
  {:ok, result} -> {:ok, result}
  {:error, error} -> {:error, ErrorContext.enhance_error(error, context)}
end

# Good: Use ErrorContext.add_context for external errors
case external_api_call() do
  {:ok, result} -> {:ok, result}
  {:error, reason} -> ErrorContext.add_context({:error, reason}, context)
end
```

### 4. Breadcrumb Usage
```elixir
# Good: Meaningful breadcrumbs at decision points
context = ErrorContext.add_breadcrumb(context, __MODULE__, :validation_passed,
  %{rules_checked: 15, validation_time_ms: 45})

context = ErrorContext.add_breadcrumb(context, __MODULE__, :entering_processing_phase,
  %{data_size: 1024, estimated_time_ms: 200})

# Avoid: Too many breadcrumbs
# Don't add breadcrumbs for every line of code
```

### 5. Context Lifecycle
```elixir
# Good: Clear context boundaries
def well_scoped_operation(params) do
  context = ErrorContext.new(__MODULE__, :well_scoped_operation, ...)
  
  ErrorContext.with_context(context, fn ->
    # All operation logic within context
    do_work(params)
  end)
end

# Avoid: Context leakage
def poorly_scoped_operation(params) do
  context = ErrorContext.new(__MODULE__, :poorly_scoped_operation, ...)
  
  # Missing with_context wrapper
  # Context stored in process dictionary but never cleaned up
  do_work(params)
end
```

---

## Conclusion

ErrorContext provides sophisticated error tracking and correlation capabilities for complex operations in ElixirScope. By using it appropriately at architectural boundaries and for multi-step operations, you can achieve:

- **Rich debugging information** with operation tracing
- **Cross-system correlation** with shared correlation IDs  
- **Hierarchical error context** with parent-child relationships
- **Automatic telemetry integration** for performance monitoring
- **Emergency recovery** with process dictionary fallbacks

The key is to use ErrorContext judiciously - for complex operations where the additional context and correlation capabilities provide real value, while using simple Error types for atomic Foundation operations.
