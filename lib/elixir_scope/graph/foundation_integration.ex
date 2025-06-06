defmodule ElixirScope.Graph.FoundationIntegration do
  @moduledoc """
  Foundation layer integration for Graph module.

  Provides telemetry, configuration, and performance monitoring integration
  with the Foundation services for all graph operations.
  """

  @doc """
  Measure algorithm execution time and emit telemetry metrics.

  Wraps algorithm execution with timing measurements and emits detailed
  telemetry data including execution time, input characteristics, and results.

  ## Examples

      iex> measure_algorithm(:shortest_path, %{nodes: 100}, fn -> :some_result end)
      :some_result
  """
  @spec measure_algorithm(atom(), map(), (-> any())) :: any()
  def measure_algorithm(algorithm_name, metadata, algorithm_fn) do
    start_time = System.monotonic_time(:microsecond)

    try do
      result = algorithm_fn.()

      end_time = System.monotonic_time(:microsecond)
      duration_us = end_time - start_time

      # Emit telemetry for successful execution
      emit_algorithm_metrics(algorithm_name, metadata, duration_us, :success)

      result
    rescue
      error ->
        end_time = System.monotonic_time(:microsecond)
        duration_us = end_time - start_time

        # Emit telemetry for failed execution
        emit_algorithm_metrics(algorithm_name, metadata, duration_us, :error)

        reraise error, __STACKTRACE__
    end
  end

  @doc """
  Emit performance metrics for graph operations.

  ## Examples

      iex> emit_metrics(:graph_created, %{type: :directed})
      :ok
  """
  @spec emit_metrics(atom(), map()) :: :ok
  def emit_metrics(event_name, metadata \\ %{}) do
    try do
      Foundation.Telemetry.emit_counter(
        [:elixir_scope, :graph, event_name],
        Map.merge(metadata, %{layer: :graph, timestamp: System.system_time(:millisecond)})
      )
    rescue
      _ ->
        # Gracefully handle telemetry failures - don't break graph operations
        :ok
    end
  end

  @doc """
  Get configuration values for graph algorithms.

  Retrieves configuration from Foundation's ConfigServer with sensible defaults.

  ## Examples

      iex> get_config(:graph_algorithms)
      %{pagerank: %{max_iterations: 100, damping_factor: 0.85}}
  """
  @spec get_config(atom()) :: map()
  def get_config(config_key) do
    if Code.ensure_loaded?(Foundation.Config) do
      try do
        case Foundation.Config.get([config_key]) do
          {:ok, config} -> config
        end
      rescue
        _ ->
          # Fallback to defaults if Foundation config is unavailable
          default_config(config_key)
      end
    else
      # Foundation not available during compilation/analysis
      default_config(config_key)
    end
  end

  @doc """
  Emit gauge metrics for algorithm performance.

  ## Examples

      iex> emit_gauge(:algorithm_duration, 1500, %{algorithm: :shortest_path})
      :ok
  """
  @spec emit_gauge(atom(), number(), map()) :: :ok
  def emit_gauge(metric_name, value, metadata \\ %{}) do
    try do
      Foundation.Telemetry.emit_gauge(
        [:elixir_scope, :graph, metric_name],
        value,
        Map.merge(metadata, %{layer: :graph, timestamp: System.system_time(:millisecond)})
      )
    rescue
      _ ->
        # Gracefully handle telemetry failures
        :ok
    end
  end

  @doc """
  Check if a graph operation should use parallel processing.

  Based on Foundation configuration and graph size characteristics.

  ## Examples

      iex> should_use_parallel_processing?(%{nodes: 5000, edges: 10000})
      true

      iex> should_use_parallel_processing?(%{nodes: 100, edges: 200})
      false
  """
  @spec should_use_parallel_processing?(map()) :: boolean()
  def should_use_parallel_processing?(graph_metadata) do
    config = get_config(:graph_performance)
    threshold = Map.get(config, :large_graph_threshold, 1000)
    parallel_enabled = Map.get(config, :parallel_processing, true)

    node_count = Map.get(graph_metadata, :nodes, 0)

    parallel_enabled and node_count >= threshold
  end

  # Private helper functions

  @spec emit_algorithm_metrics(atom(), map(), non_neg_integer(), atom()) :: :ok
  defp emit_algorithm_metrics(algorithm_name, metadata, duration_us, status) do
    base_metadata = %{
      algorithm: algorithm_name,
      status: status,
      layer: :graph,
      timestamp: System.system_time(:millisecond)
    }

    combined_metadata = Map.merge(metadata, base_metadata)

    # Emit duration gauge
    emit_gauge(:algorithm_duration_microseconds, duration_us, combined_metadata)

    # Emit count metric
    emit_metrics(:algorithm_execution, combined_metadata)

    # Emit performance classification
    performance_class = classify_performance(duration_us, metadata)

    emit_metrics(
      :algorithm_performance_class,
      Map.put(combined_metadata, :performance_class, performance_class)
    )

    :ok
  end

  @spec classify_performance(non_neg_integer(), map()) :: atom()
  defp classify_performance(duration_us, metadata) do
    _node_count = Map.get(metadata, :nodes, 0)

    cond do
      # < 1ms
      duration_us < 1_000 -> :fast
      # < 10ms
      duration_us < 10_000 -> :normal
      # < 100ms
      duration_us < 100_000 -> :slow
      # < 1s
      duration_us < 1_000_000 -> :very_slow
      # > 1s
      true -> :extremely_slow
    end
  end

  @spec default_config(atom()) :: map()
  defp default_config(:graph_algorithms) do
    %{
      pagerank: %{
        max_iterations: 100,
        damping_factor: 0.85,
        tolerance: 1.0e-6
      },
      community_detection: %{
        resolution: 1.0,
        randomness: 0.01
      },
      centrality: %{
        normalize: true,
        weighted: false
      }
    }
  end

  defp default_config(:graph_performance) do
    %{
      large_graph_threshold: 1000,
      parallel_processing: true,
      cache_enabled: true,
      max_memory_mb: 512
    }
  end

  defp default_config(_) do
    %{}
  end
end
