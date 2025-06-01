defmodule ElixirScope.Foundation.Services.TelemetryService do
  @moduledoc """
  GenServer implementation for telemetry collection and metrics.

  Provides structured telemetry with automatic metric collection,
  event emission, and performance monitoring.
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.Types.Error
  alias ElixirScope.Foundation.Contracts.Telemetry

  @behaviour Telemetry

  @type server_state :: %{
          metrics: %{atom() => map()},
          handlers: %{[atom()] => function()},
          config: map()
        }

  @default_config %{
    enable_vm_metrics: true,
    enable_process_metrics: true,
    # 5 minutes
    metric_retention_ms: 300_000,
    # 1 minute
    cleanup_interval: 60_000
  }

  ## Public API (Telemetry Behaviour Implementation)

  @impl Telemetry
  def execute(event_name, measurements, metadata) when is_list(event_name) do
    case GenServer.whereis(__MODULE__) do
      # Fail silently for telemetry
      nil -> :ok
      _pid -> GenServer.cast(__MODULE__, {:execute_event, event_name, measurements, metadata})
    end
  end

  @impl Telemetry
  def measure(event_name, metadata, fun) when is_list(event_name) and is_function(fun, 0) do
    start_time = System.monotonic_time()

    try do
      result = fun.()
      end_time = System.monotonic_time()
      duration = end_time - start_time

      measurements = %{duration: duration}
      execute(event_name ++ [:stop], measurements, metadata)

      result
    rescue
      error ->
        end_time = System.monotonic_time()
        duration = end_time - start_time

        measurements = %{duration: duration}
        error_metadata = Map.put(metadata, :error, error)
        execute(event_name ++ [:exception], measurements, error_metadata)

        reraise error, __STACKTRACE__
    end
  end

  @impl Telemetry
  def emit_counter(event_name, metadata) when is_list(event_name) do
    measurements = %{counter: 1}
    execute(event_name, measurements, metadata)
  end

  # Overloaded version for tests that pass a value
  def emit_counter(event_name, value, metadata) when is_list(event_name) and is_number(value) do
    measurements = %{counter: value}
    execute(event_name, measurements, metadata)
  end

  @impl Telemetry
  def emit_gauge(event_name, value, metadata) when is_list(event_name) and is_number(value) do
    measurements = %{gauge: value}
    execute(event_name, measurements, metadata)
  end

  @impl Telemetry
  def get_metrics do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Telemetry service not started")
      _pid -> GenServer.call(__MODULE__, :get_metrics)
    end
  end

  @impl Telemetry
  def attach_handlers(event_names) when is_list(event_names) do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Telemetry service not started")
      _pid -> GenServer.call(__MODULE__, {:attach_handlers, event_names})
    end
  end

  @impl Telemetry
  def detach_handlers(event_names) when is_list(event_names) do
    case GenServer.whereis(__MODULE__) do
      # Fail silently
      nil -> :ok
      _pid -> GenServer.cast(__MODULE__, {:detach_handlers, event_names})
    end
  end

  @impl Telemetry
  def available? do
    GenServer.whereis(__MODULE__) != nil
  end

  @impl Telemetry
  def initialize do
    initialize([])
  end

  @impl Telemetry
  def status do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Telemetry service not started")
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

  @doc """
  Reset all metrics (for testing purposes).
  """
  @spec reset_metrics() :: :ok | {:error, Error.t()}
  def reset_metrics do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Telemetry service not started")
      _pid -> GenServer.call(__MODULE__, :clear_metrics)
    end
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(opts) do
    config = Map.merge(@default_config, Map.new(opts))

    state = %{
      metrics: %{},
      handlers: %{},
      config: config
    }

    # Schedule periodic cleanup
    schedule_cleanup(config.cleanup_interval)

    # Attach VM metrics if enabled
    if config.enable_vm_metrics do
      attach_vm_metrics()
    end

    Logger.info("Telemetry service initialized successfully")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:execute_event, event_name, measurements, metadata}, state) do
    new_state = record_metric(event_name, measurements, metadata, state)

    # Execute any attached handlers
    execute_handlers(event_name, measurements, metadata, state.handlers)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:detach_handlers, event_names}, %{handlers: handlers} = state) do
    new_handlers = Map.drop(handlers, event_names)
    new_state = %{state | handlers: new_handlers}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, %{metrics: metrics} = state) do
    # Transform flat event names into nested structure for API compatibility
    nested_metrics = transform_to_nested_structure(metrics)

    # Add current timestamp to metrics
    timestamped_metrics = Map.put(nested_metrics, :retrieved_at, System.monotonic_time())

    {:reply, {:ok, timestamped_metrics}, state}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      status: :running,
      metrics_count: map_size(state.metrics),
      handlers_count: map_size(state.handlers),
      config: state.config
    }

    {:reply, {:ok, status}, state}
  end

  @impl GenServer
  def handle_call(:clear_metrics, _from, state) do
    new_state = %{state | metrics: %{}}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:attach_handlers, event_names}, _from, %{handlers: handlers} = state) do
    new_handlers =
      Enum.reduce(event_names, handlers, fn event_name, acc ->
        handler_fn = create_default_handler(event_name)
        Map.put(acc, event_name, handler_fn)
      end)

    new_state = %{state | handlers: new_handlers}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:cleanup_old_metrics, %{config: config} = state) do
    new_state = cleanup_old_metrics(state, config.metric_retention_ms)
    schedule_cleanup(config.cleanup_interval)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("Unexpected message in TelemetryService: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  defp record_metric(event_name, measurements, metadata, %{metrics: metrics} = state) do
    timestamp = System.monotonic_time()

    metric_entry = %{
      timestamp: timestamp,
      measurements: measurements,
      metadata: metadata,
      count: 1
    }

    new_metrics =
      Map.update(metrics, event_name, metric_entry, fn existing ->
        %{
          existing
          | timestamp: timestamp,
            measurements: merge_measurements(existing.measurements, measurements),
            count: existing.count + 1
        }
      end)

    %{state | metrics: new_metrics}
  end

  defp merge_measurements(existing, new) do
    Map.merge(existing, new, fn
      :gauge, _old_val, new_val ->
        # For gauges, always use the latest value (no averaging)
        new_val

      :counter, old_val, new_val when is_number(old_val) and is_number(new_val) ->
        # For counters, accumulate the values
        old_val + new_val

      _key, old_val, new_val when is_number(old_val) and is_number(new_val) ->
        # For other numeric values, keep running average (backwards compatibility)
        (old_val + new_val) / 2

      _key, _old_val, new_val ->
        # For non-numeric, keep the new value
        new_val
    end)
  end

  defp execute_handlers(event_name, measurements, metadata, handlers) do
    case Map.get(handlers, event_name) do
      nil ->
        :ok

      handler_fn when is_function(handler_fn) ->
        try do
          handler_fn.(event_name, measurements, metadata)
        rescue
          error ->
            Logger.warning("Telemetry handler failed: #{inspect(error)}")
        end
    end
  end

  defp create_default_handler(event_name) do
    fn ^event_name, measurements, metadata ->
      Logger.debug("Telemetry event: #{inspect(event_name)}",
        measurements: measurements,
        metadata: metadata
      )
    end
  end

  defp cleanup_old_metrics(%{metrics: metrics} = state, retention_ms) do
    current_time = System.monotonic_time()
    cutoff_time = current_time - retention_ms

    new_metrics =
      Enum.filter(metrics, fn {_event_name, metric_data} ->
        metric_data.timestamp > cutoff_time
      end)
      |> Map.new()

    %{state | metrics: new_metrics}
  end

  defp attach_vm_metrics do
    # Attach standard VM telemetry events
    vm_events = [
      [:vm, :memory],
      [:vm, :total_run_queue_lengths],
      [:vm, :system_counts]
    ]

    Enum.each(vm_events, fn event_name ->
      emit_gauge(event_name, 1, %{source: :vm})
    end)
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup_old_metrics, interval)
  end

  defp create_service_error(message) do
    error =
      Error.new(
        error_type: :service_unavailable,
        message: message,
        category: :system,
        subcategory: :initialization,
        severity: :medium
      )

    {:error, error}
  end

  ## Additional Functions

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
           error_type: :service_initialization_failed,
           message: "Failed to initialize telemetry service",
           context: %{reason: reason},
           category: :system,
           subcategory: :startup,
           severity: :high
         )}
    end
  end

  defp transform_to_nested_structure(metrics) do
    Enum.reduce(metrics, %{}, fn {event_name, metric_data}, acc ->
      case event_name do
        [:foundation, :event_store, :events_stored] ->
          # Transform to the expected nested structure for events_stored
          # Safely build the nested path
          foundation_map = Map.get(acc, :foundation, %{})
          updated_foundation = Map.put(foundation_map, :events_stored, metric_data.count || 0)
          Map.put(acc, :foundation, updated_foundation)

        [:foundation, :config_updates] ->
          # Transform config_updates metric
          foundation_map = Map.get(acc, :foundation, %{})
          updated_foundation = Map.put(foundation_map, :config_updates, metric_data.count || 0)
          Map.put(acc, :foundation, updated_foundation)

        [:foundation, :config_resets] ->
          # Transform config_resets metric
          foundation_map = Map.get(acc, :foundation, %{})
          updated_foundation = Map.put(foundation_map, :config_resets, metric_data.count || 0)
          Map.put(acc, :foundation, updated_foundation)

        [:foundation, :config_operations] ->
          # Transform general config operations metric
          foundation_map = Map.get(acc, :foundation, %{})
          updated_foundation = Map.put(foundation_map, :config_operations, metric_data.count || 0)
          Map.put(acc, :foundation, updated_foundation)

        [:foundation | rest] ->
          # Handle other foundation metrics
          nested_path = [:foundation] ++ rest
          put_nested_value(acc, nested_path, metric_data)

        [first | rest] when rest != [] ->
          # Handle other nested metrics
          nested_path = [first] ++ rest
          put_nested_value(acc, nested_path, metric_data)

        [single] ->
          # Single-level metrics
          Map.put(acc, single, metric_data)

        _ ->
          acc
      end
    end)
  end

  defp put_nested_value(map, [key], value) do
    Map.put(map, key, value)
  end

  defp put_nested_value(map, [key | rest], value) do
    Map.update(map, key, put_nested_value(%{}, rest, value), fn existing ->
      put_nested_value(existing, rest, value)
    end)
  end
end
