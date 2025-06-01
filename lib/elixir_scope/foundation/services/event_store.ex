defmodule ElixirScope.Foundation.Services.EventStore do
  @moduledoc """
  Event storage service implementation using GenServer.

  Provides in-memory event storage with optional persistence and pruning.
  Implements the EventStore behavior contract.
  """

  use GenServer
  require Logger

  @behaviour ElixirScope.Foundation.Contracts.EventStore

  alias ElixirScope.Foundation.Types.{Event, Error}
  alias ElixirScope.Foundation.Validation.EventValidator
  alias ElixirScope.Foundation.Contracts.EventStore, as: EventStoreContract
  alias ElixirScope.Foundation.Services.TelemetryService

  @type server_state :: %{
          events: %{Event.event_id() => Event.t()},
          correlation_index: %{Event.correlation_id() => [Event.event_id()]},
          event_sequence: [Event.event_id()],
          config: map(),
          metrics: map()
        }

  # Default configuration
  @default_config %{
    max_events: 10_000,
    max_age_seconds: 3600,
    prune_interval: 300_000,
    enable_correlation_index: true,
    enable_persistence: false,
    persistence_file: nil
  }

  ## Public API

  @impl EventStoreContract
  def store(%Event{} = event) do
    result = GenServer.call(__MODULE__, {:store_event, event})

    # Report telemetry on successful store
    case result do
      {:ok, event_id} ->
        emit_telemetry_counter([:foundation, :event_store, :events_stored], %{
          event_type: event.event_type,
          has_correlation: !is_nil(event.correlation_id)
        })

        {:ok, event_id}

      {:error, _} = error ->
        emit_telemetry_counter([:foundation, :event_store, :store_errors], %{
          event_type: event.event_type
        })

        error
    end
  end

  @impl EventStoreContract
  def store_batch(events) when is_list(events) do
    start_time = System.monotonic_time()
    result = GenServer.call(__MODULE__, {:store_batch, events})
    end_time = System.monotonic_time()

    duration = end_time - start_time

    case result do
      {:ok, event_ids} ->
        emit_telemetry_gauge([:foundation, :event_store, :batch_duration], duration, %{
          batch_size: length(events),
          result: :success
        })

        emit_telemetry_counter([:foundation, :event_store, :batch_operations], %{
          batch_size: length(events),
          result: :success
        })

        {:ok, event_ids}

      {:error, _} = error ->
        emit_telemetry_gauge([:foundation, :event_store, :batch_duration], duration, %{
          batch_size: length(events),
          result: :error
        })

        emit_telemetry_counter([:foundation, :event_store, :batch_errors], %{
          batch_size: length(events)
        })

        error
    end
  end

  @impl EventStoreContract
  def get(event_id) do
    start_time = System.monotonic_time()
    result = GenServer.call(__MODULE__, {:get_event, event_id})
    end_time = System.monotonic_time()

    duration = end_time - start_time

    case result do
      {:ok, _event} ->
        emit_telemetry_gauge([:foundation, :event_store, :get_duration], duration, %{
          result: :found
        })

        emit_telemetry_counter([:foundation, :event_store, :gets], %{result: :found})

      {:error, _} ->
        emit_telemetry_gauge([:foundation, :event_store, :get_duration], duration, %{
          result: :not_found
        })

        emit_telemetry_counter([:foundation, :event_store, :gets], %{result: :not_found})
    end

    result
  end

  @impl EventStoreContract
  def query(query_map) when is_map(query_map) do
    start_time = System.monotonic_time()
    result = GenServer.call(__MODULE__, {:query_events, query_map})
    end_time = System.monotonic_time()

    duration = end_time - start_time

    case result do
      {:ok, events} ->
        emit_telemetry_gauge([:foundation, :event_store, :query_duration], duration, %{
          result_count: length(events),
          query_type: extract_query_type(query_map)
        })

        emit_telemetry_counter([:foundation, :event_store, :queries], %{
          result_count: length(events),
          query_type: extract_query_type(query_map)
        })

      {:error, _} ->
        emit_telemetry_gauge([:foundation, :event_store, :query_duration], duration, %{
          result: :error,
          query_type: extract_query_type(query_map)
        })

        emit_telemetry_counter([:foundation, :event_store, :query_errors], %{
          query_type: extract_query_type(query_map)
        })
    end

    result
  end

  @impl EventStoreContract
  def get_by_correlation(correlation_id) do
    start_time = System.monotonic_time()
    result = GenServer.call(__MODULE__, {:get_by_correlation, correlation_id})
    end_time = System.monotonic_time()

    duration = end_time - start_time

    case result do
      {:ok, events} ->
        emit_telemetry_gauge([:foundation, :event_store, :correlation_query_duration], duration, %{
          result_count: length(events)
        })

        emit_telemetry_counter([:foundation, :event_store, :correlation_queries], %{
          result_count: length(events)
        })

      {:error, _} ->
        emit_telemetry_gauge([:foundation, :event_store, :correlation_query_duration], duration, %{
          result: :error
        })

        emit_telemetry_counter([:foundation, :event_store, :correlation_query_errors], %{})
    end

    result
  end

  @impl EventStoreContract
  def prune_before(timestamp) do
    start_time = System.monotonic_time()
    result = GenServer.call(__MODULE__, {:prune_before, timestamp})
    end_time = System.monotonic_time()

    duration = end_time - start_time

    case result do
      {:ok, pruned_count} ->
        emit_telemetry_gauge([:foundation, :event_store, :prune_duration], duration, %{
          pruned_count: pruned_count
        })

        emit_telemetry_counter([:foundation, :event_store, :events_pruned], %{
          pruned_count: pruned_count
        })

      {:error, _} ->
        emit_telemetry_gauge([:foundation, :event_store, :prune_duration], duration, %{
          result: :error
        })

        emit_telemetry_counter([:foundation, :event_store, :prune_errors], %{})
    end

    result
  end

  @impl EventStoreContract
  def stats do
    result = GenServer.call(__MODULE__, :get_stats)

    # Report current stats as telemetry
    case result do
      {:ok, stats} ->
        emit_telemetry_gauge(
          [:foundation, :event_store, :current_event_count],
          stats.current_event_count,
          %{}
        )

        emit_telemetry_gauge(
          [:foundation, :event_store, :memory_usage],
          stats.memory_usage_estimate,
          %{}
        )

        emit_telemetry_gauge([:foundation, :event_store, :uptime], stats.uptime_ms, %{})

      {:error, _} ->
        emit_telemetry_counter([:foundation, :event_store, :stats_errors], %{})
    end

    result
  end

  @impl EventStoreContract
  def available? do
    GenServer.whereis(__MODULE__) != nil
  end

  @impl EventStoreContract
  def initialize do
    do_initialize([])
  end

  @impl EventStoreContract
  def status do
    case GenServer.whereis(__MODULE__) do
      nil -> create_service_error("Event store service not started")
      _pid -> GenServer.call(__MODULE__, :get_status)
    end
  end

  ## Additional Functions

  @spec do_initialize(keyword()) :: :ok | {:error, Error.t()}
  def do_initialize(opts) do
    case start_link(opts) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        {:error,
         Error.new(
           error_type: :service_initialization_failed,
           message: "Failed to initialize event store service",
           context: %{reason: reason},
           category: :events,
           subcategory: :startup,
           severity: :high
         )}
    end
  end

  ## GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(opts) do
    config = Map.merge(@default_config, Map.new(opts))

    state = %{
      events: %{},
      correlation_index: %{},
      event_sequence: [],
      config: config,
      metrics: %{
        start_time: System.monotonic_time(:millisecond),
        events_stored: 0,
        events_pruned: 0,
        last_prune: nil
      }
    }

    # Schedule periodic pruning if enabled
    if config.prune_interval > 0 do
      schedule_pruning(config.prune_interval)
    end

    # Report initialization telemetry
    emit_telemetry_counter([:foundation, :event_store, :initializations], %{
      max_events: config.max_events,
      enable_correlation_index: config.enable_correlation_index
    })

    Logger.info("Event store initialized successfully")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:store_event, event}, _from, state) do
    case EventValidator.validate(event) do
      :ok ->
        new_state = do_store_event(event, state)
        {:reply, {:ok, event.event_id}, new_state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:store_batch, events}, _from, state) do
    # Validate all events first
    validation_results = Enum.map(events, &EventValidator.validate/1)

    case Enum.find(validation_results, fn result -> match?({:error, _}, result) end) do
      nil ->
        # All events valid, store them
        {event_ids, new_state} =
          Enum.map_reduce(events, state, fn event, acc_state ->
            {event.event_id, do_store_event(event, acc_state)}
          end)

        {:reply, {:ok, event_ids}, new_state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:get_event, event_id}, _from, %{events: events} = state) do
    case Map.get(events, event_id) do
      nil ->
        error = create_not_found_error("Event not found", %{event_id: event_id})
        {:reply, error, state}

      event ->
        {:reply, {:ok, event}, state}
    end
  end

  @impl GenServer
  def handle_call({:query_events, query}, _from, state) do
    result = execute_query(query, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(
        {:get_by_correlation, correlation_id},
        _from,
        %{correlation_index: index, events: events} = state
      ) do
    case Map.get(index, correlation_id) do
      nil ->
        {:reply, {:ok, []}, state}

      event_ids ->
        correlated_events =
          event_ids
          |> Enum.map(&Map.get(events, &1))
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(& &1.timestamp)

        {:reply, {:ok, correlated_events}, state}
    end
  end

  @impl GenServer
  def handle_call({:prune_before, timestamp}, _from, state) do
    {pruned_count, new_state} = do_prune_before(timestamp, state)
    {:reply, {:ok, pruned_count}, new_state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    current_stats = calculate_current_stats(state)
    {:reply, {:ok, current_stats}, state}
  end

  @impl GenServer
  def handle_call(:get_status, _from, %{metrics: metrics} = state) do
    current_time = System.monotonic_time(:millisecond)

    status = %{
      status: :running,
      uptime_ms: current_time - metrics.start_time,
      events_stored: metrics.events_stored,
      events_pruned: metrics.events_pruned,
      current_event_count: map_size(state.events),
      last_prune: metrics.last_prune
    }

    {:reply, {:ok, status}, state}
  end

  @impl GenServer
  def handle_info(:prune_old_events, %{config: config} = state) do
    max_age_ms = config.max_age_seconds * 1000
    cutoff_time = System.monotonic_time(:millisecond) - max_age_ms

    {_pruned_count, new_state} = do_prune_before(cutoff_time, state)

    # Schedule next pruning
    schedule_pruning(config.prune_interval)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.warning("Unexpected message in EventStore: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  defp do_store_event(%Event{} = event, %{config: config} = state) do
    # Check if we need to prune first
    state = maybe_prune_for_capacity(state, config)

    new_events = Map.put(state.events, event.event_id, event)
    new_sequence = [event.event_id | state.event_sequence]

    # Update correlation index if enabled
    new_correlation_index =
      if config.enable_correlation_index and event.correlation_id do
        Map.update(
          state.correlation_index,
          event.correlation_id,
          [event.event_id],
          fn existing -> [event.event_id | existing] end
        )
      else
        state.correlation_index
      end

    new_metrics = Map.update!(state.metrics, :events_stored, &(&1 + 1))

    %{
      state
      | events: new_events,
        event_sequence: new_sequence,
        correlation_index: new_correlation_index,
        metrics: new_metrics
    }
  end

  defp maybe_prune_for_capacity(%{config: %{max_events: max_events}} = state, _config)
       when map_size(state.events) >= max_events do
    # Remove oldest 10% of events
    prune_count = div(max_events, 10)
    oldest_event_ids = state.event_sequence |> Enum.reverse() |> Enum.take(prune_count)

    new_events = Map.drop(state.events, oldest_event_ids)

    new_sequence =
      state.event_sequence |> Enum.reverse() |> Enum.drop(prune_count) |> Enum.reverse()

    # Update correlation index
    new_correlation_index = remove_from_correlation_index(state.correlation_index, oldest_event_ids)

    new_metrics = Map.update!(state.metrics, :events_pruned, &(&1 + prune_count))

    %{
      state
      | events: new_events,
        event_sequence: new_sequence,
        correlation_index: new_correlation_index,
        metrics: new_metrics
    }
  end

  defp maybe_prune_for_capacity(state, _config), do: state

  defp do_prune_before(timestamp, state) do
    events_to_prune =
      state.events
      |> Enum.filter(fn {_id, event} -> event.timestamp < timestamp end)
      |> Enum.map(fn {id, _event} -> id end)

    new_events = Map.drop(state.events, events_to_prune)
    new_sequence = Enum.reject(state.event_sequence, &(&1 in events_to_prune))
    new_correlation_index = remove_from_correlation_index(state.correlation_index, events_to_prune)

    pruned_count = length(events_to_prune)

    new_metrics =
      state.metrics
      |> Map.update!(:events_pruned, &(&1 + pruned_count))
      |> Map.put(:last_prune, System.monotonic_time(:millisecond))

    new_state = %{
      state
      | events: new_events,
        event_sequence: new_sequence,
        correlation_index: new_correlation_index,
        metrics: new_metrics
    }

    {pruned_count, new_state}
  end

  defp execute_query(query, %{events: events}) do
    try do
      filtered_events =
        events
        |> Map.values()
        |> apply_query_filters(query)
        |> apply_query_sorting(query)
        |> apply_query_pagination(query)

      {:ok, filtered_events}
    rescue
      error ->
        create_query_error("Query execution failed", %{
          original_error: error,
          query: query
        })
    end
  end

  defp apply_query_filters(events, query) do
    Enum.filter(events, fn event ->
      Enum.all?(query, fn
        {:event_type, type} ->
          event.event_type == type

        {:node, node} ->
          event.node == node

        {:pid, pid} ->
          event.pid == pid

        {:correlation_id, corr_id} ->
          event.correlation_id == corr_id

        {:time_range, {start_time, end_time}} ->
          event.timestamp >= start_time and event.timestamp <= end_time

        {:limit, _} ->
          true

        {:offset, _} ->
          true

        {:order_by, _} ->
          true

        _ ->
          true
      end)
    end)
  end

  defp apply_query_sorting(events, query) do
    case Map.get(query, :order_by, :timestamp) do
      :timestamp -> Enum.sort_by(events, & &1.timestamp)
      :event_id -> Enum.sort_by(events, & &1.event_id)
      :event_type -> Enum.sort_by(events, & &1.event_type)
      _ -> events
    end
  end

  defp apply_query_pagination(events, query) do
    offset = Map.get(query, :offset, 0)
    limit = Map.get(query, :limit, 1000)

    events
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end

  defp remove_from_correlation_index(correlation_index, event_ids_to_remove) do
    event_ids_set = MapSet.new(event_ids_to_remove)

    correlation_index
    |> Enum.map(fn {correlation_id, event_ids} ->
      filtered_ids = Enum.reject(event_ids, &MapSet.member?(event_ids_set, &1))
      {correlation_id, filtered_ids}
    end)
    |> Enum.reject(fn {_correlation_id, event_ids} -> Enum.empty?(event_ids) end)
    |> Map.new()
  end

  defp calculate_current_stats(%{events: events, metrics: metrics, config: config}) do
    current_time = System.monotonic_time(:millisecond)
    uptime = current_time - metrics.start_time

    Map.merge(metrics, %{
      current_time: current_time,
      uptime_ms: uptime,
      current_event_count: map_size(events),
      max_events: config.max_events,
      memory_usage_estimate: estimate_memory_usage(events)
    })
  end

  defp estimate_memory_usage(events) do
    # Rough estimate based on average event size
    if map_size(events) > 0 do
      sample_events = events |> Map.values() |> Enum.take(10)

      avg_size =
        sample_events
        |> Enum.map(&:erlang.external_size/1)
        |> Enum.sum()
        |> div(length(sample_events))

      avg_size * map_size(events)
    else
      0
    end
  end

  defp schedule_pruning(interval) do
    Process.send_after(self(), :prune_old_events, interval)
  end

  defp emit_telemetry_counter(event_name, metadata) do
    if TelemetryService.available?() do
      try do
        TelemetryService.emit_counter(event_name, metadata)
      rescue
        error ->
          Logger.debug("Failed to emit telemetry counter: #{inspect(error)}")
      end
    end
  end

  defp emit_telemetry_gauge(event_name, value, metadata) do
    if TelemetryService.available?() do
      try do
        TelemetryService.emit_gauge(event_name, value, metadata)
      rescue
        error ->
          Logger.debug("Failed to emit telemetry gauge: #{inspect(error)}")
      end
    end
  end

  defp extract_query_type(query_map) do
    cond do
      Map.has_key?(query_map, :event_type) -> :by_event_type
      Map.has_key?(query_map, :time_range) -> :by_time_range
      Map.has_key?(query_map, :correlation_id) -> :by_correlation
      Map.has_key?(query_map, :node) -> :by_node
      Map.has_key?(query_map, :pid) -> :by_pid
      true -> :generic
    end
  end

  defp create_service_error(message) do
    error =
      Error.new(
        error_type: :service_unavailable,
        message: message,
        category: :system,
        subcategory: :initialization,
        severity: :high
      )

    {:error, error}
  end

  defp create_not_found_error(message, context) do
    error =
      Error.new(
        error_type: :not_found,
        message: message,
        context: context,
        category: :data,
        subcategory: :access,
        severity: :low
      )

    {:error, error}
  end

  defp create_query_error(message, context) do
    error =
      Error.new(
        error_type: :query_failed,
        message: message,
        context: context,
        category: :data,
        subcategory: :runtime,
        severity: :medium
      )

    {:error, error}
  end
end
