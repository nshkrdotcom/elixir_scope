defmodule ElixirScope.Foundation.Infrastructure.MemoryManager do
  @moduledoc """
  Memory monitoring and management framework.

  Critical for AST layer which will create large in-memory structures.
  Provides automatic memory monitoring, cleanup, and pressure relief.

  ## Features
  - Process memory tracking
  - Pressure level detection (:low, :medium, :high, :critical)
  - Automatic cleanup strategies
  - Memory usage alerts
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}
  alias ElixirScope.Foundation.Infrastructure.MemoryCleanup

  @type t :: manager_state()

  @type memory_stats :: %{
          total_memory: non_neg_integer(),
          process_memory: non_neg_integer(),
          system_memory: non_neg_integer(),
          threshold_percentage: float(),
          pressure_level: pressure_level()
        }

  @type pressure_level :: :low | :medium | :high | :critical

  @type memory_config :: %{
          check_interval: pos_integer(),
          warning_threshold: float(),
          critical_threshold: float(),
          cleanup_strategies: [module()],
          pressure_relief_enabled: boolean()
        }

  @type manager_state :: %{
          namespace: ServiceRegistry.namespace(),
          config: memory_config(),
          current_stats: memory_stats() | nil,
          pressure_level: pressure_level(),
          last_check: integer(),
          cleanup_history: [map()]
        }

  ## Public API

  @doc """
  Start the memory manager for a namespace.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    namespace = Keyword.get(opts, :namespace, :production)
    config = Keyword.get(opts, :config, default_config())

    name = ServiceRegistry.via_tuple(namespace, :memory_manager)

    GenServer.start_link(
      __MODULE__,
      [namespace: namespace, config: config],
      name: name
    )
  end

  @doc """
  Check current memory pressure level.
  """
  @spec check_pressure(ServiceRegistry.namespace()) :: pressure_level()
  def check_pressure(namespace) do
    case ServiceRegistry.lookup(namespace, :memory_manager) do
      {:ok, pid} -> GenServer.call(pid, :get_pressure)
      # Safe default
      {:error, _} -> :low
    end
  end

  @doc """
  Request cleanup for a specific service.
  """
  @spec request_cleanup(ServiceRegistry.namespace(), atom(), keyword()) :: :ok
  def request_cleanup(namespace, service, opts \\ []) do
    case ServiceRegistry.lookup(namespace, :memory_manager) do
      {:ok, pid} -> GenServer.cast(pid, {:request_cleanup, service, opts})
      {:error, _} -> :ok
    end
  end

  @doc """
  Get current memory statistics.
  """
  @spec get_stats(ServiceRegistry.namespace()) :: {:ok, memory_stats()} | {:error, term()}
  def get_stats(namespace) do
    case ServiceRegistry.lookup(namespace, :memory_manager) do
      {:ok, pid} -> GenServer.call(pid, :get_stats)
      {:error, _} = error -> error
    end
  end

  @doc """
  Check if operation should be allowed based on memory pressure.
  """
  @spec check_operation_allowed(ServiceRegistry.namespace()) :: :ok | {:error, :memory_pressure}
  def check_operation_allowed(namespace) do
    case check_pressure(namespace) do
      :critical -> {:error, :memory_pressure}
      _ -> :ok
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    config = Keyword.fetch!(opts, :config)

    state = %{
      namespace: namespace,
      config: config,
      current_stats: nil,
      pressure_level: :low,
      last_check: Utils.monotonic_timestamp(),
      cleanup_history: []
    }

    # Start periodic memory checking
    schedule_memory_check(config.check_interval)

    Logger.info("Memory manager started for namespace #{inspect(namespace)}")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_pressure, _from, state) do
    {:reply, state.pressure_level, state}
  end

  def handle_call(:get_stats, _from, state) do
    case state.current_stats do
      nil -> {:reply, {:error, :no_stats_available}, state}
      stats -> {:reply, {:ok, stats}, state}
    end
  end

  @impl true
  def handle_cast({:request_cleanup, service, opts}, state) do
    priority = Keyword.get(opts, :priority, :medium)

    spawn(fn ->
      perform_service_cleanup(state.namespace, service, priority)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:check_memory, state) do
    current_stats = collect_memory_stats()
    pressure_level = calculate_pressure_level(current_stats, state.config)

    new_state = %{
      state
      | current_stats: current_stats,
        pressure_level: pressure_level,
        last_check: Utils.monotonic_timestamp()
    }

    # Handle pressure levels
    case pressure_level do
      :critical ->
        new_state = trigger_emergency_cleanup(new_state)
        emit_memory_alert(:critical, current_stats)

      :high ->
        new_state = trigger_proactive_cleanup(new_state)
        emit_memory_alert(:high, current_stats)

      :medium ->
        emit_memory_telemetry(:warning, current_stats)

      :low ->
        emit_memory_telemetry(:normal, current_stats)
    end

    schedule_memory_check(state.config.check_interval)
    {:noreply, new_state}
  end

  ## Private Functions

  @spec default_config() :: memory_config()
  defp default_config do
    %{
      # 30 seconds
      check_interval: 30_000,
      # 70% memory usage
      warning_threshold: 0.7,
      # 90% memory usage
      critical_threshold: 0.9,
      cleanup_strategies: [
        MemoryCleanup.EventStoreCleanup,
        MemoryCleanup.ConfigCacheCleanup,
        MemoryCleanup.TelemetryCleanup
      ],
      pressure_relief_enabled: true
    }
  end

  @spec collect_memory_stats() :: memory_stats()
  defp collect_memory_stats do
    total_memory = :erlang.memory(:total)
    process_memory = :erlang.memory(:processes)
    system_memory = :erlang.memory(:system)

    # Calculate available system memory (simplified)
    available_memory =
      case File.read("/proc/meminfo") do
        {:ok, content} ->
          case Regex.run(~r/MemAvailable:\s+(\d+)\s+kB/, content) do
            [_, kb] -> String.to_integer(kb) * 1024
            # Fallback estimate
            _ -> total_memory * 10
          end

        # Fallback for non-Linux systems
        _ ->
          total_memory * 10
      end

    threshold_percentage = total_memory / available_memory

    pressure_level =
      cond do
        threshold_percentage >= 0.9 -> :critical
        threshold_percentage >= 0.7 -> :high
        threshold_percentage >= 0.5 -> :medium
        true -> :low
      end

    %{
      total_memory: total_memory,
      process_memory: process_memory,
      system_memory: system_memory,
      threshold_percentage: threshold_percentage,
      pressure_level: pressure_level
    }
  end

  @spec calculate_pressure_level(memory_stats(), memory_config()) :: pressure_level()
  defp calculate_pressure_level(stats, config) do
    cond do
      stats.threshold_percentage >= config.critical_threshold -> :critical
      stats.threshold_percentage >= config.warning_threshold -> :high
      stats.threshold_percentage >= 0.5 -> :medium
      true -> :low
    end
  end

  @spec trigger_emergency_cleanup(manager_state()) :: manager_state()
  defp trigger_emergency_cleanup(state) do
    Logger.warning("CRITICAL memory pressure detected, triggering emergency cleanup")

    # Run all cleanup strategies immediately
    Enum.each(state.config.cleanup_strategies, fn strategy ->
      spawn(fn ->
        try do
          strategy.emergency_cleanup(state.namespace)
        rescue
          error -> Logger.error("Emergency cleanup failed for #{strategy}: #{inspect(error)}")
        end
      end)
    end)

    # Record cleanup event
    cleanup_event = %{
      timestamp: Utils.monotonic_timestamp(),
      type: :emergency,
      pressure_level: :critical,
      memory_stats: state.current_stats
    }

    %{state | cleanup_history: [cleanup_event | Enum.take(state.cleanup_history, 9)]}
  end

  @spec trigger_proactive_cleanup(manager_state()) :: manager_state()
  defp trigger_proactive_cleanup(state) do
    Logger.info("High memory pressure detected, triggering proactive cleanup")

    # Run cleanup strategies with lower priority
    Enum.each(state.config.cleanup_strategies, fn strategy ->
      spawn(fn ->
        try do
          strategy.proactive_cleanup(state.namespace)
        rescue
          error -> Logger.warning("Proactive cleanup failed for #{strategy}: #{inspect(error)}")
        end
      end)
    end)

    # Record cleanup event
    cleanup_event = %{
      timestamp: Utils.monotonic_timestamp(),
      type: :proactive,
      pressure_level: :high,
      memory_stats: state.current_stats
    }

    %{state | cleanup_history: [cleanup_event | Enum.take(state.cleanup_history, 9)]}
  end

  @spec perform_service_cleanup(ServiceRegistry.namespace(), atom(), atom()) :: :ok
  defp perform_service_cleanup(namespace, service, priority) do
    Logger.info("Performing #{priority} cleanup for service #{service}")

    case service do
      :event_store ->
        MemoryCleanup.EventStoreCleanup.cleanup(namespace, service, priority: priority)

      :config_server ->
        MemoryCleanup.ConfigCacheCleanup.cleanup(namespace, service, priority: priority)

      :telemetry_service ->
        MemoryCleanup.TelemetryCleanup.cleanup(namespace, service, priority: priority)

      _ ->
        Logger.warning("No cleanup strategy for service #{service}")
    end
  end

  @spec schedule_memory_check(pos_integer()) :: reference()
  defp schedule_memory_check(interval) do
    Process.send_after(self(), :check_memory, interval)
  end

  @spec emit_memory_alert(atom(), memory_stats()) :: :ok
  defp emit_memory_alert(level, stats) do
    try do
      ElixirScope.Foundation.Telemetry.execute(
        [:foundation, :memory, :alert],
        %{
          total_memory: stats.total_memory,
          threshold_percentage: stats.threshold_percentage
        },
        %{level: level, pressure: stats.pressure_level}
      )
    rescue
      _ -> :ok
    end
  end

  @spec emit_memory_telemetry(atom(), memory_stats()) :: :ok
  defp emit_memory_telemetry(type, stats) do
    try do
      ElixirScope.Foundation.Telemetry.execute(
        [:foundation, :memory, type],
        %{
          total_memory: stats.total_memory,
          process_memory: stats.process_memory,
          threshold_percentage: stats.threshold_percentage
        },
        %{pressure: stats.pressure_level}
      )
    rescue
      _ -> :ok
    end
  end
end

defmodule ElixirScope.Foundation.Infrastructure.MemoryCleanup do
  @moduledoc """
  Behaviour for memory cleanup strategies.
  """

  @callback cleanup(ServiceRegistry.namespace(), atom(), keyword()) :: :ok | {:error, term()}
  @callback proactive_cleanup(ServiceRegistry.namespace()) :: :ok | {:error, term()}
  @callback emergency_cleanup(ServiceRegistry.namespace()) :: :ok | {:error, term()}

  defmodule EventStoreCleanup do
    @moduledoc """
    Memory cleanup strategy for EventStore.
    """

    @behaviour ElixirScope.Foundation.Infrastructure.MemoryCleanup

    @impl true
    def cleanup(namespace, :event_store, opts) do
      priority = Keyword.get(opts, :priority, :medium)

      case priority do
        :critical -> emergency_cleanup(namespace)
        :high -> proactive_cleanup(namespace)
        _ -> gentle_cleanup(namespace)
      end
    end

    @impl true
    def proactive_cleanup(namespace) do
      # Keep last hour of events
      cutoff_time = Utils.monotonic_timestamp() - 3_600_000

      try do
        case ServiceRegistry.lookup(namespace, :event_store) do
          {:ok, _pid} ->
            ElixirScope.Foundation.Events.prune_before(cutoff_time)
            :ok

          {:error, _} ->
            :ok
        end
      rescue
        error -> {:error, error}
      end
    end

    @impl true
    def emergency_cleanup(namespace) do
      # Keep only last 10 minutes of events
      cutoff_time = Utils.monotonic_timestamp() - 600_000

      try do
        case ServiceRegistry.lookup(namespace, :event_store) do
          {:ok, _pid} ->
            ElixirScope.Foundation.Events.prune_before(cutoff_time)
            :ok

          {:error, _} ->
            :ok
        end
      rescue
        error -> {:error, error}
      end
    end

    defp gentle_cleanup(namespace) do
      # Keep last 24 hours of events
      cutoff_time = Utils.monotonic_timestamp() - 86_400_000

      try do
        case ServiceRegistry.lookup(namespace, :event_store) do
          {:ok, _pid} ->
            ElixirScope.Foundation.Events.prune_before(cutoff_time)
            :ok

          {:error, _} ->
            :ok
        end
      rescue
        error -> {:error, error}
      end
    end
  end

  defmodule ConfigCacheCleanup do
    @moduledoc """
    Memory cleanup strategy for ConfigServer caches.
    """

    @behaviour ElixirScope.Foundation.Infrastructure.MemoryCleanup

    @impl true
    def cleanup(namespace, :config_server, _opts) do
      # ConfigServer doesn't have significant caches to clean in current implementation
      :ok
    end

    @impl true
    def proactive_cleanup(_namespace) do
      # Force garbage collection
      :erlang.garbage_collect()
      :ok
    end

    @impl true
    def emergency_cleanup(_namespace) do
      # Force garbage collection on all processes
      for pid <- Process.list() do
        :erlang.garbage_collect(pid)
      end

      :ok
    end
  end

  defmodule TelemetryCleanup do
    @moduledoc """
    Memory cleanup strategy for TelemetryService.
    """

    @behaviour ElixirScope.Foundation.Infrastructure.MemoryCleanup

    @impl true
    def cleanup(namespace, :telemetry_service, opts) do
      priority = Keyword.get(opts, :priority, :medium)

      try do
        case ServiceRegistry.lookup(namespace, :telemetry_service) do
          {:ok, _pid} ->
            case priority do
              :critical -> ElixirScope.Foundation.Telemetry.reset_metrics()
              # TelemetryService has automatic cleanup
              _ -> :ok
            end

          {:error, _} ->
            :ok
        end
      rescue
        error -> {:error, error}
      end
    end

    @impl true
    def proactive_cleanup(_namespace) do
      # Telemetry cleanup is handled automatically by the service
      :ok
    end

    @impl true
    def emergency_cleanup(namespace) do
      try do
        case ServiceRegistry.lookup(namespace, :telemetry_service) do
          {:ok, _pid} -> ElixirScope.Foundation.Telemetry.reset_metrics()
          {:error, _} -> :ok
        end
      rescue
        _ -> :ok
      end
    end
  end
end
