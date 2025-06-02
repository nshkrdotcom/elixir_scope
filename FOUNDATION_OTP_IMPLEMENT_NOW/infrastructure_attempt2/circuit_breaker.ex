defmodule ElixirScope.Foundation.Infrastructure.CircuitBreaker do
  @moduledoc """
  Enhanced Circuit Breaker with insights from Fuse library.

  Incorporates gradual degradation, fault injection, and comprehensive
  timer management patterns from battle-tested Erlang implementations.
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  # Enhanced state types with gradual degradation
  @type state :: :closed | :open | :half_open | {:degraded, severity()}
  @type severity :: :light | :medium | :heavy

  @type circuit_config :: %{
          failure_threshold: pos_integer(),
          reset_timeout: pos_integer(),
          call_timeout: pos_integer(),
          monitor_window: pos_integer(),
          # Enhanced configuration from Fuse insights
          degradation_threshold: pos_integer(),
          health_check_interval: pos_integer(),
          strategy: :fail_fast | :gradual_degradation,
          fault_injection: fault_injection_config()
        }

  @type fault_injection_config :: %{
          enabled: boolean(),
          failure_rate: float(),
          chaos_mode: boolean()
        }

  @type circuit_stats :: %{
          failure_count: non_neg_integer(),
          success_count: non_neg_integer(),
          last_failure_time: integer() | nil,
          state_changes: non_neg_integer(),
          total_calls: non_neg_integer(),
          # Enhanced stats
          degradation_level: severity() | nil,
          recovery_attempts: non_neg_integer()
        }

  @type circuit_state :: %{
          service: atom(),
          namespace: ServiceRegistry.namespace(),
          config: circuit_config(),
          state: state(),
          stats: circuit_stats(),
          failure_times: [integer()],
          last_reset_attempt: integer() | nil,
          timer_ref: reference() | nil,
          degradation_start: integer() | nil
        }

  ## Public API

  @doc """
  Start a circuit breaker for a service with enhanced configuration.
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
  Execute an operation through the circuit breaker with enhanced protection.
  """
  @spec execute(ServiceRegistry.namespace(), atom(), (-> term())) ::
          {:ok, term()} | {:error, :circuit_open} | {:error, term()}
  def execute(namespace, service, operation) when is_function(operation, 0) do
    case ServiceRegistry.lookup(namespace, {:circuit_breaker, service}) do
      {:ok, pid} -> GenServer.call(pid, {:execute, operation})
      {:error, _} -> operation.()
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
        total_calls: 0,
        degradation_level: nil,
        recovery_attempts: 0
      },
      failure_times: [],
      last_reset_attempt: nil,
      timer_ref: nil,
      degradation_start: nil
    }

    # Schedule health checks if enabled
    if config.health_check_interval > 0 do
      schedule_health_check(config.health_check_interval)
    end

    Logger.info("Enhanced circuit breaker started for #{service} in #{inspect(namespace)}")
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, operation}, _from, %{state: :closed} = state) do
    # Check for fault injection (chaos engineering)
    if should_inject_fault?(state.config) do
      new_state = record_failure(state)
      new_state = maybe_transition_state(new_state)
      {:reply, {:error, :fault_injected}, new_state}
    else
      execute_operation(operation, state)
    end
  end

  def handle_call({:execute, _operation}, _from, %{state: :open} = state) do
    if should_attempt_reset?(state) do
      # Transition to half-open and reset timer
      new_state = cleanup_timer(state)
      new_state = %{new_state |
        state: :half_open,
        last_reset_attempt: Utils.monotonic_timestamp(),
        stats: %{state.stats | recovery_attempts: state.stats.recovery_attempts + 1}
      }
      {:reply, {:error, :circuit_open}, new_state}
    else
      {:reply, {:error, :circuit_open}, state}
    end
  end

  def handle_call({:execute, operation}, _from, %{state: :half_open} = state) do
    execute_operation(operation, state)
  end

  # Handle degraded states with severity levels
  def handle_call({:execute, operation}, _from, %{state: {:degraded, severity}} = state) do
    case should_allow_degraded_request?(severity) do
      true -> execute_operation(operation, state)
      false -> {:reply, {:error, :service_degraded}, state}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    new_state = perform_health_check(state)
    schedule_health_check(state.config.health_check_interval)
    {:noreply, new_state}
  end

  def handle_info(:reset_timeout, state) do
    # Timer fired, attempt to close circuit if appropriate
    new_state = attempt_circuit_reset(state)
    {:noreply, new_state}
  end

  def handle_info(:cleanup_old_failures, state) do
    now = Utils.monotonic_timestamp()
    cutoff = now - state.config.monitor_window

    new_failure_times = Enum.filter(state.failure_times, fn time -> time > cutoff end)
    new_state = %{state | failure_times: new_failure_times}

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_old_failures, state.config.monitor_window)
    {:noreply, new_state}
  end

  ## Enhanced Private Functions

  @spec default_config() :: circuit_config()
  defp default_config do
    %{
      failure_threshold: 5,
      reset_timeout: 30_000,
      call_timeout: 5_000,
      monitor_window: 60_000,
      # Enhanced configuration
      degradation_threshold: 3,
      health_check_interval: 10_000,
      strategy: :gradual_degradation,
      fault_injection: %{
        enabled: false,
        failure_rate: 0.0,
        chaos_mode: false
      }
    }
  end

  @spec execute_operation((-> term()), circuit_state()) ::
    {:reply, {:ok, term()} | {:error, term()}, circuit_state()}
  defp execute_operation(operation, state) do
    case safe_execute_with_timeout(operation, state.config.call_timeout) do
      {:ok, result} ->
        new_state = record_success(state)
        new_state = maybe_transition_state(new_state)
        {:reply, {:ok, result}, new_state}

      {:error, reason} ->
        new_state = record_failure(state)
        new_state = maybe_transition_state(new_state)
        {:reply, {:error, reason}, new_state}
    end
  end

  @spec safe_execute_with_timeout((-> term()), pos_integer()) ::
    {:ok, term()} | {:error, term()}
  defp safe_execute_with_timeout(operation, timeout) do
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

  @spec maybe_transition_state(circuit_state()) :: circuit_state()
  defp maybe_transition_state(state) do
    case state.config.strategy do
      :fail_fast -> maybe_trip_circuit_fast(state)
      :gradual_degradation -> maybe_degrade_gradually(state)
    end
  end

  @spec maybe_trip_circuit_fast(circuit_state()) :: circuit_state()
  defp maybe_trip_circuit_fast(state) do
    if length(state.failure_times) >= state.config.failure_threshold do
      transition_to_open(state)
    else
      state
    end
  end

  @spec maybe_degrade_gradually(circuit_state()) :: circuit_state()
  defp maybe_degrade_gradually(state) do
    failure_count = length(state.failure_times)

    cond do
      failure_count >= state.config.failure_threshold ->
        transition_to_open(state)
      failure_count >= state.config.degradation_threshold ->
        transition_to_degraded(state, calculate_degradation_severity(failure_count, state.config))
      state.state == {:degraded, _} and failure_count < state.config.degradation_threshold ->
        transition_to_closed(state)
      true ->
        state
    end
  end

  @spec transition_to_open(circuit_state()) :: circuit_state()
  defp transition_to_open(state) do
    new_state = cleanup_timer(state)
    timer_ref = schedule_reset_timer(state.config.reset_timeout)

    new_state = %{
      new_state
      | state: :open,
        timer_ref: timer_ref,
        stats: %{state.stats | state_changes: state.stats.state_changes + 1}
    }

    emit_circuit_telemetry(state.service, :opened, new_state.stats)
    new_state
  end

  @spec transition_to_degraded(circuit_state(), severity()) :: circuit_state()
  defp transition_to_degraded(state, severity) do
    now = Utils.monotonic_timestamp()

    new_state = %{
      state
      | state: {:degraded, severity},
        degradation_start: now,
        stats: %{
          state.stats
          | state_changes: state.stats.state_changes + 1,
            degradation_level: severity
        }
    }

    emit_circuit_telemetry(state.service, :degraded, new_state.stats)
    new_state
  end

  @spec transition_to_closed(circuit_state()) :: circuit_state()
  defp transition_to_closed(state) do
    new_state = cleanup_timer(state)

    new_state = %{
      new_state
      | state: :closed,
        degradation_start: nil,
        stats: %{
          state.stats
          | state_changes: state.stats.state_changes + 1,
            degradation_level: nil
        }
    }

    emit_circuit_telemetry(state.service, :closed, new_state.stats)
    new_state
  end

  @spec cleanup_timer(circuit_state()) :: circuit_state()
  defp cleanup_timer(%{timer_ref: nil} = state), do: state
  defp cleanup_timer(%{timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end

  @spec schedule_reset_timer(pos_integer()) :: reference()
  defp schedule_reset_timer(timeout) do
    Process.send_after(self(), :reset_timeout, timeout)
  end

  @spec should_attempt_reset?(circuit_state()) :: boolean()
  defp should_attempt_reset?(state) do
    case state.last_reset_attempt do
      nil -> true
      last_attempt ->
        Utils.monotonic_timestamp() - last_attempt >= state.config.reset_timeout
    end
  end

  @spec should_inject_fault?(circuit_config()) :: boolean()
  defp should_inject_fault?(config) do
    config.fault_injection.enabled and
    :rand.uniform() < config.fault_injection.failure_rate
  end

  @spec should_allow_degraded_request?(severity()) :: boolean()
  defp should_allow_degraded_request?(severity) do
    case severity do
      :light -> :rand.uniform() < 0.8  # Allow 80% of requests
      :medium -> :rand.uniform() < 0.5  # Allow 50% of requests
      :heavy -> :rand.uniform() < 0.2   # Allow 20% of requests
    end
  end

  @spec calculate_degradation_severity(non_neg_integer(), circuit_config()) :: severity()
  defp calculate_degradation_severity(failure_count, config) do
    ratio = failure_count / config.failure_threshold

    cond do
      ratio >= 0.8 -> :heavy
      ratio >= 0.6 -> :medium
      true -> :light
    end
  end

  @spec perform_health_check(circuit_state()) :: circuit_state()
  defp perform_health_check(state) do
    # Implement health check logic based on service type
    # This could include checking dependencies, resource availability, etc.
    state
  end

  @spec attempt_circuit_reset(circuit_state()) :: circuit_state()
  defp attempt_circuit_reset(%{state: :open} = state) do
    # Attempt to transition to half-open
    %{
      state
      | state: :half_open,
        stats: %{state.stats | recovery_attempts: state.stats.recovery_attempts + 1}
    }
  end
  defp attempt_circuit_reset(state), do: state

  @spec schedule_health_check(pos_integer()) :: reference()
  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end

  @spec emit_circuit_telemetry(atom(), atom(), circuit_stats()) :: :ok
  defp emit_circuit_telemetry(service, state_change, stats) do
    try do
      ElixirScope.Foundation.Telemetry.execute(
        [:foundation, :circuit_breaker, state_change],
        %{
          failure_count: stats.failure_count,
          success_count: stats.success_count,
          total_calls: stats.total_calls,
          recovery_attempts: stats.recovery_attempts
        },
        %{
          service: service,
          degradation_level: stats.degradation_level
        }
      )
    rescue
      _ -> :ok
    end
  end
end
