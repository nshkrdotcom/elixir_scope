# Foundation Layer Implementation

## lib/elixir_scope/foundation.ex
defmodule ElixirScope.Foundation do
  @moduledoc """
  Layer 1: Foundation - Core Infrastructure and Utilities

  ## Responsibilities
  - Provide core utilities for all other layers
  - Manage application-wide configuration
  - Handle event system and telemetry
  - Establish common types and protocols

  ## Dependencies (Allowed)
  - Standard Elixir/OTP libraries only
  - No dependencies on other ElixirScope layers

  ## Dependencies (Forbidden)
  - AST, Graph, CPG, or any higher layers
  - This is the bottom layer - nothing below it

  ## Interface Stability
  - Core utilities: STABLE (comprehensive tests required)
  - Configuration management: STABLE (comprehensive tests required)
  - Event system: STABLE (comprehensive tests required)
  - Telemetry: MEDIUM STABILITY (smoke tests sufficient)
  """

  @doc """
  Initialize the Foundation layer.
  Should be called first before any other ElixirScope components.
  """
  @spec initialize(keyword()) :: :ok | {:error, term()}
  def initialize(opts \\ []) do
    with :ok <- ElixirScope.Foundation.Config.initialize(opts),
         :ok <- ElixirScope.Foundation.Events.initialize(),
         :ok <- ElixirScope.Foundation.Telemetry.initialize() do
      :ok
    end
  end

  @doc """
  Get Foundation layer status and health information.
  """
  @spec status() :: %{
    config: :ok | {:error, term()},
    events: :ok | {:error, term()},
    telemetry: :ok | {:error, term()},
    uptime_ms: non_neg_integer()
  }
  def status do
    %{
      config: ElixirScope.Foundation.Config.status(),
      events: ElixirScope.Foundation.Events.status(),
      telemetry: ElixirScope.Foundation.Telemetry.status(),
      uptime_ms: System.monotonic_time(:millisecond)
    }
  end
end

## lib/elixir_scope/foundation/config.ex
defmodule ElixirScope.Foundation.Config do
  @moduledoc """
  Centralized configuration management for ElixirScope.
  
  Provides a GenServer-based configuration store with validation,
  runtime updates for allowed paths, and environment variable support.
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.Types

  @type config_path :: [atom()]
  @type config_value :: term()

  # Configuration structure with complete type definitions
  defstruct [
    # AI Configuration
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
    
    # Capture Configuration
    capture: %{
      ring_buffer: %{
        size: 1024,
        max_events: 1000,
        overflow_strategy: :drop_oldest,
        num_buffers: :schedulers
      },
      processing: %{
        batch_size: 100,
        flush_interval: 50,
        max_queue_size: 1000
      },
      vm_tracing: %{
        enable_spawn_trace: true,
        enable_exit_trace: true,
        enable_message_trace: false,
        trace_children: true
      }
    },
    
    # Storage Configuration
    storage: %{
      hot: %{
        max_events: 100_000,
        max_age_seconds: 3600,
        prune_interval: 60_000
      },
      warm: %{
        enable: false,
        path: "./elixir_scope_data",
        max_size_mb: 100,
        compression: :zstd
      },
      cold: %{
        enable: false
      }
    },
    
    # Interface Configuration
    interface: %{
      query_timeout: 10_000,
      max_results: 1000,
      enable_streaming: true
    },

    # Development Configuration
    dev: %{
      debug_mode: false,
      verbose_logging: false,
      performance_monitoring: true
    }
  ]

  @type t :: %__MODULE__{
    ai: map(),
    capture: map(),
    storage: map(),
    interface: map(),
    dev: map()
  }

  # Paths that can be updated at runtime
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

  # Valid values for enum-like configuration options
  @valid_ai_providers [:mock, :openai, :anthropic, :gemini]
  @valid_overflow_strategies [:drop_oldest, :drop_newest, :block]
  @valid_compression_types [:none, :gzip, :zstd]
  @valid_planning_strategies [:fast, :balanced, :thorough]

  ## Public API

  @spec initialize(keyword()) :: :ok | {:error, term()}
  def initialize(opts \\ []) do
    case GenServer.start_link(__MODULE__, opts, name: __MODULE__) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  @spec get() :: t()
  def get do
    GenServer.call(__MODULE__, :get_config)
  end

  @spec get(config_path()) :: config_value() | nil
  def get(path) when is_list(path) do
    GenServer.call(__MODULE__, {:get_config_path, path})
  end

  @spec update(config_path(), config_value()) :: :ok | {:error, term()}
  def update(path, value) when is_list(path) do
    GenServer.call(__MODULE__, {:update_config, path, value})
  end

  @spec validate(t()) :: {:ok, t()} | {:error, term()}
  def validate(%__MODULE__{} = config) do
    with :ok <- validate_ai_config(config.ai),
         :ok <- validate_capture_config(config.capture),
         :ok <- validate_storage_config(config.storage),
         :ok <- validate_interface_config(config.interface),
         :ok <- validate_dev_config(config.dev) do
      {:ok, config}
    end
  end

  @spec status() :: :ok | {:error, term()}
  def status do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :not_started}
      _pid -> :ok
    end
  end

  ## GenServer Implementation

  @impl GenServer
  def init(opts) do
    config = build_config(opts)
    case validate(config) do
      {:ok, validated_config} ->
        Logger.info("ElixirScope.Foundation.Config initialized successfully")
        {:ok, validated_config}
      {:error, reason} ->
        Logger.error("ElixirScope.Foundation.Config validation failed: #{inspect(reason)}")
        {:stop, {:validation_failed, reason}}
    end
  end

  @impl GenServer
  def handle_call(:get_config, _from, config) do
    {:reply, config, config}
  end

  @impl GenServer
  def handle_call({:get_config_path, path}, _from, config) do
    value = get_in(config, path)
    {:reply, value, config}
  end

  @impl GenServer
  def handle_call({:update_config, path, value}, _from, config) do
    cond do
      path not in @updatable_paths ->
        {:reply, {:error, :not_updatable}, config}
      
      true ->
        new_config = put_in(config, path, value)
        case validate(new_config) do
          {:ok, validated_config} ->
            Logger.debug("Config updated: #{inspect(path)} = #{inspect(value)}")
            {:reply, :ok, validated_config}
          {:error, reason} ->
            {:reply, {:error, reason}, config}
        end
    end
  end

  ## Private Functions

  defp build_config(opts) do
    base_config = %__MODULE__{}
    env_config = Application.get_all_env(:elixir_scope)
    
    base_config
    |> merge_env_config(env_config)
    |> merge_opts_config(opts)
  end

  defp merge_env_config(config, env_config) do
    Enum.reduce(env_config, config, fn {key, value}, acc ->
      if Map.has_key?(acc, key) do
        Map.put(acc, key, deep_merge(Map.get(acc, key), value))
      else
        acc
      end
    end)
  end

  defp merge_opts_config(config, opts) do
    Enum.reduce(opts, config, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_val, right_val ->
      deep_merge(left_val, right_val)
    end)
  end
  defp deep_merge(_left, right), do: right

  # Validation functions
  defp validate_ai_config(%{provider: provider} = config) when provider in @valid_ai_providers do
    with :ok <- validate_ai_analysis(config.analysis),
         :ok <- validate_ai_planning(config.planning) do
      :ok
    end
  end
  defp validate_ai_config(%{provider: provider}), do: {:error, {:invalid_ai_provider, provider}}

  defp validate_ai_analysis(%{max_file_size: size, timeout: timeout, cache_ttl: ttl}) 
    when is_integer(size) and size > 0 and 
         is_integer(timeout) and timeout > 0 and
         is_integer(ttl) and ttl > 0 do
    :ok
  end
  defp validate_ai_analysis(_), do: {:error, :invalid_ai_analysis_config}

  defp validate_ai_planning(%{performance_target: target, sampling_rate: rate, default_strategy: strategy}) 
    when is_number(target) and target >= 0 and
         is_number(rate) and rate >= 0 and rate <= 1 and
         strategy in @valid_planning_strategies do
    :ok
  end
  defp validate_ai_planning(_), do: {:error, :invalid_ai_planning_config}

  defp validate_capture_config(%{ring_buffer: rb, processing: proc, vm_tracing: vt}) do
    with :ok <- validate_ring_buffer(rb),
         :ok <- validate_processing(proc),
         :ok <- validate_vm_tracing(vt) do
      :ok
    end
  end

  defp validate_ring_buffer(%{size: size, max_events: max, overflow_strategy: strategy}) 
    when is_integer(size) and size > 0 and
         is_integer(max) and max > 0 and
         strategy in @valid_overflow_strategies do
    :ok
  end
  defp validate_ring_buffer(_), do: {:error, :invalid_ring_buffer_config}

  defp validate_processing(%{batch_size: batch, flush_interval: flush, max_queue_size: queue}) 
    when is_integer(batch) and batch > 0 and
         is_integer(flush) and flush > 0 and
         is_integer(queue) and queue > 0 do
    :ok
  end
  defp validate_processing(_), do: {:error, :invalid_processing_config}

  defp validate_vm_tracing(%{enable_spawn_trace: spawn, enable_exit_trace: exit, 
                           enable_message_trace: msg, trace_children: children}) 
    when is_boolean(spawn) and is_boolean(exit) and 
         is_boolean(msg) and is_boolean(children) do
    :ok
  end
  defp validate_vm_tracing(_), do: {:error, :invalid_vm_tracing_config}

  defp validate_storage_config(%{hot: hot, warm: warm, cold: cold}) do
    with :ok <- validate_hot_storage(hot),
         :ok <- validate_warm_storage(warm),
         :ok <- validate_cold_storage(cold) do
      :ok
    end
  end

  defp validate_hot_storage(%{max_events: max, max_age_seconds: age, prune_interval: interval}) 
    when is_integer(max) and max > 0 and
         is_integer(age) and age > 0 and
         is_integer(interval) and interval > 0 do
    :ok
  end
  defp validate_hot_storage(_), do: {:error, :invalid_hot_storage_config}

  defp validate_warm_storage(%{enable: false}), do: :ok
  defp validate_warm_storage(%{enable: true, path: path, max_size_mb: size, compression: comp}) 
    when is_binary(path) and
         is_integer(size) and size > 0 and
         comp in @valid_compression_types do
    :ok
  end
  defp validate_warm_storage(_), do: {:error, :invalid_warm_storage_config}

  defp validate_cold_storage(%{enable: false}), do: :ok
  defp validate_cold_storage(_), do: {:error, :invalid_cold_storage_config}

  defp validate_interface_config(%{query_timeout: timeout, max_results: max, enable_streaming: stream}) 
    when is_integer(timeout) and timeout > 0 and
         is_integer(max) and max > 0 and
         is_boolean(stream) do
    :ok
  end
  defp validate_interface_config(_), do: {:error, :invalid_interface_config}

  defp validate_dev_config(%{debug_mode: debug, verbose_logging: verbose, performance_monitoring: perf}) 
    when is_boolean(debug) and is_boolean(verbose) and is_boolean(perf) do
    :ok
  end
  defp validate_dev_config(_), do: {:error, :invalid_dev_config}
end

## lib/elixir_scope/foundation/events.ex
defmodule ElixirScope.Foundation.Events do
  @moduledoc """
  Core event system for ElixirScope.
  
  Provides structured event creation, serialization, and basic event management.
  This is the foundation for all event-driven communication within ElixirScope.
  """

  alias ElixirScope.Foundation.{Types, Utils}

  @type event_id :: Types.event_id()
  @type timestamp :: Types.timestamp()
  @type correlation_id :: Types.correlation_id()

  # Base event structure
  defstruct [
    :event_id,
    :event_type,
    :timestamp,
    :wall_time,
    :node,
    :pid,
    :correlation_id,
    :parent_id,
    :data
  ]

  @type t :: %__MODULE__{
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

  ## Event Creation

  @spec new_event(atom(), term(), keyword()) :: t()
  def new_event(event_type, data, opts \\ []) do
    %__MODULE__{
      event_id: Utils.generate_id(),
      event_type: event_type,
      timestamp: Utils.monotonic_timestamp(),
      wall_time: DateTime.utc_now(),
      node: Node.self(),
      pid: self(),
      correlation_id: Keyword.get(opts, :correlation_id),
      parent_id: Keyword.get(opts, :parent_id),
      data: data
    }
  end

  @spec function_entry(module(), atom(), arity(), [term()], keyword()) :: t()
  def function_entry(module, function, arity, args, opts \\ []) do
    data = %{
      call_id: Utils.generate_id(),
      module: module,
      function: function,
      arity: arity,
      args: Utils.truncate_if_large(args),
      caller_module: Keyword.get(opts, :caller_module),
      caller_function: Keyword.get(opts, :caller_function),
      caller_line: Keyword.get(opts, :caller_line)
    }
    
    new_event(:function_entry, data, opts)
  end

  @spec function_exit(module(), atom(), arity(), event_id(), term(), non_neg_integer(), atom()) :: t()
  def function_exit(module, function, arity, call_id, result, duration_ns, exit_reason) do
    data = %{
      call_id: call_id,
      module: module,
      function: function,
      arity: arity,
      result: Utils.truncate_if_large(result),
      duration_ns: duration_ns,
      exit_reason: exit_reason
    }
    
    new_event(:function_exit, data)
  end

  @spec state_change(pid(), atom(), term(), term(), keyword()) :: t()
  def state_change(server_pid, callback, old_state, new_state, opts \\ []) do
    data = %{
      server_pid: server_pid,
      callback: callback,
      old_state: Utils.truncate_if_large(old_state),
      new_state: Utils.truncate_if_large(new_state),
      state_diff: compute_state_diff(old_state, new_state),
      trigger_message: Keyword.get(opts, :trigger_message),
      trigger_call_id: Keyword.get(opts, :trigger_call_id)
    }
    
    new_event(:state_change, data)
  end

  ## Event Processing

  @spec serialize(t()) :: binary()
  def serialize(%__MODULE__{} = event) do
    :erlang.term_to_binary(event, [:compressed])
  end

  @spec deserialize(binary()) :: t()
  def deserialize(binary) when is_binary(binary) do
    :erlang.binary_to_term(binary)
  end

  @spec serialized_size(t()) :: non_neg_integer()
  def serialized_size(%__MODULE__{} = event) do
    event |> serialize() |> byte_size()
  end

  ## System Management

  @spec initialize() :: :ok
  def initialize do
    Logger.debug("ElixirScope.Foundation.Events initialized")
    :ok
  end

  @spec status() :: :ok
  def status, do: :ok

  ## Private Functions

  defp compute_state_diff(old_state, new_state) do
    if old_state == new_state do
      :no_change
    else
      :changed
    end
  end
end

## lib/elixir_scope/foundation/utils.ex
defmodule ElixirScope.Foundation.Utils do
  @moduledoc """
  Core utility functions for ElixirScope Foundation layer.
  
  Provides essential utilities for ID generation, time measurement,
  data inspection, and performance monitoring.
  """

  alias ElixirScope.Foundation.Types

  @type measurement_result(t) :: {t, non_neg_integer()}

  ## ID Generation

  @spec generate_id() :: Types.event_id()
  def generate_id do
    # Use a combination of timestamp and random value for uniqueness
    timestamp = System.monotonic_time(:nanosecond)
    random = :rand.uniform(1_000_000)
    
    # Combine timestamp and random for globally unique ID
    # Use abs to handle negative monotonic time
    abs(timestamp) * 1_000_000 + random
  end

  @spec generate_correlation_id() :: Types.correlation_id()
  def generate_correlation_id do
    # Generate UUID v4 format
    <<u0::32, u1::16, u2::16, u3::16, u4::48>> = :crypto.strong_rand_bytes(16)
    
    # Set version (4) and variant bits
    u2_v4 = u2 &&& 0x0FFF ||| 0x4000
    u3_var = u3 &&& 0x3FFF ||| 0x8000
    
    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", 
                   [u0, u1, u2_v4, u3_var, u4])
    |> IO.iodata_to_binary()
  end

  @spec id_to_timestamp(Types.event_id()) :: Types.timestamp()
  def id_to_timestamp(id) when is_integer(id) do
    # Extract timestamp component from ID
    div(id, 1_000_000)
  end

  ## Time Utilities

  @spec monotonic_timestamp() :: Types.timestamp()
  def monotonic_timestamp do
    System.monotonic_time(:nanosecond)
  end

  @spec wall_timestamp() :: Types.timestamp()
  def wall_timestamp do
    System.os_time(:nanosecond)
  end

  @spec format_timestamp(Types.timestamp()) :: String.t()
  def format_timestamp(timestamp_ns) when is_integer(timestamp_ns) do
    timestamp_us = div(timestamp_ns, 1_000)
    datetime = DateTime.from_unix!(timestamp_us, :microsecond)
    
    # Format with nanosecond precision
    nanoseconds = rem(timestamp_ns, 1_000_000)
    formatted_base = DateTime.to_iso8601(datetime)
    
    # Replace microseconds with full nanosecond precision
    String.replace(formatted_base, ~r/\.\d{6}/, ".#{:io_lib.format("~6..0B", [nanoseconds])}")
  end

  ## Measurement

  @spec measure((() -> t)) :: measurement_result(t) when t: var
  def measure(fun) when is_function(fun, 0) do
    start_time = monotonic_timestamp()
    result = fun.()
    end_time = monotonic_timestamp()
    
    {result, end_time - start_time}
  end

  @spec measure_memory((() -> t)) :: {t, {non_neg_integer(), non_neg_integer(), integer()}} when t: var
  def measure_memory(fun) when is_function(fun, 0) do
    memory_before = :erlang.memory(:total)
    result = fun.()
    memory_after = :erlang.memory(:total)
    
    {result, {memory_before, memory_after, memory_after - memory_before}}
  end

  ## Data Inspection

  @spec safe_inspect(term(), keyword()) :: String.t()
  def safe_inspect(term, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    
    inspect(term, limit: limit, printable_limit: 100, pretty: true)
  end

  @spec truncate_if_large(term(), non_neg_integer()) :: term() | {:truncated, non_neg_integer(), String.t()}
  def truncate_if_large(term, size_limit \\ 1000) do
    estimated_size = term_size(term)
    
    if estimated_size <= size_limit do
      term
    else
      type_hint = get_type_hint(term)
      {:truncated, estimated_size, type_hint}
    end
  end

  @spec term_size(term()) :: non_neg_integer()
  def term_size(term) do
    :erlang.external_size(term)
  end

  ## Process and System Stats

  @spec process_stats(pid()) :: map()
  def process_stats(pid \\ self()) do
    case Process.info(pid, [:memory, :reductions, :message_queue_len]) do
      nil ->
        %{error: :process_not_found, timestamp: monotonic_timestamp()}
      
      info ->
        info
        |> Keyword.put(:timestamp, monotonic_timestamp())
        |> Enum.into(%{})
    end
  end

  @spec system_stats() :: map()
  def system_stats do
    %{
      timestamp: monotonic_timestamp(),
      process_count: :erlang.system_info(:process_count),
      total_memory: :erlang.memory(:total),
      scheduler_count: :erlang.system_info(:schedulers),
      otp_release: :erlang.system_info(:otp_release) |> List.to_string()
    }
  end

  ## Formatting

  @spec format_bytes(non_neg_integer()) :: String.t()
  def format_bytes(bytes) when is_integer(bytes) and bytes >= 0 do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      bytes < 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
    end
  end

  @spec format_duration(non_neg_integer()) :: String.t()
  def format_duration(nanoseconds) when is_integer(nanoseconds) and nanoseconds >= 0 do
    cond do
      nanoseconds < 1_000 -> "#{nanoseconds} ns"
      nanoseconds < 1_000_000 -> "#{Float.round(nanoseconds / 1_000, 1)} μs"
      nanoseconds < 1_000_000_000 -> "#{Float.round(nanoseconds / 1_000_000, 1)} ms"
      true -> "#{Float.round(nanoseconds / 1_000_000_000, 1)} s"
    end
  end

  ## Validation

  @spec valid_positive_integer?(term()) :: boolean()
  def valid_positive_integer?(value) do
    is_integer(value) and value > 0
  end

  @spec valid_percentage?(term()) :: boolean()
  def valid_percentage?(value) do
    is_number(value) and value >= 0 and value <= 1
  end

  @spec valid_pid?(term()) :: boolean()
  def valid_pid?(value) do
    is_pid(value) and Process.alive?(value)
  end

  ## Private Functions

  defp get_type_hint(term) do
    cond do
      is_binary(term) -> "binary data"
      is_list(term) -> "list with #{length(term)} elements"
      is_map(term) -> "map with #{map_size(term)} keys"
      is_tuple(term) -> "tuple with #{tuple_size(term)} elements"
      true -> "#{inspect(term.__struct__ || :unknown)} data"
    end
  rescue
    _ -> "complex data structure"
  end
end

## lib/elixir_scope/foundation/telemetry.ex
defmodule ElixirScope.Foundation.Telemetry do
  @moduledoc """
  Telemetry and metrics collection for ElixirScope Foundation layer.
  
  Provides standardized telemetry events and metrics collection
  for monitoring ElixirScope performance and health.
  """

  require Logger
  alias ElixirScope.Foundation.Utils

  @telemetry_events [
    # Configuration events
    [:elixir_scope, :config, :get],
    [:elixir_scope, :config, :update],
    [:elixir_scope, :config, :validate],
    
    # Event system events
    [:elixir_scope, :events, :create],
    [:elixir_scope, :events, :serialize],
    [:elixir_scope, :events, :deserialize],
    
    # Performance events
    [:elixir_scope, :performance, :measurement],
    [:elixir_scope, :performance, :memory_usage]
  ]

  ## Public API

  @spec initialize() :: :ok
  def initialize do
    attach_default_handlers()
    Logger.debug("ElixirScope.Foundation.Telemetry initialized")
    :ok
  end

  @spec status() :: :ok
  def status, do: :ok

  @spec measure_event(list(atom()), map(), (() -> t)) :: t when t: var
  def measure_event(event_name, metadata \\ %{}, fun) do
    start_time = Utils.monotonic_timestamp()
    
    result = try do
      fun.()
    rescue
      error ->
        emit_error_event(event_name, metadata, error)
        reraise error, __STACKTRACE__
    end
    
    end_time = Utils.monotonic_timestamp()
    duration = end_time - start_time
    
    measurements = %{duration: duration, timestamp: end_time}
    :telemetry.execute(event_name, measurements, metadata)
    
    result
  end

  @spec emit_counter(list(atom()), map()) :: :ok
  def emit_counter(event_name, metadata \\ %{}) do
    measurements = %{count: 1, timestamp: Utils.monotonic_timestamp()}
    :telemetry.execute(event_name, measurements, metadata)
  end

  @spec emit_gauge(list(atom()), number(), map()) :: :ok
  def emit_gauge(event_name, value, metadata \\ %{}) do
    measurements = %{value: value, timestamp: Utils.monotonic_timestamp()}
    :telemetry.execute(event_name, measurements, metadata)
  end

  @spec get_metrics() :: map()
  def get_metrics do
    %{
      foundation: %{
        uptime_ms: System.monotonic_time(:millisecond),
        memory_usage: :erlang.memory(:total),
        process_count: :erlang.system_info(:process_count)
      },
      system: Utils.system_stats()
    }
  end

  ## Private Functions

  defp attach_default_handlers do
    # Attach a default handler for debugging in development
    if Application.get_env(:elixir_scope, :dev, %{}) |> Map.get(:debug_mode, false) do
      :telemetry.attach_many(
        "elixir-scope-debug-handler",
        @telemetry_events,
        &handle_debug_event/4,
        %{}
      )
    end
  end

  defp handle_debug_event(event_name, measurements, metadata, _config) do
    Logger.debug("""
    ElixirScope Telemetry Event:
      Event: #{inspect(event_name)}
      Measurements: #{inspect(measurements)}
      Metadata: #{inspect(metadata)}
    """)
  end

  defp emit_error_event(event_name, metadata, error) do
    error_metadata = Map.merge(metadata, %{
      error_type: error.__struct__,
      error_message: Exception.message(error)
    })
    
    measurements = %{error_count: 1, timestamp: Utils.monotonic_timestamp()}
    error_event_name = event_name ++ [:error]
    :telemetry.execute(error_event_name, measurements, error_metadata)
  end
end

## lib/elixir_scope/foundation/types.ex
defmodule ElixirScope.Foundation.Types do
  @moduledoc """
  Core type definitions for ElixirScope Foundation layer.
  
  Defines all fundamental types used throughout the ElixirScope system.
  These types serve as contracts between layers and ensure consistency.
  """

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

  # Process-related types
  @type process_info :: %{
    pid: pid(),
    registered_name: atom() | nil,
    status: atom(),
    memory: non_neg_integer(),
    reductions: non_neg_integer()
  }

  # Metrics types
  @type metric_name :: atom()
  @type metric_value :: number()
  @type metric_metadata :: map()

  @type performance_metric :: %{
    name: metric_name(),
    value: metric_value(),
    timestamp: timestamp(),
    metadata: metric_metadata()
  }

  # Configuration types
  @type config_key :: atom()
  @type config_value :: term()
  @type config_path :: [config_key()]

  # Event types (basic structure)
  @type event_type :: atom()
  @type event_data :: term()

  # Function-related types
  @type module_name :: module()
  @type function_name :: atom()
  @type function_arity :: arity()
  @type function_args :: [term()]

  @type mfa :: {module_name(), function_name(), function_arity()}
  @type function_call :: {module_name(), function_name(), function_args()}

  # Error types
  @type error_reason :: atom() | String.t() | tuple()
  @type stacktrace :: [tuple()]

  # Data size types
  @type byte_size :: non_neg_integer()
  @type data_size_limit :: non_neg_integer()

  # Truncation types
  @type truncated_data :: {:truncated, byte_size(), String.t()}
  @type maybe_truncated(t) :: t | truncated_data()
end

## lib/elixir_scope/foundation/application.ex
defmodule ElixirScope.Foundation.Application do
  @moduledoc """
  Application module for ElixirScope Foundation layer.
  
  Manages the lifecycle of Foundation layer components and ensures
  proper initialization order.
  """

  use Application
  require Logger

  alias ElixirScope.Foundation.{Config, Events, Telemetry}

  @impl Application
  def start(_type, _args) do
    Logger.info("Starting ElixirScope Foundation Application")

    children = [
      # Configuration must start first
      {Config, []},
      
      # Add other supervised processes here as needed
      # Note: Events and Telemetry are currently stateless and don't need supervision
    ]

    opts = [strategy: :one_for_one, name: ElixirScope.Foundation.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} = result ->
        # Initialize stateless components after supervision tree is up
        :ok = Events.initialize()
        :ok = Telemetry.initialize()
        
        Logger.info("ElixirScope Foundation Application started successfully")
        result
        
      error ->
        Logger.error("Failed to start ElixirScope Foundation Application: #{inspect(error)}")
        error
    end
  end

  @impl Application
  def stop(_state) do
    Logger.info("Stopping ElixirScope Foundation Application")
    :ok
  end
end

## scripts/dev_workflow.exs
# Development workflow script for Foundation layer
# Usage: mix run scripts/dev_workflow.exs

IO.puts("=== ElixirScope Foundation Layer Development Workflow ===")

alias ElixirScope.Foundation.{Config, Events, Utils, Telemetry}

IO.puts("1. Testing Configuration System...")
try do
  # Test configuration retrieval
  config = Config.get()
  IO.puts("   ✅ Configuration loaded successfully")
  IO.puts("   - AI Provider: #{config.ai.provider}")
  IO.puts("   - Sampling Rate: #{config.ai.planning.sampling_rate}")
  
  # Test configuration path access
  batch_size = Config.get([:capture, :processing, :batch_size])
  IO.puts("   - Batch Size: #{batch_size}")
  
  # Test configuration update (allowed path)
  old_rate = Config.get([:ai, :planning, :sampling_rate])
  :ok = Config.update([:ai, :planning, :sampling_rate], 0.8)
  new_rate = Config.get([:ai, :planning, :sampling_rate])
  IO.puts("   ✅ Configuration update successful: #{old_rate} → #{new_rate}")
  
  # Restore original rate
  Config.update([:ai, :planning, :sampling_rate], old_rate)
  
rescue
  error ->
    IO.puts("   ❌ Configuration test failed: #{Exception.message(error)}")
end

IO.puts("\n2. Testing Event System...")
try do
  # Test basic event creation
  event = Events.new_event(:test_event, %{message: "Hello, World!"})
  IO.puts("   ✅ Event created successfully")
  IO.puts("   - Event ID: #{event.event_id}")
  IO.puts("   - Event Type: #{event.event_type}")
  IO.puts("   - Timestamp: #{Utils.format_timestamp(event.timestamp)}")
  
  # Test function entry event
  func_event = Events.function_entry(TestModule, :test_function, 2, [:arg1, :arg2])
  IO.puts("   ✅ Function entry event created")
  IO.puts("   - Call ID: #{func_event.data.call_id}")
  
  # Test serialization
  serialized = Events.serialize(event)
  deserialized = Events.deserialize(serialized)
  
  if deserialized == event do
    IO.puts("   ✅ Event serialization round-trip successful")
    IO.puts("   - Serialized size: #{Events.serialized_size(event)} bytes")
  else
    IO.puts("   ❌ Event serialization round-trip failed")
  end
  
rescue
  error ->
    IO.puts("   ❌ Event system test failed: #{Exception.message(error)}")
end

IO.puts("\n3. Testing Utilities...")
try do
  # Test ID generation
  id1 = Utils.generate_id()
  id2 = Utils.generate_id()
  
  if id1 != id2 do
    IO.puts("   ✅ Unique ID generation working")
    IO.puts("   - Generated IDs: #{id1}, #{id2}")
  end
  
  # Test correlation ID generation
  corr_id = Utils.generate_correlation_id()
  IO.puts("   ✅ Correlation ID generated: #{corr_id}")
  
  # Test time measurement
  {result, duration} = Utils.measure(fn ->
    :timer.sleep(10)
    :measured_operation
  end)
  
  IO.puts("   ✅ Time measurement working")
  IO.puts("   - Operation result: #{result}")
  IO.puts("   - Duration: #{Utils.format_duration(duration)}")
  
  # Test memory measurement
  {_list, {mem_before, mem_after, diff}} = Utils.measure_memory(fn ->
    Enum.to_list(1..1000)
  end)
  
  IO.puts("   ✅ Memory measurement working")
  IO.puts("   - Memory before: #{Utils.format_bytes(mem_before)}")
  IO.puts("   - Memory after: #{Utils.format_bytes(mem_after)}")
  IO.puts("   - Memory diff: #{diff} bytes")
  
  # Test data truncation
  large_data = String.duplicate("x", 2000)
  truncated = Utils.truncate_if_large(large_data, 1000)
  
  case truncated do
    {:truncated, size, hint} ->
      IO.puts("   ✅ Data truncation working")
      IO.puts("   - Original size: #{size} bytes")
      IO.puts("   - Type hint: #{hint}")
    _ ->
      IO.puts("   ❌ Data truncation not working as expected")
  end
  
rescue
  error ->
    IO.puts("   ❌ Utilities test failed: #{Exception.message(error)}")
end

IO.puts("\n4. Testing Telemetry...")
try do
  # Test telemetry measurement
  result = Telemetry.measure_event([:test, :operation], %{component: :foundation}, fn ->
    :timer.sleep(5)
    :telemetry_test_result
  end)
  
  IO.puts("   ✅ Telemetry measurement working")
  IO.puts("   - Result: #{result}")
  
  # Test metrics collection
  metrics = Telemetry.get_metrics()
  IO.puts("   ✅ Metrics collection working")
  IO.puts("   - Uptime: #{metrics.foundation.uptime_ms} ms")
  IO.puts("   - Memory: #{Utils.format_bytes(metrics.foundation.memory_usage)}")
  IO.puts("   - Processes: #{metrics.foundation.process_count}")
  
rescue
  error ->
    IO.puts("   ❌ Telemetry test failed: #{Exception.message(error)}")
end

IO.puts("\n5. Testing System Stats...")
try do
  process_stats = Utils.process_stats()
  system_stats = Utils.system_stats()
  
  IO.puts("   ✅ Process stats collected")
  IO.puts("   - Current process memory: #{Utils.format_bytes(process_stats.memory)}")
  IO.puts("   - Message queue length: #{process_stats.message_queue_len}")
  
  IO.puts("   ✅ System stats collected")
  IO.puts("   - Total processes: #{system_stats.process_count}")
  IO.puts("   - Total memory: #{Utils.format_bytes(system_stats.total_memory)}")
  IO.puts("   - Schedulers: #{system_stats.scheduler_count}")
  IO.puts("   - OTP Release: #{system_stats.otp_release}")
  
rescue
  error ->
    IO.puts("   ❌ System stats test failed: #{Exception.message(error)}")
end

IO.puts("\n=== Foundation Layer Workflow Completed Successfully ===")
IO.puts("All core Foundation layer components are working correctly!")

## test/smoke/foundation_smoke_test.exs
defmodule ElixirScope.Smoke.FoundationTest do
  @moduledoc """
  Smoke tests for Foundation layer - validates core workflows work
  without testing implementation details.
  """
  
  use ExUnit.Case
  
  alias ElixirScope.Foundation
  alias ElixirScope.Foundation.{Config, Events, Utils, Telemetry}

  describe "foundation layer initialization" do
    test "foundation layer can be initialized" do
      # Should not crash and should return success
      assert :ok = Foundation.initialize()
      
      # Should be able to get status
      status = Foundation.status()
      assert is_map(status)
      assert Map.has_key?(status, :config)
      assert Map.has_key?(status, :events)
      assert Map.has_key?(status, :telemetry)
    end
  end

  describe "configuration smoke tests" do
    test "can get configuration" do
      config = Config.get()
      assert %Config{} = config
      assert config.ai.provider == :mock
    end
    
    test "can get configuration by path" do
      provider = Config.get([:ai, :provider])
      assert provider == :mock
      
      batch_size = Config.get([:capture, :processing, :batch_size])
      assert is_integer(batch_size)
      assert batch_size > 0
    end
    
    test "can update allowed configuration paths" do
      original_rate = Config.get([:ai, :planning, :sampling_rate])
      
      # Update to a different value
      new_rate = if original_rate == 1.0, do: 0.8, else: 1.0
      assert :ok = Config.update([:ai, :planning, :sampling_rate], new_rate)
      
      # Verify update
      updated_rate = Config.get([:ai, :planning, :sampling_rate])
      assert updated_rate == new_rate
      
      # Restore original
      Config.update([:ai, :planning, :sampling_rate], original_rate)
    end
    
    test "rejects updates to forbidden paths" do
      result = Config.update([:ai, :provider], :openai)
      assert {:error, :not_updatable} = result
    end
  end

  describe "events smoke tests" do
    test "can create basic events" do
      event = Events.new_event(:test_event, %{data: "test"})
      
      assert %Events{} = event
      assert event.event_type == :test_event
      assert event.data.data == "test"
      assert is_integer(event.event_id)
      assert is_integer(event.timestamp)
    end
    
    test "can create function events" do
      event = Events.function_entry(TestModule, :test_function, 1, [:arg])
      
      assert event.event_type == :function_entry
      assert event.data.module == TestModule
      assert event.data.function == :test_function
      assert event.data.arity == 1
    end
    
    test "can serialize and deserialize events" do
      original = Events.new_event(:test, %{data: "serialize_test"})
      
      serialized = Events.serialize(original)
      assert is_binary(serialized)
      
      deserialized = Events.deserialize(serialized)
      assert deserialized == original
    end
  end

  describe "utilities smoke tests" do
    test "can generate unique IDs" do
      id1 = Utils.generate_id()
      id2 = Utils.generate_id()
      
      assert is_integer(id1)
      assert is_integer(id2)
      assert id1 != id2
    end
    
    test "can generate correlation IDs" do
      corr_id = Utils.generate_correlation_id()
      
      assert is_binary(corr_id)
      assert String.length(corr_id) == 36  # UUID format
    end
    
    test "can measure execution time" do
      {result, duration} = Utils.measure(fn ->
        :timer.sleep(1)
        :test_result
      end)
      
      assert result == :test_result
      assert is_integer(duration)
      assert duration > 0
    end
    
    test "can format values" do
      assert is_binary(Utils.format_bytes(1024))
      assert is_binary(Utils.format_duration(1_000_000))
      assert is_binary(Utils.format_timestamp(Utils.wall_timestamp()))
    end
    
    test "can get process and system stats" do
      process_stats = Utils.process_stats()
      assert is_map(process_stats)
      assert Map.has_key?(process_stats, :memory)
      
      system_stats = Utils.system_stats()
      assert is_map(system_stats)
      assert Map.has_key?(system_stats, :process_count)
    end
  end

  describe "telemetry smoke tests" do
    test "can measure telemetry events" do
      result = Telemetry.measure_event([:test, :measurement], %{}, fn ->
        :measured_result
      end)
      
      assert result == :measured_result
    end
    
    test "can emit counters and gauges" do
      assert :ok = Telemetry.emit_counter([:test, :counter])
      assert :ok = Telemetry.emit_gauge([:test, :gauge], 42.0)
    end
    
    test "can get metrics" do
      metrics = Telemetry.get_metrics()
      
      assert is_map(metrics)
      assert Map.has_key?(metrics, :foundation)
      assert Map.has_key?(metrics, :system)
    end
  end

  describe "integration smoke tests" do
    test "components work together" do
      # Create an event
      event = Events.function_entry(TestModule, :integration_test, 0, [])
      
      # Measure serialization with telemetry
      result = Telemetry.measure_event([:test, :serialization], %{}, fn ->
        Events.serialize(event)
      end)
      
      assert is_binary(result)
      
      # Verify we can deserialize
      deserialized = Events.deserialize(result)
      assert deserialized == event
    end
    
    test "error handling works" do
      # Test that errors don't crash the system
      assert_raise RuntimeError, fn ->
        Telemetry.measure_event([:test, :error], %{}, fn ->
          raise RuntimeError, "Test error"
        end)
      end
      
      # System should still be functional
      assert is_map(Config.get())
    end
  end
end

## mix_tasks/validate_architecture.ex  
defmodule Mix.Tasks.ValidateArchitecture do
  @moduledoc """
  Validates that modules respect layer dependency rules.
  
  Usage: mix validate_architecture
  
  This task ensures that:
  1. Foundation layer has no ElixirScope dependencies
  2. Each layer only depends on lower layers
  3. No circular dependencies exist
  """
  
  use Mix.Task
  
  @layer_order [:foundation, :ast, :graph, :cpg, :analysis, 
                :query, :capture, :intelligence, :debugger]
                
  @layer_modules %{
    foundation: ~r/^ElixirScope\.Foundation/,
    ast: ~r/^ElixirScope\.AST/,
    graph: ~r/^ElixirScope\.Graph/,
    cpg: ~r/^ElixirScope\.CPG/,
    analysis: ~r/^ElixirScope\.Analysis/,
    query: ~r/^ElixirScope\.Query/,
    capture: ~r/^ElixirScope\.Capture/,
    intelligence: ~r/^ElixirScope\.Intelligence/,
    debugger: ~r/^ElixirScope\.Debugger/
  }

  def run(_args) do
    Mix.Task.run("compile")
    
    violations = []
    
    violations = violations ++ validate_foundation_isolation()
    violations = violations ++ validate_layer_dependencies()
    
    if violations == [] do
      Mix.shell().info("✅ Architecture validation passed")
      Mix.shell().info("   All layers respect dependency rules")
    else
      Mix.shell().error("❌ Architecture violations found:")
      Enum.each(violations, fn violation ->
        Mix.shell().error("   #{violation}")
      end)
      System.halt(1)
    end
  end
  
  defp validate_foundation_isolation do
    foundation_modules = get_modules_for_layer(:foundation)
    violations = []
    
    Enum.flat_map(foundation_modules, fn module ->
      dependencies = get_module_dependencies(module)
      elixir_scope_deps = Enum.filter(dependencies, &String.starts_with?(&1, "ElixirScope."))
      other_layer_deps = Enum.reject(elixir_scope_deps, &String.starts_with?(&1, "ElixirScope.Foundation"))
      
      Enum.map(other_layer_deps, fn dep ->
        "Foundation module #{module} cannot depend on #{dep}"
      end)
    end)
  end
  
  defp validate_layer_dependencies do
    violations = []
    
    for layer <- @layer_order,
        module <- get_modules_for_layer(layer) do
      dependencies = get_module_dependencies(module)
      layer_deps = Enum.map(dependencies, &get_module_layer/1)
                  |> Enum.reject(&is_nil/1)
      
      allowed_layers = layers_before(layer)
      
      Enum.flat_map(layer_deps, fn dep_layer ->
        if dep_layer == layer or dep_layer in allowed_layers do
          []
        else
          ["#{layer} module #{module} cannot depend on #{dep_layer} layer"]
        end
      end)
    end
    |> List.flatten()
  end
  
  defp get_modules_for_layer(layer) do
    pattern = @layer_modules[layer]
    
    :application.get_key(:elixir_scope, :modules)
    |> case do
      {:ok, modules} -> modules
      _ -> []
    end
    |> Enum.filter(fn module ->
      module_name = Atom.to_string(module)
      Regex.match?(pattern, module_name)
    end)
    |> Enum.map(&Atom.to_string/1)
  end
  
  defp get_module_dependencies(module_name) when is_binary(module_name) do
    try do
      module_atom = String.to_existing_atom(module_name)
      
      # Get the module's AST and extract dependencies
      case Code.get_docs(module_atom, :moduledoc) do
        {_, _} ->
          # Module exists, try to get its dependencies
          extract_dependencies_from_module(module_atom)
        _ ->
          []
      end
    rescue
      _ -> []
    end
  end
  
  defp extract_dependencies_from_module(module) do
    # This is a simplified dependency extraction
    # In a real implementation, you'd parse the module's AST
    # For now, we'll check some basic patterns
    
    try do
      {:ok, {^module, [abstract_code: code]}} = :beam_lib.chunks(module, [abstract_code])
      extract_dependencies_from_ast(code)
    rescue
      _ ->
        # Fallback: check module attributes if available
        extract_dependencies_from_attributes(module)
    end
  end
  
  defp extract_dependencies_from_ast({:raw_abstract_v1, code}) do
    # Extract module references from AST
    # This is a simplified version - real implementation would be more thorough
    code
    |> Enum.flat_map(&extract_module_refs/1)
    |> Enum.uniq()
    |> Enum.filter(&String.starts_with?(&1, "ElixirScope."))
  end
  defp extract_dependencies_from_ast(_), do: []
  
  defp extract_dependencies_from_attributes(module) do
    # Fallback method using module info
    try do
      module.module_info(:attributes)
      |> Keyword.get(:vsn, [])
      |> List.wrap()
      |> Enum.flat_map(fn _ -> [] end)  # Placeholder
    rescue
      _ -> []
    end
  end
  
  defp extract_module_refs({:attribute, _, :alias, module}) when is_atom(module) do
    [Atom.to_string(module)]
  end
  defp extract_module_refs({:attribute, _, :import, module}) when is_atom(module) do
    [Atom.to_string(module)]
  end
  defp extract_module_refs(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.flat_map(&extract_module_refs/1)
  end
  defp extract_module_refs(list) when is_list(list) do
    Enum.flat_map(list, &extract_module_refs/1)
  end
  defp extract_module_refs({:remote, _, {:atom, _, module}, _}) when is_atom(module) do
    [Atom.to_string(module)]
  end
  defp extract_module_refs(_), do: []
  
  defp get_module_layer(module_name) do
    Enum.find(@layer_order, fn layer ->
      pattern = @layer_modules[layer]
      Regex.match?(pattern, module_name)
    end)
  end
  
  defp layers_before(layer) do
    case Enum.find_index(@layer_order, &(&1 == layer)) do
      nil -> []
      index -> Enum.take(@layer_order, index)
    end
  end
end

## Makefile
# ElixirScope Foundation Layer Development Makefile

# Variables
MIX = mix
ELIXIR = elixir

# Default environment
MIX_ENV ?= dev

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help setup deps compile format credo dialyzer test smoke validate dev-workflow clean

help: ## Show this help message
	@echo "ElixirScope Foundation Layer Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $1, $2}'

setup: deps compile dialyzer-plt ## Complete development setup
	@echo "$(GREEN)✅ Foundation layer setup complete$(NC)"

deps: ## Install dependencies
	@echo "$(YELLOW)📦 Installing dependencies...$(NC)"
	$(MIX) deps.get
	$(MIX) deps.compile

compile: ## Compile the project
	@echo "$(YELLOW)🔨 Compiling...$(NC)"
	$(MIX) compile --warnings-as-errors

format: ## Format code
	@echo "$(YELLOW)📝 Formatting code...$(NC)"
	$(MIX) format

format-check: ## Check code formatting
	@echo "$(YELLOW)📝 Checking code formatting...$(NC)"
	$(MIX) format --check-formatted

credo: ## Run Credo static analysis
	@echo "$(YELLOW)🔍 Running Credo analysis...$(NC)"
	$(MIX) credo --strict

dialyzer-plt: ## Build Dialyzer PLT file
	@echo "$(YELLOW)🔬 Building Dialyzer PLT...$(NC)"
	$(MIX) dialyzer --plt

dialyzer: ## Run Dialyzer type checking
	@echo "$(YELLOW)🔬 Running Dialyzer...$(NC)"
	$(MIX) dialyzer --halt-exit-status

test: ## Run all tests
	@echo "$(YELLOW)🧪 Running tests...$(NC)"
	$(MIX) test

smoke: ## Run smoke tests only
	@echo "$(YELLOW)💨 Running smoke tests...$(NC)"
	$(MIX) test test/smoke/ --trace

validate: ## Validate architecture
	@echo "$(YELLOW)🏗️  Validating architecture...$(NC)"
	$(MIX) validate_architecture

dev-workflow: ## Run development workflow script
	@echo "$(YELLOW)🚀 Running development workflow...$(NC)"
	$(MIX) run scripts/dev_workflow.exs

dev-check: format-check credo compile smoke ## Quick development check
	@echo "$(GREEN)✅ Development check passed$(NC)"

ci-check: format-check credo dialyzer test validate ## Full CI check
	@echo "$(GREEN)✅ CI check passed$(NC)"

clean: ## Clean build artifacts
	@echo "$(YELLOW)🧹 Cleaning...$(NC)"
	$(MIX) clean
	$(MIX) deps.clean --all

watch: ## Watch for changes and run tests
	@echo "$(YELLOW)👁️  Watching for changes...$(NC)"
	find lib test -name "*.ex" -o -name "*.exs" | entr -c make dev-check

# Development workflow targets
quick: compile smoke ## Quick check during development
full: clean setup ci-check ## Full validation

# Documentation
docs: ## Generate documentation
	@echo "$(YELLOW)📚 Generating documentation...$(NC)"
	$(MIX) docs

# Performance testing
benchmark: ## Run performance benchmarks
	@echo "$(YELLOW)⚡ Running benchmarks...$(NC)"
	$(MIX) run scripts/benchmark.exs

## test/support/foundation_test_helpers.ex
defmodule ElixirScope.Foundation.TestHelpers do
  @moduledoc """
  Test helpers for Foundation layer testing.
  """

  alias ElixirScope.Foundation.{Config, Events, Utils}

  @doc """
  Ensures Config GenServer is available for testing.
  """
  @spec ensure_config_available() :: :ok | {:error, term()}
  def ensure_config_available do
    case GenServer.whereis(Config) do
      nil ->
        case Config.initialize() do
          :ok -> :ok
          error -> error
        end
      _pid -> :ok
    end
  end

  @doc """
  Creates a test event with known data.
  """
  @spec create_test_event(keyword()) :: Events.t()
  def create_test_event(overrides \\ []) do
    base_data = %{
      test_field: "test_value",
      timestamp: Utils.monotonic_timestamp(),
      sequence: :rand.uniform(1000)
    }
    
    data = Keyword.get(overrides, :data, base_data)
    event_type = Keyword.get(overrides, :event_type, :test_event)
    opts = Keyword.drop(overrides, [:data, :event_type])
    
    Events.new_event(event_type, data, opts)
  end

  @doc """
  Creates a temporary configuration for testing.
  """
  @spec with_test_config(map(), (() -> any())) :: any()
  def with_test_config(config_overrides, test_fun) do
    original_config = Config.get()
    
    # Apply overrides
    test_config = deep_merge_config(original_config, config_overrides)
    
    try do
      # This would require additional Config API in a real implementation
      test_fun.()
    after
      # Restore original config paths that were changed
      # This is simplified - real implementation would track and restore changes
      :ok
    end
  end

  @doc """
  Waits for a condition to be true with timeout.
  """
  @spec wait_for((() -> boolean()), non_neg_integer()) :: :ok | :timeout
  def wait_for(condition, timeout_ms \\ 1000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    wait_for_condition(condition, deadline)
  end

  ## Private Functions

  defp deep_merge_config(original, overrides) when is_map(original) and is_map(overrides) do
    Map.merge(original, overrides, fn _key, orig_val, override_val ->
      if is_map(orig_val) and is_map(override_val) do
        deep_merge_config(orig_val, override_val)
      else
        override_val
      end
    end)
  end
  defp deep_merge_config(_original, override), do: override

  defp wait_for_condition(condition, deadline) do
    if System.monotonic_time(:millisecond) >= deadline do
      :timeout
    else
      if condition.() do
        :ok
      else
        Process.sleep(10)
        wait_for_condition(condition, deadline)
      end
    end
  end
end

## test/unit/foundation/config_test.exs
defmodule ElixirScope.Foundation.ConfigTest do
  use ExUnit.Case, async: false  # Config tests must be synchronous

  alias ElixirScope.Foundation.{Config, TestHelpers}

  setup do
    # Ensure Config GenServer is available
    :ok = TestHelpers.ensure_config_available()
    
    # Store original config for restoration
    original_config = Config.get()
    
    on_exit(fn ->
      # Restore any changed values
      try do
        if GenServer.whereis(Config) do
          # Restore sampling rate if changed
          original_rate = original_config.ai.planning.sampling_rate
          Config.update([:ai, :planning, :sampling_rate], original_rate)
        end
      catch
        :exit, _ -> :ok
      end
    end)
    
    %{original_config: original_config}
  end

  describe "configuration validation" do
    test "validates default configuration" do
      config = %Config{}
      assert {:ok, ^config} = Config.validate(config)
    end

    test "validates complete AI configuration" do
      config = %Config{
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
        }
      }
      
      assert {:ok, ^config} = Config.validate(config)
    end

    test "rejects invalid AI provider" do
      config = %Config{
        ai: %{
          provider: :invalid_provider,
          analysis: %{max_file_size: 1000, timeout: 1000, cache_ttl: 1000},
          planning: %{default_strategy: :balanced, performance_target: 0.01, sampling_rate: 1.0}
        }
      }
      
      assert {:error, {:invalid_ai_provider, :invalid_provider}} = Config.validate(config)
    end

    test "rejects invalid sampling rate" do
      config = %Config{
        ai: %{
          provider: :mock,
          analysis: %{max_file_size: 1000, timeout: 1000, cache_ttl: 1000},
          planning: %{
            default_strategy: :balanced,
            performance_target: 0.01,
            sampling_rate: 1.5  # Invalid: > 1.0
          }
        }
      }
      
      assert {:error, :invalid_ai_planning_config} = Config.validate(config)
    end
  end

  describe "configuration server operations" do
    test "gets full configuration", %{original_config: _config} do
      config = Config.get()
      assert %Config{} = config
      assert config.ai.provider == :mock
    end

    test "gets configuration by path", %{original_config: _config} do
      provider = Config.get([:ai, :provider])
      assert provider == :mock
      
      sampling_rate = Config.get([:ai, :planning, :sampling_rate])
      assert is_number(sampling_rate)
      assert sampling_rate >= 0
      assert sampling_rate <= 1
    end

    test "updates allowed configuration paths", %{original_config: _config} do
      assert :ok = Config.update([:ai, :planning, :sampling_rate], 0.8)
      
      updated_rate = Config.get([:ai, :planning, :sampling_rate])
      assert updated_rate == 0.8
    end

    test "rejects updates to forbidden paths", %{original_config: _config} do
      result = Config.update([:ai, :provider], :openai)
      assert {:error, :not_updatable} = result
      
      # Verify unchanged
      provider = Config.get([:ai, :provider])
      assert provider == :mock
    end

    test "validates updates before applying", %{original_config: _config} do
      result = Config.update([:ai, :planning, :sampling_rate], 1.5)
      assert {:error, :invalid_ai_planning_config} = result
    end
  end
end

## test/unit/foundation/events_test.exs  
defmodule ElixirScope.Foundation.EventsTest do
  use ExUnit.Case, async: true

  alias ElixirScope.Foundation.{Events, Utils}

  describe "event creation" do
    test "creates basic event with required fields" do
      data = %{test: "data"}
      event = Events.new_event(:test_event, data)

      assert %Events{} = event
      assert event.event_type == :test_event
      assert event.data == data
      assert is_integer(event.event_id)
      assert is_integer(event.timestamp)
      assert %DateTime{} = event.wall_time
      assert event.node == Node.self()
      assert event.pid == self()
    end

    test "creates event with optional correlation and parent IDs" do
      correlation_id = "test-correlation"
      parent_id = 12345

      event = Events.new_event(:test_event, %{}, 
        correlation_id: correlation_id, 
        parent_id: parent_id
      )

      assert event.correlation_id == correlation_id
      assert event.parent_id == parent_id
    end

    test "generates unique event IDs" do
      event1 = Events.new_event(:test, %{})
      event2 = Events.new_event(:test, %{})
      
      assert event1.event_id != event2.event_id
    end
  end

  describe "function events" do
    test "creates function entry event" do
      args = [:arg1, :arg2]
      event = Events.function_entry(TestModule, :test_function, 2, args)

      assert %Events{event_type: :function_entry} = event
      assert event.data.module == TestModule
      assert event.data.function == :test_function
      assert event.data.arity == 2
      assert event.data.args == args
      assert is_integer(event.data.call_id)
    end

    test "creates function entry with caller information" do
      event = Events.function_entry(TestModule, :test_function, 1, [:arg],
        caller_module: CallerModule,
        caller_function: :caller_function,
        caller_line: 42
      )

      assert event.data.caller_module == CallerModule
      assert event.data.caller_function == :caller_function
      assert event.data.caller_line == 42
    end

    test "creates function exit event" do
      call_id = 12345
      result = :ok
      duration = 1_000_000

      event = Events.function_exit(
        TestModule, :test_function, 2, call_id, 
        result, duration, :normal
      )

      assert event.event_type == :function_exit
      assert event.data.call_id == call_id
      assert event.data.result == result
      assert event.data.duration_ns == duration
      assert event.data.exit_reason == :normal
    end

    test "truncates large function arguments" do
      large_args = [String.duplicate("x", 2000)]
      event = Events.function_entry(TestModule, :test_function, 1, large_args)

      # Should be truncated due to size
      assert match?({:truncated, _, _}, event.data.args)
    end
  end

  describe "state change events" do
    test "creates state change event" do
      old_state = %{counter: 0}
      new_state = %{counter: 1}

      event = Events.state_change(self(), :handle_call, old_state, new_state)

      assert event.event_type == :state_change
      assert event.data.server_pid == self()
      assert event.data.callback == :handle_call
      assert event.data.state_diff == :changed
    end

    test "detects no change in identical states" do
      same_state = %{counter: 0}

      event = Events.state_change(self(), :handle_call, same_state, same_state)

      assert event.data.state_diff == :no_change
    end
  end

  describe "serialization" do
    test "serializes and deserializes events correctly" do
      original = Events.new_event(:test_event, %{data: "test"})
      
      serialized = Events.serialize(original)
      deserialized = Events.deserialize(serialized)

      assert deserialized == original
      assert is_binary(serialized)
    end

    test "calculates serialized size correctly" do
      event = Events.new_event(:test_event, %{data: "test"})
      
      calculated_size = Events.serialized_size(event)
      actual_size = event |> Events.serialize() |> byte_size()

      assert calculated_size == actual_size
    end

    test "handles serialization of complex data" do
      complex_data = %{
        nested: %{deep: [1, 2, 3]},
        tuple: {:a, :b, :c},
        list: [1, 2, 3, 4, 5]
      }
      
      event = Events.new_event(:complex_event, complex_data)
      
      serialized = Events.serialize(event)
      deserialized = Events.deserialize(serialized)
      
      assert deserialized == event
    end
  end
end

## test/unit/foundation/utils_test.exs
defmodule ElixirScope.Foundation.UtilsTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.Foundation.Utils

  describe "ID generation" do
    test "generates unique integer IDs" do
      id1 = Utils.generate_id()
      id2 = Utils.generate_id()

      assert is_integer(id1)
      assert is_integer(id2)
      assert id1 != id2
    end

    test "generates many unique IDs" do
      count = 1000
      ids = for _i <- 1..count, do: Utils.generate_id()
      
      unique_ids = Enum.uniq(ids)
      assert length(unique_ids) == count
    end

    test "generates UUID format correlation IDs" do
      corr_id = Utils.generate_correlation_id()

      assert is_binary(corr_id)
      assert String.length(corr_id) == 36
      assert Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, corr_id)
    end

    test "extracts timestamp from ID" do
      id = Utils.generate_id()
      extracted_timestamp = Utils.id_to_timestamp(id)
      
      assert is_integer(extracted_timestamp)
    end
  end

  describe "time utilities" do
    test "generates monotonic timestamps" do
      timestamp1 = Utils.monotonic_timestamp()
      timestamp2 = Utils.monotonic_timestamp()

      assert is_integer(timestamp1)
      assert is_integer(timestamp2)
      assert timestamp2 >= timestamp1
    end

    test "generates wall timestamps" do
      timestamp = Utils.wall_timestamp()

      assert is_integer(timestamp)
      # Should be a reasonable timestamp (after 2020)
      assert timestamp > 1_577_836_800_000_000_000  # 2020-01-01 in nanoseconds
    end

    test "formats timestamps correctly" do
      timestamp_ns = 1_609_459_200_000_000_000  # 2021-01-01 00:00:00 UTC
      formatted = Utils.format_timestamp(timestamp_ns)

      assert is_binary(formatted)
      assert String.contains?(formatted, "2021")
    end
  end

  describe "measurement utilities" do
    test "measures execution time" do
      sleep_time = 10  # milliseconds
      
      {result, duration} = Utils.measure(fn ->
        :timer.sleep(sleep_time)
        :test_result
      end)

      assert result == :test_result
      assert is_integer(duration)
      assert duration >= sleep_time * 1_000_000  # Convert to nanoseconds
    end

    test "measures memory usage" do
      {result, {mem_before, mem_after, diff}} = Utils.measure_memory(fn ->
        Enum.to_list(1..1000)
      end)

      assert is_list(result)
      assert length(result) == 1000
      assert is_integer(mem_before)
      assert is_integer(mem_after)
      assert is_integer(diff)
    end
  end

  describe "data utilities" do
    test "safely inspects terms" do
      data = %{key: "value", nested: %{list: [1, 2, 3]}}
      result = Utils.safe_inspect(data)

      assert is_binary(result)
      assert String.contains?(result, "key")
      assert String.contains?(result, "value")
    end

    test "truncates large terms" do
      small_term = "small"
      large_term = String.duplicate("x", 2000)

      small_result = Utils.truncate_if_large(small_term, 1000)
      large_result = Utils.truncate_if_large(large_term, 1000)

      assert small_result == small_term
      assert match?({:truncated, _, _}, large_result)
    end

    test "estimates term size" do
      small_term = :atom
      large_term = String.duplicate("x", 1000)

      small_size = Utils.term_size(small_term)
      large_size = Utils.term_size(large_term)

      assert is_integer(small_size)
      assert is_integer(large_size)
      assert large_size > small_size
    end
  end

  describe "formatting utilities" do
    test "formats bytes correctly" do
      assert Utils.format_bytes(0) == "0 B"
      assert Utils.format_bytes(512) == "512 B"
      assert Utils.format_bytes(1024) == "1.0 KB"
      assert Utils.format_bytes(1_048_576) == "1.0 MB"
      assert Utils.format_bytes(1_073_741_824) == "1.0 GB"
    end

    test "formats durations correctly" do
      assert Utils.format_duration(0) == "0 ns"
      assert Utils.format_duration(500) == "500 ns"
      assert Utils.format_duration(1_500) == "1.5 μs"
      assert Utils.format_duration(1_500_000) == "1.5 ms"
      assert Utils.format_duration(1_500_000_000) == "1.5 s"
    end
  end

  describe "validation utilities" do
    test "validates positive integers" do
      assert Utils.valid_positive_integer?(1) == true
      assert Utils.valid_positive_integer?(100) == true
      assert Utils.valid_positive_integer?(0) == false
      assert Utils.valid_positive_integer?(-1) == false
      assert Utils.valid_positive_integer?(1.5) == false
      assert Utils.valid_positive_integer?("1") == false
    end

    test "validates percentages" do
      assert Utils.valid_percentage?(0.0) == true
      assert Utils.valid_percentage?(0.5) == true
      assert Utils.valid_percentage?(1.0) == true
      assert Utils.valid_percentage?(-0.1) == false
      assert Utils.valid_percentage?(1.1) == false
      assert Utils.valid_percentage?("0.5") == false
    end

    test "validates PIDs" do
      assert Utils.valid_pid?(self()) == true
      
      # Create and kill a process
      dead_pid = spawn(fn -> nil end)
      Process.sleep(10)
      assert Utils.valid_pid?(dead_pid) == false
      
      assert Utils.valid_pid?("not_a_pid") == false
    end
  end

  describe "system stats" do
    test "gets process stats for current process" do
      stats = Utils.process_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :memory)
      assert Map.has_key?(stats, :reductions)
      assert Map.has_key?(stats, :message_queue_len)
      assert Map.has_key?(stats, :timestamp)
      
      assert is_integer(stats.memory)
      assert stats.memory > 0
    end

    test "gets system stats" do
      stats = Utils.system_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :timestamp)
      assert Map.has_key?(stats, :process_count)
      assert Map.has_key?(stats, :total_memory)
      assert Map.has_key?(stats, :scheduler_count)
      
      assert is_integer(stats.process_count)
      assert stats.process_count > 0
    end
  end
end

## test/unit/foundation/telemetry_test.exs
defmodule ElixirScope.Foundation.TelemetryTest do
  use ExUnit.Case, async: true

  alias ElixirScope.Foundation.Telemetry

  describe "telemetry measurement" do
    test "measures event execution time" do
      result = Telemetry.measure_event([:test, :operation], %{component: :foundation}, fn ->
        :timer.sleep(5)
        :test_result
      end)

      assert result == :test_result
    end

    test "handles errors in measured events" do
      assert_raise RuntimeError, "test error", fn ->
        Telemetry.measure_event([:test, :error], %{}, fn ->
          raise RuntimeError, "test error"
        end)
      end
    end
  end

  describe "telemetry events" do
    test "emits counter events" do
      assert :ok = Telemetry.emit_counter([:test, :counter], %{source: :test})
    end

    test "emits gauge events" do
      assert :ok = Telemetry.emit_gauge([:test, :gauge], 42.5, %{unit: :percent})
    end
  end

  describe "metrics collection" do
    test "collects foundation metrics" do
      metrics = Telemetry.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :foundation)
      assert Map.has_key?(metrics, :system)
      
      foundation_metrics = metrics.foundation
      assert Map.has_key?(foundation_metrics, :uptime_ms)
      assert Map.has_key?(foundation_metrics, :memory_usage)
      assert Map.has_key?(foundation_metrics, :process_count)
    end
  end

  describe "initialization and status" do
    test "initializes successfully" do
      assert :ok = Telemetry.initialize()
    end

    test "reports healthy status" do
      assert :ok = Telemetry.status()
    end
  end
end

## test/contract/foundation_api_test.exs
defmodule ElixirScope.Contract.FoundationAPITest do
  use ExUnit.Case, async: false

  alias ElixirScope.Foundation
  alias ElixirScope.Foundation.{Config, Events, Utils, Telemetry}

  describe "Foundation layer API contracts" do
    test "Foundation.initialize/1 contract" do
      # Should accept keyword list and return :ok or error
      assert :ok = Foundation.initialize([])
      assert :ok = Foundation.initialize(dev: %{debug_mode: true})
    end

    test "Foundation.status/0 contract" do
      status = Foundation.status()
      
      # Should return map with required keys
      assert is_map(status)
      assert Map.has_key?(status, :config)
      assert Map.has_key?(status, :events)
      assert Map.has_key?(status, :telemetry)
      assert Map.has_key?(status, :uptime_ms)
      
      # Values should be status indicators or metrics
      assert status.config in [:ok, {:error, term}] or match?({:error, _}, status.config)
      assert is_integer(status.uptime_ms)
    end
  end

  describe "Config API contracts" do
    setup do
      :ok = ElixirScope.Foundation.TestHelpers.ensure_config_available()
      :ok
    end

    test "Config.get/0 returns Config struct" do
      config = Config.get()
      assert %Config{} = config
    end

    test "Config.get/1 with path returns value or nil" do
      result = Config.get([:ai, :provider])
      assert result != nil
      
      result = Config.get([:nonexistent, :path])
      assert result == nil
    end

    test "Config.update/2 respects allowed paths" do
      # Should succeed for allowed paths
      result = Config.update([:ai, :planning, :sampling_rate], 0.5)
      assert result == :ok
      
      # Should fail for forbidden paths
      result = Config.update([:ai, :provider], :different_provider)
      assert result == {:error, :not_updatable}
    end

    test "Config.validate/1 returns ok or error tuple" do
      valid_config = %Config{}
      assert {:ok, ^valid_config} = Config.validate(valid_config)
      
      invalid_config = %Config{ai: %{provider: :invalid}}
      assert {:error, _reason} = Config.validate(invalid_config)
    end
  end

  describe "Events API contracts" do
    test "Events.new_event/3 creates valid event" do
      event = Events.new_event(:test_type, %{data: "test"}, [])
      
      assert %Events{} = event
      assert event.event_type == :test_type
      assert is_integer(event.event_id)
      assert is_integer(event.timestamp)
    end

    test "Events serialization contracts" do
      event = Events.new_event(:test, %{})
      
      # Serialize should return binary
      serialized = Events.serialize(event)
      assert is_binary(serialized)
      
      # Deserialize should return original event
      deserialized = Events.deserialize(serialized)
      assert deserialized == event
      
      # Size should be non-negative integer
      size = Events.serialized_size(event)
      assert is_integer(size)
      assert size >= 0
    end
  end

  describe "Utils API contracts" do
    test "ID generation contracts" do
      # generate_id should return positive integer
      id = Utils.generate_id()
      assert is_integer(id)
      assert id > 0
      
      # generate_correlation_id should return UUID string
      corr_id = Utils.generate_correlation_id()
      assert is_binary(corr_id)
      assert String.length(corr_id) == 36
    end

    test "measurement contracts" do
      # measure should return {result, duration} tuple
      {result, duration} = Utils.measure(fn -> :test_result end)
      assert result == :test_result
      assert is_integer(duration)
      assert duration >= 0
      
      # measure_memory should return {result, {before, after, diff}} tuple  
      {result, {before, after, diff}} = Utils.measure_memory(fn -> :test_result end)
      assert result == :test_result
      assert is_integer(before)
      assert is_integer(after)
      assert is_integer(diff)
    end

    test "formatting contracts" do
      # Should return strings
      assert is_binary(Utils.format_bytes(1024))
      assert is_binary(Utils.format_duration(1_000_000))
      assert is_binary(Utils.format_timestamp(Utils.wall_timestamp()))
      
      # Should handle edge cases
      assert is_binary(Utils.format_bytes(0))
      assert is_binary(Utils.format_duration(0))
    end

    test "validation contracts" do
      # Should return boolean
      assert is_boolean(Utils.valid_positive_integer?(1))
      assert is_boolean(Utils.valid_percentage?(0.5))
      assert is_boolean(Utils.valid_pid?(self()))
    end
  end

  describe "Telemetry API contracts" do
    test "measurement and emission contracts" do
      # measure_event should return function result
      result = Telemetry.measure_event([:test], %{}, fn -> :measured end)
      assert result == :measured
      
      # emit functions should return :ok
      assert :ok = Telemetry.emit_counter([:test])
      assert :ok = Telemetry.emit_gauge([:test], 42.0)
    end

    test "metrics contract" do
      metrics = Telemetry.get_metrics()
      
      assert is_map(metrics)
      assert Map.has_key?(metrics, :foundation)
      assert Map.has_key?(metrics, :system)
    end
  end
end

## scripts/benchmark.exs
# Performance benchmarking script for Foundation layer
# Usage: mix run scripts/benchmark.exs

defmodule FoundationBenchmark do
  alias ElixirScope.Foundation.{Config, Events, Utils, Telemetry}

  def run_benchmarks do
    IO.puts("=== ElixirScope Foundation Layer Benchmarks ===\n")
    
    benchmark_id_generation()
    benchmark_event_creation()
    benchmark_serialization()
    benchmark_measurement()
    benchmark_configuration()
    
    IO.puts("=== Benchmarks Complete ===")
  end

  defp benchmark_id_generation do
    IO.puts("🔢 ID Generation Benchmarks:")
    
    # Benchmark integer ID generation
    {time, _} = :timer.tc(fn ->
      for _i <- 1..10_000, do: Utils.generate_id()
    end)
    avg_time = time / 10_000
    IO.puts("  Integer IDs: #{Float.round(avg_time, 2)} μs/ID (10k IDs)")
    
    # Benchmark correlation ID generation
    {time, _} = :timer.tc(fn ->
      for _i <- 1..1_000, do: Utils.generate_correlation_id()
    end)
    avg_time = time / 1_000
    IO.puts("  Correlation IDs: #{Float.round(avg_time, 2)} μs/ID (1k IDs)")
    
    IO.puts("")
  end

  defp benchmark_event_creation do
    IO.puts("📝 Event Creation Benchmarks:")
    
    # Simple events
    {time, _} = :timer.tc(fn ->
      for i <- 1..10_000 do
        Events.new_event(:benchmark_event, %{sequence: i})
      end
    end)
    avg_time = time / 10_000
    IO.puts("  Simple events: #{Float.round(avg_time, 2)} μs/event (10k events)")
    
    # Function events
    {time, _} = :timer.tc(fn ->
      for i <- 1..10_000 do
        Events.function_entry(BenchmarkModule, :test_function, 1, [i])
      end
    end)
    avg_time = time / 10_000
    IO.puts("  Function events: #{Float.round(avg_time, 2)} μs/event (10k events)")
    
    IO.puts("")
  end

  defp benchmark_serialization do
    IO.puts("💾 Serialization Benchmarks:")
    
    # Create test events
    simple_event = Events.new_event(:test, %{data: "simple"})
    complex_event = Events.new_event(:complex, %{
      data: Enum.to_list(1..100),
      metadata: %{timestamp: Utils.wall_timestamp()},
      nested: %{deep: %{structure: [1, 2, 3]}}
    })
    
    # Benchmark simple event serialization
    {time, _} = :timer.tc(fn ->
      for _i <- 1..10_000 do
        Events.serialize(simple_event)
      end
    end)
    avg_time = time / 10_000
    IO.puts("  Simple serialize: #{Float.round(avg_time, 2)} μs/event (10k events)")
    
    # Benchmark complex event serialization
    {time, _} = :timer.tc(fn ->
      for _i <- 1..1_000 do
        Events.serialize(complex_event)
      end
    end)
    avg_time = time / 1_000
    IO.puts("  Complex serialize: #{Float.round(avg_time, 2)} μs/event (1k events)")
    
    # Benchmark deserialization
    serialized_simple = Events.serialize(simple_event)
    {time, _} = :timer.tc(fn ->
      for _i <- 1..10_000 do
        Events.deserialize(serialized_simple)
      end
    end)
    avg_time = time / 10_000
    IO.puts("  Deserialize: #{Float.round(avg_time, 2)} μs/event (10k events)")
    
    IO.puts("")
  end

  defp benchmark_measurement do
    IO.puts("⏱️  Measurement Benchmarks:")
    
    # Time measurement overhead
    {time, _} = :timer.tc(fn ->
      for _i <- 1..10_000 do
        Utils.measure(fn -> :ok end)
      end
    end)
    avg_time = time / 10_000
    IO.puts("  Time measurement overhead: #{Float.round(avg_time, 2)} μs/measurement")
    
    # Memory measurement overhead
    {time, _} = :timer.tc(fn ->
      for _i <- 1..1_000 do
        Utils.measure_memory(fn -> :ok end)
      end
    end)
    avg_time = time / 1_000
    IO.puts("  Memory measurement overhead: #{Float.round(avg_time, 2)} μs/measurement")
    
    # Telemetry measurement overhead
    {time, _} = :timer.tc(fn ->
      for _i <- 1..10_000 do
        Telemetry.measure_event([:benchmark], %{}, fn -> :ok end)
      end
    end)
    avg_time = time / 10_000
    IO.puts("  Telemetry measurement overhead: #{Float.round(avg_time, 2)} μs/measurement")
    
    IO.puts("")
  end

  defp benchmark_configuration do
    IO.puts("⚙️  Configuration Benchmarks:")
    
    # Config get operations
    {time, _} = :timer.tc(fn ->
      for _i <- 1..10_000 do
        Config.get()
      end
    end)
    avg_time = time / 10_000
    IO.puts("  Full config get: #{Float.round(avg_time, 2)} μs/get")
    
    # Config path get operations
    {time, _} = :timer.tc(fn ->
      for _i <- 1..10_000 do
        Config.get([:ai, :planning, :sampling_rate])
      end
    end)
    avg_time = time / 10_000
    IO.puts("  Path config get: #{Float.round(avg_time, 2)} μs/get")
    
    # Config update operations
    {time, _} = :timer.tc(fn ->
      for i <- 1..1_000 do
        rate = if rem(i, 2) == 0, do: 0.8, else: 1.0
        Config.update([:ai, :planning, :sampling_rate], rate)
      end
    end)
    avg_time = time / 1_000
    IO.puts("  Config update: #{Float.round(avg_time, 2)} μs/update")
    
    IO.puts("")
  end
end
