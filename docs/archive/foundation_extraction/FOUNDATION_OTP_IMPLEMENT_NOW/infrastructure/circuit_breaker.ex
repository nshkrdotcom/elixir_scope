defmodule ElixirScope.Foundation.Infrastructure.CircuitBreaker do
  @moduledoc """
  Circuit Breaker GenServer implementation for Foundation service protection.

  Provides automatic failure detection and recovery with graceful degradation.
  Establishes resilience patterns for higher layers (AST, etc.).

  ## States
  - :closed - Normal operation, requests pass through
  - :open - Failure threshold exceeded, requests fail fast
  - :half_open - Testing if service has recovered

  ## Configuration
  - failure_threshold: Number of consecutive failures before opening
  - reset_timeout: Time to wait before attempting reset
  - call_timeout: Maximum time for individual operations
  - monitor_window: Time window for failure counting
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}
  alias ElixirScope.Foundation.Types.Error

  @type state :: :closed | :open | :half_open
  @type t :: circuit_state()

  @type circuit_config :: %{
          failure_threshold: pos_integer(),
          reset_timeout: pos_integer(),
          call_timeout: pos_integer(),
          monitor_window: pos_integer()
        }

  @type circuit_stats :: %{
          failure_count: non_neg_integer(),
          success_count: non_neg_integer(),
          last_failure_time: integer() | nil,
          state_changes: non_neg_integer(),
          total_calls: non_neg_integer()
        }

  @type circuit_state :: %{
          service: atom(),
          namespace: ServiceRegistry.namespace(),
          config: circuit_config(),
          state: state(),
          stats: circuit_stats(),
          failure_times: [integer()],
          last_reset_attempt: integer() | nil
        }

  ## Public API

  @doc """
  Start a circuit breaker for a service.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    service = Keyword.fetch!(opts, :service)
    namespace = Keyword.get(opts, :namespace, :production)
    config = Keyword.get(opts, :config, default_config())

    name = ServiceRegistry.via_tuple(namespace, {:circuit_breaker, service})

    GenServer.start_link(
      __MODULE__,
      [service: service, namespace: namespace, config: config],
      name: name
    )
  end

  @doc """
  Execute an operation through the circuit breaker.
  """
  @spec execute(ServiceRegistry.namespace(), atom(), (-> term())) ::
          {:ok, term()} | {:error, :circuit_open} | {:error, term()}
  def execute(namespace, service, operation) when is_function(operation, 0) do
    case ServiceRegistry.lookup(namespace, {:circuit_breaker, service}) do
      {:ok, pid} -> GenServer.call(pid, {:execute, operation})
      # No circuit breaker, execute directly
      {:error, _} -> operation.()
    end
  end

  @doc """
  Check circuit breaker state.
  """
  @spec check_state(ServiceRegistry.namespace(), atom()) ::
          {:ok, state()} | {:error, term()}
  def check_state(namespace, service) do
    case ServiceRegistry.lookup(namespace, {:circuit_breaker, service}) do
      {:ok, pid} -> GenServer.call(pid, :get_state)
      {:error, _} = error -> error
    end
  end

  @doc """
  Get circuit breaker statistics.
  """
  @spec get_stats(ServiceRegistry.namespace(), atom()) ::
          {:ok, circuit_stats()} | {:error, term()}
  def get_stats(namespace, service) do
    case ServiceRegistry.lookup(namespace, {:circuit_breaker, service}) do
      {:ok, pid} -> GenServer.call(pid, :get_stats)
      {:error, _} = error -> error
    end
  end

  @doc """
  Reset circuit breaker to closed state (for testing/admin).
  """
  @spec reset(ServiceRegistry.namespace(), atom()) :: :ok | {:error, term()}
  def reset(namespace, service) do
    case ServiceRegistry.lookup(namespace, {:circuit_breaker, service}) do
      {:ok, pid} -> GenServer.call(pid, :reset)
      {:error, _} = error -> error
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    service = Keyword.fetch!(opts, :service)
    namespace = Keyword.fetch!(opts, :namespace)
    config = Keyword.fetch!(opts, :config)

    state = %{
      service: service,
      namespace: namespace,
      config: config,
      state: :closed,
      stats: %{
        failure_count: 0,
        success_count: 0,
        last_failure_time: nil,
        state_changes: 0,
        total_calls: 0
      },
      failure_times: [],
      last_reset_attempt: nil
    }

    Logger.info("Circuit breaker started for #{service} in #{inspect(namespace)}")
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, operation}, _from, %{state: :closed} = state) do
    case safe_execute(operation, state.config.call_timeout) do
      {:ok, result} ->
        new_state = record_success(state)
        {:reply, {:ok, result}, new_state}

      {:error, reason} ->
        new_state = record_failure(state)
        new_state = maybe_trip_circuit(new_state)
        {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call({:execute, _operation}, _from, %{state: :open} = state) do
    if should_attempt_reset?(state) do
      {:reply, {:error, :circuit_open},
       %{state | state: :half_open, last_reset_attempt: Utils.monotonic_timestamp()}}
    else
      {:reply, {:error, :circuit_open}, state}
    end
  end

  def handle_call({:execute, operation}, _from, %{state: :half_open} = state) do
    case safe_execute(operation, state.config.call_timeout) do
      {:ok, result} ->
        # Success in half-open state closes the circuit
        new_state = %{
          state
          | state: :closed,
            stats: %{
              state.stats
              | success_count: state.stats.success_count + 1,
                total_calls: state.stats.total_calls + 1,
                state_changes: state.stats.state_changes + 1
            },
            failure_times: []
        }

        emit_circuit_telemetry(state.service, :closed, new_state.stats)
        {:reply, {:ok, result}, new_state}

      {:error, reason} ->
        # Failure in half-open state reopens the circuit
        new_state = %{
          state
          | state: :open,
            stats: %{
              state.stats
              | failure_count: state.stats.failure_count + 1,
                total_calls: state.stats.total_calls + 1,
                last_failure_time: Utils.monotonic_timestamp(),
                state_changes: state.stats.state_changes + 1
            }
        }

        emit_circuit_telemetry(state.service, :opened, new_state.stats)
        {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state.state}, state}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, {:ok, state.stats}, state}
  end

  def handle_call(:reset, _from, state) do
    new_state = %{
      state
      | state: :closed,
        stats: %{state.stats | state_changes: state.stats.state_changes + 1},
        failure_times: [],
        last_reset_attempt: nil
    }

    emit_circuit_telemetry(state.service, :reset, new_state.stats)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:cleanup_old_failures, state) do
    now = Utils.monotonic_timestamp()
    cutoff = now - state.config.monitor_window

    new_failure_times = Enum.filter(state.failure_times, fn time -> time > cutoff end)
    new_state = %{state | failure_times: new_failure_times}

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_old_failures, state.config.monitor_window)
    {:noreply, new_state}
  end

  ## Private Functions

  @spec default_config() :: circuit_config()
  defp default_config do
    %{
      failure_threshold: 5,
      # 30 seconds
      reset_timeout: 30_000,
      # 5 seconds
      call_timeout: 5_000,
      # 1 minute
      monitor_window: 60_000
    }
  end

  @spec safe_execute((-> term()), pos_integer()) :: {:ok, term()} | {:error, term()}
  defp safe_execute(operation, timeout) do
    task = Task.async(operation)

    case Task.yield(task, timeout) do
      {:ok, result} ->
        {:ok, result}

      nil ->
        Task.shutdown(task, :brutal_kill)
        {:error, :timeout}
    end
  rescue
    error -> {:error, error}
  end

  @spec record_success(circuit_state()) :: circuit_state()
  defp record_success(state) do
    %{
      state
      | stats: %{
          state.stats
          | success_count: state.stats.success_count + 1,
            total_calls: state.stats.total_calls + 1
        }
    }
  end

  @spec record_failure(circuit_state()) :: circuit_state()
  defp record_failure(state) do
    now = Utils.monotonic_timestamp()

    %{
      state
      | stats: %{
          state.stats
          | failure_count: state.stats.failure_count + 1,
            total_calls: state.stats.total_calls + 1,
            last_failure_time: now
        },
        failure_times: [now | state.failure_times]
    }
  end

  @spec maybe_trip_circuit(circuit_state()) :: circuit_state()
  defp maybe_trip_circuit(state) do
    if length(state.failure_times) >= state.config.failure_threshold do
      new_state = %{
        state
        | state: :open,
          stats: %{state.stats | state_changes: state.stats.state_changes + 1}
      }

      emit_circuit_telemetry(state.service, :opened, new_state.stats)
      new_state
    else
      state
    end
  end

  @spec should_attempt_reset?(circuit_state()) :: boolean()
  defp should_attempt_reset?(state) do
    case state.last_reset_attempt do
      nil ->
        true

      last_attempt ->
        Utils.monotonic_timestamp() - last_attempt >= state.config.reset_timeout
    end
  end

  @spec emit_circuit_telemetry(atom(), atom(), circuit_stats()) :: :ok
  defp emit_circuit_telemetry(service, state_change, stats) do
    try do
      ElixirScope.Foundation.Telemetry.execute(
        [:foundation, :circuit_breaker, state_change],
        %{
          failure_count: stats.failure_count,
          success_count: stats.success_count,
          total_calls: stats.total_calls
        },
        %{service: service}
      )
    rescue
      # Don't let telemetry failures break circuit breaker
      _ -> :ok
    end
  end
end

defmodule ElixirScope.Foundation.Infrastructure.CircuitBreakerRegistry do
  @moduledoc """
  Registry for managing circuit breakers across services.
  """

  alias ElixirScope.Foundation.{ServiceRegistry}
  alias ElixirScope.Foundation.Infrastructure.CircuitBreaker

  @doc """
  Register a circuit breaker for a service.
  """
  @spec register_circuit(ServiceRegistry.namespace(), atom(), CircuitBreaker.circuit_config()) ::
          {:ok, pid()} | {:error, term()}
  def register_circuit(namespace, service, config) do
    CircuitBreaker.start_link(
      service: service,
      namespace: namespace,
      config: config
    )
  end

  @doc """
  Execute operation with circuit breaker protection.
  """
  @spec protected_call(ServiceRegistry.namespace(), atom(), (-> term())) ::
          {:ok, term()} | {:error, term()}
  def protected_call(namespace, service, operation) do
    CircuitBreaker.execute(namespace, service, operation)
  end

  @doc """
  Get health status of all circuit breakers in namespace.
  """
  @spec health_check(ServiceRegistry.namespace()) :: %{atom() => map()}
  def health_check(namespace) do
    services = ServiceRegistry.list_services(namespace)

    Enum.reduce(services, %{}, fn service, acc ->
      case CircuitBreaker.get_stats(namespace, service) do
        {:ok, stats} ->
          Map.put(acc, service, %{status: :healthy, stats: stats})

        {:error, _} ->
          Map.put(acc, service, %{status: :no_circuit_breaker})
      end
    end)
  end
end
