defmodule ElixirScope.Foundation.Config do
  @moduledoc """
  Public API for configuration management.

  Thin wrapper around ConfigServer that provides a clean, documented interface.
  All business logic is delegated to the service layer.
  """

  @behaviour ElixirScope.Foundation.Contracts.Configurable

  alias ElixirScope.Foundation.Services.ConfigServer
  alias ElixirScope.Foundation.Types.{Config, Error}

  @type config_path :: [atom()]
  @type config_value :: term()

  @doc """
  Initialize the configuration service.

  ## Examples

      iex> ElixirScope.Foundation.Config.initialize()
      :ok
  """
  @spec initialize() :: :ok | {:error, Error.t()}
  def initialize() do
    ConfigServer.initialize()
  end

  @doc """
  Initialize the configuration service with options.

  ## Examples

      iex> ElixirScope.Foundation.Config.initialize(cache_size: 1000)
      :ok
  """
  @spec initialize(keyword()) :: :ok | {:error, Error.t()}
  def initialize(opts) when is_list(opts) do
    ConfigServer.initialize(opts)
  end

  @doc """
  Get configuration service status.

  ## Examples

      iex> ElixirScope.Foundation.Config.status()
      {:ok, %{status: :running, uptime: 12345}}
  """
  @spec status() :: {:ok, map()} | {:error, Error.t()}
  def status() do
    ConfigServer.status()
  end

  @doc """
  Get the complete configuration.

  ## Examples

      iex> ElixirScope.Foundation.Config.get()
      {:ok, %Config{...}}
  """
  @spec get() :: {:ok, Config.t()} | {:error, Error.t()}
  defdelegate get(), to: ConfigServer

  @doc """
  Get a configuration value by path.

  ## Examples

      iex> ElixirScope.Foundation.Config.get([:ai, :provider])
      {:ok, :openai}

      iex> ElixirScope.Foundation.Config.get([:nonexistent, :path])
      {:error, %Error{error_type: :config_path_not_found}}
  """
  @spec get(config_path()) :: {:ok, config_value()} | {:error, Error.t()}
  defdelegate get(path), to: ConfigServer

  @doc """
  Update a configuration value at the given path.

  Only paths returned by `updatable_paths/0` can be updated at runtime.

  ## Examples

      iex> ElixirScope.Foundation.Config.update([:dev, :debug_mode], true)
      :ok

      iex> ElixirScope.Foundation.Config.update([:ai, :provider], :anthropic)
      {:error, %Error{error_type: :config_update_forbidden}}
  """
  @spec update(config_path(), config_value()) :: :ok | {:error, Error.t()}
  defdelegate update(path, value), to: ConfigServer

  @doc """
  Validate a configuration structure.

  ## Examples

      iex> config = %Config{ai: %{provider: :invalid}}
      iex> ElixirScope.Foundation.Config.validate(config)
      {:error, %Error{error_type: :invalid_config_value}}
  """
  @spec validate(Config.t()) :: :ok | {:error, Error.t()}
  defdelegate validate(config), to: ConfigServer

  @doc """
  Get the list of paths that can be updated at runtime.

  ## Examples

      iex> ElixirScope.Foundation.Config.updatable_paths()
      [
        [:ai, :planning, :sampling_rate],
        [:dev, :debug_mode],
        ...
      ]
  """
  @spec updatable_paths() :: [config_path()]
  defdelegate updatable_paths(), to: ConfigServer

  @doc """
  Reset configuration to defaults.

  ## Examples

      iex> ElixirScope.Foundation.Config.reset()
      :ok
  """
  @spec reset() :: :ok | {:error, Error.t()}
  defdelegate reset(), to: ConfigServer

  @doc """
  Check if the configuration service is available.

  ## Examples

      iex> ElixirScope.Foundation.Config.available?()
      true
  """
  @spec available?() :: boolean()
  defdelegate available?(), to: ConfigServer

  @doc """
  Subscribe to configuration change notifications.

  The calling process will receive messages of the form:
  `{:config_notification, {:config_updated, path, new_value}}`

  ## Examples

      iex> ElixirScope.Foundation.Config.subscribe()
      :ok
  """
  @spec subscribe() :: :ok | {:error, Error.t()}
  def subscribe do
    ConfigServer.subscribe()
  end

  @doc """
  Unsubscribe from configuration change notifications.

  ## Examples

      iex> ElixirScope.Foundation.Config.unsubscribe()
      :ok
  """
  @spec unsubscribe() :: :ok
  def unsubscribe do
    ConfigServer.unsubscribe()
  end

  @doc """
  Get configuration with a default value if path doesn't exist.

  ## Examples

      iex> ElixirScope.Foundation.Config.get_with_default([:ai, :timeout], 30_000)
      30_000
  """
  @spec get_with_default(config_path(), config_value()) :: config_value()
  def get_with_default(path, default) do
    case get(path) do
      {:ok, value} -> value
      {:error, _} -> default
    end
  end

  @doc """
  Update configuration if the path is updatable, otherwise return error.

  Convenience function that checks updatable paths before attempting update.

  ## Examples

      iex> ElixirScope.Foundation.Config.safe_update([:dev, :debug_mode], true)
      :ok
  """
  @spec safe_update(config_path(), config_value()) :: :ok | {:error, Error.t()}
  def safe_update(path, value) do
    if path in updatable_paths() do
      update(path, value)
    else
      {:error, Error.new(
        error_type: :config_update_forbidden,
        message: "Configuration path cannot be updated at runtime",
        context: %{path: path, allowed_paths: updatable_paths()},
        category: :config,
        subcategory: :validation,
        severity: :medium
      )}
    end
  end
end




# defmodule ElixirScope.Foundation.Config do
#   @moduledoc """
#   Centralized configuration management for ElixirScope with robust error handling.
#   """

#   use GenServer
#   require Logger

#   alias ElixirScope.Foundation.{Error, ErrorContext}

#   @behaviour Access

#   @type config_path :: [atom()]
#   @type config_value :: term()

#   # Configuration structure with complete type definitions
#   defstruct [
#     # AI Configuration
#     ai: %{
#       provider: :mock,
#       api_key: nil,
#       model: "gpt-4",
#       analysis: %{
#         max_file_size: 1_000_000,
#         timeout: 30_000,
#         cache_ttl: 3600
#       },
#       planning: %{
#         default_strategy: :balanced,
#         performance_target: 0.01,
#         sampling_rate: 1.0
#       }
#     },

#     # Capture Configuration
#     capture: %{
#       ring_buffer: %{
#         size: 1024,
#         max_events: 1000,
#         overflow_strategy: :drop_oldest,
#         num_buffers: :schedulers
#       },
#       processing: %{
#         batch_size: 100,
#         flush_interval: 50,
#         max_queue_size: 1000
#       },
#       vm_tracing: %{
#         enable_spawn_trace: true,
#         enable_exit_trace: true,
#         enable_message_trace: false,
#         trace_children: true
#       }
#     },

#     # Storage Configuration
#     storage: %{
#       hot: %{
#         max_events: 100_000,
#         max_age_seconds: 3600,
#         prune_interval: 60_000
#       },
#       warm: %{
#         enable: false,
#         path: "./elixir_scope_data",
#         max_size_mb: 100,
#         compression: :zstd
#       },
#       cold: %{
#         enable: false
#       }
#     },

#     # Interface Configuration
#     interface: %{
#       query_timeout: 10_000,
#       max_results: 1000,
#       enable_streaming: true
#     },

#     # Development Configuration
#     dev: %{
#       debug_mode: false,
#       verbose_logging: false,
#       performance_monitoring: true
#     }
#   ]

#   @type t :: %__MODULE__{
#           ai: map(),
#           capture: map(),
#           storage: map(),
#           interface: map(),
#           dev: map()
#         }

#   ## Access Behavior Implementation

#   @impl Access
#   def fetch(%__MODULE__{} = config, key) do
#     config
#     |> Map.from_struct()
#     |> Map.fetch(key)
#   end

#   @impl Access
#   @spec get_and_update(ElixirScope.Foundation.Config.t(), any(), (any() -> :pop | {any(), any()})) ::
#           {any(), struct()}
#   def get_and_update(%__MODULE__{} = config, key, function) do
#     map_config = Map.from_struct(config)

#     case Map.get_and_update(map_config, key, function) do
#       {current_value, updated_map} ->
#         case struct(__MODULE__, updated_map) do
#           updated_config when is_struct(updated_config, __MODULE__) ->
#             {current_value, updated_config}

#           _ ->
#             # Fallback if struct creation fails
#             {current_value, config}
#         end
#     end
#   end

#   @impl Access
#   def pop(%__MODULE__{} = config, key) do
#     map_config = Map.from_struct(config)
#     {value, updated_map} = Map.pop(map_config, key)
#     updated_config = struct(__MODULE__, updated_map)
#     {value, updated_config}
#   end

#   # Paths that can be updated at runtime
#   @updatable_paths [
#     [:ai, :planning, :sampling_rate],
#     [:ai, :planning, :performance_target],
#     [:capture, :processing, :batch_size],
#     [:capture, :processing, :flush_interval],
#     [:interface, :query_timeout],
#     [:interface, :max_results],
#     [:dev, :debug_mode],
#     [:dev, :verbose_logging],
#     [:dev, :performance_monitoring]
#   ]

#   ## Public API

#   @spec initialize(keyword()) :: :ok | {:error, Error.t()}
#   def initialize(opts \\ []) do
#     context = ErrorContext.new(__MODULE__, :initialize, metadata: %{opts: opts})

#     ErrorContext.with_context(context, fn ->
#       case GenServer.start_link(__MODULE__, opts, name: __MODULE__) do
#         {:ok, _pid} ->
#           :ok

#         {:error, {:already_started, _pid}} ->
#           :ok

#         {:error, reason} ->
#           Error.error_result(
#             :initialization_failed,
#             "Failed to start Config GenServer",
#             context: %{reason: reason}
#           )
#       end
#     end)
#   end

#   @spec status() :: :ok
#   def status, do: :ok

#   @spec get() :: t() | {:error, Error.t()}
#   def get do
#     context = ErrorContext.new(__MODULE__, :get)

#     ErrorContext.with_context(context, fn ->
#       case GenServer.whereis(__MODULE__) do
#         nil ->
#           Error.error_result(
#             :service_unavailable,
#             "Configuration service not started"
#           )

#         _pid ->
#           GenServer.call(__MODULE__, :get_config)
#       end
#     end)
#   end

#   @spec get(config_path()) :: config_value() | nil | {:error, Error.t()}
#   def get(path) when is_list(path) do
#     context = ErrorContext.new(__MODULE__, :get, metadata: %{path: path})

#     ErrorContext.with_context(context, fn ->
#       case GenServer.whereis(__MODULE__) do
#         nil ->
#           Error.error_result(
#             :service_unavailable,
#             "Configuration service not started"
#           )

#         _pid ->
#           GenServer.call(__MODULE__, {:get_config_path, path})
#       end
#     end)
#   end

# @spec update(config_path(), config_value()) :: :ok | {:error, Error.t()}
# def update(path, value) when is_list(path) do
#   context = ErrorContext.new(__MODULE__, :update, metadata: %{path: path, value: value})

#   ErrorContext.with_context(context, fn ->
#     case GenServer.whereis(__MODULE__) do
#       nil ->
#         Error.error_result(
#           :service_unavailable,
#           "Configuration service not started"
#         )

#       _pid ->
#         GenServer.call(__MODULE__, {:update_config, path, value})
#     end
#   end)
# end

# @spec validate(t()) :: :ok | {:error, Error.t()}
# def validate(%__MODULE__{} = config) do
#   context = ErrorContext.new(__MODULE__, :validate)

#   ErrorContext.with_context(context, fn ->
#     with :ok <- validate_ai_config(config.ai),
#          :ok <- validate_capture_config(config.capture),
#          :ok <- validate_storage_config(config.storage),
#          :ok <- validate_interface_config(config.interface),
#          :ok <- validate_dev_config(config.dev) do
#       :ok  # Return :ok instead of {:ok, config}
#     end
#   end)
# end

# ## GenServer Implementation

#   @spec start_link(keyword()) :: GenServer.on_start()
#   def start_link(init_arg) do
#     GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
#   end

# @impl GenServer
# def init(opts) do
#   context = ErrorContext.new(__MODULE__, :init, metadata: %{opts: opts})

#   case ErrorContext.with_context(context, fn -> build_config(opts) end) do
#     {:ok, config} ->
#       case validate(config) do
#         :ok ->  # Now expecting :ok instead of {:ok, validated_config}
#           Logger.info("ElixirScope.Foundation.Config initialized successfully")
#           {:ok, config}  # Return the original config

#         {:error, error} ->
#           Logger.error("Config validation failed: #{Error.to_string(error)}")
#           {:stop, {:validation_failed, error}}
#       end

#     {:error, error} ->
#       Logger.error("Config build failed: #{Error.to_string(error)}")
#       {:stop, {:build_failed, error}}
#   end
# end


#   @impl GenServer
#   def handle_call(:get_config, _from, config) do
#     {:reply, config, config}
#   end

#   # @impl GenServer
#   # def handle_call({:get_config_path, path}, _from, config) do
#   #   value = get_in(config, path)
#   #   {:reply, value, config}
#   # end
#   # @impl GenServer
#   # def handle_call({:get_config_path, []}, _from, config) do
#   #   {:reply, {:error, :invalid_path}, config}
#   # end
#   # def handle_call({:get_config_path, path}, _from, config) when is_list(path) do
#   #   value = get_in(config, path)
#   #   {:reply, value, config}
#   # end
#   @impl GenServer
#   def handle_call({:get_config_path, []}, _from, config) do
#     # Don't call get_in with empty path - return the whole config
#     {:reply, config, config}
#   end

#   def handle_call({:get_config_path, path}, _from, config) when is_list(path) and path != [] do
#     value = get_in(config, path)
#     {:reply, value, config}
#   end


# @impl GenServer
# def handle_call({:update_config, path, value}, _from, config) do
#   context = ErrorContext.new(__MODULE__, :handle_update, metadata: %{path: path, value: value})

#   result =
#     ErrorContext.with_context(context, fn ->
#       cond do
#         path not in @updatable_paths ->
#           # Return proper Error struct instead of atom
#           Error.error_result(:config_update_forbidden,
#             "Configuration path #{inspect(path)} cannot be updated at runtime",
#             context: %{path: path, allowed_paths: @updatable_paths})

#         true ->
#           new_config = put_in(config, path, value)

#           case validate(new_config) do
#             :ok ->
#               Logger.debug("Config updated: #{inspect(path)} = #{inspect(value)}")
#               {:ok, new_config}

#             {:error, _} = error ->
#               error
#           end
#       end
#     end)

#   case result do
#     {:ok, new_config} -> {:reply, :ok, new_config}
#     {:error, error} -> {:reply, {:error, error}, config}
#   end
# end
#   ## Validation Functions

#   @spec validate_ai_config(map()) :: :ok | {:error, Error.t()}
#   defp validate_ai_config(%{provider: provider} = config) do
#     context = ErrorContext.new(__MODULE__, :validate_ai_config, metadata: %{provider: provider})

#     ErrorContext.with_context(context, fn ->
#       with :ok <- validate_provider(provider),
#            :ok <- validate_ai_analysis(config.analysis),
#            :ok <- validate_ai_planning(config.planning) do
#         :ok
#       end
#     end)
#   end

#   @spec validate_provider(atom()) :: :ok | {:error, Error.t()}
#   defp validate_provider(provider) do
#     valid_providers = [:mock, :openai, :anthropic, :gemini]

#     if provider in valid_providers do
#       :ok
#     else
#       Error.error_result(
#         :invalid_config_value,
#         "Invalid AI provider",
#         context: %{
#           provider: provider,
#           valid_providers: valid_providers
#         }
#       )
#     end
#   end

#   @spec validate_ai_analysis(map()) :: :ok | {:error, Error.t()}
#   defp validate_ai_analysis(%{max_file_size: size, timeout: timeout, cache_ttl: ttl})
#        when is_integer(size) and size > 0 and
#               is_integer(timeout) and timeout > 0 and
#               is_integer(ttl) and ttl > 0 do
#     :ok
#   end

#   defp validate_ai_analysis(_) do
#     Error.error_result(:validation_failed, "Invalid AI analysis configuration")
#   end

#   @spec validate_ai_planning(map()) :: :ok | {:error, Error.t()}
#   defp validate_ai_planning(%{
#          performance_target: target,
#          sampling_rate: rate,
#          default_strategy: strategy
#        }) do
#     valid_strategies = [:fast, :balanced, :thorough]

#     cond do
#       not is_number(target) or target < 0 ->
#         Error.error_result(
#           :constraint_violation,
#           "Performance target must be a non-negative number"
#         )

#       not is_number(rate) or rate < 0 or rate > 1 ->
#         Error.error_result(:range_error, "Sampling rate must be between 0 and 1")

#       strategy not in valid_strategies ->
#         Error.error_result(:invalid_config_value, "Invalid planning strategy")

#       true ->
#         :ok
#     end
#   end

#   defp validate_ai_planning(_) do
#     Error.error_result(:validation_failed, "Invalid AI planning configuration")
#   end

#   @spec validate_capture_config(map()) :: :ok | {:error, Error.t()}
#   defp validate_capture_config(%{ring_buffer: rb, processing: proc, vm_tracing: vt}) do
#     with :ok <- validate_ring_buffer(rb),
#          :ok <- validate_processing(proc),
#          :ok <- validate_vm_tracing(vt) do
#       :ok
#     end
#   end

#   @spec validate_ring_buffer(map()) :: :ok | {:error, Error.t()}
#   defp validate_ring_buffer(%{size: size, max_events: max, overflow_strategy: strategy})
#        when is_integer(size) and size > 0 and
#               is_integer(max) and max > 0 do
#     valid_strategies = [:drop_oldest, :drop_newest, :block]

#     if strategy in valid_strategies do
#       :ok
#     else
#       Error.error_result(:invalid_config_value, "Invalid overflow strategy")
#     end
#   end

#   defp validate_ring_buffer(_) do
#     Error.error_result(:validation_failed, "Invalid ring buffer configuration")
#   end

#   @spec validate_processing(map()) :: :ok | {:error, Error.t()}
#   defp validate_processing(%{batch_size: batch, flush_interval: flush, max_queue_size: queue})
#        when is_integer(batch) and batch > 0 and
#               is_integer(flush) and flush > 0 and
#               is_integer(queue) and queue > 0 do
#     :ok
#   end

#   defp validate_processing(_) do
#     Error.error_result(:validation_failed, "Invalid processing configuration")
#   end

#   @spec validate_vm_tracing(map()) :: :ok | {:error, Error.t()}
#   defp validate_vm_tracing(%{
#          enable_spawn_trace: spawn,
#          enable_exit_trace: exit,
#          enable_message_trace: msg,
#          trace_children: children
#        })
#        when is_boolean(spawn) and is_boolean(exit) and
#               is_boolean(msg) and is_boolean(children) do
#     :ok
#   end

#   defp validate_vm_tracing(_) do
#     Error.error_result(:validation_failed, "Invalid VM tracing configuration")
#   end

#   @spec validate_storage_config(map()) :: :ok | {:error, Error.t()}
#   defp validate_storage_config(%{hot: hot, warm: warm, cold: cold}) do
#     with :ok <- validate_hot_storage(hot),
#          :ok <- validate_warm_storage(warm),
#          :ok <- validate_cold_storage(cold) do
#       :ok
#     end
#   end

#   @spec validate_hot_storage(map()) :: :ok | {:error, Error.t()}
#   defp validate_hot_storage(%{max_events: max, max_age_seconds: age, prune_interval: interval})
#        when is_integer(max) and max > 0 and
#               is_integer(age) and age > 0 and
#               is_integer(interval) and interval > 0 do
#     :ok
#   end

#   defp validate_hot_storage(_) do
#     Error.error_result(:validation_failed, "Invalid hot storage configuration")
#   end

#   @spec validate_warm_storage(map()) :: :ok | {:error, Error.t()}
#   defp validate_warm_storage(%{enable: false}), do: :ok

#   defp validate_warm_storage(%{enable: true, path: path, max_size_mb: size, compression: comp})
#        when is_binary(path) and is_integer(size) and size > 0 do
#     valid_compression = [:none, :gzip, :zstd]

#     if comp in valid_compression do
#       :ok
#     else
#       Error.error_result(:invalid_config_value, "Invalid compression type")
#     end
#   end

#   defp validate_warm_storage(_) do
#     Error.error_result(:validation_failed, "Invalid warm storage configuration")
#   end

#   @spec validate_cold_storage(map()) :: :ok | {:error, Error.t()}
#   defp validate_cold_storage(%{enable: false}), do: :ok

#   defp validate_cold_storage(_) do
#     Error.error_result(:validation_failed, "Invalid cold storage configuration")
#   end

#   @spec validate_interface_config(map()) :: :ok | {:error, Error.t()}
#   defp validate_interface_config(%{
#          query_timeout: timeout,
#          max_results: max,
#          enable_streaming: stream
#        })
#        when is_integer(timeout) and timeout > 0 and
#               is_integer(max) and max > 0 and
#               is_boolean(stream) do
#     :ok
#   end

#   defp validate_interface_config(_) do
#     Error.error_result(:validation_failed, "Invalid interface configuration")
#   end

#   @spec validate_dev_config(map()) :: :ok | {:error, Error.t()}
#   defp validate_dev_config(%{
#          debug_mode: debug,
#          verbose_logging: verbose,
#          performance_monitoring: perf
#        })
#        when is_boolean(debug) and is_boolean(verbose) and is_boolean(perf) do
#     :ok
#   end

#   defp validate_dev_config(_) do
#     Error.error_result(:validation_failed, "Invalid dev configuration")
#   end

#   ## Private Helper Functions

#   @spec build_config(keyword()) :: {:ok, t()} | {:error, Error.t()}
#   defp build_config(opts) do
#     context = ErrorContext.new(__MODULE__, :build_config, metadata: %{opts: opts})

#     ErrorContext.with_context(context, fn ->
#       base_config = %__MODULE__{}
#       env_config = Application.get_all_env(:elixir_scope)

#       merged_config =
#         base_config
#         |> merge_env_config(env_config)
#         |> merge_opts_config(opts)

#       {:ok, merged_config}
#     end)
#   end

#   @spec merge_env_config(t(), keyword()) :: t()
#   defp merge_env_config(config, env_config) do
#     Enum.reduce(env_config, config, fn {key, value}, acc ->
#       if Map.has_key?(acc, key) do
#         current_value = Map.get(acc, key)
#         merged_value = deep_merge(current_value, value)
#         Map.put(acc, key, merged_value)
#       else
#         acc
#       end
#     end)
#   end

#   @spec merge_opts_config(t(), keyword()) :: t()
#   defp merge_opts_config(config, opts) do
#     Enum.reduce(opts, config, fn {key, value}, acc ->
#       Map.put(acc, key, value)
#     end)
#   end

#   @spec deep_merge(term(), term()) :: term()
#   defp deep_merge(left, right) when is_map(left) and is_list(right) do
#     # Convert keyword list to map, then merge recursively
#     right_map = Enum.into(right, %{})

#     Map.merge(left, right_map, fn _key, left_val, right_val ->
#       deep_merge(left_val, right_val)
#     end)
#   end

#   defp deep_merge(left, right) when is_map(left) and is_map(right) do
#     Map.merge(left, right, fn _key, left_val, right_val ->
#       deep_merge(left_val, right_val)
#     end)
#   end

#   defp deep_merge(_left, right), do: right
# end
