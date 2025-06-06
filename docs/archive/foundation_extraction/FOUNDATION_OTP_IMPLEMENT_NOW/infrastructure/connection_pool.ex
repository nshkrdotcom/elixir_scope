defmodule ElixirScope.Foundation.Infrastructure.ConnectionPool do
  @moduledoc """
  Generic connection pooling infrastructure for external services.

  Establishes patterns for AST external tool integrations.
  Provides managed connection pools with monitoring and recovery.

  ## Features
  - Configurable pool sizes and timeouts
  - Connection health monitoring
  - Automatic connection recovery
  - Pool statistics and monitoring
  """

  @type t :: pool_config()

  @type pool_config :: %{
          min_size: non_neg_integer(),
          max_size: pos_integer(),
          checkout_timeout: pos_integer(),
          idle_timeout: pos_integer(),
          max_retries: non_neg_integer(),
          health_check_interval: pos_integer()
        }

  @type connection_spec :: %{
          module: module(),
          options: keyword(),
          health_check: (connection() -> boolean())
        }

  @type connection :: term()
  @type connection_info :: %{
          connection: connection(),
          created_at: integer(),
          last_used: integer(),
          health_status: :healthy | :unhealthy | :unknown
        }

  @callback create_connection(options :: keyword()) :: {:ok, connection()} | {:error, term()}
  @callback close_connection(connection()) :: :ok
  @callback ping_connection(connection()) :: :ok | {:error, term()}

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  @doc """
  Start a connection pool.
  """
  @spec start_pool(ServiceRegistry.namespace(), atom(), connection_spec(), pool_config()) ::
          {:ok, pid()} | {:error, term()}
  def start_pool(namespace, pool_name, connection_spec, config) do
    ConnectionPoolManager.start_link(
      namespace: namespace,
      pool_name: pool_name,
      connection_spec: connection_spec,
      config: config
    )
  end

  @doc """
  Checkout a connection from the pool.
  """
  @spec checkout(ServiceRegistry.namespace(), atom()) :: {:ok, connection()} | {:error, term()}
  def checkout(namespace, pool_name) do
    case ServiceRegistry.lookup(namespace, {:connection_pool, pool_name}) do
      {:ok, pid} -> ConnectionPoolManager.checkout(pid)
      {:error, _} = error -> error
    end
  end

  @doc """
  Return a connection to the pool.
  """
  @spec checkin(ServiceRegistry.namespace(), atom(), connection()) :: :ok
  def checkin(namespace, pool_name, connection) do
    case ServiceRegistry.lookup(namespace, {:connection_pool, pool_name}) do
      {:ok, pid} -> ConnectionPoolManager.checkin(pid, connection)
      {:error, _} -> :ok
    end
  end

  @doc """
  Execute a function with a pooled connection.
  """
  @spec with_connection(ServiceRegistry.namespace(), atom(), (connection() -> term())) ::
          {:ok, term()} | {:error, term()}
  def with_connection(namespace, pool_name, fun) when is_function(fun, 1) do
    case checkout(namespace, pool_name) do
      {:ok, connection} ->
        try do
          result = fun.(connection)
          checkin(namespace, pool_name, connection)
          {:ok, result}
        rescue
          error ->
            # Don't return connection on error - it might be corrupted
            {:error, error}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Get pool statistics.
  """
  @spec get_pool_stats(ServiceRegistry.namespace(), atom()) :: {:ok, map()} | {:error, term()}
  def get_pool_stats(namespace, pool_name) do
    case ServiceRegistry.lookup(namespace, {:connection_pool, pool_name}) do
      {:ok, pid} -> ConnectionPoolManager.get_stats(pid)
      {:error, _} = error -> error
    end
  end
end

defmodule ElixirScope.Foundation.Infrastructure.ConnectionPoolManager do
  @moduledoc """
  GenServer implementation of connection pool management.
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}
  alias ElixirScope.Foundation.Infrastructure.ConnectionPool

  @type pool_state :: %{
          namespace: ServiceRegistry.namespace(),
          pool_name: atom(),
          connection_spec: ConnectionPool.connection_spec(),
          config: ConnectionPool.pool_config(),
          connections: [ConnectionPool.connection_info()],
          available: :queue.queue(),
          checked_out: %{reference() => ConnectionPool.connection_info()},
          stats: map()
        }

  ## Public API

  @doc """
  Start the connection pool manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    pool_name = Keyword.fetch!(opts, :pool_name)

    name = ServiceRegistry.via_tuple(namespace, {:connection_pool, pool_name})
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Checkout a connection from the pool.
  """
  @spec checkout(pid()) :: {:ok, ConnectionPool.connection()} | {:error, term()}
  def checkout(pid) do
    GenServer.call(pid, :checkout, 5000)
  end

  @doc """
  Return a connection to the pool.
  """
  @spec checkin(pid(), ConnectionPool.connection()) :: :ok
  def checkin(pid, connection) do
    GenServer.cast(pid, {:checkin, connection})
  end

  @doc """
  Get pool statistics.
  """
  @spec get_stats(pid()) :: {:ok, map()}
  def get_stats(pid) do
    GenServer.call(pid, :get_stats)
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
      stats: %{
        created_connections: 0,
        destroyed_connections: 0,
        checkout_count: 0,
        checkin_count: 0,
        errors: 0,
        start_time: Utils.monotonic_timestamp()
      }
    }

    # Pre-populate pool with minimum connections
    new_state = ensure_min_connections(state)

    # Schedule health checks
    schedule_health_check(config.health_check_interval)

    Logger.info("Connection pool #{pool_name} started in #{inspect(namespace)}")
    {:ok, new_state}
  end

  @impl true
  def handle_call(:checkout, {from_pid, _ref} = from, state) do
    case :queue.out(state.available) do
      {{:value, conn_info}, remaining_queue} ->
        # Found available connection
        monitor_ref = Process.monitor(from_pid)
        updated_conn_info = %{conn_info | last_used: Utils.monotonic_timestamp()}
        new_checked_out = Map.put(state.checked_out, monitor_ref, updated_conn_info)
        new_stats = Map.update!(state.stats, :checkout_count, &(&1 + 1))

        new_state = %{
          state
          | available: remaining_queue,
            checked_out: new_checked_out,
            stats: new_stats
        }

        {:reply, {:ok, conn_info.connection}, new_state}

      {:empty, _} when map_size(state.checked_out) < state.config.max_size ->
        # Create new connection
        case create_new_connection(state) do
          {:ok, conn_info} ->
            monitor_ref = Process.monitor(from_pid)
            new_checked_out = Map.put(state.checked_out, monitor_ref, conn_info)
            new_connections = [conn_info | state.connections]

            new_stats =
              state.stats
              |> Map.update!(:created_connections, &(&1 + 1))
              |> Map.update!(:checkout_count, &(&1 + 1))

            new_state = %{
              state
              | connections: new_connections,
                checked_out: new_checked_out,
                stats: new_stats
            }

            {:reply, {:ok, conn_info.connection}, new_state}

          {:error, reason} ->
            new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
            {:reply, {:error, reason}, %{state | stats: new_stats}}
        end

      {:empty, _} ->
        # Pool exhausted
        {:reply, {:error, :pool_exhausted}, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        available_connections: :queue.len(state.available),
        checked_out_connections: map_size(state.checked_out),
        total_connections: length(state.connections),
        pool_utilization: map_size(state.checked_out) / state.config.max_size
      })

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_cast({:checkin, connection}, state) do
    # Find the connection in checked_out and move to available
    case find_checked_out_connection(connection, state.checked_out) do
      {monitor_ref, conn_info} ->
        Process.demonitor(monitor_ref, [:flush])
        updated_conn_info = %{conn_info | last_used: Utils.monotonic_timestamp()}
        new_available = :queue.in(updated_conn_info, state.available)
        new_checked_out = Map.delete(state.checked_out, monitor_ref)
        new_stats = Map.update!(state.stats, :checkin_count, &(&1 + 1))

        new_state = %{
          state
          | available: new_available,
            checked_out: new_checked_out,
            stats: new_stats
        }

        {:noreply, new_state}

      nil ->
        # Connection not found in checked_out - might be from a different pool
        Logger.warning("Attempted to check in unknown connection to pool #{state.pool_name}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    # Process that checked out a connection died
    case Map.get(state.checked_out, monitor_ref) do
      nil ->
        {:noreply, state}

      conn_info ->
        # Close the connection since the process died
        close_connection(conn_info.connection, state.connection_spec)
        new_checked_out = Map.delete(state.checked_out, monitor_ref)
        new_connections = List.delete(state.connections, conn_info)
        new_stats = Map.update!(state.stats, :destroyed_connections, &(&1 + 1))

        new_state = %{
          state
          | connections: new_connections,
            checked_out: new_checked_out,
            stats: new_stats
        }

        # Ensure we still have minimum connections
        final_state = ensure_min_connections(new_state)
        {:noreply, final_state}
    end
  end

  def handle_info(:health_check, state) do
    new_state = perform_health_checks(state)
    schedule_health_check(state.config.health_check_interval)
    {:noreply, new_state}
  end

  ## Private Functions

  @spec create_new_connection(pool_state()) ::
          {:ok, ConnectionPool.connection_info()} | {:error, term()}
  defp create_new_connection(state) do
    case state.connection_spec.module.create_connection(state.connection_spec.options) do
      {:ok, connection} ->
        conn_info = %{
          connection: connection,
          created_at: Utils.monotonic_timestamp(),
          last_used: Utils.monotonic_timestamp(),
          health_status: :unknown
        }

        {:ok, conn_info}

      {:error, _} = error ->
        error
    end
  end

  @spec close_connection(ConnectionPool.connection(), ConnectionPool.connection_spec()) :: :ok
  defp close_connection(connection, connection_spec) do
    try do
      connection_spec.module.close_connection(connection)
    rescue
      error ->
        Logger.warning("Error closing connection: #{inspect(error)}")
        :ok
    end
  end

  @spec find_checked_out_connection(ConnectionPool.connection(), map()) ::
          {reference(), ConnectionPool.connection_info()} | nil
  defp find_checked_out_connection(connection, checked_out) do
    Enum.find(checked_out, fn {_ref, conn_info} ->
      conn_info.connection == connection
    end)
  end

  @spec ensure_min_connections(pool_state()) :: pool_state()
  defp ensure_min_connections(state) do
    current_count = length(state.connections)
    needed = state.config.min_size - current_count

    if needed > 0 do
      new_connections = create_connections(needed, state)

      new_available =
        Enum.reduce(new_connections, state.available, fn conn_info, queue ->
          :queue.in(conn_info, queue)
        end)

      %{
        state
        | connections: new_connections ++ state.connections,
          available: new_available,
          stats: Map.update!(state.stats, :created_connections, &(&1 + length(new_connections)))
      }
    else
      state
    end
  end

  @spec create_connections(non_neg_integer(), pool_state()) :: [ConnectionPool.connection_info()]
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

  @spec perform_health_checks(pool_state()) :: pool_state()
  defp perform_health_checks(state) do
    # Check health of available connections
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

    # Update connections list
    healthy_connections =
      Enum.filter(state.connections, fn conn_info ->
        conn_info in healthy_available or
          Enum.any?(Map.values(state.checked_out), &(&1 == conn_info))
      end)

    new_state = %{
      state
      | connections: healthy_connections,
        available: new_available,
        stats: Map.update!(state.stats, :destroyed_connections, &(&1 + length(unhealthy_available)))
    }

    # Ensure we still have minimum connections after cleanup
    ensure_min_connections(new_state)
  end

  @spec check_connection_health(ConnectionPool.connection_info(), ConnectionPool.connection_spec()) ::
          boolean()
  defp check_connection_health(conn_info, connection_spec) do
    try do
      # Check if connection is too old (idle timeout)
      now = Utils.monotonic_timestamp()
      idle_time = now - conn_info.last_used

      if idle_time > connection_spec.options[:idle_timeout] do
        false
      else
        # Use custom health check function
        connection_spec.health_check.(conn_info.connection)
      end
    rescue
      _ -> false
    end
  end

  @spec schedule_health_check(pos_integer()) :: reference()
  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end
end

defmodule ElixirScope.Foundation.Infrastructure.DatabaseConnection do
  @moduledoc """
  Example database connection implementation for the connection pool.
  """

  @behaviour ElixirScope.Foundation.Infrastructure.ConnectionPool

  @impl true
  def create_connection(opts) do
    # Simulate database connection creation
    database_url = Keyword.get(opts, :database_url, "postgresql://localhost/test")
    timeout = Keyword.get(opts, :timeout, 5000)

    # In a real implementation, this would use a database driver
    case simulate_database_connect(database_url, timeout) do
      {:ok, conn} -> {:ok, conn}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def close_connection(conn) do
    # Simulate closing database connection
    simulate_database_disconnect(conn)
  end

  @impl true
  def ping_connection(conn) do
    # Simulate database health check
    case simulate_database_ping(conn) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  ## Simulation Functions (replace with real implementation)

  defp simulate_database_connect(_url, _timeout) do
    # Simulate connection creation
    connection_id = :rand.uniform(1000)
    {:ok, %{id: connection_id, created_at: Utils.monotonic_timestamp()}}
  end

  defp simulate_database_disconnect(_conn) do
    # Simulate connection cleanup
    :ok
  end

  defp simulate_database_ping(conn) do
    # Simulate health check - occasionally fail to test error handling
    if :rand.uniform(100) > 95 do
      {:error, :connection_lost}
    else
      :ok
    end
  end
end

defmodule ElixirScope.Foundation.Infrastructure.ConnectionPoolRegistry do
  @moduledoc """
  Registry for managing multiple connection pools.
  """

  alias ElixirScope.Foundation.{ServiceRegistry}
  alias ElixirScope.Foundation.Infrastructure.{ConnectionPool, ConnectionPoolManager}

  @doc """
  Register a new connection pool.
  """
  @spec register_pool(
          ServiceRegistry.namespace(),
          atom(),
          ConnectionPool.connection_spec(),
          ConnectionPool.pool_config()
        ) ::
          {:ok, pid()} | {:error, term()}
  def register_pool(namespace, pool_name, connection_spec, config) do
    ConnectionPoolManager.start_link(
      namespace: namespace,
      pool_name: pool_name,
      connection_spec: connection_spec,
      config: config
    )
  end

  @doc """
  Get connection from a registered pool.
  """
  @spec get_connection(ServiceRegistry.namespace(), atom()) ::
          {:ok, ConnectionPool.connection()} | {:error, term()}
  def get_connection(namespace, pool_name) do
    ConnectionPool.checkout(namespace, pool_name)
  end

  @doc """
  Return connection to a registered pool.
  """
  @spec return_connection(ServiceRegistry.namespace(), atom(), ConnectionPool.connection()) :: :ok
  def return_connection(namespace, pool_name, connection) do
    ConnectionPool.checkin(namespace, pool_name, connection)
  end

  @doc """
  Execute function with pooled connection.
  """
  @spec with_pooled_connection(ServiceRegistry.namespace(), atom(), (ConnectionPool.connection() ->
                                                                       term())) ::
          {:ok, term()} | {:error, term()}
  def with_pooled_connection(namespace, pool_name, fun) do
    ConnectionPool.with_connection(namespace, pool_name, fun)
  end

  @doc """
  Get statistics for all pools in a namespace.
  """
  @spec get_all_pool_stats(ServiceRegistry.namespace()) :: {:ok, map()} | {:error, term()}
  def get_all_pool_stats(namespace) do
    # Find all connection pools in the namespace
    services = ServiceRegistry.list_services(namespace)

    pool_services =
      Enum.filter(services, fn service ->
        case service do
          {:connection_pool, _pool_name} -> true
          _ -> false
        end
      end)

    stats =
      Enum.reduce(pool_services, %{}, fn {:connection_pool, pool_name}, acc ->
        case ConnectionPool.get_pool_stats(namespace, pool_name) do
          {:ok, pool_stats} -> Map.put(acc, pool_name, pool_stats)
          {:error, _} -> acc
        end
      end)

    {:ok, stats}
  end
end
