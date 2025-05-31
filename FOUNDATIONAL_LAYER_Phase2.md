
## Phase 2: Robust Design Implementation

### 2.1 Fix Struct Handling with Explicit Error Management

**Step 1: Replace Silent Fallbacks with Explicit Error Handling**

```elixir
# NEW: Robust Config module with explicit error handling
defmodule ElixirScope.Foundation.Config do
  use GenServer
  
  alias ElixirScope.Foundation.{Error, ErrorContext}
  
  @behaviour Access
  
  # Structure remains the same but with validation
  defstruct [
    ai: %{
      provider: :mock,
      api_key: nil,
      model: "gpt-4",
      analysis: %{
        max_file_size: 1_000_000,
        timeout: 30_000,
        cache_ttl: 3600
      },
      planning: %{
        default_strategy: :balanced,
        performance_target: 0.01,
        sampling_rate: 1.0
      }
    },
    # ... other fields
  ]

  ## Access Behavior - Fixed Implementation
  
  @impl Access
  def fetch(%__MODULE__{} = config, key) do
    config
    |> Map.from_struct()
    |> Map.fetch(key)
  end

  @impl Access
  def get_and_update(%__MODULE__{} = config, key, function) do
    context = ErrorContext.new(__MODULE__, :get_and_update, 
                              metadata: %{key: key})
    
    ErrorContext.with_context(context, fn ->
      map_config = Map.from_struct(config)
      
      case Map.get_and_update(map_config, key, function) do
        {current_value, updated_map} ->
          case safe_struct_creation(updated_map, context) do
            {:ok, updated_config} ->
              case validate_config_change(config, updated_config, key, context) do
                :ok -> {current_value, updated_config}
                {:error, validation_error} ->
                  # Log error but maintain original config
                  Logger.error("Config validation failed: #{Error.to_string(validation_error)}")
                  {current_value, config}
              end
            {:error, struct_error} ->
              Logger.error("Config struct creation failed: #{Error.to_string(struct_error)}")
              {current_value, config}
          end
      end
    end)
  end

  @impl Access
  def pop(%__MODULE__{} = config, key) do
    context = ErrorContext.new(__MODULE__, :pop, metadata: %{key: key})
    
    ErrorContext.with_context(context, fn ->
      map_config = Map.from_struct(config)
      {value, updated_map} = Map.pop(map_config, key)
      
      case safe_struct_creation(updated_map, context) do
        {:ok, updated_config} -> {value, updated_config}
        {:error, _} -> {value, config}  # Fallback to original
      end
    end)
  end

  ## Safe Struct Creation with Validation
  
  defp safe_struct_creation(map_data, context) do
    ErrorContext.with_context(context, fn ->
      try do
        # Attempt struct creation
        new_config = struct(__MODULE__, map_data)
        
        # Validate the new struct
        case validate_struct_integrity(new_config) do
          :ok -> {:ok, new_config}
          {:error, _} = error -> error
        end
      rescue
        error in [ArgumentError, KeyError] ->
          Error.error_result(
            :invalid_config_structure,
            "Failed to create Config struct: #{Exception.message(error)}",
            context: %{map_data: inspect(map_data), error: Exception.message(error)}
          )
      end
    end)
  end

  defp validate_struct_integrity(%__MODULE__{} = config) do
    # Ensure all required fields are present and have correct types
    required_checks = [
      {config.ai, :map, "ai config must be a map"},
      {config.capture, :map, "capture config must be a map"},
      {config.storage, :map, "storage config must be a map"},
      {config.interface, :map, "interface config must be a map"},
      {config.dev, :map, "dev config must be a map"}
    ]
    
    case validate_required_fields(required_checks) do
      :ok -> validate(config)  # Full validation
      {:error, _} = error -> error
    end
  end

  defp validate_required_fields(checks) do
    errors = Enum.reduce(checks, [], fn {value, expected_type, error_msg}, acc ->
      if valid_type?(value, expected_type) do
        acc
      else
        [error_msg | acc]
      end
    end)
    
    case errors do
      [] -> :ok
      _ -> Error.error_result(
        :invalid_config_structure,
        "Config structure validation failed",
        context: %{errors: errors}
      )
    end
  end

  defp validate_config_change(old_config, new_config, changed_key, context) do
    # Only validate the changed section for performance
    case changed_key do
      :ai -> validate_ai_config(new_config.ai)
      :capture -> validate_capture_config(new_config.capture)
      :storage -> validate_storage_config(new_config.storage)
      :interface -> validate_interface_config(new_config.interface)
      :dev -> validate_dev_config(new_config.dev)
      _ -> validate(new_config)  # Full validation for unknown keys
    end
  end
```

**Step 2: Complete All Missing Validation Functions**

```elixir
  ## Complete Validation Implementation

  def validate(%__MODULE__{} = config) do
    context = ErrorContext.new(__MODULE__, :validate)
    
    ErrorContext.with_context(context, fn ->
      validation_steps = [
        {:ai, fn -> validate_ai_config(config.ai) end},
        {:capture, fn -> validate_capture_config(config.capture) end},
        {:storage, fn -> validate_storage_config(config.storage) end},
        {:interface, fn -> validate_interface_config(config.interface) end},
        {:dev, fn -> validate_dev_config(config.dev) end}
      ]
      
      execute_validation_pipeline(validation_steps, context)
    end)
  end

  defp execute_validation_pipeline(steps, context) do
    Enum.reduce_while(steps, :ok, fn {section, validator}, _acc ->
      case ErrorContext.with_context(context, validator) do
        :ok -> {:cont, :ok}
        {:error, error} ->
          enhanced_error = Error.add_context(error, %{
            validation_section: section,
            context: context
          })
          {:halt, {:error, enhanced_error}}
      end
    end)
  end

  # AI Configuration Validation - Complete Implementation
  defp validate_ai_config(%{provider: provider} = config) when is_map(config) do
    context = ErrorContext.new(__MODULE__, :validate_ai_config, 
                              metadata: %{provider: provider})
    
    ErrorContext.with_context(context, fn ->
      with :ok <- validate_ai_provider(provider),
           :ok <- validate_ai_analysis(config[:analysis] || %{}),
           :ok <- validate_ai_planning(config[:planning] || %{}) do
        :ok
      end
    end)
  end
  defp validate_ai_config(config) do
    Error.error_result(
      :invalid_config_structure,
      "AI config must be a map with provider field",
      context: %{received: config}
    )
  end

  defp validate_ai_provider(provider) when provider in [:mock, :openai, :anthropic, :gemini] do
    :ok
  end
  defp validate_ai_provider(provider) do
    Error.error_result(
      :invalid_config_value,
      "Invalid AI provider",
      context: %{
        received: provider,
        valid_providers: [:mock, :openai, :anthropic, :gemini]
      }
    )
  end

  defp validate_ai_analysis(analysis) when is_map(analysis) do
    required_fields = [
      {:max_file_size, :positive_integer, "max_file_size must be a positive integer"},
      {:timeout, :positive_integer, "timeout must be a positive integer"},
      {:cache_ttl, :positive_integer, "cache_ttl must be a positive integer"}
    ]
    
    validate_config_section(analysis, required_fields, :ai_analysis)
  end

  defp validate_ai_planning(planning) when is_map(planning) do
    with :ok <- validate_planning_strategy(planning[:default_strategy]),
         :ok <- validate_performance_target(planning[:performance_target]),
         :ok <- validate_sampling_rate(planning[:sampling_rate]) do
      :ok
    end
  end

  defp validate_planning_strategy(strategy) when strategy in [:fast, :balanced, :thorough] do
    :ok
  end
  defp validate_planning_strategy(strategy) do
    Error.error_result(
      :invalid_config_value,
      "Invalid planning strategy",
      context: %{
        received: strategy,
        valid_strategies: [:fast, :balanced, :thorough]
      }
    )
  end

  defp validate_performance_target(target) when is_number(target) and target >= 0 do
    :ok
  end
  defp validate_performance_target(target) do
    Error.error_result(
      :constraint_violation,
      "Performance target must be a non-negative number",
      context: %{received: target}
    )
  end

  defp validate_sampling_rate(rate) when is_number(rate) and rate >= 0 and rate <= 1 do
    :ok
  end
  defp validate_sampling_rate(rate) do
    Error.error_result(
      :range_error,
      "Sampling rate must be between 0 and 1",
      context: %{received: rate}
    )
  end

  # Capture Configuration Validation - New Implementation
  defp validate_capture_config(capture) when is_map(capture) do
    context = ErrorContext.new(__MODULE__, :validate_capture_config)
    
    ErrorContext.with_context(context, fn ->
      with :ok <- validate_ring_buffer(capture[:ring_buffer] || %{}),
           :ok <- validate_processing(capture[:processing] || %{}),
           :ok <- validate_vm_tracing(capture[:vm_tracing] || %{}) do
        :ok
      end
    end)
  end

  defp validate_ring_buffer(buffer_config) when is_map(buffer_config) do
    required_fields = [
      {:size, :positive_integer, "ring buffer size must be positive integer"},
      {:max_events, :positive_integer, "max_events must be positive integer"},
      {:overflow_strategy, :overflow_strategy, "invalid overflow strategy"},
      {:num_buffers, :buffer_count, "invalid buffer count"}
    ]
    
    validate_config_section(buffer_config, required_fields, :ring_buffer)
  end

  defp validate_processing(proc_config) when is_map(proc_config) do
    required_fields = [
      {:batch_size, :positive_integer, "batch_size must be positive integer"},
      {:flush_interval, :positive_integer, "flush_interval must be positive integer"},
      {:max_queue_size, :positive_integer, "max_queue_size must be positive integer"}
    ]
    
    validate_config_section(proc_config, required_fields, :processing)
  end

  defp validate_vm_tracing(vm_config) when is_map(vm_config) do
    required_fields = [
      {:enable_spawn_trace, :boolean, "enable_spawn_trace must be boolean"},
      {:enable_exit_trace, :boolean, "enable_exit_trace must be boolean"},
      {:enable_message_trace, :boolean, "enable_message_trace must be boolean"},
      {:trace_children, :boolean, "trace_children must be boolean"}
    ]
    
    validate_config_section(vm_config, required_fields, :vm_tracing)
  end

  # Storage Configuration Validation - New Implementation
  defp validate_storage_config(storage) when is_map(storage) do
    context = ErrorContext.new(__MODULE__, :validate_storage_config)
    
    ErrorContext.with_context(context, fn ->
      with :ok <- validate_hot_storage(storage[:hot] || %{}),
           :ok <- validate_warm_storage(storage[:warm] || %{}),
           :ok <- validate_cold_storage(storage[:cold] || %{}) do
        :ok
      end
    end)
  end

  defp validate_hot_storage(hot_config) when is_map(hot_config) do
    required_fields = [
      {:max_events, :positive_integer, "max_events must be positive integer"},
      {:max_age_seconds, :positive_integer, "max_age_seconds must be positive integer"},
      {:prune_interval, :positive_integer, "prune_interval must be positive integer"}
    ]
    
    validate_config_section(hot_config, required_fields, :hot_storage)
  end

  defp validate_warm_storage(%{enable: false}), do: :ok
  defp validate_warm_storage(%{enable: true} = warm_config) do
    required_fields = [
      {:path, :string, "path must be a string"},
      {:max_size_mb, :positive_integer, "max_size_mb must be positive integer"},
      {:compression, :compression_type, "invalid compression type"}
    ]
    
    validate_config_section(warm_config, required_fields, :warm_storage)
  end
  defp validate_warm_storage(warm_config) do
    Error.error_result(
      :invalid_config_structure,
      "Warm storage config must have enable field",
      context: %{received: warm_config}
    )
  end

  defp validate_cold_storage(%{enable: false}), do: :ok
  defp validate_cold_storage(%{enable: true}), do: :ok  # Placeholder for future
  defp validate_cold_storage(cold_config) do
    Error.error_result(
      :invalid_config_structure,
      "Cold storage config must have enable field",
      context: %{received: cold_config}
    )
  end

  # Interface Configuration Validation - New Implementation
  defp validate_interface_config(interface) when is_map(interface) do
    required_fields = [
      {:query_timeout, :positive_integer, "query_timeout must be positive integer"},
      {:max_results, :positive_integer, "max_results must be positive integer"},
      {:enable_streaming, :boolean, "enable_streaming must be boolean"}
    ]
    
    validate_config_section(interface, required_fields, :interface)
  end

  # Dev Configuration Validation - New Implementation
  defp validate_dev_config(dev) when is_map(dev) do
    required_fields = [
      {:debug_mode, :boolean, "debug_mode must be boolean"},
      {:verbose_logging, :boolean, "verbose_logging must be boolean"},
      {:performance_monitoring, :boolean, "performance_monitoring must be boolean"}
    ]
    
    validate_config_section(dev, required_fields, :dev)
  end

  ## Validation Helpers

  defp validate_config_section(config_map, required_fields, section_name) do
    errors = Enum.reduce(required_fields, [], fn {field, type, error_msg}, acc ->
      value = Map.get(config_map, field)
      
      if valid_type?(value, type) do
        acc
      else
        ["#{field}: #{error_msg} (got: #{inspect(value)})" | acc]
      end
    end)
    
    case errors do
      [] -> :ok
      _ -> Error.error_result(
        :validation_failed,
        "Configuration validation failed for #{section_name}",
        context: %{section: section_name, errors: errors}
      )
    end
  end

  defp valid_type?(value, :positive_integer), do: is_integer(value) and value > 0
  defp valid_type?(value, :boolean), do: is_boolean(value)
  defp valid_type?(value, :string), do: is_binary(value)
  defp valid_type?(value, :overflow_strategy), do: value in [:drop_oldest, :drop_newest, :block]
  defp valid_type?(value, :compression_type), do: value in [:none, :gzip, :zstd]
  defp valid_type?(:schedulers, :buffer_count), do: true
  defp valid_type?(value, :buffer_count), do: is_integer(value) and value > 0
  defp valid_type?(_value, _type), do: false
```

### 2.2 Formalized Error Code System

**Step 3: Implement Standardized Error Code Architecture**

```elixir
# Enhanced Error module with formalized error propagation
defmodule ElixirScope.Foundation.Error do
  
  # Hierarchical Error Code System
  @error_categories %{
    # Configuration errors (C000-C999)
    config: %{
      base_code: 1000,
      subcodes: %{
        structure: 100,    # C100-C199: Structure issues
        validation: 200,   # C200-C299: Validation failures  
        access: 300,       # C300-C399: Access/permission issues
        runtime: 400       # C400-C499: Runtime update issues
      }
    },
    
    # System errors (S000-S999)
    system: %{
      base_code: 2000,
      subcodes: %{
        initialization: 100,  # S100-S199: Startup failures
        resources: 200,       # S200-S299: Resource exhaustion
        dependencies: 300,    # S300-S399: Dependency failures
        runtime: 400          # S400-S499: Runtime system errors
      }
    },
    
    # Data errors (D000-D999)
    data: %{
      base_code: 3000,
      subcodes: %{
        serialization: 100,   # D100-D199: Serialization issues
        validation: 200,      # D200-D299: Data validation
        corruption: 300,      # D300-D399: Data corruption
        not_found: 400        # D400-D499: Missing data
      }
    },
    
    # External errors (E000-E999)
    external: %{
      base_code: 4000,
      subcodes: %{
        network: 100,         # E100-E199: Network issues
        service: 200,         # E200-E299: External service failures
        timeout: 300,         # E300-E399: Timeout issues
        auth: 400            # E400-E499: Authentication failures
      }
    }
  }

  @error_definitions %{
    # Configuration Errors
    {:config, :structure, :invalid_config_structure} => {1101, :high, "Configuration structure is invalid"},
    {:config, :structure, :missing_required_field} => {1102, :high, "Required configuration field missing"},
    {:config, :validation, :invalid_config_value} => {1201, :medium, "Configuration value failed validation"},
    {:config, :validation, :constraint_violation} => {1202, :medium, "Configuration constraint violated"},
    {:config, :validation, :range_error} => {1203, :low, "Value outside acceptable range"},
    {:config, :access, :config_not_found} => {1301, :high, "Configuration not found"},
    {:config, :runtime, :config_update_forbidden} => {1401, :medium, "Configuration update not allowed"},
    
    # System Errors  
    {:system, :initialization, :initialization_failed} => {2101, :critical, "System initialization failed"},
    {:system, :initialization, :service_unavailable} => {2102, :high, "Required service unavailable"},
    {:system, :resources, :resource_exhausted} => {2201, :high, "System resources exhausted"},
    {:system, :dependencies, :dependency_failed} => {2301, :high, "Required dependency failed"},
    {:system, :runtime, :internal_error} => {2401, :critical, "Internal system error"},
    
    # Data Errors
    {:data, :serialization, :serialization_failed} => {3101, :medium, "Data serialization failed"},
    {:data, :serialization, :deserialization_failed} => {3102, :medium, "Data deserialization failed"},
    {:data, :validation, :type_mismatch} => {3201, :low, "Data type mismatch"},
    {:data, :validation, :format_error} => {3202, :low, "Data format error"},
    {:data, :corruption, :data_corruption} => {3301, :critical, "Data corruption detected"},
    {:data, :not_found, :data_not_found} => {3401, :low, "Requested data not found"},
    
    # External Errors
    {:external, :network, :network_error} => {4101, :medium, "Network communication error"},
    {:external, :service, :external_service_error} => {4201, :medium, "External service error"},
    {:external, :timeout, :timeout} => {4301, :medium, "Operation timeout"},
    {:external, :auth, :authentication_failed} => {4401, :high, "Authentication failed"}
  }

  defstruct [
    :code,              # Hierarchical error code (e.g., 1201)
    :error_type,        # Symbolic error type (e.g., :invalid_config_value)
    :message,           # Human-readable message
    :severity,          # :low, :medium, :high, :critical
    :context,           # Error context map
    :correlation_id,    # For tracing
    :timestamp,         # When error occurred
    :stacktrace,        # Stack trace if available
    :category,          # :config, :system, :data, :external
    :subcategory,       # :structure, :validation, etc.
    :retry_strategy,    # How to handle retries
    :recovery_actions   # Suggested recovery steps
  ]

  ## Error Creation API

  def new(error_type, message \\ nil, opts \\ []) do
    {code, severity, default_message} = get_error_definition(error_type)
    {category, subcategory} = categorize_error(error_type)
    
    %__MODULE__{
      code: code,
      error_type: error_type,
      message: message || default_message,
      severity: severity,
      context: Keyword.get(opts, :context, %{}),
      correlation_id: Keyword.get(opts, :correlation_id),
      timestamp: DateTime.utc_now(),
      stacktrace: Keyword.get(opts, :stacktrace),
      category: category,
      subcategory: subcategory,
      retry_strategy: determine_retry_strategy(error_type, severity),
      recovery_actions: suggest_recovery_actions(error_type, opts)
    }
  end

  ## Error Result Helpers

  def error_result(error_type, message \\ nil, opts \\ []) do
    {:error, new(error_type, message, opts)}
  end

  def wrap_error(result, error_type, message \\ nil, opts \\ []) do
    case result do
      {:error, existing_error} when is_struct(existing_error, __MODULE__) ->
        # Chain errors while preserving original context
        enhanced_error = %{existing_error | 
          context: Map.merge(existing_error.context, %{
            wrapped_by: error_type,
            wrapper_message: message,
            wrapper_context: Keyword.get(opts, :context, %{})
          })
        }
        {:error, enhanced_error}
      
      {:error, reason} ->
        # Wrap raw error reasons
        error_result(error_type, message, 
                    Keyword.put(opts, :context, 
                               Map.merge(Keyword.get(opts, :context, %{}), 
                                       %{original_reason: reason})))
      
      other ->
        other
    end
  end

  ## Error Analysis and Recovery

  def is_retryable?(%__MODULE__{retry_strategy: strategy}) do
    strategy != :no_retry
  end

  def retry_delay(%__MODULE__{retry_strategy: :exponential_backoff}, attempt) do
    min(1000 * :math.pow(2, attempt), 30_000) |> round()
  end
  def retry_delay(%__MODULE__{retry_strategy: :fixed_delay}, _attempt), do: 1000
  def retry_delay(%__MODULE__{retry_strategy: :immediate}, _attempt), do: 0
  def retry_delay(%__MODULE__{retry_strategy: :no_retry}, _attempt), do: :infinity

  def should_escalate?(%__MODULE__{severity: severity}) do
    severity in [:high, :critical]
  end

  ## Private Implementation

  defp get_error_definition(error_type) do
    # Find the error definition by searching the hierarchy
    Enum.find_value(@error_definitions, {9999, :unknown, "Unknown error"}, fn
      {{_cat, _subcat, ^error_type}, definition} -> definition
      _ -> nil
    end)
  end

  defp categorize_error(error_type) do
    Enum.find_value(@error_definitions, {:unknown, :unknown}, fn
      {{cat, subcat, ^error_type}, _definition} -> {cat, subcat}
      _ -> nil
    end)
  end

  defp determine_retry_strategy(error_type, severity) do
    case {error_type, severity} do
      # Network errors are usually retryable
      {error_type, _} when error_type in [:network_error, :timeout] -> :exponential_backoff
      # Service errors might be retryable
      {:external_service_error, severity} when severity in [:low, :medium] -> :fixed_delay
      # System resource issues might resolve quickly
      {:resource_exhausted, _} -> :immediate
      # Config and data errors usually aren't retryable
      {error_type, _} when error_type in [:invalid_config_value, :data_corruption] -> :no_retry
      # High severity errors generally shouldn't be retried
      {_, :critical} -> :no_retry
      # Default: allow one retry with delay
      _ -> :fixed_delay
    end
  end

  defp suggest_recovery_actions(error_type, opts) do
    base_actions = case error_type do
      :invalid_config_value ->
        ["Check configuration format", "Validate against schema", "Review documentation"]
      :service_unavailable ->
        ["Check service health", "Verify network connectivity", "Review service logs"]
      :resource_exhausted ->
        ["Check memory usage", "Review resource limits", "Scale resources if needed"]
      :timeout ->
        ["Increase timeout value", "Check network latency", "Review service performance"]
      _ ->
        ["Check logs for details", "Review error context", "Contact support if needed"]
    end
    
    # Add context-specific actions
    context_actions = case Keyword.get(opts, :context) do
      %{operation: operation} -> ["Review #{operation} implementation"]
      _ -> []
    end
    
    base_actions ++ context_actions
  end

  ## String Representation

  def to_string(%__MODULE__{} = error) do
    base = "[#{error.code}:#{error.error_type}] #{error.message}"
    
    context_str = if map_size(error.context) > 0 do
      " | Context: #{inspect(error.context, limit: 3)}"
    else
      ""
    end
    
    severity_str = " | Severity: #{error.severity}"
    
    base <> context_str <> severity_str
  end

  ## Error Metrics Collection

  def collect_error_metrics(%__MODULE__{} = error) do
    # Emit telemetry for error tracking
    ElixirScope.Foundation.Telemetry.emit_counter(
      [:foundation, :errors, error.category, error.subcategory],
      %{
        error_type: error.error_type,
        severity: error.severity,
        code: error.code
      }
    )
  end
end
```

### 2.3 Enhanced Error Context with Proper Propagation

**Step 4: Implement Robust Error Context Propagation**

```elixir
defmodule ElixirScope.Foundation.ErrorContext do
  alias ElixirScope.Foundation.Error
  
  defstruct [
    :operation_id,      # Unique ID for this operation
    :module,            # Module where operation started
    :function,          # Function where operation started
    :correlation_id,    # Cross-system correlation
    :start_time,        # When operation began
    :metadata,          # Additional context data
    :breadcrumbs,       # Operation trail
    :parent_context     # Nested context support
  ]

  ## Context Creation and Management

  def new(module, function, opts \\ []) do
    %__MODULE__{
      operation_id: ElixirScope.Foundation.Utils.generate_id(),
      module: module,
      function: function,
      correlation_id: Keyword.get(opts, :correlation_id, 
                                 ElixirScope.Foundation.Utils.generate_correlation_id()),
      start_time: ElixirScope.Foundation.Utils.monotonic_timestamp(),
      metadata: Keyword.get(opts, :metadata, %{}),
      breadcrumbs: [%{module: module, function: function, 
                     timestamp: ElixirScope.Foundation.Utils.monotonic_timestamp()}],
      parent_context: Keyword.get(opts, :parent_context)
    }
  end

  def child_context(%__MODULE__{} = parent, module, function, metadata \\ %{}) do
    %__MODULE__{
      operation_id: ElixirScope.Foundation.Utils.generate_id(),
      module: module,
      function: function,
      correlation_id: parent.correlation_id,
      start_time: ElixirScope.Foundation.Utils.monotonic_timestamp(),
      metadata: Map.merge(parent.metadata, metadata),
      breadcrumbs: parent.breadcrumbs ++ [%{
        module: module, 
        function: function, 
        timestamp: ElixirScope.Foundation.Utils.monotonic_timestamp()
      }],
      parent_context: parent
    }
  end

  def add_breadcrumb(%__MODULE__{} = context, module, function, metadata \\ %{}) do
    breadcrumb = %{
      module: module,
      function: function,
      timestamp: ElixirScope.Foundation.Utils.monotonic_timestamp(),
      metadata: metadata
    }
    
    %{context | breadcrumbs: context.breadcrumbs ++ [breadcrumb]}
  end

  def add_metadata(%__MODULE__{} = context, new_metadata) when is_map(new_metadata) do
    %{context | metadata: Map.merge(context.metadata, new_metadata)}
  end

  ## Error Context Integration

  def with_context(%__MODULE__{} = context, fun) when is_function(fun, 0) do
    # Store context in process dictionary for emergency access
    Process.put(:error_context, context)
    
    try do
      result = fun.()
      
      # Clean up and enhance successful results with context
      Process.delete(:error_context)
      enhance_result_with_context(result, context)
      
    rescue
      exception ->
        # Capture and enhance exception with full context
        enhanced_error = create_exception_error(exception, context, __STACKTRACE__)
        
        # Clean up
        Process.delete(:error_context)
        
        # Emit error telemetry
        Error.collect_error_metrics(enhanced_error)
        
        {:error, enhanced_error}
    end
  end

  def enhance_error(%Error{} = error, %__MODULE__{} = context) do
    # Enhance existing error with additional context
    enhanced_context = Map.merge(error.context, %{
      operation_context: %{
        operation_id: context.operation_id,
        correlation_id: context.correlation_id,
        breadcrumbs: context.breadcrumbs,
        duration_ns: ElixirScope.Foundation.Utils.monotonic_timestamp() - context.start_time,
        metadata: context.metadata
      }
    })
    
    %{error | 
      context: enhanced_context,
      correlation_id: error.correlation_id || context.correlation_id
    }
  end

  def enhance_error({:error, %Error{} = error}, %__MODULE__{} = context) do
    {:error, enhance_error(error, context)}
  end
  
  def enhance_error({:error, reason}, %__MODULE__{} = context) do
    # Convert raw error to structured error with context
    error = Error.new(:external_error, "External operation failed", [
      context: %{
        original_reason: reason,
        operation_context: %{
          operation_id: context.operation_id,
          correlation_id: context.correlation_id,
          breadcrumbs: context.breadcrumbs,
          duration_ns: ElixirScope.Foundation.Utils.monotonic_timestamp() - context.start_time
        }
      },
      correlation_id: context.correlation_id
    ])
    
    {:error, error}
  end

  def enhance_error(result, _context), do: result

  ## Context Recovery and Debugging

  def get_current_context do
    # Emergency context retrieval from process dictionary
    Process.get(:error_context)
  end

  def format_breadcrumbs(%__MODULE__{breadcrumbs: breadcrumbs}) do
    Enum.map_join(breadcrumbs, " -> ", fn %{module: mod, function: func, timestamp: ts} ->
      relative_time = ElixirScope.Foundation.Utils.monotonic_timestamp() - ts
      "#{mod}.#{func} (#{ElixirScope.Foundation.Utils.format_duration(relative_time)} ago)"
    end)
  end

  def get_operation_duration(%__MODULE__{start_time: start_time}) do
    ElixirScope.Foundation.Utils.monotonic_timestamp() - start_time
  end

  ## Private Helpers

  defp enhance_result_with_context(result, context) do
    # For successful results, we might want to add telemetry
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

  defp create_exception_error(exception, context, stacktrace) do
    Error.new(:internal_error, "Exception in operation: #{Exception.message(exception)}", [
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
    ])
  end

  defp format_stacktrace(stacktrace) do
    stacktrace
    |> Enum.take(10)  # Limit depth
    |> Enum.map(fn
      {module, function, arity, location} ->
        %{
          module: module,
          function: function,
          arity: arity,
          file: Keyword.get(location, :file),
          line: Keyword.get(location, :line)
        }
      entry ->
        %{raw: inspect(entry)}
    end)
  end
end
```