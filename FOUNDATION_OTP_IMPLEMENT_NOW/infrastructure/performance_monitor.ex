defmodule ElixirScope.Foundation.Infrastructure.PerformanceMonitor do
  @moduledoc """
  Performance monitoring infrastructure for Foundation services.

  Establishes baseline performance metrics and monitoring patterns for higher layers.
  Provides comprehensive performance monitoring with alerting and trending.

  ## Metric Types
  - :latency - Operation duration measurements
  - :throughput - Operations per second
  - :error_rate - Error percentage over time
  - :resource_usage - Memory, CPU, process counts
  """

  use GenServer
  require Logger

  alias ElixirScope.Foundation.{ServiceRegistry, Utils}

  @type t :: performance_metric()

  @type metric_type :: :latency | :throughput | :error_rate | :resource_usage
  @type performance_metric :: %{
          type: metric_type(),
          name: String.t(),
          value: number(),
          unit: atom(),
          tags: map(),
          timestamp: DateTime.t()
        }

  @type performance_summary :: %{
          service: atom(),
          metrics: [performance_metric()],
          period_start: DateTime.t(),
          period_end: DateTime.t(),
          aggregations: map()
        }

  @type time_window :: :minute | :hour | :day
  @type aggregation_type :: :avg | :min | :max | :p50 | :p95 | :p99

  ## Public API

  @doc """
  Start performance monitor for a namespace.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    namespace = Keyword.get(opts, :namespace, :production)
    name = ServiceRegistry.via_tuple(namespace, :performance_monitor)
    GenServer.start_link(__MODULE__, [namespace: namespace], name: name)
  end

  @doc """
  Record a latency metric.
  """
  @spec record_latency(ServiceRegistry.namespace(), [atom()], number(), map()) :: :ok
  def record_latency(namespace, event_name, duration_us, tags \\ %{}) do
    metric = %{
      type: :latency,
      name: format_event_name(event_name),
      value: duration_us,
      unit: :microseconds,
      tags: tags,
      timestamp: DateTime.utc_now()
    }

    record_metric(namespace, metric)
  end

  @doc """
  Record a throughput metric.
  """
  @spec record_throughput(ServiceRegistry.namespace(), [atom()], number(), map()) :: :ok
  def record_throughput(namespace, event_name, ops_per_second, tags \\ %{}) do
    metric = %{
      type: :throughput,
      name: format_event_name(event_name),
      value: ops_per_second,
      unit: :ops_per_second,
      tags: tags,
      timestamp: DateTime.utc_now()
    }

    record_metric(namespace, metric)
  end

  @doc """
  Record an error rate metric.
  """
  @spec record_error_rate(ServiceRegistry.namespace(), [atom()], float(), map()) :: :ok
  def record_error_rate(namespace, event_name, error_percentage, tags \\ %{}) do
    metric = %{
      type: :error_rate,
      name: format_event_name(event_name),
      value: error_percentage,
      unit: :percentage,
      tags: tags,
      timestamp: DateTime.utc_now()
    }

    record_metric(namespace, metric)
  end

  @doc """
  Get metrics for a service within a time window.
  """
  @spec get_metrics(ServiceRegistry.namespace(), atom(), time_window(), aggregation_type()) ::
          {:ok, [performance_metric()]} | {:error, term()}
  def get_metrics(namespace, service, time_window, aggregation) do
    case ServiceRegistry.lookup(namespace, :performance_monitor) do
      {:ok, pid} ->
        GenServer.call(pid, {:get_metrics, service, time_window, aggregation})

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Get performance summary for all services.
  """
  @spec get_performance_summary(ServiceRegistry.namespace()) ::
          {:ok, [performance_summary()]} | {:error, term()}
  def get_performance_summary(namespace) do
    case ServiceRegistry.lookup(namespace, :performance_monitor) do
      {:ok, pid} -> GenServer.call(pid, :get_performance_summary)
      {:error, _} = error -> error
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    namespace = Keyword.fetch!(opts, :namespace)

    state = %{
      namespace: namespace,
      metrics: %{},
      baselines: %{},
      alert_rules: load_alert_rules(),
      last_cleanup: Utils.monotonic_timestamp()
    }

    # Schedule periodic cleanup and aggregation
    schedule_cleanup()
    schedule_baseline_calculation()

    Logger.info("Performance monitor started for namespace #{inspect(namespace)}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:record_metric, metric}, state) do
    new_state = store_metric(metric, state)
    new_state = maybe_trigger_aggregation(new_state)
    new_state = maybe_trigger_alerting(metric, new_state)

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_metrics, service, time_window, aggregation}, _from, state) do
    metrics = aggregate_metrics(service, time_window, aggregation, state.metrics)
    {:reply, {:ok, metrics}, state}
  end

  def handle_call(:get_performance_summary, _from, state) do
    services = ServiceRegistry.list_services(state.namespace)

    summaries =
      Enum.map(services, fn service ->
        service_metrics = get_service_metrics(service, state.metrics)

        %{
          service: service,
          metrics: service_metrics,
          period_start: get_period_start(service_metrics),
          period_end: get_period_end(service_metrics),
          aggregations: calculate_service_aggregations(service_metrics)
        }
      end)

    {:reply, {:ok, summaries}, state}
  end

  @impl true
  def handle_info(:cleanup_old_metrics, state) do
    new_state = cleanup_old_metrics(state)
    schedule_cleanup()
    {:noreply, new_state}
  end

  def handle_info(:calculate_baselines, state) do
    new_state = calculate_performance_baselines(state)
    schedule_baseline_calculation()
    {:noreply, new_state}
  end

  ## Private Functions

  @spec record_metric(ServiceRegistry.namespace(), performance_metric()) :: :ok
  defp record_metric(namespace, metric) do
    case ServiceRegistry.lookup(namespace, :performance_monitor) do
      {:ok, pid} -> GenServer.cast(pid, {:record_metric, metric})
      # Fail silently for performance monitoring
      {:error, _} -> :ok
    end
  end

  @spec format_event_name([atom()]) :: String.t()
  defp format_event_name(event_name) when is_list(event_name) do
    event_name |> Enum.map(&Atom.to_string/1) |> Enum.join(".")
  end

  @spec store_metric(performance_metric(), map()) :: map()
  defp store_metric(metric, state) do
    time_bucket = time_bucket(metric.timestamp, :minute)
    bucket_key = {metric.name, time_bucket}

    bucket_metrics = Map.get(state.metrics, bucket_key, [])
    new_metrics = Map.put(state.metrics, bucket_key, [metric | bucket_metrics])

    %{state | metrics: new_metrics}
  end

  @spec time_bucket(DateTime.t(), time_window()) :: DateTime.t()
  defp time_bucket(timestamp, :minute) do
    %{timestamp | second: 0, microsecond: {0, 0}}
  end

  defp time_bucket(timestamp, :hour) do
    %{timestamp | minute: 0, second: 0, microsecond: {0, 0}}
  end

  defp time_bucket(timestamp, :day) do
    %{timestamp | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  @spec aggregate_metrics(atom(), time_window(), aggregation_type(), map()) :: [
          performance_metric()
        ]
  defp aggregate_metrics(service, time_window, aggregation, metrics) do
    service_name = Atom.to_string(service)

    relevant_metrics =
      metrics
      |> Enum.filter(fn {{metric_name, _}, _} ->
        String.contains?(metric_name, service_name)
      end)
      |> Enum.flat_map(fn {_, metric_list} -> metric_list end)
      |> Enum.filter(&in_time_window?(&1, time_window))

    apply_aggregation(relevant_metrics, aggregation)
  end

  @spec in_time_window?(performance_metric(), time_window()) :: boolean()
  defp in_time_window?(metric, time_window) do
    now = DateTime.utc_now()

    cutoff =
      case time_window do
        :minute -> DateTime.add(now, -60, :second)
        :hour -> DateTime.add(now, -3600, :second)
        :day -> DateTime.add(now, -86400, :second)
      end

    DateTime.compare(metric.timestamp, cutoff) != :lt
  end

  @spec apply_aggregation([performance_metric()], aggregation_type()) :: [performance_metric()]
  defp apply_aggregation([], _), do: []

  defp apply_aggregation(metrics, aggregation) do
    grouped = Enum.group_by(metrics, &{&1.type, &1.name})

    Enum.map(grouped, fn {{type, name}, metric_group} ->
      values = Enum.map(metric_group, & &1.value)

      aggregated_value =
        case aggregation do
          :avg -> Enum.sum(values) / length(values)
          :min -> Enum.min(values)
          :max -> Enum.max(values)
          :p50 -> percentile(values, 0.5)
          :p95 -> percentile(values, 0.95)
          :p99 -> percentile(values, 0.99)
        end

      %{
        type: type,
        name: name,
        value: aggregated_value,
        unit: hd(metric_group).unit,
        tags: %{aggregation: aggregation, sample_count: length(values)},
        timestamp: DateTime.utc_now()
      }
    end)
  end

  @spec percentile([number()], float()) :: number()
  defp percentile(values, p) when p >= 0 and p <= 1 do
    sorted = Enum.sort(values)
    count = length(sorted)
    index = trunc(p * (count - 1))
    Enum.at(sorted, index, 0)
  end

  @spec maybe_trigger_aggregation(map()) :: map()
  defp maybe_trigger_aggregation(state) do
    # Trigger aggregation every 60 seconds
    if Utils.monotonic_timestamp() - state.last_cleanup > 60_000 do
      spawn(fn ->
        perform_metric_aggregation(state.namespace)
      end)
    end

    state
  end

  @spec maybe_trigger_alerting(performance_metric(), map()) :: map()
  defp maybe_trigger_alerting(metric, state) do
    Enum.each(state.alert_rules, fn rule ->
      if matches_alert_rule?(metric, rule) do
        trigger_performance_alert(metric, rule, state.namespace)
      end
    end)

    state
  end

  @spec matches_alert_rule?(performance_metric(), map()) :: boolean()
  defp matches_alert_rule?(metric, rule) do
    name_matches = String.contains?(metric.name, rule.metric_pattern)

    threshold_exceeded =
      case rule.comparison do
        :gt -> metric.value > rule.threshold
        :lt -> metric.value < rule.threshold
        :eq -> metric.value == rule.threshold
      end

    name_matches and threshold_exceeded
  end

  @spec trigger_performance_alert(performance_metric(), map(), ServiceRegistry.namespace()) :: :ok
  defp trigger_performance_alert(metric, rule, namespace) do
    alert = %{
      type: :performance_alert,
      severity: rule.severity,
      metric: metric,
      rule: rule,
      namespace: namespace,
      timestamp: DateTime.utc_now()
    }

    Logger.warning(
      "Performance alert triggered: #{metric.name} = #{metric.value} #{rule.comparison} #{rule.threshold}"
    )

    # Store alert event
    try do
      case ElixirScope.Foundation.Events.new_event(:performance_alert, alert) do
        {:ok, event} -> ElixirScope.Foundation.Events.store(event)
        _ -> :ok
      end
    rescue
      _ -> :ok
    end

    # Emit telemetry
    try do
      ElixirScope.Foundation.Telemetry.execute(
        [:foundation, :performance, :alert],
        %{value: metric.value, threshold: rule.threshold},
        %{metric: metric.name, severity: rule.severity}
      )
    rescue
      _ -> :ok
    end
  end

  @spec get_service_metrics(atom(), map()) :: [performance_metric()]
  defp get_service_metrics(service, metrics) do
    service_name = Atom.to_string(service)

    metrics
    |> Enum.filter(fn {{metric_name, _}, _} ->
      String.contains?(metric_name, service_name)
    end)
    |> Enum.flat_map(fn {_, metric_list} -> metric_list end)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
  end

  @spec get_period_start([performance_metric()]) :: DateTime.t()
  defp get_period_start([]), do: DateTime.utc_now()

  defp get_period_start(metrics) do
    metrics
    |> Enum.min_by(& &1.timestamp, DateTime)
    |> Map.get(:timestamp)
  end

  @spec get_period_end([performance_metric()]) :: DateTime.t()
  defp get_period_end([]), do: DateTime.utc_now()

  defp get_period_end(metrics) do
    metrics
    |> Enum.max_by(& &1.timestamp, DateTime)
    |> Map.get(:timestamp)
  end

  @spec calculate_service_aggregations([performance_metric()]) :: map()
  defp calculate_service_aggregations(metrics) do
    by_type = Enum.group_by(metrics, & &1.type)

    Enum.into(by_type, %{}, fn {type, type_metrics} ->
      values = Enum.map(type_metrics, & &1.value)

      aggregations =
        if length(values) > 0 do
          %{
            avg: Enum.sum(values) / length(values),
            min: Enum.min(values),
            max: Enum.max(values),
            count: length(values),
            p95: percentile(values, 0.95)
          }
        else
          %{avg: 0, min: 0, max: 0, count: 0, p95: 0}
        end

      {type, aggregations}
    end)
  end

  @spec cleanup_old_metrics(map()) :: map()
  defp cleanup_old_metrics(state) do
    # Keep 1 hour
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)

    new_metrics =
      state.metrics
      |> Enum.filter(fn {{_, time_bucket}, _} ->
        DateTime.compare(time_bucket, cutoff_time) != :lt
      end)
      |> Map.new()

    %{state | metrics: new_metrics, last_cleanup: Utils.monotonic_timestamp()}
  end

  @spec calculate_performance_baselines(map()) :: map()
  defp calculate_performance_baselines(state) do
    services = ServiceRegistry.list_services(state.namespace)

    baselines =
      Enum.into(services, %{}, fn service ->
        service_metrics = get_service_metrics(service, state.metrics)
        baseline = calculate_service_baseline(service_metrics)
        {service, baseline}
      end)

    %{state | baselines: baselines}
  end

  @spec calculate_service_baseline([performance_metric()]) :: map()
  defp calculate_service_baseline(metrics) do
    by_type = Enum.group_by(metrics, & &1.type)

    Enum.into(by_type, %{}, fn {type, type_metrics} ->
      values = Enum.map(type_metrics, & &1.value)

      # Need sufficient samples
      baseline =
        if length(values) >= 10 do
          %{
            baseline_avg: Enum.sum(values) / length(values),
            baseline_p95: percentile(values, 0.95),
            sample_count: length(values),
            calculated_at: DateTime.utc_now()
          }
        else
          %{
            baseline_avg: nil,
            baseline_p95: nil,
            sample_count: length(values),
            calculated_at: DateTime.utc_now()
          }
        end

      {type, baseline}
    end)
  end

  @spec perform_metric_aggregation(ServiceRegistry.namespace()) :: :ok
  defp perform_metric_aggregation(namespace) do
    # Perform background metric aggregation
    # This could include writing to external time-series databases
    Logger.debug("Performing metric aggregation for #{inspect(namespace)}")
    :ok
  end

  @spec load_alert_rules() :: [map()]
  defp load_alert_rules do
    [
      %{
        metric_pattern: "latency",
        # 10ms in microseconds
        threshold: 10_000,
        comparison: :gt,
        severity: :warning
      },
      %{
        metric_pattern: "error_rate",
        # 5% error rate
        threshold: 5.0,
        comparison: :gt,
        severity: :critical
      },
      %{
        metric_pattern: "throughput",
        # Less than 1 op/sec
        threshold: 1.0,
        comparison: :lt,
        severity: :warning
      }
    ]
  end

  @spec schedule_cleanup() :: reference()
  defp schedule_cleanup do
    # 5 minutes
    Process.send_after(self(), :cleanup_old_metrics, 300_000)
  end

  @spec schedule_baseline_calculation() :: reference()
  defp schedule_baseline_calculation do
    # 10 minutes
    Process.send_after(self(), :calculate_baselines, 600_000)
  end
end

defmodule ElixirScope.Foundation.Infrastructure.ServiceInstrumentation do
  @moduledoc """
  Automatic service instrumentation for performance monitoring.
  """

  defmacro __using__(opts) do
    quote do
      import ElixirScope.Foundation.Infrastructure.ServiceInstrumentation

      @before_compile ElixirScope.Foundation.Infrastructure.ServiceInstrumentation
      @service_metrics Keyword.get(unquote(opts), :metrics, [:latency, :throughput, :errors])
      @service_namespace Keyword.get(unquote(opts), :namespace, :production)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      defp emit_latency_metric(operation, duration_us) do
        ElixirScope.Foundation.Infrastructure.PerformanceMonitor.record_latency(
          @service_namespace,
          [:foundation, __MODULE__, operation],
          duration_us,
          %{module: __MODULE__, operation: operation}
        )
      end

      defp emit_throughput_metric(operation, ops_per_second) do
        ElixirScope.Foundation.Infrastructure.PerformanceMonitor.record_throughput(
          @service_namespace,
          [:foundation, __MODULE__, operation],
          ops_per_second,
          %{module: __MODULE__, operation: operation}
        )
      end

      defp emit_error_metric(operation, error_type) do
        ElixirScope.Foundation.Infrastructure.PerformanceMonitor.record_error_rate(
          @service_namespace,
          [:foundation, __MODULE__, operation],
          # 100% error rate for this operation
          100.0,
          %{module: __MODULE__, operation: operation, error_type: error_type}
        )
      end
    end
  end

  defmacro instrument_function(name, args_pattern \\ quote(do: args), do: block) do
    quote do
      def unquote(name)(unquote(args_pattern) = args) do
        start_time = System.monotonic_time(:microsecond)
        operation = unquote(name)

        try do
          result = unquote(block)
          duration = System.monotonic_time(:microsecond) - start_time

          emit_latency_metric(operation, duration)
          result
        rescue
          error ->
            duration = System.monotonic_time(:microsecond) - start_time
            emit_latency_metric(operation, duration)
            emit_error_metric(operation, error.__struct__)

            reraise error, __STACKTRACE__
        end
      end
    end
  end
end
