defmodule ElixirScope.Foundation.Infrastructure.EnhancedConnectionPoolManager do
  @moduledoc """
  Enhanced connection pool manager with Poolboy insights.
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}
  alias ElixirScope.Foundation.Infrastructure.EnhancedConnectionPool

  @type enhanced_pool_state :: %{
          namespace: ServiceRegistry.namespace(),
          pool_name: atom(),
          connection_spec: map(),
          config: EnhancedConnectionPool.enhanced_pool_config(),
          connections: [EnhancedConnectionPool.connection_info()],
          available: :queue.queue(),
          checked_out: %{reference() => EnhancedConnectionPool.connection_info()},
          overflow_connections: %{reference() => EnhancedConnectionPool.connection_info()},
          stats: EnhancedConnectionPool.pool_stats(),
          strategy_state: map()
        }

  ## Public API

  @doc """
  Start the enhanced connection pool manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    pool_name = Keyword.fetch!(opts, :pool_name)

    name = ServiceRegistry.via_tuple(namespace, {:connection_pool, pool_name})
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Checkout a connection with overflow support.
  """
  @spec checkout_with_overflow(pid(), boolean(), pos_integer()) ::
          {:ok, term(), boolean()} | {:error, term()}
  def checkout_with_overflow(pid, allow_overflow, timeout) do
    GenServer.call(pid, {:checkout_with_overflow, allow_overflow}, timeout)
  end

  @doc """
  Check in a connection (regular or overflow).
  """
  @spec checkin_connection(pid(), term(), boolean()) :: :ok
  def checkin_connection(pid, connection, is_overflow) do
    GenServer.cast(pid, {:checkin_connection, connection, is_overflow})
  end

  @doc """
  Handle connection error (close corrupted connection).
  """
  @spec handle_connection_error(pid(), term(), boolean(), term()) :: :ok
  def handle_connection_error(pid, connection, is_overflow, error) do
    GenServer.cast(pid, {:connection_error, connection, is_overflow, error})
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    pool_name = Keyword.fetch!(opts, :pool_name)
    connection_spec = Keyword.fetch!(opts, :connection_spec)
    config = Keyword.fetch!(opts, :config)

    state = %{
      namespace: namespace,
      pool_name: pool_name,
      connection_spec: connection_spec,
      config: config,
      connections: [],
      available: :queue.new(),
      checked_out: %{},
      overflow_connections: %{},
      stats: %{
        size: 0,
        available: 0,
        checked_out: 0,
        overflow: 0,
        total_checkouts: 0,
        total_checkins: 0,
        health_checks_passed: 0,
        health_checks_failed: 0,
        connections_created: 0,
        connections_destroyed: 0
      },
      strategy_state: initialize_strategy_state(config.strategy)
    }

    # Pre-populate pool with minimum connections
    new_state = ensure_min_connections(state)

    # Schedule health checks and maintenance
    schedule_health_check(config.health_check_interval)
    schedule_maintenance(60_000)  # Every minute

    Logger.info("Enhanced connection pool #{pool_name} started in #{inspect(namespace)}")
    {:ok, new_state}
  end

  @impl true
  def handle_call({:checkout_with_overflow, allow_overflow}, {from_pid, _ref} = from, state) do
    case get_connection_with_strategy(state) do
      {:ok, conn_info, remaining_state} ->
        # Regular connection available
        handle_successful_checkout(conn_info, from_pid, remaining_state, false)

      {:empty, _} when allow_overflow and map_size(state.overflow_connections) < state.config.max_overflow ->
        # Create overflow connection
        case create_overflow_connection(state, from_pid) do
          {:ok, new_state} ->
            # Return the overflow connection info
            {monitor_ref, overflow_conn} =
              state.overflow_connections
              |> Enum.find(fn {_ref, conn} -> conn.is_overflow end)

            {:reply, {:ok, overflow_conn.connection, true}, new_state}

          {:error, reason} ->
            new_stats = Map.update!(state.stats, :connections_created, &(&1 + 1))
            {:reply, {:error, reason}, %{state | stats: new_stats}}
        end

      {:empty, _} when map_size(state.checked_out) < state.config.max_size ->
        # Create new regular connection
        case create_new_connection(state) do
          {:ok, conn_info} ->
            handle_successful_checkout(conn_info, from_pid, state, false)

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:empty, _} ->
        # Pool exhausted
        {:reply, {:error, :pool_exhausted}, state}
    end
  end

  @impl true
  def handle_cast({:checkin_connection, connection, is_overflow}, state) do
    if is_overflow do
      handle_overflow_checkin(connection, state)
    else
      handle_regular_checkin(connection, state)
    end
  end

  def handle_cast({:connection_error, connection, is_overflow, error}, state) do
    Logger.warning("Connection error in pool #{state.pool_name}: #{inspect(error)}")

    if is_overflow do
      handle_overflow_connection_error(connection, state)
    else
      handle_regular_connection_error(connection, state)
    end
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    cond do
      Map.has_key?(state.checked_out, monitor_ref) ->
        handle_borrower_death_regular(monitor_ref, state)

      Map.has_key?(state.overflow_connections, monitor_ref) ->
        handle_borrower_death_overflow(monitor_ref, state)

      true ->
        {:noreply, state}
    end
  end

  def handle_info(:health_check, state) do
    new_state = perform_enhanced_health_checks(state)
    schedule_health_check(state.config.health_check_interval)
    {:noreply, new_state}
  end

  def handle_info(:maintenance, state) do
    new_state = perform_maintenance(state)
    schedule_maintenance(60_000)
    {:noreply, new_state}
  end

  ## Strategy Implementation

  @spec get_connection_with_strategy(enhanced_pool_state()) ::
          {:ok, EnhancedConnectionPool.connection_info(), enhanced_pool_state()} |
          {:empty, enhanced_pool_state()}
  defp get_connection_with_strategy(state) do
    case state.config.strategy do
      :lifo -> get_connection_lifo(state)
      :fifo -> get_connection_fifo(state)
      :round_robin -> get_connection_round_robin(state)
      :least_used -> get_connection_least_used(state)
    end
  end

  @spec get_connection_lifo(enhanced_pool_state()) ::
          {:ok, EnhancedConnectionPool.connection_info(), enhanced_pool_state()} |
          {:empty, enhanced_pool_state()}
  defp get_connection_lifo(state) do
    case :queue.out_r(state.available) do  # LIFO: out from rear
      {{:value, conn_info}, remaining_queue} ->
        new_state = %{state | available: remaining_queue}
        {:ok, conn_info, new_state}
      {:empty, _} ->
        {:empty, state}
    end
  end

  @spec get_connection_fifo(enhanced_pool_state()) ::
          {:ok, EnhancedConnectionPool.connection_info(), enhanced_pool_state()} |
          {:empty, enhanced_pool_state()}
  defp get_connection_fifo(state) do
    case :queue.out(state.available) do  # FIFO: out from front
      {{:value, conn_info}, remaining_queue} ->
        new_state = %{state | available: remaining_queue}
        {:ok, conn_info, new_state}
      {:empty, _} ->
        {:empty, state}
    end
  end

  @spec get_connection_round_robin(enhanced_pool_state()) ::
          {:ok, EnhancedConnectionPool.connection_info(), enhanced_pool_state()} |
          {:empty, enhanced_pool_state()}
  defp get_connection_round_robin(state) do
    case :queue.out(state.available) do
      {{:value, conn_info}, remaining_queue} ->
        # For round-robin, put connection at back after checkout tracking
        new_strategy_state = Map.update(state.strategy_state, :round_robin_position, 0, &(&1 + 1))
        new_state = %{state | available: remaining_queue, strategy_state: new_strategy_state}
        {:ok, conn_info, new_state}
      {:empty, _} ->
        {:empty, state}
    end
  end

  @spec get_connection_least_used(enhanced_pool_state()) ::
          {:ok, EnhancedConnectionPool.connection_info(), enhanced_pool_state()} |
          {:empty, enhanced_pool_state()}
  defp get_connection_least_used(state) do
    case :queue.to_list(state.available) do
      [] ->
        {:empty, state}
      connections ->
        # Find connection with least checkout count
        least_used = Enum.min_by(connections, & &1.checkout_count)
        remaining_connections = List.delete(connections, least_used)
        new_available = :queue.from_list(remaining_connections)

        new_state = %{state | available: new_available}
        {:ok, least_used, new_state}
    end
  end

  ## Connection Management

  @spec create_overflow_connection(enhanced_pool_state(), pid()) ::
          {:ok, enhanced_pool_state()} | {:error, term()}
  defp create_overflow_connection(state, borrower_pid) do
    case create_connection(state.connection_spec, true) do
      {:ok, conn_info} ->
        monitor_ref = Process.monitor(borrower_pid)
        new_overflow = Map.put(state.overflow_connections, monitor_ref, conn_info)

        new_stats =
          state.stats
          |> Map.update!(:connections_created, &(&1 + 1))
          |> Map.update!(:total_checkouts, &(&1 + 1))
          |> Map.update!(:overflow, &(&1 + 1))

        new_state = %{state | overflow_connections: new_overflow, stats: new_stats}
        {:ok, new_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

end
