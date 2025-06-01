defmodule ElixirScope.Foundation.Services.ConfigServer do
  @moduledoc """
  GenServer implementation for configuration management.

  Handles configuration persistence, updates, and notifications.
  Delegates business logic to ConfigLogic module.
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.Types.{Config, Error}
  alias ElixirScope.Foundation.Logic.ConfigLogic
  alias ElixirScope.Foundation.Validation.ConfigValidator
  alias ElixirScope.Foundation.Contracts.Configurable
  alias ElixirScope.Foundation.Services.{EventStore, TelemetryService}

  @behaviour Configurable

  @type server_state :: %{
          config: Config.t(),
          subscribers: [pid()],
          metrics: map()
        }

  ## Public API (Configurable Behaviour Implementation)

  @impl Configurable
  def get do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Configuration service not started")
      _pid -> GenServer.call(__MODULE__, :get_config)
    end
  end

  @impl Configurable
  def get(path) when is_list(path) do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Configuration service not started")
      _pid -> GenServer.call(__MODULE__, {:get_config_path, path})
    end
  end

  @impl Configurable
  def update(path, value) when is_list(path) do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Configuration service not started")
      _pid -> GenServer.call(__MODULE__, {:update_config, path, value})
    end
  end

  @impl Configurable
  def validate(config) do
    ConfigValidator.validate(config)
  end

  @impl Configurable
  def updatable_paths do
    ConfigLogic.updatable_paths()
  end

  @impl Configurable
  def reset do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Configuration service not started")
      _pid -> GenServer.call(__MODULE__, :reset_config)
    end
  end

  @impl Configurable
  def available? do
    GenServer.whereis(__MODULE__) != nil
  end

  ## Additional Functions

  @spec initialize() :: :ok | {:error, Error.t()}
  def initialize() do
    initialize([])
  end

  @spec initialize(keyword()) :: :ok | {:error, Error.t()}
  def initialize(opts) do
    case start_link(opts) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> 
        {:error, Error.new(
          error_type: :service_initialization_failed,
          message: "Failed to initialize configuration service",
          context: %{reason: reason},
          category: :config,
          subcategory: :startup,
          severity: :high
        )}
    end
  end

  @spec status() :: {:ok, map()} | {:error, Error.t()}
  def status() do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Configuration service not started")
      _pid -> GenServer.call(__MODULE__, :get_status)
    end
  end

  ## GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  def subscribe(pid \\ self()) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  def unsubscribe(pid \\ self()) do
    GenServer.call(__MODULE__, {:unsubscribe, pid})
  end

  ## GenServer Callbacks

  @impl GenServer
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
        Logger.error("Failed to initialize configuration: #{ElixirScope.Foundation.Error.to_string(error)}")
        {:stop, {:config_validation_failed, error}}
    end
  end

  @impl GenServer
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
            metrics: Map.merge(state.metrics, %{
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
        emit_config_telemetry(:config_reset, %{reset_from_updates_count: state.metrics.updates_count})
        
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
  def handle_call(:get_metrics, _from, %{metrics: metrics} = state) do
    current_metrics = Map.put(metrics, :current_time, System.monotonic_time(:millisecond))
    {:reply, {:ok, current_metrics}, state}
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

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      send(pid, {:config_notification, message})
    end)
  end

  defp emit_config_event(event_type, data) do
    # Only emit if EventStore is available to avoid blocking config operations
    if EventStore.available?() do
      try do
        case ElixirScope.Foundation.Events.new_event(event_type, data) do
          {:ok, event} ->
            case EventStore.store(event) do
              {:ok, _id} -> :ok
              {:error, error} ->
                Logger.warning("Failed to emit config event: #{ElixirScope.Foundation.Error.to_string(error)}")
            end
          {:error, error} ->
            Logger.warning("Failed to create config event: #{ElixirScope.Foundation.Error.to_string(error)}")
        end
      rescue
        error ->
          Logger.warning("Exception while emitting config event: #{inspect(error)}")
      end
    end
  end

  defp emit_config_telemetry(operation_type, metadata) do
    # Only emit if TelemetryService is available to avoid blocking config operations
    if TelemetryService.available?() do
      try do
        case operation_type do
          :config_updated ->
            TelemetryService.emit_counter([:foundation, :config_updates], metadata)
          :config_reset ->
            TelemetryService.emit_counter([:foundation, :config_resets], metadata)
          _ ->
            TelemetryService.emit_counter([:foundation, :config_operations], Map.put(metadata, :operation, operation_type))
        end
      rescue
        error ->
          Logger.warning("Exception while emitting config telemetry: #{inspect(error)}")
      end
    end
  end

  defp create_service_error(message) do
    error = Error.new(
      error_type: :service_unavailable,
      message: message,
      category: :system,
      subcategory: :initialization,
      severity: :high
    )

    {:error, error}
  end
end
