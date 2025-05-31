defmodule ElixirScope.Foundation.Config do
  @moduledoc """
  Centralized configuration management for ElixirScope with robust error handling.
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.{Error, ErrorContext}

  @behaviour Access

  @type config_path :: [atom()]
  @type config_value :: term()

  # Configuration validation schemas
  @ai_analysis_schema %{
    required: [:max_file_size, :timeout, :cache_ttl],
    types: %{
      max_file_size: :integer,
      timeout: :integer,
      cache_ttl: :integer
    }
  }

  @ai_planning_schema %{
    required: [:default_strategy, :performance_target, :sampling_rate],
    types: %{
      default_strategy: {:one_of, [:fast, :balanced, :thorough]},
      performance_target: :number,
      sampling_rate: :number
    }
  }

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

  ## Access Behavior Implementation

  @impl Access
  def fetch(%__MODULE__{} = config, key) do
    config
    |> Map.from_struct()
    |> Map.fetch(key)
  end

  @impl Access
  def get_and_update(%__MODULE__{} = config, key, function) do
    map_config = Map.from_struct(config)

    case Map.get_and_update(map_config, key, function) do
      {current_value, updated_map} ->
        case struct(__MODULE__, updated_map) do
          updated_config when is_struct(updated_config, __MODULE__) ->
            {current_value, updated_config}
          _ ->
            # Fallback if struct creation fails
            {current_value, config}
        end
    end
  end

  @impl Access
  def pop(%__MODULE__{} = config, key) do
    map_config = Map.from_struct(config)
    {value, updated_map} = Map.pop(map_config, key)
    updated_config = struct(__MODULE__, updated_map)
    {value, updated_config}
  end

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
  #@valid_overflow_strategies [:drop_oldest, :drop_newest, :block]
  #@valid_compression_types [:none, :gzip, :zstd]

  ## Public API

  @spec initialize(keyword()) :: :ok | {:error, Error.t()}
  def initialize(opts \\ []) do
    context = ErrorContext.new(__MODULE__, :initialize, metadata: %{opts: opts})

    ErrorContext.with_context(context, fn ->
      case GenServer.start_link(__MODULE__, opts, name: __MODULE__) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        {:error, reason} ->
          Error.error_result(:initialization_failed,
            "Failed to start Config GenServer",
            context: %{reason: reason}
          )
      end
    end)
  end

  @spec status() :: :ok
  def status, do: :ok

  @spec get() :: t() | {:error, Error.t()}
  def get do
    context = ErrorContext.new(__MODULE__, :get)

    ErrorContext.with_context(context, fn ->
      case GenServer.whereis(__MODULE__) do
        nil ->
          Error.error_result(:service_unavailable,
            "Configuration service not started"
          )
        _pid ->
          GenServer.call(__MODULE__, :get_config)
      end
    end)
  end

  @spec get(config_path()) :: config_value() | nil | {:error, Error.t()}
  def get(path) when is_list(path) do
    context = ErrorContext.new(__MODULE__, :get, metadata: %{path: path})

    ErrorContext.with_context(context, fn ->
      case GenServer.whereis(__MODULE__) do
        nil ->
          Error.error_result(:service_unavailable,
            "Configuration service not started"
          )
        _pid ->
          GenServer.call(__MODULE__, {:get_config_path, path})
      end
    end)
  end

  @spec update(config_path(), config_value()) :: :ok | {:error, Error.t()}
  def update(path, value) when is_list(path) do
    context = ErrorContext.new(__MODULE__, :update, metadata: %{path: path, value: value})

    ErrorContext.with_context(context, fn ->
      case GenServer.whereis(__MODULE__) do
        nil ->
          Error.error_result(:service_unavailable,
            "Configuration service not started"
          )
        _pid ->
          GenServer.call(__MODULE__, {:update_config, path, value})
      end
    end)
  end

  @spec validate(t()) :: :ok | {:error, Error.t()}
  def validate(%__MODULE__{} = config) do
    context = ErrorContext.new(__MODULE__, :validate)

    ErrorContext.with_context(context, fn ->
      with :ok <- validate_ai_config(config.ai),
           :ok <- validate_capture_config(config.capture),
           :ok <- validate_storage_config(config.storage),
           :ok <- validate_interface_config(config.interface),
           :ok <- validate_dev_config(config.dev) do
        :ok
      end
    end)
  end

  ## GenServer Implementation

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    context = ErrorContext.new(__MODULE__, :init, metadata: %{opts: opts})

    case ErrorContext.with_context(context, fn -> build_config(opts) end) do
      {:ok, config} ->
        case validate(config) do
          :ok ->
            Logger.info("ElixirScope.Foundation.Config initialized successfully")
            {:ok, config}
          {:error, error} ->
            Logger.error("Config validation failed: #{Error.to_string(error)}")
            {:stop, {:validation_failed, error}}
        end
      {:error, error} ->
        Logger.error("Config build failed: #{Error.to_string(error)}")
        {:stop, {:build_failed, error}}
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
    context = ErrorContext.new(__MODULE__, :handle_update, metadata: %{path: path, value: value})

    result = ErrorContext.with_context(context, fn ->
      cond do
        path not in @updatable_paths ->
          Error.error_result(:config_update_forbidden,
            "Configuration path cannot be updated at runtime",
            context: %{path: path, updatable_paths: @updatable_paths}
          )

        true ->
          # Replace this line:
          # new_config = put_in(config, path, value)

          # With this:
          new_config = put_in(config, path, value)

          case validate(new_config) do
            :ok ->
              Logger.debug("Config updated: #{inspect(path)} = #{inspect(value)}")
              {:ok, new_config}
            {:error, _} = error ->
              error
          end
      end
    end)

    case result do
      {:ok, new_config} -> {:reply, :ok, new_config}
      {:error, error} -> {:reply, {:error, error}, config}
    end
  end

  # # Add this private function:
  # defp put_config_value(_config, [], value) do
  #   value
  # end

  # defp put_config_value(config, [key], value) when is_struct(config) do
  #   Map.put(config, key, value)
  # end

  # defp put_config_value(config, [key], value) when is_map(config) do
  #   Map.put(config, key, value)
  # end

  # defp put_config_value(config, [key | rest], value) when is_struct(config) do
  #   current_value = Map.get(config, key)
  #   new_value = put_config_value(current_value, rest, value)
  #   Map.put(config, key, new_value)
  # end

  # defp put_config_value(config, [key | rest], value) when is_map(config) do
  #   current_value = Map.get(config, key)
  #   new_value = put_config_value(current_value, rest, value)
  #   Map.put(config, key, new_value)
  # end


  # # # Add this private function:
  # # defp get_config_value(config, []) do
  # #   config
  # # end

  # defp get_config_value(config, [key | rest]) when is_struct(config) do
  #   # Convert struct to map for the first access
  #   map_config = Map.from_struct(config)
  #   get_config_value(Map.get(map_config, key), rest)
  # end

  # defp get_config_value(config, [key | rest]) when is_map(config) do
  #   get_config_value(Map.get(config, key), rest)
  # end

  # defp get_config_value(nil, _path), do: nil
  # defp get_config_value(value, []), do: value

  ## Validation Functions

  @spec validate_ai_config(map()) :: :ok | {:error, Error.t()}
  defp validate_ai_config(%{provider: provider} = config) do
    context = ErrorContext.new(__MODULE__, :validate_ai_config, metadata: %{provider: provider})

    ErrorContext.with_context(context, fn ->
      with :ok <- validate_provider(provider),
           :ok <- validate_ai_analysis(config.analysis),
           :ok <- validate_ai_planning(config.planning) do
        :ok
      end
    end)
  end

  @spec validate_provider(atom()) :: :ok | {:error, Error.t()}
  defp validate_provider(provider) do
    if provider in @valid_ai_providers do
      :ok
    else
      Error.error_result(:invalid_config_value,
        "Invalid AI provider",
        context: %{
          provider: provider,
          valid_providers: @valid_ai_providers
        }
      )
    end
  end

  @spec validate_ai_analysis(map()) :: :ok | {:error, Error.t()}
  defp validate_ai_analysis(analysis) do
    with :ok <- validate_map(analysis, @ai_analysis_schema),
         :ok <- validate_positive_integers(analysis, [:max_file_size, :timeout, :cache_ttl]) do
      :ok
    end
  end

  @spec validate_ai_planning(map()) :: :ok | {:error, Error.t()}
  defp validate_ai_planning(planning) do
    with :ok <- validate_map(planning, @ai_planning_schema),
         :ok <- validate_performance_target(planning.performance_target),
         :ok <- validate_sampling_rate(planning.sampling_rate) do
      :ok
    end
  end

  @spec validate_performance_target(number()) :: :ok | {:error, Error.t()}
  defp validate_performance_target(target) do
    if is_number(target) and target >= 0 do
      :ok
    else
      Error.error_result(:constraint_violation,
        "Performance target must be a non-negative number",
        context: %{target: target}
      )
    end
  end

  @spec validate_sampling_rate(number()) :: :ok | {:error, Error.t()}
  defp validate_sampling_rate(rate) do
    if is_number(rate) and rate >= 0 and rate <= 1 do
      :ok
    else
      Error.error_result(:range_error,
        "Sampling rate must be between 0 and 1",
        context: %{rate: rate}
      )
    end
  end

  @spec validate_positive_integers(map(), [atom()]) :: :ok | {:error, Error.t()}
  defp validate_positive_integers(data, fields) do
    errors = Enum.reduce(fields, [], fn field, acc ->
      value = Map.get(data, field)
      if is_integer(value) and value > 0 do
        acc
      else
        [{field, value} | acc]
      end
    end)

    case errors do
      [] -> :ok
      _ ->
        Error.error_result(:constraint_violation,
          "Fields must be positive integers",
          context: %{invalid_fields: errors}
        )
    end
  end

  # Simplified validation schemas and functions for other config sections
  @spec validate_map(map(), map()) :: :ok | {:error, Error.t()}
  defp validate_map(data, schema) when is_map(data) and is_map(schema) do
    required = Map.get(schema, :required, [])
    types = Map.get(schema, :types, %{})

    with :ok <- validate_required_fields(data, required),
         :ok <- validate_field_types(data, types) do
      :ok
    end
  end

  @spec validate_required_fields(map(), [atom()]) :: :ok | {:error, Error.t()}
  defp validate_required_fields(data, required) do
    missing = Enum.reject(required, &Map.has_key?(data, &1))

    case missing do
      [] -> :ok
      _ ->
        Error.error_result(:missing_required_config,
          "Required fields missing",
          context: %{missing_fields: missing}
        )
    end
  end

  @spec validate_field_types(map(), map()) :: :ok | {:error, Error.t()}
  defp validate_field_types(data, types) do
    errors = Enum.reduce(types, [], fn {field, expected_type}, acc ->
      case Map.get(data, field) do
        nil -> acc  # Field not present, handled by required validation
        value ->
          if valid_type?(value, expected_type) do
            acc
          else
            [{field, expected_type, typeof(value)} | acc]
          end
      end
    end)

    case errors do
      [] -> :ok
      _ ->
        Error.error_result(:type_mismatch,
          "Field type validation failed",
          context: %{field_errors: errors}
        )
    end
  end

  # Placeholder validation functions - implement as needed
  @spec validate_capture_config(map()) :: :ok | {:error, Error.t()}
  defp validate_capture_config(_capture), do: :ok

  @spec validate_storage_config(map()) :: :ok | {:error, Error.t()}
  defp validate_storage_config(_storage), do: :ok

  @spec validate_interface_config(map()) :: :ok | {:error, Error.t()}
  defp validate_interface_config(_interface), do: :ok

  @spec validate_dev_config(map()) :: :ok | {:error, Error.t()}
  defp validate_dev_config(_dev), do: :ok

  ## Private Helper Functions

  @spec build_config(keyword()) :: {:ok, t()} | {:error, Error.t()}
  defp build_config(opts) do
    context = ErrorContext.new(__MODULE__, :build_config, metadata: %{opts: opts})

    ErrorContext.with_context(context, fn ->
      base_config = %__MODULE__{}
      env_config = Application.get_all_env(:elixir_scope)

      merged_config = base_config
      |> merge_env_config(env_config)
      |> merge_opts_config(opts)

      {:ok, merged_config}
    end)
  end

  @spec merge_env_config(t(), keyword()) :: t()
  defp merge_env_config(config, env_config) do
    Enum.reduce(env_config, config, fn {key, value}, acc ->
      if Map.has_key?(acc, key) do
        current_value = Map.get(acc, key)
        merged_value = deep_merge(current_value, value)
        Map.put(acc, key, merged_value)
      else
        acc
      end
    end)
  end

  @spec merge_opts_config(t(), keyword()) :: t()
  defp merge_opts_config(config, opts) do
    Enum.reduce(opts, config, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  @spec deep_merge(term(), term()) :: term()
  defp deep_merge(left, right) when is_map(left) and is_list(right) do
    # Convert keyword list to map, then merge recursively
    right_map = Enum.into(right, %{})
    Map.merge(left, right_map, fn _key, left_val, right_val ->
      deep_merge(left_val, right_val)
    end)
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_val, right_val ->
      deep_merge(left_val, right_val)
    end)
  end

  defp deep_merge(_left, right), do: right

  # Type validation helpers
  defp valid_type?(value, :integer), do: is_integer(value)
  defp valid_type?(value, :number), do: is_number(value)
  defp valid_type?(value, :atom), do: is_atom(value)
  defp valid_type?(value, :boolean), do: is_boolean(value)
  defp valid_type?(value, {:one_of, types}), do: value in types
  defp valid_type?(_value, _type), do: false

  defp typeof(value) when is_integer(value), do: :integer
  defp typeof(value) when is_number(value), do: :number
  defp typeof(value) when is_atom(value), do: :atom
  defp typeof(value) when is_boolean(value), do: :boolean
  defp typeof(_value), do: :unknown
end


  # TODO: implement remaining validation functions with same pattern

  # defp validate_capture_config(capture) do
  #   with :ok <- validate_ring_buffer(capture.ring_buffer),
  #       :ok <- validate_processing(capture.processing),
  #       :ok <- validate_vm_tracing(capture.vm_tracing) do
  #     :ok
  #   end
  # end

  # defp validate_storage_config(storage) do
  #   with :ok <- validate_hot_storage(storage.hot),
  #       :ok <- validate_warm_storage(storage.warm),
  #       :ok <- validate_cold_storage(storage.cold) do
  #     :ok
  #   end
  # end

  # defp validate_interface_config(interface) do
  #   schema = %{
  #     required: [:query_timeout, :max_results, :enable_streaming],
  #     types: %{
  #       query_timeout: :integer,
  #       max_results: :integer,
  #       enable_streaming: :boolean
  #     }
  #   }
  #   ErrorHandler.validate_map(interface, schema)
  # end

  # defp validate_dev_config(dev) do
  #   schema = %{
  #     required: [:debug_mode, :verbose_logging, :performance_monitoring],
  #     types: %{
  #       debug_mode: :boolean,
  #       verbose_logging: :boolean,
  #       performance_monitoring: :boolean
  #     }
  #   }
  #   ErrorHandler.validate_map(dev, schema)
  # end

  ## Private Functions

#   defp build_config(opts) do
#     safe_call do
#       base_config = %__MODULE__{}
#       env_config = Application.get_all_env(:elixir_scope)

#       base_config
#       |> merge_env_config(env_config)
#       |> merge_opts_config(opts)
#     end
#   end

#   # TODO: BELOW HERE, wrap in safe_call where appropriate

#   defp merge_env_config(config, env_config) do
#     Enum.reduce(env_config, config, fn {key, value}, acc ->
#       if Map.has_key?(acc, key) do
#         Map.put(acc, key, deep_merge(Map.get(acc, key), value))
#       else
#         acc
#       end
#     end)
#   end

#   defp merge_opts_config(config, opts) do
#     Enum.reduce(opts, config, fn {key, value}, acc ->
#       Map.put(acc, key, value)
#     end)
#   end

#   defp deep_merge(left, right) when is_map(left) and is_map(right) do
#     Map.merge(left, right, fn _key, left_val, right_val ->
#       deep_merge(left_val, right_val)
#     end)
#   end
#   defp deep_merge(_left, right), do: right

#   # # Validation functions
#   # defp validate_ai_config(%{provider: provider} = config) when provider in @valid_ai_providers do
#   #   with :ok <- validate_ai_analysis(config.analysis),
#   #        :ok <- validate_ai_planning(config.planning) do
#   #     :ok
#   #   end
#   # end
#   # defp validate_ai_config(%{provider: provider}), do: {:error, {:invalid_ai_provider, provider}}

#   # defp validate_ai_analysis(%{max_file_size: size, timeout: timeout, cache_ttl: ttl})
#   #   when is_integer(size) and size > 0 and
#   #        is_integer(timeout) and timeout > 0 and
#   #        is_integer(ttl) and ttl > 0 do
#   #   :ok
#   # end
#   # defp validate_ai_analysis(_), do: {:error, :invalid_ai_analysis_config}

#   # defp validate_ai_planning(%{performance_target: target, sampling_rate: rate, default_strategy: strategy})
#   #   when is_number(target) and target >= 0 and
#   #        is_number(rate) and rate >= 0 and rate <= 1 and
#   #        strategy in @valid_planning_strategies do
#   #   :ok
#   # end
#   # defp validate_ai_planning(_), do: {:error, :invalid_ai_planning_config}

#   defp validate_capture_config(%{ring_buffer: rb, processing: proc, vm_tracing: vt}) do
#     with :ok <- validate_ring_buffer(rb),
#          :ok <- validate_processing(proc),
#          :ok <- validate_vm_tracing(vt) do
#       :ok
#     end
#   end

#   defp validate_ring_buffer(%{size: size, max_events: max, overflow_strategy: strategy})
#     when is_integer(size) and size > 0 and
#          is_integer(max) and max > 0 and
#          strategy in @valid_overflow_strategies do
#     :ok
#   end
#   defp validate_ring_buffer(_), do: {:error, :invalid_ring_buffer_config}

#   defp validate_processing(%{batch_size: batch, flush_interval: flush, max_queue_size: queue})
#     when is_integer(batch) and batch > 0 and
#          is_integer(flush) and flush > 0 and
#          is_integer(queue) and queue > 0 do
#     :ok
#   end
#   defp validate_processing(_), do: {:error, :invalid_processing_config}

#   defp validate_vm_tracing(%{enable_spawn_trace: spawn, enable_exit_trace: exit,
#                            enable_message_trace: msg, trace_children: children})
#     when is_boolean(spawn) and is_boolean(exit) and
#          is_boolean(msg) and is_boolean(children) do
#     :ok
#   end
#   defp validate_vm_tracing(_), do: {:error, :invalid_vm_tracing_config}

#   defp validate_storage_config(%{hot: hot, warm: warm, cold: cold}) do
#     with :ok <- validate_hot_storage(hot),
#          :ok <- validate_warm_storage(warm),
#          :ok <- validate_cold_storage(cold) do
#       :ok
#     end
#   end

#   defp validate_hot_storage(%{max_events: max, max_age_seconds: age, prune_interval: interval})
#     when is_integer(max) and max > 0 and
#          is_integer(age) and age > 0 and
#          is_integer(interval) and interval > 0 do
#     :ok
#   end
#   defp validate_hot_storage(_), do: {:error, :invalid_hot_storage_config}

#   defp validate_warm_storage(%{enable: false}), do: :ok
#   defp validate_warm_storage(%{enable: true, path: path, max_size_mb: size, compression: comp})
#     when is_binary(path) and
#          is_integer(size) and size > 0 and
#          comp in @valid_compression_types do
#     :ok
#   end
#   defp validate_warm_storage(_), do: {:error, :invalid_warm_storage_config}

#   defp validate_cold_storage(%{enable: false}), do: :ok
#   defp validate_cold_storage(_), do: {:error, :invalid_cold_storage_config}

#   defp validate_interface_config(%{query_timeout: timeout, max_results: max, enable_streaming: stream})
#     when is_integer(timeout) and timeout > 0 and
#          is_integer(max) and max > 0 and
#          is_boolean(stream) do
#     :ok
#   end
#   defp validate_interface_config(_), do: {:error, :invalid_interface_config}

#   defp validate_dev_config(%{debug_mode: debug, verbose_logging: verbose, performance_monitoring: perf})
#     when is_boolean(debug) and is_boolean(verbose) and is_boolean(perf) do
#     :ok
#   end
#   defp validate_dev_config(_), do: {:error, :invalid_dev_config}

# end
