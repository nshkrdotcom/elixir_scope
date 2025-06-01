defmodule ElixirScope.Foundation.Services.ConfigServer do
  @moduledoc """
  GenServer implementation for configuration management.

  Handles configuration persistence, updates, and notifications.
  Delegates business logic to ConfigLogic module.

  This server provides a centralized point for configuration access and
  modification, with support for subscriptions to configuration changes.

  See `@type server_state` for the internal state structure.

  ## Examples

      # Get configuration
      {:ok, config} = ElixirScope.Foundation.Services.ConfigServer.get()

      # Update a configuration value
      :ok = ElixirScope.Foundation.Services.ConfigServer.update([:ai, :provider], :openai)

      # Subscribe to configuration changes
      :ok = ElixirScope.Foundation.Services.ConfigServer.subscribe()
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.Types.{Config, Error}
  alias ElixirScope.Foundation.Logic.ConfigLogic
  alias ElixirScope.Foundation.Validation.ConfigValidator
  alias ElixirScope.Foundation.Contracts.Configurable
  alias ElixirScope.Foundation.Services.{EventStore, TelemetryService}

  @behaviour Configurable

  @typedoc "Internal state of the configuration server"
  @type server_state :: %{
          config: Config.t(),
          subscribers: [pid()],
          metrics: metrics()
        }

  @typedoc "Metrics tracking for the configuration server"
  @type metrics :: %{
          start_time: integer(),
          updates_count: non_neg_integer(),
          last_update: integer() | nil
        }

  ## Public API (Configurable Behaviour Implementation)

  @doc """
  Get the complete configuration.

  Returns the current configuration or an error if the service is unavailable.
  """
  @impl Configurable
  @spec get() :: {:ok, Config.t()} | {:error, Error.t()}
  def get do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Configuration service not started")
      _pid -> GenServer.call(__MODULE__, :get_config)
    end
  end

  @doc """
  Get a configuration value by path.

  ## Parameters
  - `path`: List of atoms representing the path to the configuration value

  ## Examples

      {:ok, provider} = get([:ai, :provider])
      {:ok, timeout} = get([:capture, :processing, :timeout])
  """
  @impl Configurable
  @spec get([atom()]) :: {:ok, term()} | {:error, Error.t()}
  def get(path) when is_list(path) do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Configuration service not started")
      _pid -> GenServer.call(__MODULE__, {:get_config_path, path})
    end
  end

  @doc """
  Update a configuration value at the given path.

  ## Parameters
  - `path`: List of atoms representing the path to the configuration value
  - `value`: New value to set

  ## Examples

      :ok = update([:ai, :provider], :openai)
      :ok = update([:capture, :ring_buffer, :size], 2048)
  """
  @impl Configurable
  @spec update([atom()], term()) :: :ok | {:error, Error.t()}
  def update(path, value) when is_list(path) do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Configuration service not started")
      _pid -> GenServer.call(__MODULE__, {:update_config, path, value})
    end
  end

  @doc """
  Validate a configuration structure.

  Delegates to the ConfigValidator module for validation logic.
  """
  @impl Configurable
  @spec validate(Config.t()) :: :ok | {:error, Error.t()}
  def validate(config) do
    ConfigValidator.validate(config)
  end

  @doc """
  Get the list of paths that can be updated at runtime.

  Delegates to the ConfigLogic module for the list of updatable paths.
  """
  @impl Configurable
  @spec updatable_paths() :: [[atom(), ...], ...]
  def updatable_paths do
    ConfigLogic.updatable_paths()
  end

  @doc """
  Reset configuration to defaults.

  Resets the configuration to its default values and notifies all subscribers.
  """
  @impl Configurable
  @spec reset() :: :ok | {:error, Error.t()}
  def reset do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Configuration service not started")
      _pid -> GenServer.call(__MODULE__, :reset_config)
    end
  end

  @doc """
  Check if the configuration service is available.

  Returns true if the GenServer is running and registered.
  """
  @impl Configurable
  @spec available?() :: boolean()
  def available? do
    GenServer.whereis(__MODULE__) != nil
  end

  ## Additional Functions

  @doc """
  Initialize the configuration service with default options.

  ## Examples

      :ok = ElixirScope.Foundation.Services.ConfigServer.initialize()
  """
  @spec initialize() :: :ok | {:error, Error.t()}
  def initialize() do
    initialize([])
  end

  @doc """
  Initialize the configuration service with custom options.

  ## Parameters
  - `opts`: Keyword list of initialization options

  ## Examples

      :ok = ElixirScope.Foundation.Services.ConfigServer.initialize(debug: true)
  """
  @spec initialize(keyword()) :: :ok | {:error, Error.t()}
  def initialize(opts) do
    case start_link(opts) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        {:error,
         Error.new(
           code: 5001,
           error_type: :service_initialization_failed,
           message: "Failed to initialize configuration service",
           severity: :high,
           context: %{reason: reason},
           category: :config,
           subcategory: :startup
         )}
    end
  end

  @doc """
  Get the current status of the configuration service.

  Returns service health information including uptime and statistics.
  """
  @spec status() :: {:ok, map()} | {:error, Error.t()}
  def status() do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Configuration service not started")
      _pid -> GenServer.call(__MODULE__, :get_status)
    end
  end

  ## GenServer API

  @doc """
  Start the configuration server.

  ## Parameters
  - `opts`: Keyword list of options passed to GenServer initialization
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stop the configuration server.
  """
  @spec stop() :: :ok
  def stop do
    GenServer.stop(__MODULE__)
  end

  @doc """
  Subscribe to configuration change notifications.

  ## Parameters
  - `pid`: Process to subscribe (defaults to calling process)

  ## Examples

      :ok = ElixirScope.Foundation.Services.ConfigServer.subscribe()
      :ok = ElixirScope.Foundation.Services.ConfigServer.subscribe(some_pid)
  """
  @spec subscribe(pid()) :: :ok | {:error, Error.t()}
  def subscribe(pid \\ self()) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  @doc """
  Unsubscribe from configuration change notifications.

  ## Parameters
  - `pid`: Process to unsubscribe (defaults to calling process)
  """
  @spec unsubscribe(pid()) :: :ok | {:error, Error.t()}
  def unsubscribe(pid \\ self()) do
    GenServer.call(__MODULE__, {:unsubscribe, pid})
  end

  ## GenServer Callbacks

  @doc """
  Initialize the GenServer state.

  Builds the initial configuration and sets up metrics tracking.
  """
  @impl GenServer
  @spec init(keyword()) :: {:ok, server_state()} | {:stop, term()}
  def init(opts) do
    case ConfigLogic.build_config(opts) do
      {:ok, config} ->
        Logger.info("Configuration server initialized successfully")

        state = %{
          config: config,
          subscribers: [],
          metrics: %{
            start_time: System.monotonic_time(:millisecond),
            updates_count: 0,
            last_update: nil
          }
        }

        {:ok, state}

      {:error, error} ->
        Logger.error("Failed to initialize configuration: #{inspect(error)}")
        {:stop, {:config_validation_failed, error}}
    end
  end

  @impl GenServer
  @spec handle_call(term(), GenServer.from(), server_state()) ::
          {:reply, term(), server_state()} | {:noreply, server_state()}
  def handle_call(:get_config, _from, %{config: config} = state) do
    {:reply, {:ok, config}, state}
  end

  @impl GenServer
  def handle_call({:get_config_path, path}, _from, %{config: config} = state) do
    result = ConfigLogic.get_config_value(config, path)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:update_config, path, value}, _from, %{config: config} = state) do
    case ConfigLogic.update_config(config, path, value) do
      {:ok, new_config} ->
        Logger.debug("Configuration updated: #{inspect(path)} = #{inspect(value)}")

        new_state = %{
          state
          | config: new_config,
            metrics:
              Map.merge(state.metrics, %{
                updates_count: state.metrics.updates_count + 1,
                last_update: System.monotonic_time(:millisecond)
              })
        }

        # Notify subscribers
        notify_subscribers(state.subscribers, {:config_updated, path, value})

        # Emit event to EventStore for audit and correlation
        emit_config_event(:config_updated, %{
          path: path,
          new_value: value,
          previous_value: ConfigLogic.get_config_value(config, path),
          timestamp: System.monotonic_time(:millisecond)
        })

        # Emit telemetry for config updates
        emit_config_telemetry(:config_updated, %{path: path})

        {:reply, :ok, new_state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:reset_config, _from, state) do
    new_config = ConfigLogic.reset_config()

    case ConfigValidator.validate(new_config) do
      :ok ->
        new_state = %{state | config: new_config}
        notify_subscribers(state.subscribers, {:config_reset, new_config})

        # Emit event to EventStore for audit and correlation
        emit_config_event(:config_reset, %{
          timestamp: System.monotonic_time(:millisecond),
          reset_from_updates_count: state.metrics.updates_count
        })

        # Emit telemetry for config resets
        emit_config_telemetry(:config_reset, %{
          reset_from_updates_count: state.metrics.updates_count
        })

        {:reply, :ok, new_state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:subscribe, pid}, _from, %{subscribers: subscribers} = state) do
    if pid in subscribers do
      {:reply, :ok, state}
    else
      Process.monitor(pid)
      new_state = %{state | subscribers: [pid | subscribers]}
      {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:unsubscribe, pid}, _from, %{subscribers: subscribers} = state) do
    new_subscribers = List.delete(subscribers, pid)
    new_state = %{state | subscribers: new_subscribers}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_status, _from, %{metrics: metrics} = state) do
    current_time = System.monotonic_time(:millisecond)

    status = %{
      status: :running,
      uptime_ms: current_time - metrics.start_time,
      updates_count: metrics.updates_count,
      last_update: metrics.last_update,
      subscribers_count: length(state.subscribers)
    }

    {:reply, {:ok, status}, state}
  end

  @impl GenServer
  @spec handle_info(term(), server_state()) :: {:noreply, server_state()}
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{subscribers: subscribers} = state) do
    # Remove dead subscriber
    new_subscribers = List.delete(subscribers, pid)
    new_state = %{state | subscribers: new_subscribers}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.warning("Unexpected message in ConfigServer: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  @spec notify_subscribers([pid()], term()) :: :ok
  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      send(pid, {:config_notification, message})
    end)
  end

  @spec emit_config_event(atom(), map()) :: :ok
  defp emit_config_event(event_type, data) do
    # Only emit if EventStore is available to avoid blocking config operations
    if EventStore.available?() do
      try do
        case ElixirScope.Foundation.Events.new_event(event_type, data) do
          {:ok, event} ->
            case EventStore.store(event) do
              {:ok, _id} ->
                :ok

              {:error, error} ->
                Logger.warning("Failed to emit config event: #{inspect(error)}")
            end

          {:error, error} ->
            Logger.warning("Failed to create config event: #{inspect(error)}")
        end
      rescue
        error ->
          Logger.warning("Exception while emitting config event: #{inspect(error)}")
      end
    end
  end

  @spec emit_config_telemetry(atom(), map()) :: :ok
  defp emit_config_telemetry(operation_type, metadata) do
    # Only emit if TelemetryService is available to avoid blocking config operations
    if TelemetryService.available?() do
      try do
        case operation_type do
          :config_updated ->
            TelemetryService.emit_counter([:foundation, :config_updates], metadata)

          :config_reset ->
            TelemetryService.emit_counter([:foundation, :config_resets], metadata)
        end
      rescue
        error ->
          Logger.warning("Exception while emitting config telemetry: #{inspect(error)}")
      end
    end
  end

  @spec create_service_error(String.t()) :: {:error, Error.t()}
  defp create_service_error(message) do
    error =
      Error.new(
        code: 5000,
        error_type: :service_unavailable,
        message: message,
        severity: :high,
        category: :system,
        subcategory: :initialization
      )

    {:error, error}
  end
end
