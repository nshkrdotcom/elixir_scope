defmodule ElixirScope.Foundation.Telemetry do
  @moduledoc """
  Telemetry and metrics collection for ElixirScope Foundation layer.

  Provides standardized telemetry events and metrics collection
  for monitoring ElixirScope performance and health.
  """

  require Logger
  # , Error} #, ErrorContext}
  alias ElixirScope.Foundation.{Utils}

  @telemetry_events [
    # Configuration events
    [:elixir_scope, :config, :get],
    [:elixir_scope, :config, :update],
    [:elixir_scope, :config, :validate],

    # Event system events
    [:elixir_scope, :events, :create],
    [:elixir_scope, :events, :serialize],
    [:elixir_scope, :events, :deserialize],

    # Performance events
    [:elixir_scope, :performance, :measurement],
    [:elixir_scope, :performance, :memory_usage]
  ]

  ## Public API

  @spec initialize() :: :ok
  def initialize do
    attach_default_handlers()
    Logger.debug("ElixirScope.Foundation.Telemetry initialized")
    :ok
  end

  @spec status() :: :ok
  def status, do: :ok

  @spec measure_event([atom(), ...], map(), (-> t)) :: t when t: var
  def measure_event(event_name, metadata \\ %{}, fun) when is_function(fun, 0) do
    start_time = Utils.monotonic_timestamp()

    # Don't wrap in ErrorContext - let exceptions propagate
    try do
      result = fun.()

      end_time = Utils.monotonic_timestamp()
      duration = end_time - start_time

      measurements = %{duration: duration, timestamp: end_time}
      :telemetry.execute(event_name, measurements, metadata)

      result
    rescue
      exception ->
        # Still measure the duration even if it failed
        end_time = Utils.monotonic_timestamp()
        duration = end_time - start_time

        measurements = %{duration: duration, timestamp: end_time}
        error_metadata = Map.put(metadata, :exception, exception)

        # Emit both the normal event and an error event
        :telemetry.execute(event_name, measurements, error_metadata)
        emit_error_event(event_name, metadata, {:error, exception})

        # Re-raise the exception so the test can catch it
        reraise exception, __STACKTRACE__
    end
  end

  @spec emit_counter([atom(), ...], map()) :: :ok
  def emit_counter(event_name, metadata \\ %{}) do
    measurements = %{count: 1, timestamp: Utils.monotonic_timestamp()}
    :telemetry.execute(event_name, measurements, metadata)
  end

  @spec emit_gauge(list(atom()), number(), map()) :: :ok
  def emit_gauge(event_name, value, metadata \\ %{}) do
    measurements = %{value: value, timestamp: Utils.monotonic_timestamp()}
    :telemetry.execute(event_name, measurements, metadata)
  end

  @spec get_metrics() :: %{
          foundation: %{
            uptime_ms: integer(),
            memory_usage: non_neg_integer(),
            process_count: non_neg_integer()
          },
          system: %{
            timestamp: integer(),
            process_count: non_neg_integer(),
            total_memory: non_neg_integer(),
            scheduler_count: pos_integer(),
            otp_release: binary()
          }
        }
  def get_metrics do
    %{
      foundation: %{
        uptime_ms: System.monotonic_time(:millisecond),
        memory_usage: :erlang.memory(:total),
        process_count: :erlang.system_info(:process_count)
      },
      system: Utils.system_stats()
    }
  end

  ## Private Functions

  @spec attach_default_handlers() :: :ok
  defp attach_default_handlers do
    # Attach a default handler for debugging in development
    if Application.get_env(:elixir_scope, :dev, []) |> Keyword.get(:debug_mode, false) do
      :telemetry.attach_many(
        "elixir-scope-debug-handler",
        @telemetry_events,
        &handle_debug_event/4,
        %{}
      )
    end

    :ok
  end

  @spec handle_debug_event(list(atom()), map(), map(), map()) :: :ok
  defp handle_debug_event(event_name, measurements, metadata, _config) do
    Logger.debug("""
    ElixirScope Telemetry Event:
      Event: #{inspect(event_name)}
      Measurements: #{inspect(measurements)}
      Metadata: #{inspect(metadata)}
    """)
  end

  @spec emit_error_event([atom(), ...], map(), {:error, struct()}) :: :ok
  defp emit_error_event(event_name, metadata, {:error, err}) do
    error_metadata =
      if err.__struct__ == ElixirScope.Foundation.Error do
        Map.merge(metadata, %{
          error_code: err.code,
          error_message: err.message
        })
      else
        Map.merge(metadata, %{
          error_type: :external_error,
          error_message: inspect(err)
        })
      end

    measurements = %{error_count: 1, timestamp: Utils.monotonic_timestamp()}
    error_event_name = event_name ++ [:error]
    :telemetry.execute(error_event_name, measurements, error_metadata)
  end
end
