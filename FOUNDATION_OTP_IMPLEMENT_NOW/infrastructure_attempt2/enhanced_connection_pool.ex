defmodule ElixirScope.Foundation.Infrastructure.EnhancedConnectionPool do
  @spec create_new_connection(enhanced_pool_state()) ::
          {:ok, EnhancedConnectionPool.connection_info()} | {:error, term()}
  defp create_new_connection(state) do
    create_connection(state.connection_spec, false)
  end

  @spec create_connection(map(), boolean()) ::
          {:ok, EnhancedConnectionPool.connection_info()} | {:error, term()}
  defp create_connection(connection_spec, is_overflow) do
    case connection_spec.module.create_connection(connection_spec.options) do
      {:ok, connection} ->
        now = Utils.monotonic_timestamp()
        conn_info = %{
          connection: connection,
          created_at: now,
          last_used: now,
          checkout_count: 0,
          health_status: :unknown,
          is_overflow: is_overflow,
          ttl: if(is_overflow, do: 300_000, else: 3_600_000)  # 5min vs 1hour
        }

        {:ok, conn_info}

      {:error, _} = error ->
        error
    end
  end

  @spec handle_successful_checkout(EnhancedConnectionPool.connection_info(), pid(), enhanced_pool_state(), boolean()) ::
          {:reply, {:ok, term(), boolean()}, enhanced_pool_state()}
  defp handle_successful_checkout(conn_info, borrower_pid, state, is_overflow) do
    monitor_ref = Process.monitor(borrower_pid)
    updated_conn_info = %{
      conn_info |
      last_used: Utils.monotonic_timestamp(),
      checkout_count: conn_info.checkout_count + 1
    }

    new_checked_out = Map.put(state.checked_out, monitor_ref, updated_conn_info)

    new_stats =
      state.stats
      |> Map.update!(:total_checkouts, &(&1 + 1))
      |> Map.update!(:checked_out, &(&1 + 1))
      |> Map.update!(:available, &(&1 - 1))

    new_state = %{state | checked_out: new_checked_out, stats: new_stats}
    {:reply, {:ok, conn_info.connection, is_overflow}, new_state}
  end

  @spec handle_regular_checkin(term(), enhanced_pool_state()) :: {:noreply, enhanced_pool_state()}
  defp handle_regular_checkin(connection, state) do
    case find_checked_out_connection(connection, state.checked_out) do
      {monitor_ref, conn_info} ->
        Process.demonitor(monitor_ref, [:flush])

        # Health check connection before returning to pool
        updated_conn_info = %{conn_info | last_used: Utils.monotonic_timestamp()}

        case check_connection_health(updated_conn_info, state.connection_spec) do
          true ->
            new_available = add_to_available_with_strategy(updated_conn_info, state)
            new_checked_out = Map.delete(state.checked_out, monitor_ref)

            new_stats =
              state.stats
              |> Map.update!(:total_checkins, &(&1 + 1))
              |> Map.update!(:checked_out, &(&1 - 1))
              |> Map.update!(:available, &(&1 + 1))
              |> Map.update!(:health_checks_passed, &(&1 + 1))

            new_state = %{state |
              available: new_available,
              checked_out: new_checked_out,
              stats: new_stats
            }
            {:noreply, new_state}

          false ->
            # Connection failed health check, destroy it
            close_connection(connection, state.connection_spec)
            new_checked_out = Map.delete(state.checked_out, monitor_ref)
            new_connections = List.delete(state.connections, conn_info)

            new_stats =
              state.stats
              |> Map.update!(:total_checkins, &(&1 + 1))
              |> Map.update!(:checked_out, &(&1 - 1))
              |> Map.update!(:connections_destroyed, &(&1 + 1))
              |> Map.update!(:health_checks_failed, &(&1 + 1))

            new_state = %{state |
              connections: new_connections,
              checked_out: new_checked_out,
              stats: new_stats
            }

            # Ensure we still have minimum connections
            final_state = ensure_min_connections(new_state)
            {:noreply, final_state}
        end

      nil ->
        Logger.warning("Attempted to check in unknown connection to pool #{state.pool_name}")
        {:noreply, state}
    end
  end

  @spec handle_overflow_checkin(term(), enhanced_pool_state()) :: {:noreply, enhanced_pool_state()}
  defp handle_overflow_checkin(connection, state) do
    case find_overflow_connection(connection, state.overflow_connections) do
      {monitor_ref, conn_info} ->
        Process.demonitor(monitor_ref, [:flush])

        # Always close overflow connections on checkin
        close_connection(connection, state.connection_spec)
        new_overflow = Map.delete(state.overflow_connections, monitor_ref)

        new_stats =
          state.stats
          |> Map.update!(:total_checkins, &(&1 + 1))
          |> Map.update!(:overflow, &(&1 - 1))
          |> Map.update!(:connections_destroyed, &(&1 + 1))

        new_state = %{state | overflow_connections: new_overflow, stats: new_stats}
        {:noreply, new_state}

      nil ->
        Logger.warning("Attempted to check in unknown overflow connection to pool #{state.pool_name}")
        {:noreply, state}
    end
  end

  @spec handle_borrower_death_regular(reference(), enhanced_pool_state()) :: {:noreply, enhanced_pool_state()}
  defp handle_borrower_death_regular(monitor_ref, state) do
    case Map.get(state.checked_out, monitor_ref) do
      nil ->
        {:noreply, state}

      conn_info ->
        # Close the connection since the borrower process died
        close_connection(conn_info.connection, state.connection_spec)
        new_checked_out = Map.delete(state.checked_out, monitor_ref)
        new_connections = List.delete(state.connections, conn_info)

        new_stats =
          state.stats
          |> Map.update!(:connections_destroyed, &(&1 + 1))
          |> Map.update!(:checked_out, &(&1 - 1))

        new_state = %{state |
          connections: new_connections,
          checked_out: new_checked_out,
          stats: new_stats
        }

        # Ensure we still have minimum connections
        final_state = ensure_min_connections(new_state)
        {:noreply, final_state}
    end
  end

  @spec handle_borrower_death_overflow(reference(), enhanced_pool_state()) :: {:noreply, enhanced_pool_state()}
  defp handle_borrower_death_overflow(monitor_ref, state) do
    case Map.get(state.overflow_connections, monitor_ref) do
      nil ->
        {:noreply, state}

      conn_info ->
        # Close the overflow connection
        close_connection(conn_info.connection, state.connection_spec)
        new_overflow = Map.delete(state.overflow_connections, monitor_ref)

        new_stats =
          state.stats
          |> Map.update!(:connections_destroyed, &(&1 + 1))
          |> Map.update!(:overflow, &(&1 - 1))

        new_state = %{state | overflow_connections: new_overflow, stats: new_stats}
        {:noreply, new_state}
    end
  end

  ## Health Check Implementation

  @spec perform_enhanced_health_checks(enhanced_pool_state()) :: enhanced_pool_state()
  defp perform_enhanced_health_checks(state) do
    case state.config.health_check_strategy do
      :passive -> perform_passive_health_checks(state)
      :active -> perform_active_health_checks(state)
      :mixed -> perform_mixed_health_checks(state)
    end
  end

  @spec perform_passive_health_checks(enhanced_pool_state()) :: enhanced_pool_state()
  defp perform_passive_health_checks(state) do
    # Only check connections when they're returned to pool
    # This is handled in handle_regular_checkin
    state
  end

  @spec perform_active_health_checks(enhanced_pool_state()) :: enhanced_pool_state()
  defp perform_active_health_checks(state) do
    # Proactively check all available connections
    {healthy_available, unhealthy_available} =
      state.available
      |> :queue.to_list()
      |> Enum.split_with(fn conn_info ->
        check_connection_health(conn_info, state.connection_spec)
      end)

    # Close unhealthy connections
    Enum.each(unhealthy_available, fn conn_info ->
      close_connection(conn_info.connection, state.connection_spec)
    end)

    # Update available queue with only healthy connections
    new_available = :queue.from_list(healthy_available)

    # Update stats
    health_checks_passed = length(healthy_available)
    health_checks_failed = length(unhealthy_available)

    new_stats =
      state.stats
      |> Map.update!(:health_checks_passed, &(&1 + health_checks_passed))
      |> Map.update!(:health_checks_failed, &(&1 + health_checks_failed))
      |> Map.update!(:connections_destroyed, &(&1 + health_checks_failed))

    # Update connections list
    healthy_connections =
      Enum.filter(state.connections, fn conn_info ->
        conn_info in healthy_available or
          Enum.any?(Map.values(state.checked_out), &(&1 == conn_info))
      end)

    new_state = %{state |
      connections: healthy_connections,
      available: new_available,
      stats: new_stats
    }

    # Ensure we still have minimum connections after cleanup
    ensure_min_connections(new_state)
  end

  @spec perform_mixed_health_checks(enhanced_pool_state()) :: enhanced_pool_state()
  defp perform_mixed_health_checks(state) do
    # Check half the available connections actively, others passively
    available_list = :queue.to_list(state.available)
    {to_check, to_leave} = Enum.split(available_list, div(length(available_list), 2))

    {healthy_checked, unhealthy_checked} =
      Enum.split_with(to_check, fn conn_info ->
        check_connection_health(conn_info, state.connection_spec)
      end)

    # Close unhealthy connections
    Enum.each(unhealthy_checked, fn conn_info ->
      close_connection(conn_info.connection, state.connection_spec)
    end)

    # Rebuild available queue
    new_available = :queue.from_list(healthy_checked ++ to_leave)

    new_stats =
      state.stats
      |> Map.update!(:health_checks_passed, &(&1 + length(healthy_checked)))
      |> Map.update!(:health_checks_failed, &(&1 + length(unhealthy_checked)))
      |> Map.update!(:connections_destroyed, &(&1 + length(unhealthy_checked)))

    new_state = %{state | available: new_available, stats: new_stats}
    ensure_min_connections(new_state)
  end

  ## Maintenance and Cleanup

  @spec perform_maintenance(enhanced_pool_state()) :: enhanced_pool_state()
  defp perform_maintenance(state) do
    state
    |> cleanup_expired_connections()
    |> cleanup_idle_connections()
    |> ensure_min_connections()
  end

  @spec cleanup_expired_connections(enhanced_pool_state()) :: enhanced_pool_state()
  defp cleanup_expired_connections(state) do
    now = Utils.monotonic_timestamp()

    # Check TTL for available connections
    {valid_available, expired_available} =
      state.available
      |> :queue.to_list()
      |> Enum.split_with(fn conn_info ->
        (now - conn_info.created_at) < conn_info.ttl
      end)

    # Close expired connections
    Enum.each(expired_available, fn conn_info ->
      close_connection(conn_info.connection, state.connection_spec)
    end)

    new_available = :queue.from_list(valid_available)

    new_stats = Map.update!(state.stats, :connections_destroyed, &(&1 + length(expired_available)))

    %{state | available: new_available, stats: new_stats}
  end

  @spec cleanup_idle_connections(enhanced_pool_state()) :: enhanced_pool_state()
  defp cleanup_idle_connections(state) do
    now = Utils.monotonic_timestamp()
    idle_threshold = state.config.idle_timeout

    # Find idle connections beyond minimum pool size
    available_list = :queue.to_list(state.available)
    current_size = length(state.connections)

    if current_size > state.config.min_size do
      {keep_connections, idle_connections} =
        available_list
        |> Enum.sort_by(& &1.last_used, :desc)  # Most recently used first
        |> Enum.split(state.config.min_size)

      # Close truly idle connections
      connections_to_close =
        idle_connections
        |> Enum.filter(fn conn_info ->
          (now - conn_info.last_used) > idle_threshold
        end)
        |> Enum.take(current_size - state.config.min_size)

      Enum.each(connections_to_close, fn conn_info ->
        close_connection(conn_info.connection, state.connection_spec)
      end)

      remaining_connections = available_list -- connections_to_close
      new_available = :queue.from_list(remaining_connections)

      new_stats = Map.update!(state.stats, :connections_destroyed, &(&1 + length(connections_to_close)))

      %{state | available: new_available, stats: new_stats}
    else
      state
    end
  end

  ## Helper Functions

  @spec add_to_available_with_strategy(EnhancedConnectionPool.connection_info(), enhanced_pool_state()) :: :queue.queue()
  defp add_to_available_with_strategy(conn_info, state) do
    case state.config.strategy do
      :lifo -> :queue.in_r(conn_info, state.available)  # Add to rear for LIFO
      :fifo -> :queue.in(conn_info, state.available)    # Add to rear for FIFO
      :round_robin -> :queue.in(conn_info, state.available)  # Add to rear
      :least_used -> :queue.in(conn_info, state.available)   # Add to rear
    end
  end

  @spec find_checked_out_connection(term(), map()) ::
          {reference(), EnhancedConnectionPool.connection_info()} | nil
  defp find_checked_out_connection(connection, checked_out) do
    Enum.find(checked_out, fn {_ref, conn_info} ->
      conn_info.connection == connection
    end)
  end

  @spec find_overflow_connection(term(), map()) ::
          {reference(), EnhancedConnectionPool.connection_info()} | nil
  defp find_overflow_connection(connection, overflow_connections) do
    Enum.find(overflow_connections, fn {_ref, conn_info} ->
      conn_info.connection == connection
    end)
  end

  @spec check_connection_health(EnhancedConnectionPool.connection_info(), map()) :: boolean()
  defp check_connection_health(conn_info, connection_spec) do
    try do
      case connection_spec.health_check.(conn_info.connection) do
        true -> true
        :ok -> true
        {:ok, _} -> true
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  @spec close_connection(term(), map()) :: :ok
  defp close_connection(connection, connection_spec) do
    try do
      connection_spec.module.close_connection(connection)
    rescue
      error ->
        Logger.warning("Error closing connection: #{inspect(error)}")
        :ok
    end
  end

  @spec ensure_min_connections(enhanced_pool_state()) :: enhanced_pool_state()
  defp ensure_min_connections(state) do
    current_count = length(state.connections)
    needed = state.config.min_size - current_count

    if needed > 0 do
      new_connections = create_connections(needed, state)

      new_available =
        Enum.reduce(new_connections, state.available, fn conn_info, queue ->
          :queue.in(conn_info, queue)
        end)

      new_stats = Map.update!(state.stats, :connections_created, &(&1 + length(new_connections)))

      %{state |
        connections: new_connections ++ state.connections,
        available: new_available,
        stats: new_stats
      }
    else
      state
    end
  end

  @spec create_connections(non_neg_integer(), enhanced_pool_state()) ::
          [EnhancedConnectionPool.connection_info()]
  defp create_connections(count, state) do
    Enum.reduce(1..count, [], fn _i, acc ->
      case create_new_connection(state) do
        {:ok, conn_info} ->
          [conn_info | acc]

        {:error, reason} ->
          Logger.warning(
            "Failed to create connection for pool #{state.pool_name}: #{inspect(reason)}"
          )
          acc
      end
    end)
  end

  @spec initialize_strategy_state(EnhancedConnectionPool.pool_strategy()) :: map()
  defp initialize_strategy_state(:round_robin), do: %{round_robin_position: 0}
  defp initialize_strategy_state(_), do: %{}

  @spec schedule_health_check(pos_integer()) :: reference()
  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end

  @spec schedule_maintenance(pos_integer()) :: reference()
  defp schedule_maintenance(interval) do
    Process.send_after(self(), :maintenance, interval)
  end
endmoduledoc """
  Enhanced connection pool with insights from Poolboy.

  Features:
  - LIFO/FIFO/Round-robin strategies for worker management
  - Overflow management for burst traffic handling
  - Advanced monitoring with process tracking
  - Graceful connection cleanup on borrower death
  - Health check strategies (passive/active/mixed)
  """

  @type pool_strategy :: :lifo | :fifo | :round_robin | :least_used
  @type health_check_strategy :: :passive | :active | :mixed

  @type enhanced_pool_config :: %{
          min_size: non_neg_integer(),
          max_size: pos_integer(),
          max_overflow: non_neg_integer(),
          checkout_timeout: pos_integer(),
          idle_timeout: pos_integer(),
          max_retries: non_neg_integer(),
          health_check_interval: pos_integer(),
          # Enhanced configuration
          strategy: pool_strategy(),
          health_check_strategy: health_check_strategy(),
          connection_ttl: pos_integer(),
          overflow_ttl: pos_integer()
        }

  @type connection_info :: %{
          connection: term(),
          created_at: integer(),
          last_used: integer(),
          checkout_count: non_neg_integer(),
          health_status: :healthy | :unhealthy | :unknown,
          is_overflow: boolean(),
          ttl: pos_integer()
        }

  @type pool_stats :: %{
          size: non_neg_integer(),
          available: non_neg_integer(),
          checked_out: non_neg_integer(),
          overflow: non_neg_integer(),
          total_checkouts: non_neg_integer(),
          total_checkins: non_neg_integer(),
          health_checks_passed: non_neg_integer(),
          health_checks_failed: non_neg_integer(),
          connections_created: non_neg_integer(),
          connections_destroyed: non_neg_integer()
        }

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  @doc """
  Start an enhanced connection pool with overflow and strategy support.
  """
  @spec start_pool(ServiceRegistry.namespace(), atom(), map(), enhanced_pool_config()) ::
          {:ok, pid()} | {:error, term()}
  def start_pool(namespace, pool_name, connection_spec, config) do
    EnhancedConnectionPoolManager.start_link(
      namespace: namespace,
      pool_name: pool_name,
      connection_spec: connection_spec,
      config: config
    )
  end

  @doc """
  Execute function with connection, supporting overflow handling.
  """
  @spec with_connection(ServiceRegistry.namespace(), atom(), (term() -> term()), keyword()) ::
          {:ok, term()} | {:error, term()}
  def with_connection(namespace, pool_name, fun, opts \\ []) when is_function(fun, 1) do
    timeout = Keyword.get(opts, :timeout, 5000)
    allow_overflow = Keyword.get(opts, :allow_overflow, true)

    case checkout_with_overflow(namespace, pool_name, allow_overflow, timeout) do
      {:ok, connection, is_overflow} ->
        try do
          result = fun.(connection)
          checkin_connection(namespace, pool_name, connection, is_overflow)
          {:ok, result}
        rescue
          error ->
            # Don't return connection on error - it might be corrupted
            handle_connection_error(namespace, pool_name, connection, is_overflow, error)
            {:error, error}
        end

      {:error, _} = error ->
        error
    end
  end

  ## Private Functions

  @spec checkout_with_overflow(ServiceRegistry.namespace(), atom(), boolean(), pos_integer()) ::
          {:ok, term(), boolean()} | {:error, term()}
  defp checkout_with_overflow(namespace, pool_name, allow_overflow, timeout) do
    case ServiceRegistry.lookup(namespace, {:connection_pool, pool_name}) do
      {:ok, pid} ->
        EnhancedConnectionPoolManager.checkout_with_overflow(pid, allow_overflow, timeout)
      {:error, _} = error -> error
    end
  end

  @spec checkin_connection(ServiceRegistry.namespace(), atom(), term(), boolean()) :: :ok
  defp checkin_connection(namespace, pool_name, connection, is_overflow) do
    case ServiceRegistry.lookup(namespace, {:connection_pool, pool_name}) do
      {:ok, pid} ->
        EnhancedConnectionPoolManager.checkin_connection(pid, connection, is_overflow)
      {:error, _} -> :ok
    end
  end

  @spec handle_connection_error(ServiceRegistry.namespace(), atom(), term(), boolean(), term()) :: :ok
  defp handle_connection_error(namespace, pool_name, connection, is_overflow, error) do
    case ServiceRegistry.lookup(namespace, {:connection_pool, pool_name}) do
      {:ok, pid} ->
        EnhancedConnectionPoolManager.handle_connection_error(pid, connection, is_overflow, error)
      {:error, _} -> :ok
    end
  end
end
