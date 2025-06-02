# Registry Telemetry Handlers Examples
#
# This file demonstrates how to set up telemetry handlers for monitoring
# ElixirScope Foundation Registry operations in production.

defmodule RegistryTelemetryHandlers do
  @moduledoc """
  Example telemetry handlers for monitoring ElixirScope Foundation Registry performance.

  These handlers can be used to integrate Registry metrics with your monitoring
  infrastructure (Prometheus, StatsD, DataDog, etc.).
  """

  require Logger

  @doc """
  Sets up all Registry telemetry handlers for production monitoring.

  Call this during application startup to begin collecting metrics.
  """
  def setup_handlers do
    # Attach lookup performance handler
    :telemetry.attach(
      "registry-lookup-performance",
      [:elixir_scope, :foundation, :registry, :lookup],
      &handle_lookup_metrics/4,
      %{}
    )

    # Attach registration performance handler
    :telemetry.attach(
      "registry-registration-performance",
      [:elixir_scope, :foundation, :registry, :register],
      &handle_registration_metrics/4,
      %{}
    )

    Logger.info("Registry telemetry handlers attached successfully")
  end

  @doc """
  Removes all Registry telemetry handlers.

  Useful for testing or graceful shutdown.
  """
  def remove_handlers do
    :telemetry.detach("registry-lookup-performance")
    :telemetry.detach("registry-registration-performance")
    Logger.info("Registry telemetry handlers detached")
  end

  ## Private Handler Functions

  defp handle_lookup_metrics(_event_name, measurements, metadata, _config) do
    # Extract metrics
    duration_us = measurements.duration
    duration_ms = duration_us / 1000

    # Log performance metrics
    Logger.debug(fn ->
      "Registry lookup: #{metadata.namespace} -> #{metadata.service} " <>
      "in #{Float.round(duration_ms, 2)}ms (#{metadata.result})"
    end)

    # Send to monitoring system
    case metadata.result do
      :found ->
        # Successful lookup metrics
        emit_counter("registry.lookup.success", metadata)
        emit_histogram("registry.lookup.duration_ms", duration_ms, metadata)

      :not_found ->
        # Missing service metrics
        emit_counter("registry.lookup.not_found", metadata)
        emit_histogram("registry.lookup.duration_ms", duration_ms, metadata)

        # Alert if we're looking up production services that don't exist
        if production_namespace?(metadata.namespace) do
          Logger.warning("Production service not found: #{inspect(metadata)}")
          emit_counter("registry.lookup.production_miss", metadata)
        end
    end

    # Performance alerting
    if duration_ms > 5.0 do
      Logger.warning("Slow registry lookup: #{duration_ms}ms for #{inspect(metadata)}")
      emit_counter("registry.lookup.slow", metadata)
    end
  end

  defp handle_registration_metrics(_event_name, measurements, metadata, _config) do
    duration_us = measurements.duration
    duration_ms = duration_us / 1000

    Logger.debug(fn ->
      "Registry registration: #{metadata.namespace} -> #{metadata.service} " <>
      "in #{Float.round(duration_ms, 2)}ms (#{metadata.result})"
    end)

    # Send to monitoring system
    case metadata.result do
      :ok ->
        emit_counter("registry.register.success", metadata)
        emit_histogram("registry.register.duration_ms", duration_ms, metadata)

      {:error, reason} ->
        emit_counter("registry.register.error", Map.put(metadata, :error_reason, reason))

        Logger.warning("Registry registration failed: #{inspect(reason)} for #{inspect(metadata)}")
    end

    # Performance alerting
    if duration_ms > 10.0 do
      Logger.warning("Slow registry registration: #{duration_ms}ms for #{inspect(metadata)}")
      emit_counter("registry.register.slow", metadata)
    end
  end

  ## Monitoring Integration Functions

  # These functions should be implemented to integrate with your monitoring system

  defp emit_counter(metric_name, metadata) do
    # Example: Send to StatsD
    # StatsD.increment(metric_name, tags: format_tags(metadata))

    # Example: Send to Prometheus
    # :prometheus_counter.inc(metric_name, format_labels(metadata))

    # For demonstration, just log
    Logger.debug("Counter: #{metric_name} with tags: #{inspect(format_tags(metadata))}")
  end

  defp emit_histogram(metric_name, value, metadata) do
    # Example: Send to StatsD
    # StatsD.histogram(metric_name, value, tags: format_tags(metadata))

    # Example: Send to Prometheus
    # :prometheus_histogram.observe(metric_name, format_labels(metadata), value)

    # For demonstration, just log
    Logger.debug("Histogram: #{metric_name} = #{value} with tags: #{inspect(format_tags(metadata))}")
  end

  defp format_tags(metadata) do
    [
      "namespace:#{format_namespace(metadata.namespace)}",
      "service:#{metadata.service}",
      "node:#{node()}"
    ]
  end

  defp format_labels(metadata) do
    [
      namespace: format_namespace(metadata.namespace),
      service: to_string(metadata.service),
      node: to_string(node())
    ]
  end

  defp format_namespace({type, ref}) when is_reference(ref) do
    "#{type}_#{ref_to_string(ref)}"
  end
  defp format_namespace(namespace) when is_atom(namespace) do
    to_string(namespace)
  end
  defp format_namespace(namespace) do
    inspect(namespace)
  end

  defp ref_to_string(ref) do
    ref
    |> :erlang.ref_to_list()
    |> List.to_string()
    |> String.replace(~r/[^\w]/, "_")
  end

  defp production_namespace?(:production), do: true
  defp production_namespace?({:production, _}), do: true
  defp production_namespace?(_), do: false
end

# Example usage in your application startup:
#
# defmodule MyApp.Application do
#   use Application
#
#   def start(_type, _args) do
#     children = [
#       # ... your other children
#     ]
#
#     # Setup Registry telemetry monitoring
#     RegistryTelemetryHandlers.setup_handlers()
#
#     opts = [strategy: :one_for_one, name: MyApp.Supervisor]
#     Supervisor.start_link(children, opts)
#   end
# end

# Example custom monitoring integration:
defmodule CustomRegistryMonitoring do
  @moduledoc """
  Example of custom Registry monitoring with business logic.
  """

  def setup_business_logic_handlers do
    # Monitor service discovery patterns
    :telemetry.attach(
      "registry-service-discovery",
      [:elixir_scope, :foundation, :registry, :lookup],
      &track_service_discovery_patterns/4,
      %{}
    )

    # Monitor service lifecycle
    :telemetry.attach(
      "registry-service-lifecycle",
      [:elixir_scope, :foundation, :registry, :register],
      &track_service_lifecycle/4,
      %{}
    )
  end

  defp track_service_discovery_patterns(_event, measurements, metadata, _config) do
    # Track which services are being looked up frequently
    # This can help identify hot paths and optimize service placement

    service_key = {metadata.namespace, metadata.service}

    # Increment lookup counter (you'd use a real counter here)
    # CounterStorage.increment("service_lookups", service_key)

    # Track lookup patterns for optimization
    if measurements.duration > 1000 do  # > 1ms
      # Log slow lookups for investigation
      # SlowQueryTracker.record(service_key, measurements.duration, metadata)
    end
  end

  defp track_service_lifecycle(_event, _measurements, metadata, _config) do
    case metadata.result do
      :ok ->
        # Service successfully registered
        # LifecycleTracker.record_registration(metadata.namespace, metadata.service)

      {:error, {:already_registered, _pid}} ->
        # Attempted to register already existing service
        # This might indicate a bug or unexpected restart
        Logger.warning("Attempted to re-register service: #{inspect(metadata)}")

      {:error, reason} ->
        # Registration failed for other reasons
        Logger.error("Service registration failed: #{inspect(reason)} for #{inspect(metadata)}")
    end
  end
end
