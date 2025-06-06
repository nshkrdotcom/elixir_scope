## Phase 3: Robustness Pattern Application

### 3.1 Pattern 1: Progressive Formalization in Foundation Layer

**Applied to Configuration System:**

```elixir
defmodule ElixirScope.Foundation.Config.ProgressiveValidation do
  @moduledoc """
  Progressive validation that starts lightweight and becomes more comprehensive
  """
  
  # Validation levels: :basic -> :standard -> :comprehensive -> :production
  @validation_levels [:basic, :standard, :comprehensive, :production]
  
  def validate_with_level(config, level \\ :standard) do
    case level do
      :basic -> 
        # Just check structure exists
        basic_structure_check(config)
        
      :standard -> 
        # Standard validation (current implementation)
        ElixirScope.Foundation.Config.validate(config)
        
      :comprehensive ->
        # Add cross-field validation and constraints
        with :ok <- ElixirScope.Foundation.Config.validate(config),
             :ok <- validate_cross_field_constraints(config),
             :ok <- validate_environmental_constraints(config) do
          :ok
        end
        
      :production ->
        # Full validation including runtime checks
        with :ok <- validate_with_level(config, :comprehensive),
             :ok <- validate_runtime_constraints(config),
             :ok <- validate_security_constraints(config) do
          :ok
        end
    end
  end
  
  defp basic_structure_check(%ElixirScope.Foundation.Config{} = _config), do: :ok
  defp basic_structure_check(_), do: {:error, Error.new(:invalid_config_structure, "Not a Config struct")}
  
  defp validate_cross_field_constraints(config) do
    # Example: ring buffer size should accommodate batch size
    ring_size = get_in(config, [:capture, :ring_buffer, :size]) || 0
    batch_size = get_in(config, [:capture, :processing, :batch_size]) || 0
    
    if ring_size >= batch_size * 2 do
      :ok
    else
      Error.error_result(:constraint_violation, 
                        "Ring buffer size should be at least 2x batch size",
                        context: %{ring_size: ring_size, batch_size: batch_size})
    end
  end
  
  defp validate_environmental_constraints(config) do
    # Check if AI provider is available in current environment
    provider = get_in(config, [:ai, :provider])
    api_key = get_in(config, [:ai, :api_key])
    
    if provider != :mock and is_nil(api_key) do
      Error.error_result(:constraint_violation,
                        "AI provider #{provider} requires API key in production",
                        context: %{provider: provider})
    else
      :ok
    end
  end
  
  defp validate_runtime_constraints(config) do
    # Check system resources can support configuration
    max_events = get_in(config, [:storage, :hot, :max_events]) || 0
    estimated_memory = max_events * 1024  # Rough estimate
    available_memory = :erlang.memory(:total)
    
    if estimated_memory > available_memory * 0.5 do  # Don't use more than 50% of memory
      Error.error_result(:resource_exhausted,
                        "Configuration would exceed available memory",
                        context: %{estimated: estimated_memory, available: available_memory})
    else
      :ok
    end
  end
  
  defp validate_security_constraints(config) do
    # Security validations for production
    debug_mode = get_in(config, [:dev, :debug_mode]) || false
    verbose_logging = get_in(config, [:dev, :verbose_logging]) || false
    
    if Mix.env() == :prod and (debug_mode or verbose_logging) do
      Error.error_result(:constraint_violation,
                        "Debug features should be disabled in production",
                        context: %{debug_mode: debug_mode, verbose_logging: verbose_logging})
    else
      :ok
    end
  end
end
```

**Applied to Event System:**

```elixir
defmodule ElixirScope.Foundation.Events.ProgressiveProcessing do
  @moduledoc """
  Progressive event processing with increasing sophistication
  """
  
  def process_event(event, processing_level \\ :standard) do
    context = ErrorContext.new(__MODULE__, :process_event, 
                              metadata: %{level: processing_level, event_type: event.event_type})
    
    ErrorContext.with_context(context, fn ->
      case processing_level do
        :minimal ->
          # Just validate and store
          basic_event_processing(event)
          
        :standard ->
          # Add correlation and basic enrichment
          with :ok <- basic_event_processing(event),
               enriched_event <- enrich_event(event),
               :ok <- store_event(enriched_event) do
            {:ok, enriched_event}
          end
          
        :comprehensive ->
          # Add pattern detection and analysis
          with {:ok, enriched_event} <- process_event(event, :standard),
               analysis <- analyze_event_patterns(enriched_event),
               :ok <- store_analysis(analysis) do
            {:ok, enriched_event, analysis}
          end
          
        :ai_enhanced ->
          # Add AI-powered insights (expensive)
          with {:ok, enriched_event, analysis} <- process_event(event, :comprehensive),
               insights <- generate_ai_insights(enriched_event, analysis) do
            {:ok, enriched_event, analysis, insights}
          end
      end
    end)
  end
  
  defp basic_event_processing(event) do
    case Events.validate_event(event) do
      :ok -> :ok
      {:error, _} = error -> error
    end
  end
  
  defp enrich_event(event) do
    # Add computed fields
    %{event | 
      data: Map.merge(event.data, %{
        enriched_at: Utils.wall_timestamp(),
        process_info: Utils.process_stats(event.pid)
      })
    }
  end
  
  defp store_event(_event), do: :ok  # Placeholder
  defp analyze_event_patterns(_event), do: %{}  # Placeholder
  defp store_analysis(_analysis), do: :ok  # Placeholder
  defp generate_ai_insights(_event, _analysis), do: %{}  # Placeholder
end
```

### 3.2 Pattern 2: Graceful Degradation in Foundation Layer

**Applied to Configuration Service:**

```elixir
defmodule ElixirScope.Foundation.Config.GracefulDegradation do
  @moduledoc """
  Graceful degradation for configuration service failures
  """
  
  # Cache for emergency fallback
  @fallback_cache :foundation_config_fallback
  
  def get_with_fallback(path \\ []) do
    case ElixirScope.Foundation.Config.get(path) do
      {:error, :service_unavailable} -> 
        get_fallback_config(path)
        
      {:error, reason} ->
        Logger.warn("Config get failed (#{inspect(reason)}), using fallback")
        get_fallback_config(path)
        
      config ->
        # Success - update fallback cache
        update_fallback_cache(path, config)
        config
    end
  end
  
  def update_with_fallback(path, value) do
    case ElixirScope.Foundation.Config.update(path, value) do
      :ok -> 
        # Success - update fallback cache
        update_fallback_cache(path, value)
        :ok
        
      {:error, :service_unavailable} ->
        Logger.warn("Config service unavailable, caching update for retry")
        cache_pending_update(path, value)
        :ok  # Return success but cache for later
        
      {:error, reason} = error ->
        Logger.error("Config update failed: #{inspect(reason)}")
        error
    end
  end
  
  def initialize_fallback_system do
    :ets.new(@fallback_cache, [:named_table, :public, :set])
    
    # Start background process to retry failed updates
    Task.start_link(&retry_pending_updates/0)
  end
  
  defp get_fallback_config([]) do
    case :ets.lookup(@fallback_cache, :full_config) do
      [{:full_config, config}] -> config
      [] -> get_default_config()
    end
  end
  
  defp get_fallback_config(path) do
    case :ets.lookup(@fallback_cache, path) do
      [{^path, value}] -> value
      [] -> 
        # Try to get from full config
        full_config = get_fallback_config([])
        get_in(full_config, path)
    end
  end
  
  defp update_fallback_cache([], config) do
    :ets.insert(@fallback_cache, {:full_config, config})
  end
  
  defp update_fallback_cache(path, value) do
    :ets.insert(@fallback_cache, {path, value})
  end
  
  defp cache_pending_update(path, value) do
    pending_key = {:pending, path}
    :ets.insert(@fallback_cache, {pending_key, {value, Utils.wall_timestamp()}})
  end
  
  defp retry_pending_updates do
    Process.sleep(5000)  # Wait 5 seconds between retries
    
    # Get all pending updates
    pending = :ets.match(@fallback_cache, {{:pending, :'$1'}, :'$2'})
    
    Enum.each(pending, fn [path, {value, _timestamp}] ->
      case ElixirScope.Foundation.Config.update(path, value) do
        :ok ->
          Logger.info("Successfully applied pending config update: #{inspect(path)}")
          :ets.delete(@fallback_cache, {:pending, path})
          
        {:error, reason} ->
          Logger.warn("Retry of pending config update failed: #{inspect(reason)}")
      end
    end)
    
    retry_pending_updates()
  end
  
  defp get_default_config do
    # Return minimal working configuration
    %ElixirScope.Foundation.Config{
      ai: %{
        provider: :mock,
        api_key: nil,
        model: "fallback",
        analysis: %{max_file_size: 100_000, timeout: 5_000, cache_ttl: 300},
        planning: %{default_strategy: :fast, performance_target: 0.1, sampling_rate: 0.1}
      },
      capture: %{
        ring_buffer: %{size: 100, max_events: 1000, overflow_strategy: :drop_oldest, num_buffers: 1},
        processing: %{batch_size: 10, flush_interval: 100, max_queue_size: 100},
        vm_tracing: %{enable_spawn_trace: false, enable_exit_trace: false, 
                     enable_message_trace: false, trace_children: false}
      },
      storage: %{
        hot: %{max_events: 1000, max_age_seconds: 300, prune_interval: 60_000},
        warm: %{enable: false, path: "/tmp", max_size_mb: 10, compression: :none},
        cold: %{enable: false}
      },
      interface: %{query_timeout: 1000, max_results: 100, enable_streaming: false},
      dev: %{debug_mode: false, verbose_logging: false, performance_monitoring: false}
    }
  end
end
```

**Applied to Event System:**

```elixir
defmodule ElixirScope.Foundation.Events.GracefulDegradation do
  @moduledoc """
  Graceful degradation for event system failures
  """
  
  @emergency_buffer :foundation_events_emergency
  
  def new_event_safe(event_type, data, opts \\ []) do
    case Events.new_event(event_type, data, opts) do
      {:error, reason} ->
        Logger.warn("Event creation failed (#{inspect(reason)}), creating minimal event")
        create_minimal_event(event_type, data, opts)
        
      event ->
        event
    end
  end
  
  def serialize_safe(event) do
    case Events.serialize(event) do
      {:error, reason} ->
        Logger.warn("Event serialization failed (#{inspect(reason)}), using fallback")
        fallback_serialize(event)
        
      binary ->
        binary
    end
  end
  
  def deserialize_safe(binary) do
    case Events.deserialize(binary) do
      {:error, reason} ->
        Logger.warn("Event deserialization failed (#{inspect(reason)}), attempting recovery")
        attempt_recovery_deserialize(binary)
        
      event ->
        event
    end
  end
  
  defp create_minimal_event(event_type, data, opts) do
    # Create bare minimum event structure
    %Events{
      event_id: Utils.generate_id(),
      event_type: event_type,
      timestamp: Utils.monotonic_timestamp(),
      wall_time: DateTime.utc_now(),
      node: Node.self(),
      pid: self(),
      correlation_id: Keyword.get(opts, :correlation_id),
      parent_id: Keyword.get(opts, :parent_id),
      data: safe_data_conversion(data)
    }
  end
  
  defp safe_data_conversion(data) do
    try do
      # Ensure data is serializable
      _test = :erlang.term_to_binary(data)
      data
    rescue
      _ ->
        # Fallback to string representation
        %{safe_representation: inspect(data), original_type: typeof(data)}
    end
  end
  
  defp fallback_serialize(event) do
    # Simple JSON-like serialization as fallback
    try do
      event
      |> Map.from_struct()
      |> Jason.encode!()
    rescue
      _ ->
        # Ultimate fallback
        inspect(event)
    end
  end
  
  defp attempt_recovery_deserialize(binary) do
    try do
      # Try JSON decode first
      case Jason.decode(binary) do
        {:ok, map} -> reconstruct_event_from_map(map)
        {:error, _} -> create_error_event(binary)
      end
    rescue
      _ -> create_error_event(binary)
    end
  end
  
  defp reconstruct_event_from_map(map) do
    # Attempt to reconstruct event from map
    %Events{
      event_id: Map.get(map, "event_id", Utils.generate_id()),
      event_type: String.to_atom(Map.get(map, "event_type", "unknown")),
      timestamp: Map.get(map, "timestamp", Utils.monotonic_timestamp()),
      wall_time: DateTime.utc_now(),
      node: Node.self(),
      pid: self(),
      correlation_id: Map.get(map, "correlation_id"),
      parent_id: Map.get(map, "parent_id"),
      data: Map.get(map, "data", %{recovery: true})
    }
  end
  
  defp create_error_event(binary) do
    %Events{
      event_id: Utils.generate_id(),
      event_type: :deserialization_error,
      timestamp: Utils.monotonic_timestamp(),
      wall_time: DateTime.utc_now(),
      node: Node.self(),
      pid: self(),
      correlation_id: nil,
      parent_id: nil,
      data: %{
        error: "Failed to deserialize event",
        binary_size: byte_size(binary),
        binary_sample: String.slice(binary, 0, 100)
      }
    }
  end
  
  defp typeof(value) when is_atom(value), do: :atom
  defp typeof(value) when is_binary(value), do: :string
  defp typeof(value) when is_map(value), do: :map
  defp typeof(value) when is_list(value), do: :list
  defp typeof(_), do: :unknown
end
```

### 3.3 Pattern 3: Circuit Breaker in Foundation Layer

**Applied to External Dependencies:**

```elixir
defmodule ElixirScope.Foundation.CircuitBreaker do
  @moduledoc """
  Circuit breaker implementation for protecting Foundation from external failures
  """
  
  use GenServer
  
  @states [:closed, :open, :half_open]
  @default_failure_threshold 5
  @default_reset_timeout 60_000  # 1 minute
  @default_success_threshold 3   # For half-open -> closed
  
  defstruct [
    :name,
    :state,
    :failure_count,
    :success_count,
    :last_failure_time,
    :failure_threshold,
    :reset_timeout,
    :success_threshold
  ]
  
  ## Client API
  
  def start_link(name, opts \\ []) do
    GenServer.start_link(__MODULE__, {name, opts}, name: via_tuple(name))
  end
  
  def call(name, fun, timeout \\ 5000) when is_function(fun, 0) do
    case GenServer.call(via_tuple(name), :get_state, timeout) do
      :open ->
        Error.error_result(:circuit_open, "Circuit breaker is open for #{name}")
        
      state when state in [:closed, :half_open] ->
        start_time = Utils.monotonic_timestamp()
        
        try do
          result = fun.()
          duration = Utils.monotonic_timestamp() - start_time
          
          GenServer.cast(via_tuple(name), {:record_success, duration})
          result
          
        rescue
          exception ->
            duration = Utils.monotonic_timestamp() - start_time
            GenServer.cast(via_tuple(name), {:record_failure, exception, duration})
            
            # Re-raise the exception
            reraise exception, __STACKTRACE__
        end
    end
  end
  
  def get_state(name) do
    GenServer.call(via_tuple(name), :get_state)
  end
  
  def reset(name) do
    GenServer.cast(via_tuple(name), :reset)
  end
  
  ## Server Implementation
  
  def init({name, opts}) do
    state = %__MODULE__{
      name: name,
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      failure_threshold: Keyword.get(opts, :failure_threshold, @default_failure_threshold),
      reset_timeout: Keyword.get(opts, :reset_timeout, @default_reset_timeout),
      success_threshold: Keyword.get(opts, :success_threshold, @default_success_threshold)
    }
    
    {:ok, state}
  end
  
  def handle_call(:get_state, _from, state) do
    current_state = maybe_transition_to_half_open(state)
    {:reply, current_state.state, current_state}
  end
  
  def handle_cast({:record_success, duration}, state) do
    new_state = handle_success(state, duration)
    {:noreply, new_state}
  end
  
  def handle_cast({:record_failure, exception, duration}, state) do
    new_state = handle_failure(state, exception, duration)
    {:noreply, new_state}
  end
  
  def handle_cast(:reset, state) do
    new_state = %{state | state: :closed, failure_count: 0, success_count: 0}
    {:noreply, new_state}
  end
  
  ## State Transitions
  
  defp handle_success(state, duration) do
    # Emit success metrics
    emit_circuit_metrics(state.name, :success, duration)
    
    case state.state do
      :closed ->
        # Reset failure count on success
        %{state | failure_count: 0}
        
      :half_open ->
        new_success_count = state.success_count + 1
        
        if new_success_count >= state.success_threshold do
          # Transition to closed
          Logger.info("Circuit breaker #{state.name} transitioned to CLOSED")
          %{state | state: :closed, success_count: 0, failure_count: 0}
        else
          %{state | success_count: new_success_count}
        end
        
      :open ->
        # Shouldn't happen, but handle gracefully
        state
    end
  end
  
  defp handle_failure(state, exception, duration) do
    # Emit failure metrics
    emit_circuit_metrics(state.name, :failure, duration, %{exception: exception.__struct__})
    
    new_failure_count = state.failure_count + 1
    
    case state.state do
      :closed when new_failure_count >= state.failure_threshold ->
        # Transition to open
        Logger.warn("Circuit breaker #{state.name} transitioned to OPEN after #{new_failure_count} failures")
        %{state | 
          state: :open, 
          failure_count: new_failure_count,
          last_failure_time: Utils.wall_timestamp()
        }
        
      :half_open ->
        # Transition back to open
        Logger.warn("Circuit breaker #{state.name} transitioned back to OPEN from HALF_OPEN")
        %{state | 
          state: :open, 
          failure_count: new_failure_count,
          success_count: 0,
          last_failure_time: Utils.wall_timestamp()
        }
        
      _ ->
        %{state | failure_count: new_failure_count}
    end
  end
  
  defp maybe_transition_to_half_open(%{state: :open} = state) do
    current_time = Utils.wall_timestamp()
    
    if current_time - state.last_failure_time >= state.reset_timeout do
      Logger.info("Circuit breaker #{state.name} transitioned to HALF_OPEN")
      %{state | state: :half_open, success_count: 0}
    else
      state
    end
  end
  
  defp maybe_transition_to_half_open(state), do: state
  
  ## Utilities
  
  defp via_tuple(name) do
    {:via, Registry, {ElixirScope.Foundation.CircuitBreakerRegistry, name}}
  end
  
  defp emit_circuit_metrics(name, result, duration, metadata \\ %{}) do
    Telemetry.emit_counter(
      [:foundation, :circuit_breaker, result],
      Map.merge(metadata, %{circuit_name: name})
    )
    
    Telemetry.emit_gauge(
      [:foundation, :circuit_breaker, :duration],
      duration,
      %{circuit_name: name, result: result}
    )
  end
end
```

